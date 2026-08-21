@tool
extends Node2D
## 关卡基类 - 提供公共的场景构建方法

class_name LevelBaseV2

var player: CharacterBody2D
var hud_layer: CanvasLayer
var dialogue_layer: CanvasLayer
var _hint_labels: Array[Dictionary] = []
const HINT_DURATION: float = 3.0
const HINT_FADE_TIME: float = 0.5
const HINT_LINE_HEIGHT: int = 80
var _floor_text_label: Label
var _floor_name: String = ""
var _signal_callbacks: Array[Dictionary] = []
var _loop_tweens: Array[Tween] = []  # 无限循环tween，场景切换前需kill
var _exiting: bool = false
var _stamina_bar: ProgressBar
var _sanity_bar: ProgressBar
var _battery_bar: ProgressBar
var _status_container: HBoxContainer
var _stamina_label: Label
var _sanity_label: Label
var _battery_label: Label
var atmosphere: AtmosphereLayer
var darkness: DarknessLayer
var player_lighting: Node2D
var rule_paper: Control  # 规则纸条UI
var _player_in_light_count: int = 0
# 房间天花板系统（房间内外视野隔离）
var _room_ceilings: Dictionary = {}  # room_id → {ceiling, rect}
var _outside_masks: Array = []       # 4个遮罩ColorRect（进入房间时遮挡外部）
var _current_room_id: String = ""
var _room_detection_enabled: bool = false  # 场景完全初始化后才开启
var _mask_top: ColorRect
var _mask_bottom: ColorRect
var _mask_left: ColorRect
var _mask_right: ColorRect
var _depth_sort_layer: Node2D
const LIGHT_SANITY_RECOVERY: float = 2.0
const ELEVATOR_DOOR_TEX_PATH := "res://assets/sprites/_0013_电梯门.png"
const ELEVATOR_DOOR_OPEN_TEX_PATH := "res://assets/sprites/打开的电梯门.png"

# 缓存的灯光纹理（避免每次 add_room_light 都重新生成）
var _cached_circle_texture_64: ImageTexture = null
var _cached_circle_texture_32: ImageTexture = null
@export var WALL_FRONT_FACE_DEPTH: float = 22.0  ## 水平墙正面高度
@export var WALL_SIDE_FACE_DEPTH: float = 5.0   ## 竖向墙侧面宽度

## 当前场景音频ID（对应 GameConfig.BGM / GameConfig.AMBIENCE 的键名）
## 子类设置后 setup_ui() 会自动播放
var scene_audio_id: String = ""

# 世界标签 UI 系统（标签在 CanvasLayer 中渲染，不受相机缩放影响）
var _world_label_layer: CanvasLayer
var _world_label_container: Control
var _tracked_labels: Array = []  # [{label: Label, world_pos: Vector2}]
var _camera_zoom_factor: float = 6.0

## 编辑器模式：递归设置所有子节点的 owner，使其在编辑器场景树中可选中
func _editor_set_owners(root: Node, owner: Node) -> void:
	for child in root.get_children():
		child.set_owner(owner)
		_editor_set_owners(child, owner)

func _process(_delta: float) -> void:
	# 更新灯光区域状态（理智恢复由 PlayerStats._process 统一处理）
	if PlayerStats and "in_light_area" in PlayerStats:
		PlayerStats.in_light_area = _player_in_light_count > 0
	_update_world_labels()

## 递归设置所有世界空间Label为线性过滤（防止摄像头缩放时文字模糊）
static func fix_label_filter(node: Node) -> void:
	if node is CanvasLayer:
		return  # 跳过UI层
	if node is Label:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for child in node.get_children():
		fix_label_filter(child)

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")

func setup_player(pos: Vector2, zoom: float = 6.0) -> CharacterBody2D:
	_camera_zoom_factor = zoom
	player = PLAYER_SCENE.instantiate()
	player.position = pos

	# 获取场景中已有的节点
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	var col: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	var area: Area2D = player.get_node_or_null("InteractionArea")
	var cam: Camera2D = player.get_node_or_null("Camera2D")

	# 配置精灵（运行时加载实际贴图）
	if sprite:
		sprite.texture = GameManager.load_char_texture("sister", 16, 20)
		GameManager.fit_character_sprite(sprite, "sister")
		player.sprite = sprite

	# 配置碰撞（用 GameManager 的标准尺寸）
	if col:
		GameManager.fit_character_collision(col, "sister")
		player.collision = col

	# 配置交互区域
	if area:
		player.interaction_area = area

	# 配置摄像机
	if cam:
		cam.zoom = Vector2(zoom, zoom)
		player.camera = cam

	# 添加角色阴影遮挡体
	player.add_child(GameManager.create_character_shadow_occluder("sister"))

	# 玩家照明系统（手机/手电筒/火柴）
	player_lighting = load("res://scripts/items/player_lighting.gd").new()
	player_lighting.flashlight_battery = PlayerStats.saved_flashlight_battery
	player.add_child(player_lighting)

	# 所有子节点就绪后再加入场景树
	_ensure_depth_sort_layer().add_child(player)

	return player

func _build_arrival_elevator(pos: Vector2) -> void:
	# 到达电梯（玩家从这里出来，显示打开的门）
	var door_center := pos + Vector2(0, -20)
	var door_size := Vector2(72, 60)
	var door_container = Node2D.new()
	add_child(door_container)
	if ResourceLoader.exists(ELEVATOR_DOOR_OPEN_TEX_PATH):
		var door = Sprite2D.new()
		door.texture = load(ELEVATOR_DOOR_OPEN_TEX_PATH)
		door.centered = true
		door.position = door_center
		var tex_size = door.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			door.scale = Vector2(door_size.x / tex_size.x, door_size.y / tex_size.y)
		door_container.add_child(door)
	else:
		add_elevator_door_visual(door_center, door_size)
	add_elevator_door_blocker(door_center, door_size)
	var elev_label_text = "电梯" if Engine.is_editor_hint() else LocaleManager.world_text("电梯")
	var elev_label = create_world_label(elev_label_text, pos + Vector2(-14, -58), 14, Color(0.4, 0.4, 0.45))

func add_elevator_door_visual(center: Vector2, size: Vector2 = Vector2(72, 60)) -> Node:
	var top_left := center - size * 0.5
	if ResourceLoader.exists(ELEVATOR_DOOR_TEX_PATH):
		var door = Sprite2D.new()
		door.texture = load(ELEVATOR_DOOR_TEX_PATH)
		door.centered = true
		door.position = center
		var tex_size = door.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			door.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
		add_child(door)
		return door

	var fallback = Node2D.new()
	add_child(fallback)
	var door_left = ColorRect.new()
	door_left.color = Color(0.18, 0.18, 0.2)
	door_left.position = top_left + Vector2(0, 2)
	door_left.size = Vector2(4, size.y - 2)
	fallback.add_child(door_left)
	var door_right = ColorRect.new()
	door_right.color = Color(0.18, 0.18, 0.2)
	door_right.position = top_left + Vector2(size.x - 4, 2)
	door_right.size = Vector2(4, size.y - 2)
	fallback.add_child(door_right)
	var door_top = ColorRect.new()
	door_top.color = Color(0.18, 0.18, 0.2)
	door_top.position = top_left
	door_top.size = Vector2(size.x, 4)
	fallback.add_child(door_top)
	return fallback

func add_elevator_door_blocker(center: Vector2, size: Vector2 = Vector2(72, 60)) -> StaticBody2D:
	var blocker = StaticBody2D.new()
	blocker.collision_layer = 4
	blocker.position = center
	add_child(blocker)
	var blocker_col = CollisionShape2D.new()
	var blocker_shape = RectangleShape2D.new()
	blocker_shape.size = size
	blocker_col.shape = blocker_shape
	blocker.add_child(blocker_col)
	return blocker

func setup_ui(floor_name: String) -> void:
	_floor_name = floor_name
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 30
	top_bar.offset_top = 15
	top_bar.offset_right = -30
	top_bar.offset_bottom = 60
	hud_layer.add_child(top_bar)
	
	_floor_text_label = Label.new()
	_floor_text_label.text = LocaleManager.world_text(_floor_name)
	_floor_text_label.add_theme_font_size_override("font_size", 30)
	_floor_text_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_bar.add_child(_floor_text_label)
	

	
	# 状态HUD（饱食度条 + 异常状态图标）
	_setup_status_hud(hud_layer)
	LocaleManager.locale_changed.connect(_on_locale_changed_status)
	
	# 规则纸条UI
	var rules_layer = CanvasLayer.new()
	rules_layer.layer = 15
	add_child(rules_layer)
	rule_paper = load("res://scenes/ui/rule_paper_ui.tscn").instantiate()
	rules_layer.add_child(rule_paper)
	
	# 背包UI
	var inv_layer = CanvasLayer.new()
	inv_layer.layer = 15
	inv_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inv_layer)
	var inv_ui = Control.new()
	inv_ui.set_script(load("res://scripts/ui/inventory_ui.gd"))
	inv_layer.add_child(inv_ui)
	
	# 对话UI（使用dialogue_ui.tscn，内含头像系统）
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	dialogue_layer = dlg_scene.instantiate()
	add_child(dialogue_layer)
	
	# 氛围效果层
	atmosphere = AtmosphereLayer.new()
	add_child(atmosphere)
	
	# 黑暗层（CanvasModulate，让未照亮区域变暗）
	# 默认关闭（brightness=1.0），关卡脚本里调用 enable_darkness() 开启
	darkness = DarknessLayer.new()
	add_child(darkness)
	darkness.set_darkness(1.0)  # 默认全亮，关卡手动开暗
	
	# 触屏控件（仅移动端显示，摇杆+按钮）
	var touch_ctrl = load("res://scripts/ui/touch_controls.gd").new()
	add_child(touch_ctrl)
	move_child(touch_ctrl, 0)  # 移到最前，确保优先处理触屏输入
	
	# 自动播放音频（如果 scene_audio_id 已设置）
	_auto_play_audio()
	
	# 修正世界空间文字过滤（防止摄像头缩放导致模糊）
	call_deferred("_apply_label_filter")

## 打开规则纸条并等待玩家关闭
func show_rule_paper_and_wait() -> void:
	if rule_paper and rule_paper.has_method("open"):
		rule_paper.open()
		await rule_paper.closed

func _exit_tree() -> void:
	_exiting = true
	# 杀掉所有无限循环tween
	for tw in _loop_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	for entry in _signal_callbacks:
		if entry["signal"].is_connected(entry["callable"]):
			entry["signal"].disconnect(entry["callable"])
	_signal_callbacks.clear()

func _apply_label_filter() -> void:
	fix_label_filter(self)

## 初始化世界标签 UI 层（首次调用 create_world_label 时自动调用）
func _init_world_label_ui() -> void:
	_world_label_layer = CanvasLayer.new()
	_world_label_layer.layer = 4  # 在 HUD(5) 和对话(10) 之下
	_world_label_layer.name = "WorldLabelUI"
	add_child(_world_label_layer)
	_world_label_container = Control.new()
	_world_label_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_label_layer.add_child(_world_label_container)

func set_world_labels_visible(visible: bool) -> void:
	if _world_label_container:
		_world_label_container.visible = visible

func _world_label_scale_multiplier() -> float:
	return clampf(1.0 + (_camera_zoom_factor - 1.0) * 0.22, 1.0, 1.45)

## 创建一个跟踪世界坐标的 UI 标签（不受相机缩放影响，文字清晰）
## font_size 为世界空间原始大小，内部使用较温和的缩放倍数，避免遮挡白模
func create_world_label(text: String, world_pos: Vector2, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	if not _world_label_layer:
		_init_world_label_ui()
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(round(font_size * _world_label_scale_multiplier())))
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_label_container.add_child(lbl)
	_tracked_labels.append({"label": lbl, "world_pos": world_pos})
	return lbl

func create_tracked_world_label(text: String, target: Node2D, offset: Vector2 = Vector2.ZERO, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	if not _world_label_layer:
		_init_world_label_ui()
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(round(font_size * _world_label_scale_multiplier())))
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_label_container.add_child(lbl)
	_tracked_labels.append({"label": lbl, "target": target, "offset": offset, "world_pos": target.global_position + offset})
	return lbl

## 每帧更新所有跟踪标签的屏幕位置
func _update_world_labels() -> void:
	if not player or not player.camera or _tracked_labels.is_empty():
		return
	var vp_size = get_viewport().get_visible_rect().size
	var zoom = player.camera.zoom
	var cam_center = player.camera.get_screen_center_position()
	var i := 0
	while i < _tracked_labels.size():
		var entry = _tracked_labels[i]
		var label = entry["label"]
		if not is_instance_valid(label):
			_tracked_labels.remove_at(i)
			continue
		var world_pos: Vector2 = entry["world_pos"]
		if entry.has("target"):
			var target = entry["target"]
			if not is_instance_valid(target):
				label.queue_free()
				_tracked_labels.remove_at(i)
				continue
			world_pos = target.global_position + entry.get("offset", Vector2.ZERO)
			entry["world_pos"] = world_pos
			_tracked_labels[i] = entry
		var sp = (world_pos - cam_center) * zoom + vp_size / 2.0
		label.position = sp
		i += 1

func _auto_play_audio() -> void:
	if scene_audio_id == "":
		return
	var bgm = GameConfig.get_bgm(scene_audio_id)
	if bgm:
		AudioManager.play_bgm(bgm)
	var amb = GameConfig.get_ambience(scene_audio_id)
	if amb:
		AudioManager.play_ambience(amb)

func play_sfx(sfx_id: String) -> void:
	## 快捷播放音效（自动查 GameConfig）
	var stream = GameConfig.get_sfx(sfx_id)
	if stream:
		AudioManager.play_sfx(stream)

func show_hint(text: String, duration: float = HINT_DURATION) -> void:
	# 将已有提示上移
	for entry in _hint_labels:
		var lbl = entry.get("label")
		if is_instance_valid(lbl):
			lbl.position.y -= HINT_LINE_HEIGHT

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -750
	label.offset_right = 750
	label.offset_top = -180
	label.offset_bottom = -90
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	label.text = text
	label.modulate.a = 1.0
	hud_layer.add_child(label)

	var entry: Dictionary = {"label": label, "timer": duration}
	_hint_labels.append(entry)

	# 持续duration秒后淡出
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(label, "modulate:a", 0.0, HINT_FADE_TIME)
	tw.tween_callback(_remove_hint.bind(entry))

func _remove_hint(entry: Dictionary) -> void:
	var label: Label = entry.get("label")
	var idx = _hint_labels.find(entry)
	if idx >= 0:
		_hint_labels.remove_at(idx)
	if is_instance_valid(label):
		label.queue_free()
	# 将剩余提示移回原位
	for remaining in _hint_labels:
		var lbl = remaining.get("label")
		if is_instance_valid(lbl):
			lbl.position.y += HINT_LINE_HEIGHT

func enable_darkness(brightness: float = 0.15, fade_time: float = 2.0) -> void:
	## 开启黑暗环境（未被光源照亮的区域变暗）
	if darkness:
		darkness.fade_to_dark(brightness, fade_time)
	PlayerStats.darkness_environment = true

func disable_darkness(fade_time: float = 1.0) -> void:
	## 关闭黑暗环境（恢复全亮）
	if darkness:
		darkness.fade_to_bright(fade_time)
	PlayerStats.darkness_environment = false

func add_room_light(pos: Vector2, energy: float = 1.8, scale: float = 2.5) -> PointLight2D:
	## 在房间内放置暖色灯光
	var light = PointLight2D.new()
	light.position = pos
	light.texture = _make_circle_light_texture(64)
	light.energy = energy
	light.texture_scale = scale
	light.color = Color(1.0, 0.9, 0.7)
	light.shadow_enabled = true
	# 同时照亮 light_mask=1（环境）和 light_mask=2（玩家）
	light.range_item_cull_mask = 3
	add_child(light)
	_add_light_detection_area(pos, scale * 32.0)
	return light

func add_corridor_light(pos: Vector2, energy: float = 1.2, scale: float = 1.8) -> PointLight2D:
	## 在走廊放置冷白灯光
	var light = PointLight2D.new()
	light.position = pos
	light.texture = _make_circle_light_texture(64)
	light.energy = energy
	light.texture_scale = scale
	light.color = Color(0.85, 0.9, 1.0)
	light.shadow_enabled = true
	# 同时照亮 light_mask=1（环境）和 light_mask=2（玩家）
	light.range_item_cull_mask = 3
	add_child(light)
	_add_light_detection_area(pos, scale * 32.0)
	return light

func add_flickering_light(pos: Vector2, energy: float = 1.2, scale: float = 1.8) -> PointLight2D:
	## 走廊闪烁灯 — 随机明暗跳动，制造不安氛围
	var light = add_corridor_light(pos, energy, scale)
	if not Engine.is_editor_hint():
		var tw = create_tween().set_loops()
		# 不规则闪烁模式：正常→暗→正常→快闪→暗
		tw.tween_property(light, "energy", energy * 0.3, randf_range(0.05, 0.1))
		tw.tween_property(light, "energy", energy, randf_range(0.05, 0.15))
		tw.tween_interval(randf_range(1.0, 3.0))
		tw.tween_property(light, "energy", energy * 0.1, 0.03)
		tw.tween_property(light, "energy", energy * 0.8, 0.05)
		tw.tween_property(light, "energy", energy * 0.15, 0.04)
		tw.tween_property(light, "energy", energy, 0.08)
		tw.tween_interval(randf_range(2.0, 5.0))
		_loop_tweens.append(tw)
	return light

func add_broken_light(pos: Vector2, scale: float = 1.8) -> PointLight2D:
	## 损坏灯 — 完全熄灭，只有非常微弱的残光偶尔闪一下
	var light = PointLight2D.new()
	light.position = pos
	light.texture = _make_circle_light_texture(64)
	light.energy = 0.0
	light.texture_scale = scale
	light.color = Color(0.85, 0.9, 1.0)
	light.shadow_enabled = true
	add_child(light)
	if not Engine.is_editor_hint():
		var tw = create_tween().set_loops()
		tw.tween_interval(randf_range(4.0, 8.0))
		tw.tween_property(light, "energy", 0.4, 0.03)
		tw.tween_property(light, "energy", 0.0, 0.05)
		tw.tween_interval(0.1)
		tw.tween_property(light, "energy", 0.2, 0.02)
		tw.tween_property(light, "energy", 0.0, 0.08)
		_loop_tweens.append(tw)
	return light

func _add_light_detection_area(pos: Vector2, radius: float) -> void:
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1  # 检测玩家
	add_child(area)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			_player_in_light_count += 1
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			_player_in_light_count = maxi(_player_in_light_count - 1, 0)
	)

func _make_circle_light_texture(size: int) -> ImageTexture:
	# 使用缓存避免重复生成（灯光纹理只有 64 和 32 两种尺寸）
	if size == 64:
		if _cached_circle_texture_64 == null:
			_cached_circle_texture_64 = TextureUtils.make_circle_texture(64)
		return _cached_circle_texture_64
	elif size == 32:
		if _cached_circle_texture_32 == null:
			_cached_circle_texture_32 = TextureUtils.make_circle_texture(32)
		return _cached_circle_texture_32
	return TextureUtils.make_circle_texture(size)

func enable_stamina() -> void:
	## 快捷启用体力系统
	PlayerStats.stamina_enabled = true
	if _stamina_bar:
		_stamina_bar.visible = true

func add_dust_ambient(pos: Vector2, area_size: Vector2 = Vector2(60, 40)) -> GPUParticles2D:
	## 环境灰尘粒子 — 在特定区域（角落、阁楼）飘浮细小灰尘
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.amount = 8
	particles.lifetime = 4.0
	particles.speed_scale = 0.3
	particles.z_index = 2
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 1, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area_size.x / 2, area_size.y / 2, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.color = Color(0.8, 0.75, 0.65, 0.25)
	
	var alpha_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	
	particles.process_material = mat
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for px in 4:
		for py in 4:
			var dist = Vector2(px - 2, py - 2).length() / 2.0
			var a = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	particles.texture = ImageTexture.create_from_image(img)
	add_child(particles)
	return particles

func add_door_light_leak(pos: Vector2, width: float = 30.0, direction: String = "bottom") -> PointLight2D:
	## 门缝漏光 — 关闭的门底部/侧边透出一线暗黄光
	## direction: "bottom"(门底), "left"(左侧), "right"(右侧)
	var leak = ColorRect.new()
	leak.color = Color(0.9, 0.75, 0.4, 0.15)
	match direction:
		"bottom":
			leak.position = Vector2(pos.x - width / 2, pos.y)
			leak.size = Vector2(width, 3)
		"left":
			leak.position = Vector2(pos.x - 2, pos.y - width / 2)
			leak.size = Vector2(3, width)
		"right":
			leak.position = Vector2(pos.x, pos.y - width / 2)
			leak.size = Vector2(3, width)
	leak.z_index = 1
	add_child(leak)
	
	# 漏光处微弱灯光
	var light = PointLight2D.new()
	light.position = pos
	light.color = Color(1.0, 0.85, 0.5)
	light.energy = 0.15
	light.texture = _make_circle_light_texture(32)
	light.texture_scale = 1.5
	add_child(light)

	# 轻微呼吸效果（灯光闪烁暗示房间里有东西）
	if not Engine.is_editor_hint():
		var tw = create_tween().set_loops()
		tw.tween_property(light, "energy", 0.08, randf_range(1.5, 2.5))
		tw.tween_property(light, "energy", 0.15, randf_range(1.5, 2.5))
		_loop_tweens.append(tw)
	return light

func add_floor_zone(top_left: Vector2, size: Vector2, color: Color, floor_type: String = "") -> void:
	var tex_path: String = ""
	if floor_type == "corridor":
		tex_path = "res://assets/sprites/_0000_走廊地板.png"
	elif floor_type == "room":
		tex_path = "res://assets/sprites/_0001_房间木地板.png"
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var zone = TextureRect.new()
		zone.position = top_left
		zone.size = size
		zone.texture = load(tex_path)
		zone.stretch_mode = TextureRect.STRETCH_TILE
		zone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		zone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		zone.modulate = Color(0.24, 0.21, 0.18)
		add_child(zone)
	else:
		var zone = ColorRect.new()
		zone.position = top_left
		zone.size = size
		zone.color = color
		add_child(zone)

func add_wall(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	var shape = CollisionShape2D.new()
	shape.position = pos
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	parent.add_child(shape)
	parent.add_to_group("nav_obstacle")  # 供导航网格烘焙使用

func add_visible_wall(
		parent: Node2D,
		pos: Vector2,
		size: Vector2,
		color: Color = Color(0.1, 0.08, 0.07),
		show_cap: bool = true,
		show_front_face: bool = true,
		show_side_face: bool = true,
		face_normal: Vector2 = Vector2.ZERO,
		face_z_index: int = 0) -> void:
	var col_center := pos
	var col_size := size
	if size.x >= size.y and face_normal != Vector2.ZERO and absf(face_normal.y) > 0.5 and show_front_face:
		var dir_y := signf(face_normal.y)
		col_size.y += WALL_FRONT_FACE_DEPTH
		col_center.y -= dir_y * WALL_FRONT_FACE_DEPTH / 2.0
	elif size.y > size.x and face_normal != Vector2.ZERO and absf(face_normal.x) > 0.5 and show_side_face:
		var dir_x := signf(face_normal.x)
		col_size.x += WALL_SIDE_FACE_DEPTH
		col_center.x -= dir_x * WALL_SIDE_FACE_DEPTH / 2.0
	add_wall(parent, col_center, col_size)
	if show_cap:
		var vis = _make_wall_rect(pos - size / 2, size, color.lightened(0.05), 4)
		add_child(vis)
	if size.x >= size.y:
		if face_normal != Vector2.ZERO and absf(face_normal.y) > 0.5 and show_front_face:
			_add_horizontal_wall_face_dir(pos, size, color, signf(face_normal.y), face_z_index)
		elif show_front_face:
			_add_horizontal_wall_face(pos, size, color, face_z_index)
	if size.y >= size.x:
		if face_normal != Vector2.ZERO and absf(face_normal.x) > 0.5 and show_side_face:
			_add_vertical_wall_face_dir(pos, size, color, signf(face_normal.x), face_z_index)
		elif show_side_face:
			_add_vertical_wall_face(pos, size, color, face_z_index)
	# 遮光体 — 阻挡 PointLight2D，实现"看不到房间内部"效果
	var occluder = LightOccluder2D.new()
	occluder.position = pos
	occluder.occluder_light_mask = 0  # 暂不产生阴影（防止走廊出现横向黑线）
	var poly = OccluderPolygon2D.new()
	var half = size / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	occluder.occluder = poly
	add_child(occluder)

func _make_wall_rect(top_left: Vector2, size: Vector2, color: Color, z_index: int) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = top_left
	rect.size = size
	rect.color = color
	rect.z_index = z_index
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _ensure_depth_sort_layer() -> Node2D:
	if _depth_sort_layer and is_instance_valid(_depth_sort_layer):
		return _depth_sort_layer
	_depth_sort_layer = Node2D.new()
	_depth_sort_layer.name = "DepthSortLayer"
	_depth_sort_layer.y_sort_enabled = true
	_depth_sort_layer.z_index = 5
	add_child(_depth_sort_layer)
	return _depth_sort_layer

func _resolve_standard_furniture_kind(label_text: String) -> String:
	if label_text == "床头柜" or label_text == "衣柜" or label_text.contains("柜"):
		return "cabinet"
	if label_text.contains("沙发"):
		return "sofa"
	if label_text.contains("椅"):
		return "chair"
	if label_text == "书桌" or label_text.contains("桌"):
		return "desk"
	if label_text.contains("床"):
		return "bed"
	return ""

func _add_textured_furniture_visual(texture_path: String, pos: Vector2, footprint_size: Vector2, display_size: Vector2, texture_size: Vector2, texture_offset_y: float, modulate: Color = Color.WHITE) -> void:
	var spr = Sprite2D.new()
	spr.texture = load(texture_path)
	spr.position = pos + Vector2(footprint_size.x / 2.0, footprint_size.y)
	spr.offset = Vector2(0.0, texture_offset_y)
	spr.scale = display_size / texture_size
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = modulate
	_ensure_depth_sort_layer().add_child(spr)

func _add_textured_furniture_body(pos: Vector2, display_size: Vector2, collision_size: Vector2 = Vector2.ZERO) -> void:
	if collision_size == Vector2.ZERO:
		collision_size = display_size
	var body = StaticBody2D.new()
	body.collision_layer = 4
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new()
	shp.size = collision_size
	col.shape = shp
	col.position = collision_size / 2.0
	body.add_child(col)
	body.position = pos
	add_child(body)

func add_standard_furniture(pos: Vector2, size: Vector2, label_text: String, color: Color) -> bool:
	const BED_TEX    = "res://assets/sprites/_0005_单人床.png"
	const DESK_TEX   = "res://assets/sprites/_0006_桌子1.png"
	const DESK_TEX_2 = "res://assets/sprites/_0009_桌子2.png"
	const SOFA_TEX   = "res://assets/sprites/_0007_沙发.png"
	const CABINET_TEX= "res://assets/sprites/_0008_柜子.png"
	const LONG_CABINET_TEX = "res://assets/sprites/_0010_长储物柜.png"
	const CHAIR_TEX  = "res://assets/sprites/_0011_椅子.png"
	if label_text == "书桌" and ResourceLoader.exists(DESK_TEX_2):
		var writing_desk_size = Vector2(size.x, 34.0)
		_add_textured_furniture_visual(DESK_TEX_2, pos, size, writing_desk_size, Vector2(137.0, 111.0), -55.5)
		_add_textured_furniture_body(pos, writing_desk_size, size)
		return true
	if label_text == "柜台" and ResourceLoader.exists(DESK_TEX_2):
		var counter_size = Vector2(size.x, 36.0)
		_add_textured_furniture_visual(DESK_TEX_2, pos, size, counter_size, Vector2(137.0, 111.0), -55.5)
		_add_textured_furniture_body(pos, counter_size, size)
		return true
	if label_text == "货架" and ResourceLoader.exists(LONG_CABINET_TEX):
		var shelf_size = Vector2(size.x, 24.0)
		_add_textured_furniture_visual(LONG_CABINET_TEX, pos, size, shelf_size, Vector2(380.0, 87.0), -43.5)
		_add_textured_furniture_body(pos, shelf_size, size)
		return true
	var furniture_kind = _resolve_standard_furniture_kind(label_text)
	match furniture_kind:
		"bed":
			if not ResourceLoader.exists(BED_TEX):
				return false
			var display_size = Vector2(size.x, 55.0)
			_add_textured_furniture_visual(BED_TEX, pos, size, display_size, Vector2(140.0, 228.0), -114.0)
			_add_textured_furniture_body(pos, display_size, size)
		"desk":
			if not ResourceLoader.exists(DESK_TEX):
				return false
			var display_size = Vector2(size.x, 30.0)
			_add_textured_furniture_visual(DESK_TEX, pos, size, display_size, Vector2(179.0, 118.0), -59.0)
			_add_textured_furniture_body(pos, display_size, size)
		"sofa":
			if not ResourceLoader.exists(SOFA_TEX):
				return false
			var display_size = Vector2(size.x, 40.0)
			_add_textured_furniture_visual(SOFA_TEX, pos, size, display_size, Vector2(251.0, 140.0), -70.0)
			_add_textured_furniture_body(pos, display_size, size)
		"cabinet":
			if not ResourceLoader.exists(CABINET_TEX):
				return false
			var display_size = Vector2(size.x, 45.0)
			_add_textured_furniture_visual(CABINET_TEX, pos, size, display_size, Vector2(182.0, 151.0), -75.5)
			_add_textured_furniture_body(pos, display_size, size)
		"chair":
			if not ResourceLoader.exists(CHAIR_TEX):
				return false
			var display_size = Vector2(size.x, 32.0)
			_add_textured_furniture_visual(CHAIR_TEX, pos, size, display_size, Vector2(82.0, 108.0), -54.0)
			_add_textured_furniture_body(pos, display_size, size)
		_:
			return false
	return true

func _add_furniture(pos: Vector2, size: Vector2, label_text: String, color: Color) -> void:
	if add_standard_furniture(pos, size, label_text, color):
		return
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.z_index = 3
	add_child(rect)
	var furn_label_text = label_text if Engine.is_editor_hint() else LocaleManager.world_text(label_text)
	create_world_label(furn_label_text, pos + Vector2(2, -12), 18, Color(0.35, 0.3, 0.25))

func create_elevator_card_pickup(pos: Vector2) -> Area2D:
	var card_area = Area2D.new()
	card_area.set_script(load("res://scripts/items/simple_pickup.gd"))
	card_area.position = pos
	card_area.collision_layer = 16
	card_area.item_id = "elevator_card"
	card_area.item_name = "电梯卡"
	card_area._level = self
	add_child(card_area)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	card_area.add_child(col)

	const CARD_TEX := "res://assets/sprites/_0000_电梯卡.png"
	var card_vis: CanvasItem
	if ResourceLoader.exists(CARD_TEX):
		var card_sprite = Sprite2D.new()
		card_sprite.texture = load(CARD_TEX)
		card_sprite.position = Vector2(-6, -4)
		var tex_size = card_sprite.texture.get_size()
		card_sprite.scale = Vector2(12.0 / tex_size.x, 8.0 / tex_size.y)
		card_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card_area.add_child(card_sprite)
		card_vis = card_sprite
	else:
		var visual = ColorRect.new()
		visual.color = Color(0.45, 0.8, 1.0, 0.7)
		visual.position = Vector2(-6, -4)
		visual.size = Vector2(12, 8)
		card_area.add_child(visual)
		card_vis = visual

	var card_name = "电梯卡" if Engine.is_editor_hint() else InventoryManager.get_item_data("elevator_card").get("name", "电梯卡")
	var interact_hint = "" if Engine.is_editor_hint() else InputDevice.hint("interact")
	var label = create_world_label("%s %s" % [card_name, interact_hint], pos + Vector2(-18, -20), 18, Color(0.5, 0.8, 1.0))
	label.visible = false
	card_area._name_label = label
	card_area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())

	var tw = create_tween().set_loops()
	_loop_tweens.append(tw)
	tw.tween_property(card_vis, "modulate:a", 0.4, 1.5)
	tw.tween_property(card_vis, "modulate:a", 1.0, 1.5)

	return card_area

func _add_horizontal_wall_face(pos: Vector2, size: Vector2, color: Color, face_z_index: int = 0) -> void:
	_add_horizontal_wall_face_dir(pos, size, color, 1.0, face_z_index)

func _add_horizontal_wall_face_dir(pos: Vector2, size: Vector2, color: Color, dir_sign: float, face_z_index: int = 0) -> void:
	var face_h: float = 48.0  # 和门贴图显示高度一致
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/_0002_水平墙正面.png")
	# 880×162 原始尺寸，缩放到 size.x × face_h
	spr.scale = Vector2(size.x / 880.0, face_h / 162.0)
	# 将墙面贴到面向玩家的边缘上，而不是厚障碍块的几何中心。
	# size.y=8 时退化为旧公式；更厚的障碍块会自动把墙面推到可见边缘。
	var center_y := pos.y + dir_sign * (size.y * 0.5 - 16.0)
	spr.position = Vector2(pos.x, center_y)
	spr.z_index = face_z_index
	add_child(spr)

func _add_vertical_wall_face(pos: Vector2, size: Vector2, color: Color, face_z_index: int = 0) -> void:
	_add_vertical_wall_face_dir(pos, size, color, 1.0, face_z_index)

func _add_vertical_wall_face_dir(pos: Vector2, size: Vector2, color: Color, dir_sign: float, face_z_index: int = 0) -> void:
	var face_w: float = WALL_SIDE_FACE_DEPTH  # 5.0 场景单位
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/_0004_竖向墙侧面.png")
	# 55×329 原始尺寸，缩放到 face_w × size.y
	spr.scale = Vector2(face_w / 55.0, size.y / 329.0)
	var center_x := pos.x + (size.x * 0.5 + face_w * 0.5) * dir_sign
	spr.position = Vector2(center_x, pos.y)
	spr.z_index = face_z_index
	add_child(spr)

func create_npc_visual(pos: Vector2, npc_id: String) -> CharacterBody2D:
	var display_name = GameManager.NAMES.get(npc_id, npc_id)
	var color = GameManager.CHAR_COLORS.get(npc_id, Color(0.5, 0.5, 0.5))
	
	var npc = CharacterBody2D.new()
	npc.position = pos
	npc.collision_layer = 2
	npc.collision_mask = 4
	npc.set_script(load("res://scripts/npc/npc_base.gd"))
	
	# ART: NPC精灵（替换素材请改 SPRITE_PATHS[npc_id]）
	var sprite = Sprite2D.new()
	sprite.texture = GameManager.load_char_texture(npc_id, 14, 18)
	GameManager.fit_character_sprite(sprite, npc_id)
	npc.add_child(sprite)
	npc.sprite = sprite
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = GameManager.NPC_COLLISION_SIZE
	col.shape = shape
	col.position = GameManager.NPC_COLLISION_OFFSET
	npc.add_child(col)
	npc.collision = col
	npc.add_child(GameManager.create_character_shadow_occluder(npc_id))
	
	var label = create_tracked_world_label(
		display_name,
		npc,
		Vector2(0, -GameManager.get_character_visual_height(npc_id) - 10.0),
		18,
		color.lightened(0.3)
	)
	label.visible = false
	npc.name_label = label
	npc.npc_name = display_name
	npc.npc_id = npc_id
	
	# 所有子节点就绪后再加入场景树
	_ensure_depth_sort_layer().add_child(npc)
	
	return npc

func set_npc_story_dialogue(npc: CharacterBody2D, chapter: String, event: String) -> void:
	if npc and is_instance_valid(npc):
		npc.set_dialogue(StoryText.lines(chapter, event))

func create_trigger_area(pos: Vector2, size: Vector2) -> Area2D:
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 1  # 检测玩家（collision_layer = 1）
	add_child(area)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	
	return area

## 创建房间门（可锁/不锁）
## pos: 门中心位置, size: 门尺寸(宽, 高), locked: 是否上锁
## room_side_normal: 从门洞指向房间内部的法线，用于决定门向内/向外开
## 锁住的门需要万能钥匙(master_key)才能打开
func add_door(walls_parent: Node2D, pos: Vector2, size: Vector2, locked: bool = false, room_side_normal: Vector2 = Vector2.UP, visual_z_index: int = 11) -> Dictionary:
	var is_vertical = size.x < size.y
	var hinge_world_pos = pos + (Vector2(0.0, -size.y / 2.0) if is_vertical else Vector2(-size.x / 2.0, 0.0))
	var collision_center = Vector2(0.0, size.y / 2.0) if is_vertical else Vector2(size.x / 2.0, 0.0)
	var visual_local_pos = Vector2(-size.x / 2.0, 0.0) if is_vertical else Vector2(0.0, -size.y / 2.0)

	# 门的碰撞体与视觉共用同一个旋转轴，形成真正的铰链门
	var door_pivot = Node2D.new()
	door_pivot.position = hinge_world_pos
	door_pivot.z_index = 11
	add_child(door_pivot)

	var door_body = StaticBody2D.new()
	door_body.collision_layer = 4
	if locked:
		door_body.add_to_group("nav_obstacle")  # 锁门参与导航阻挡；普通门保持通路
	door_pivot.add_child(door_body)
	
	var door_col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	door_col.shape = rect
	door_col.position = collision_center
	door_body.add_child(door_col)
	
	# 门洞底色（开门时露出）
	var door_gap = ColorRect.new()
	door_gap.position = pos - size / 2
	door_gap.size = size
	door_gap.color = Color(0.05, 0.035, 0.03, 0.0)
	door_gap.z_index = visual_z_index
	add_child(door_gap)
	
	# 门的视觉
	const DOOR_CLOSED_TEX = "res://assets/sprites/_0003_关闭门.png"
	var door_visual: CanvasItem
	if not is_vertical and ResourceLoader.exists(DOOR_CLOSED_TEX):
		# 斜俯视风格：门板贴图固定在走廊侧门口，开门时淡出
		var disp_h := 48.0
		var display_width := size.x + 4.0
		var sprite_center_y := pos.y - 12.0
		if room_side_normal.y > 0.5:
			sprite_center_y = pos.y - 20.0
		var spr = Sprite2D.new()
		spr.texture = load(DOOR_CLOSED_TEX)
		# 缩放：宽度填满门口，高度固定显示高度
		spr.scale = Vector2(display_width / 209.0, disp_h / 312.0)
		# 门嵌在墙面里；朝南的房门额外上移，使门板底边与墙面底边对齐
		spr.position = Vector2(pos.x, sprite_center_y)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.self_modulate = Color(0.7, 0.65, 0.6)  # 压暗，与周围墙体亮度一致
		spr.z_index = visual_z_index
		add_child(spr)
		door_gap.position = Vector2(pos.x - display_width / 2.0, sprite_center_y - disp_h / 2.0)
		door_gap.size = Vector2(display_width, disp_h)
		door_gap.color = Color(0.02, 0.015, 0.015, 0.0)
		door_visual = spr
	else:
		var door_rect = ColorRect.new()
		door_rect.position = visual_local_pos
		door_rect.size = size
		door_rect.color = Color(0.35, 0.2, 0.1) if locked else Color(0.2, 0.15, 0.08)
		door_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		door_rect.z_index = 0
		door_pivot.add_child(door_rect)
		door_visual = door_rect
	
	# 门框装饰（有贴图门时跳过水平门框，贴图本身已包含门框视觉）
	var frame_color = Color(0.3, 0.22, 0.16)
	var use_sprite_door = door_visual is Sprite2D
	if is_vertical:
		var frame_left = ColorRect.new()
		frame_left.position = Vector2(pos.x - size.x / 2 - 1, pos.y - size.y / 2)
		frame_left.size = Vector2(2, size.y)
		frame_left.color = frame_color
		frame_left.z_index = visual_z_index
		add_child(frame_left)
		var frame_right = ColorRect.new()
		frame_right.position = Vector2(pos.x + size.x / 2 - 1, pos.y - size.y / 2)
		frame_right.size = Vector2(2, size.y)
		frame_right.color = frame_color
		frame_right.z_index = visual_z_index
		add_child(frame_right)
	else:
		if not use_sprite_door:
			var frame_top = ColorRect.new()
			frame_top.position = Vector2(pos.x - size.x / 2, pos.y - size.y / 2 - 1)
			frame_top.size = Vector2(size.x, 2)
			frame_top.color = frame_color
			frame_top.z_index = visual_z_index
			add_child(frame_top)
			var frame_bottom = ColorRect.new()
			frame_bottom.position = Vector2(pos.x - size.x / 2, pos.y + size.y / 2 - 1)
			frame_bottom.size = Vector2(size.x, 2)
			frame_bottom.color = frame_color
			frame_bottom.z_index = visual_z_index
			add_child(frame_bottom)
	
	# 锁图标
	var lock_label = null
	if locked:
		lock_label = create_world_label("🔒", pos + Vector2(-8, -12), 14, Color(1.0, 0.6, 0.2))
	
	# 所有门都创建触发区；普通门自动开关，锁门保留 E 交互
	var interact_area = Area2D.new()
	interact_area.position = pos
	interact_area.collision_layer = 16
	interact_area.collision_mask = 19
	interact_area.z_index = 11  # 显示在天花板遮罩(z=10)之上
	
	var area_col = CollisionShape2D.new()
	var area_shape = RectangleShape2D.new()
	area_shape.size = size + Vector2(20, 20)
	area_col.shape = area_shape
	interact_area.add_child(area_col)
	
	var door_text = "门" if Engine.is_editor_hint() else LocaleManager.world_text("门")
	var door_hint = "" if Engine.is_editor_hint() else InputDevice.hint("interact")
	var hint_label = create_world_label("%s %s" % [door_text, door_hint], pos + Vector2(-20, -22), 16, Color(1.0, 1.0, 0.7) if locked else Color(0.9, 0.9, 0.8))
	hint_label.visible = false
	
	interact_area.set_meta("door_body", door_body)
	interact_area.set_meta("door_collision", door_col)
	interact_area.set_meta("door_visual", door_visual)
	interact_area.set_meta("door_gap", door_gap)
	interact_area.set_meta("door_pivot", door_pivot)
	interact_area.set_meta("lock_label", lock_label)
	interact_area.set_meta("hint_label", hint_label)
	interact_area.set_meta("level", self)
	interact_area.set_meta("locked", locked)
	interact_area.set_meta("door_vertical", is_vertical)
	interact_area.set_meta("room_side_normal", room_side_normal.normalized())
	interact_area.set_script(load("res://scripts/items/door_controller.gd"))
	add_child(interact_area)
	
	return {"body": door_body, "visual": door_visual, "gap": door_gap, "label": lock_label, "hint": hint_label, "interact_area": interact_area, "pivot": door_pivot}

# === 房间天花板系统 ===
# 在房间上方放置不透明遮罩，玩家进入时揭开，离开时盖回
# 同时在房间内看不到外部（外部遮罩）

func add_room_ceiling(room_id: String, top_left: Vector2, room_size: Vector2, room_rect_override: Rect2 = Rect2()) -> void:
	# 确保遮罩已初始化
	_ensure_masks_ready()
	var room_rect := room_rect_override if room_rect_override.size != Vector2.ZERO else Rect2(top_left, room_size)
	# 天花板：覆盖房间的暗色矩形
	var ceiling = ColorRect.new()
	ceiling.position = top_left
	ceiling.size = room_size
	ceiling.color = Color(0.02, 0.015, 0.015, 1.0)
	ceiling.z_index = 10
	ceiling.light_mask = 0  # 不受灯光影响，始终保持暗色
	add_child(ceiling)
	# 进入房间检测区（比房间稍小，确保玩家走进去才触发）
	var area = Area2D.new()
	area.position = room_rect.position + room_rect.size / 2
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = room_rect.size - Vector2(20, 20)
	col.shape = shape
	area.add_child(col)
	var rid = room_id
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			_enter_room(rid)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			_exit_room(rid)
	)
	_room_ceilings[room_id] = {"ceiling": ceiling, "rect": room_rect}

func _ensure_masks_ready() -> void:
	if _mask_top != null:
		return
	var mask_color = Color(0.02, 0.015, 0.015, 0.0)
	_mask_top = ColorRect.new()
	_mask_top.color = mask_color
	_mask_top.z_index = 12
	_mask_top.light_mask = 0
	add_child(_mask_top)
	_mask_bottom = ColorRect.new()
	_mask_bottom.color = mask_color
	_mask_bottom.z_index = 12
	_mask_bottom.light_mask = 0
	add_child(_mask_bottom)
	_mask_left = ColorRect.new()
	_mask_left.color = mask_color
	_mask_left.z_index = 12
	_mask_left.light_mask = 0
	add_child(_mask_left)
	_mask_right = ColorRect.new()
	_mask_right.color = mask_color
	_mask_right.z_index = 12
	_mask_right.light_mask = 0
	add_child(_mask_right)

func _enter_room(room_id: String) -> void:
	if not _room_detection_enabled:
		return
	if _current_room_id == room_id:
		return
	_current_room_id = room_id
	var data = _room_ceilings[room_id]
	# 淡出这个房间的天花板（揭开房间）
	var tw = create_tween()
	tw.tween_property(data["ceiling"], "color:a", 0.0, 0.3)
	# 遮挡房间外部
	_show_outside_mask(data["rect"])

func _exit_room(room_id: String) -> void:
	if _current_room_id != room_id:
		return
	_current_room_id = ""
	var data = _room_ceilings[room_id]
	# 淡入天花板（盖回房间）
	var tw = create_tween()
	tw.tween_property(data["ceiling"], "color:a", 1.0, 0.3)
	# 移除外部遮罩
	_hide_outside_mask()

func _show_outside_mask(room_rect: Rect2) -> void:
	var M = 800.0
	var rx = room_rect.position.x
	var ry = room_rect.position.y
	var rr = rx + room_rect.size.x
	var rb = ry + room_rect.size.y
	# 上方遮罩
	_mask_top.position = Vector2(-M, -M)
	_mask_top.size = Vector2(M * 2, ry + M)
	# 下方遮罩
	_mask_bottom.position = Vector2(-M, rb)
	_mask_bottom.size = Vector2(M * 2, M - rb)
	# 左侧遮罩（房间高度范围内）
	_mask_left.position = Vector2(-M, ry)
	_mask_left.size = Vector2(rx + M, rb - ry)
	# 右侧遮罩（房间高度范围内）
	_mask_right.position = Vector2(rr, ry)
	_mask_right.size = Vector2(M - rr, rb - ry)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mask_top, "color:a", 1.0, 0.3)
	tw.tween_property(_mask_bottom, "color:a", 1.0, 0.3)
	tw.tween_property(_mask_left, "color:a", 1.0, 0.3)
	tw.tween_property(_mask_right, "color:a", 1.0, 0.3)

func _hide_outside_mask() -> void:
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mask_top, "color:a", 0.0, 0.3)
	tw.tween_property(_mask_bottom, "color:a", 0.0, 0.3)
	tw.tween_property(_mask_left, "color:a", 0.0, 0.3)
	tw.tween_property(_mask_right, "color:a", 0.0, 0.3)

func _make_light_texture(size: int) -> ImageTexture:
	return TextureUtils.make_circle_texture(size)

# ====== 状态HUD ======

func _setup_status_hud(parent: CanvasLayer) -> void:
	# 体力条 + 理智条 + 异常状态图标
	var status_vbox = VBoxContainer.new()
	status_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_vbox.offset_left = 30
	status_vbox.offset_top = 57
	status_vbox.offset_right = 240
	status_vbox.add_theme_constant_override("separation", 6)
	parent.add_child(status_vbox)
	
	# — 体力条（绿色）—
	_stamina_label = Label.new()
	_stamina_label.text = LocaleManager.t("stat_stamina")
	_stamina_label.add_theme_font_size_override("font_size", 22)
	_stamina_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	status_vbox.add_child(_stamina_label)
	
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(180, 12)
	_stamina_bar.max_value = PlayerStats.max_stamina
	_stamina_bar.value = PlayerStats.stamina
	_stamina_bar.show_percentage = false
	_stamina_bar.visible = PlayerStats.stamina_enabled
	var stam_bg = StyleBoxFlat.new()
	stam_bg.bg_color = Color(0.15, 0.12, 0.12)
	stam_bg.corner_radius_top_left = 2
	stam_bg.corner_radius_top_right = 2
	stam_bg.corner_radius_bottom_left = 2
	stam_bg.corner_radius_bottom_right = 2
	_stamina_bar.add_theme_stylebox_override("background", stam_bg)
	var stam_fill = StyleBoxFlat.new()
	stam_fill.bg_color = Color(0.4, 0.8, 0.3)
	stam_fill.corner_radius_top_left = 2
	stam_fill.corner_radius_top_right = 2
	stam_fill.corner_radius_bottom_left = 2
	stam_fill.corner_radius_bottom_right = 2
	_stamina_bar.add_theme_stylebox_override("fill", stam_fill)
	status_vbox.add_child(_stamina_bar)
	
	# — 理智条（蓝紫色）—
	_sanity_label = Label.new()
	_sanity_label.text = LocaleManager.t("stat_sanity")
	_sanity_label.add_theme_font_size_override("font_size", 22)
	_sanity_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.9))
	status_vbox.add_child(_sanity_label)
	
	_sanity_bar = ProgressBar.new()
	_sanity_bar.custom_minimum_size = Vector2(180, 12)
	_sanity_bar.max_value = PlayerStats.max_sanity
	_sanity_bar.value = PlayerStats.sanity
	_sanity_bar.show_percentage = false
	var san_bg = StyleBoxFlat.new()
	san_bg.bg_color = Color(0.12, 0.1, 0.15)
	san_bg.corner_radius_top_left = 2
	san_bg.corner_radius_top_right = 2
	san_bg.corner_radius_bottom_left = 2
	san_bg.corner_radius_bottom_right = 2
	_sanity_bar.add_theme_stylebox_override("background", san_bg)
	var san_fill = StyleBoxFlat.new()
	san_fill.bg_color = Color(0.5, 0.4, 0.9)
	san_fill.corner_radius_top_left = 2
	san_fill.corner_radius_top_right = 2
	san_fill.corner_radius_bottom_left = 2
	san_fill.corner_radius_bottom_right = 2
	_sanity_bar.add_theme_stylebox_override("fill", san_fill)
	status_vbox.add_child(_sanity_bar)
	
	# — 电池条（橙色，有手电筒时显示）—
	var has_flashlight := InventoryManager.has_item("flashlight")
	_battery_label = Label.new()
	_battery_label.text = LocaleManager.t("stat_battery")
	_battery_label.add_theme_font_size_override("font_size", 22)
	_battery_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_battery_label.visible = has_flashlight
	status_vbox.add_child(_battery_label)
	
	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size = Vector2(180, 12)
	_battery_bar.max_value = 100.0
	_battery_bar.value = 100.0
	_battery_bar.show_percentage = false
	_battery_bar.visible = has_flashlight
	var bat_bg = StyleBoxFlat.new()
	bat_bg.bg_color = Color(0.15, 0.12, 0.08)
	bat_bg.corner_radius_top_left = 2
	bat_bg.corner_radius_top_right = 2
	bat_bg.corner_radius_bottom_left = 2
	bat_bg.corner_radius_bottom_right = 2
	_battery_bar.add_theme_stylebox_override("background", bat_bg)
	var bat_fill = StyleBoxFlat.new()
	bat_fill.bg_color = Color(0.9, 0.7, 0.2)
	bat_fill.corner_radius_top_left = 2
	bat_fill.corner_radius_top_right = 2
	bat_fill.corner_radius_bottom_left = 2
	bat_fill.corner_radius_bottom_right = 2
	_battery_bar.add_theme_stylebox_override("fill", bat_fill)
	status_vbox.add_child(_battery_bar)
	
	# 状态图标行（预留）
	_status_container = HBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 4)
	status_vbox.add_child(_status_container)
	
	# 信号连接 — 体力条
	var _stam_cb = func(current: float, max_val: float):
		if _stamina_bar:
			_stamina_bar.value = current
			_stamina_bar.visible = PlayerStats.stamina_enabled
			var fill_style: StyleBoxFlat = _stamina_bar.get_theme_stylebox("fill")
			if current / max_val < 0.25:
				fill_style.bg_color = Color(0.9, 0.2, 0.2)
			elif current / max_val < 0.5:
				fill_style.bg_color = Color(0.9, 0.6, 0.2)
			else:
				fill_style.bg_color = Color(0.4, 0.8, 0.3)
	PlayerStats.stamina_changed.connect(_stam_cb)
	_signal_callbacks.append({"signal": PlayerStats.stamina_changed, "callable": _stam_cb})
	
	# 信号连接 — 理智条
	var _san_cb = func(current: float, max_val: float):
		if _sanity_bar:
			_sanity_bar.value = current
			var fill_style: StyleBoxFlat = _sanity_bar.get_theme_stylebox("fill")
			if current / max_val < 0.25:
				fill_style.bg_color = Color(0.9, 0.1, 0.2)
			elif current / max_val < 0.5:
				fill_style.bg_color = Color(0.8, 0.4, 0.5)
			else:
				fill_style.bg_color = Color(0.5, 0.4, 0.9)
	PlayerStats.sanity_changed.connect(_san_cb)
	_signal_callbacks.append({"signal": PlayerStats.sanity_changed, "callable": _san_cb})

	# 信号连接 — 电池条
	var _bat_cb = func(current: float, max_val: float):
		PlayerStats.saved_flashlight_battery = current
		var has_flashlight_now := InventoryManager.has_item("flashlight")
		if _battery_label:
			_battery_label.visible = has_flashlight_now
		if _battery_bar:
			_battery_bar.max_value = max_val
			_battery_bar.value = current
			_battery_bar.visible = has_flashlight_now
			var fill_style: StyleBoxFlat = _battery_bar.get_theme_stylebox("fill")
			var battery_ratio := current / max_val if max_val > 0.0 else 0.0
			if battery_ratio < 0.2:
				fill_style.bg_color = Color(0.9, 0.2, 0.1)
			elif battery_ratio < 0.4:
				fill_style.bg_color = Color(0.9, 0.5, 0.1)
			else:
				fill_style.bg_color = Color(0.9, 0.7, 0.2)
	if player_lighting:
		player_lighting.battery_changed.connect(_bat_cb)
		_signal_callbacks.append({"signal": player_lighting.battery_changed, "callable": _bat_cb})
		_bat_cb.call(float(player_lighting.get("flashlight_battery")), float(player_lighting.get("max_battery")))
	var _flashlight_item_cb = func(item_id: String):
		if item_id != "flashlight" or not player_lighting:
			return
		_bat_cb.call(float(player_lighting.get("flashlight_battery")), float(player_lighting.get("max_battery")))
	InventoryManager.item_added.connect(_flashlight_item_cb)
	_signal_callbacks.append({"signal": InventoryManager.item_added, "callable": _flashlight_item_cb})
	InventoryManager.item_removed.connect(_flashlight_item_cb)
	_signal_callbacks.append({"signal": InventoryManager.item_removed, "callable": _flashlight_item_cb})

func _on_locale_changed_status(_locale: String) -> void:
	if _floor_text_label:
		_floor_text_label.text = LocaleManager.world_text(_floor_name)
	if _stamina_label:
		_stamina_label.text = LocaleManager.t("stat_stamina")
	if _sanity_label:
		_sanity_label.text = LocaleManager.t("stat_sanity")
	if _battery_label:
		_battery_label.text = LocaleManager.t("stat_battery")

func _refresh_status_icons() -> void:
	if not _status_container:
		return
	for child in _status_container.get_children():
		child.queue_free()

## 运行时创建导航区域并自动烘焙（从当前场景的 StaticBody2D 生成可行走多边形）
## 在所有 add_wall/add_visible_wall 调用完成后调用此函数
func setup_navigation(bounds: Rect2 = Rect2(-460, -310, 920, 620)) -> void:
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	add_child(nav_region)

	var nav_poly = NavigationPolygon.new()
	nav_poly.agent_radius = 14.0
	# 使用分组模式：只解析标记了 nav_obstacle 的 StaticBody2D 节点
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_poly.source_geometry_group_name = "nav_obstacle"

	# 可行走区域边界（略小于关卡边界以避免贴边）
	var inset = 6.0
	nav_poly.add_outline(PackedVector2Array([
		Vector2(bounds.position.x + inset, bounds.position.y + inset),
		Vector2(bounds.end.x - inset, bounds.position.y + inset),
		Vector2(bounds.end.x - inset, bounds.end.y - inset),
		Vector2(bounds.position.x + inset, bounds.end.y - inset),
	]))
	nav_region.navigation_polygon = nav_poly
	# 异步烘焙，完成后导航自动生效
	nav_region.bake_navigation_polygon()

# ===== 场景节点发现系统（支持编辑器拖拽放置的节点） =====

## 检查场景中是否有编辑器放置的可视化节点（GameWall、FloorZone 等）
func has_scene_visual_nodes() -> bool:
	for child in get_children():
		if child is GameWall or child is FloorZone or child is GameFurniture:
			return true
		if child is GameDoor or child is GameCeiling or child is GameNPC:
			return true
		if child is GamePickup or child is GameContainer:
			return true
		if child is GameElevatorDoor or child is GameDecorRect or child is GameDoorLeak:
			return true
	return false

## 发现并初始化场景中所有编辑器放置的节点
## 在 _ready() 中调用，替代 _build_floor() 等代码生成方法
func discover_scene_nodes() -> void:
	# 1. 收集所有 GameWall，合并到一个 StaticBody2D 中
	var wall_nodes: Array[Node] = []
	for child in get_children():
		if child is GameWall:
			wall_nodes.append(child)
	if not wall_nodes.is_empty():
		var walls := StaticBody2D.new()
		walls.name = "Walls"
		walls.collision_layer = 4
		add_child(walls)
		for gw in wall_nodes:
			# GameWall 已有自己的碰撞体，将其移到 Walls 下
			# 但 GameWall extends StaticBody2D，不能简单 add_child
			# 所以让 GameWall 保持原位，把它的碰撞复制到 Walls
			for col_child in gw.get_children():
				if col_child is CollisionShape2D:
					var dup := col_child.duplicate()
					dup.position = gw.position + col_child.position
					walls.add_child(dup)
			gw.add_to_group("nav_obstacle")

	# 2. FloorZone 已自动创建视觉子节点，无需额外处理

	# 3. RoomLight 已自动创建灯光和检测区域

	# 4. GameFurniture — 注册容器交互
	for child in get_children():
		if child is GameFurniture:
			_setup_furniture_interaction(child)

	# 5. GameDoor — 运行时创建门系统
	for child in get_children():
		if child is GameDoor:
			child._built_runtime = false
			child._rebuild()

	# 6. GameCeiling — 注册到天花板系统
	for child in get_children():
		if child is GameCeiling:
			_register_ceiling(child)

	# 7. GameNPC — 生成NPC
	for child in get_children():
		if child is GameNPC:
			child.spawn_npc(self)

## 设置家具交互（搜索容器）
func _setup_furniture_interaction(furn: GameFurniture) -> void:
	if Engine.is_editor_hint():
		return
	if furn.contained_item_id == "":
		return
	# 创建交互区域
	var area := Area2D.new()
	area.position = furn.position + furn.furniture_size / 2.0
	area.collision_layer = 16
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	area.set_script(load("res://scripts/items/furniture_container.gd"))
	area.furniture_name = furn.furniture_name
	area.contained_item_id = furn.contained_item_id
	area.contained_item_name = furn.contained_item_name
	area._level = self
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = furn.furniture_size + Vector2(10, 10)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	# 名称标签
	var display_name := LocaleManager.world_text(furn.furniture_name)
	var hint_text := InputDevice.hint("interact")
	var name_label := create_world_label("%s %s" % [display_name, hint_text], furn.position + Vector2(-10, -22), 18, furn.furniture_color.lightened(0.4))
	name_label.visible = false
	area._name_label = name_label
	area.tree_exiting.connect(func(): if is_instance_valid(name_label): name_label.queue_free())

## 注册天花板到房间天花板系统
func _register_ceiling(ceil_node: GameCeiling) -> void:
	if Engine.is_editor_hint():
		return
	_ensure_masks_ready()
	var room_rect := ceil_node.get_room_rect()
	var ceiling := ceil_node.get_node_or_null("ColorRect")
	if not ceiling:
		# 查找第一个 ColorRect 子节点
		for c in ceil_node.get_children():
			if c is ColorRect:
				ceiling = c
				break
	if not ceiling:
		return
	_room_ceilings[ceil_node.room_id] = {"ceiling": ceiling, "rect": room_rect}
	# 创建检测区域
	var area := Area2D.new()
	area.position = room_rect.position + room_rect.size / 2
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = room_rect.size - Vector2(20, 20)
	col.shape = shape
	area.add_child(col)
	var rid := ceil_node.room_id
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			_enter_room(rid)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			_exit_room(rid)
	)
