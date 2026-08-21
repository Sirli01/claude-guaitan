@tool
extends Node2D
## 序章 - 夏桐的房间
## 墙壁和家具已在 .tscn 场景文件中定义（GameWall / GameFurniture 节点）
## 流程：黑屏渐亮 → 姐姐独白（带头像） → 操作提示 → 拾取手机 → 背包教程 → 出门

var player: CharacterBody2D
var phone_area: Area2D
var door_area: Area2D
var phone_ui: Control
var hud_layer: CanvasLayer
var dialogue_layer: CanvasLayer
var phone_checked: bool = false
var _stamina_bar: ProgressBar
var _sanity_bar: ProgressBar
var _interact_prompt: Label  # "按E拾取"提示标签
var _phone_opened_once: bool = false  # 玩家是否已从背包打开过手机
var _wlm: Node  # WorldLabelManager

# 存储信号回调以便场景退出时断开
var _signal_callbacks: Array[Dictionary] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	GameManager.set_state(GameManager.GameState.CUTSCENE)
	GameManager.change_floor(GameManager.Floor.PROLOGUE)

	var is_returning = InventoryManager.has_item("phone")

	_wlm = load("res://scripts/utils/world_label_manager.gd").new()
	_wlm.setup(self, 4.0)
	_setup_window_effects()
	_setup_furniture_labels()
	_build_player()
	if not is_returning:
		_build_phone_area()
	_build_door()
	_build_ui()
	LevelBaseV2.fix_label_filter(self)

	if is_returning:
		# 从街道返回 — 跳过独白，简单渐入即可
		var fade_rect = ColorRect.new()
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color.BLACK
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_layer.add_child(fade_rect)

		var fade_tw = create_tween()
		fade_tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await fade_tw.finished
		fade_rect.queue_free()

		GameManager.set_state(GameManager.GameState.PLAYING)
		player.unfreeze_player()
		_show_hint(LocaleManager.t("hint_back_in_room"), 3.0)
		return

	# 玩家初始冻结（开场过场期间不可移动）
	player.freeze_player()

	# === 开场序列 ===
	# 1. 黑屏渐亮（2秒）
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fade_rect)

	var fade_tw = create_tween()
	fade_tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
	await fade_tw.finished
	fade_rect.queue_free()

	DialogueManager.start_dialogue(StoryText.lines("prologue", "intro"))
	await DialogueManager.dialogue_ended

	# 3. 对话结束，切换到自由操控
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()

	# 4. 操作提示
	var move_key = InputDevice.get_hint("move")
	var run_key = InputDevice.get_hint("run")
	_show_hint(LocaleManager.t("hint_controls") % [move_key, run_key, run_key], 5.0)

## 窗户效果（阳光光束 + 光尘粒子）— 复杂视觉效果保留在代码中
func _setup_window_effects() -> void:
	var win_x = 176.0
	var win_y = -456.0

	# 窗框
	var win_frame = ColorRect.new()
	win_frame.color = Color(0.45, 0.35, 0.25, 0.0)
	win_frame.position = Vector2(win_x - 88, win_y - 12)
	win_frame.size = Vector2(176, 48)
	win_frame.z_index = 1
	add_child(win_frame)

	# 阳光光束（带柔光shader的Polygon2D，边缘渐隐）
	var beam = Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(win_x - 56, win_y + 24),
		Vector2(win_x + 56, win_y + 24),
		Vector2(win_x + 240, win_y + 560),
		Vector2(win_x + 40, win_y + 560),
	])
	beam.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	beam.color = Color.WHITE
	beam.z_index = 3
	var beam_shader = ShaderMaterial.new()
	var bs = Shader.new()
	bs.code = """
shader_type canvas_item;
void fragment() {
	float edge = 1.0 - 2.0 * abs(UV.x - 0.5);
	edge = smoothstep(0.0, 0.7, edge);
	float vert = 1.0 - UV.y * 0.6;
	float a = edge * vert * 0.10;
	COLOR = vec4(1.0, 0.92, 0.65, a);
}
"""
	beam_shader.shader = bs
	beam.material = beam_shader
	add_child(beam)

	# 内层更亮的核心光束
	var beam_core = Polygon2D.new()
	beam_core.polygon = PackedVector2Array([
		Vector2(win_x - 32, win_y + 24),
		Vector2(win_x + 32, win_y + 24),
		Vector2(win_x + 160, win_y + 480),
		Vector2(win_x + 72, win_y + 480),
	])
	beam_core.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	beam_core.color = Color.WHITE
	beam_core.z_index = 3
	var core_shader = ShaderMaterial.new()
	var cs = Shader.new()
	cs.code = """
shader_type canvas_item;
void fragment() {
	float edge = 1.0 - 2.0 * abs(UV.x - 0.5);
	edge = smoothstep(0.0, 0.8, edge);
	float vert = 1.0 - UV.y * 0.5;
	float a = edge * vert * 0.07;
	COLOR = vec4(1.0, 0.95, 0.7, a);
}
"""
	core_shader.shader = cs
	beam_core.material = core_shader
	add_child(beam_core)

	# 窗户处的暖光源
	var win_light = PointLight2D.new()
	win_light.position = Vector2(win_x, win_y + 120)
	win_light.color = Color(1.0, 0.9, 0.65)
	win_light.energy = 0.5
	var wl_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for px in 64:
		for py in 64:
			var dist = Vector2(px - 32, py - 32).length() / 32.0
			var a = clampf(1.0 - dist, 0.0, 1.0)
			wl_img.set_pixel(px, py, Color(1, 1, 1, a * a))
	win_light.texture = ImageTexture.create_from_image(wl_img)
	win_light.texture_scale = 10.0
	add_child(win_light)

	# 窗户光尘粒子（细小的灰尘在光束中飘浮）
	var dust = GPUParticles2D.new()
	dust.position = Vector2(win_x + 60, win_y + 280)
	dust.z_index = 4
	dust.amount = 12
	dust.lifetime = 5.0
	dust.speed_scale = 0.3
	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0.5, 1.0, 0)
	dust_mat.spread = 30.0
	dust_mat.initial_velocity_min = 3.0
	dust_mat.initial_velocity_max = 6.0
	dust_mat.gravity = Vector3(0, 1, 0)
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(80, 160, 0)
	dust_mat.scale_min = 0.3
	dust_mat.scale_max = 0.8
	dust_mat.color = Color(1.0, 0.95, 0.75, 0.5)
	var dcurve = CurveTexture.new()
	var dc = Curve.new()
	dc.add_point(Vector2(0.0, 0.0))
	dc.add_point(Vector2(0.2, 1.0))
	dc.add_point(Vector2(0.8, 1.0))
	dc.add_point(Vector2(1.0, 0.0))
	dcurve.curve = dc
	dust_mat.alpha_curve = dcurve
	dust.process_material = dust_mat
	var dimg = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for dpx in 4:
		for dpy in 4:
			var dd = Vector2(dpx - 2, dpy - 2).length() / 2.0
			var da = clampf(1.0 - dd, 0.0, 1.0)
			dimg.set_pixel(dpx, dpy, Color(1, 1, 1, da))
	dust.texture = ImageTexture.create_from_image(dimg)
	add_child(dust)

## 为场景中的 GameFurniture 节点创建世界标签
func _setup_furniture_labels() -> void:
	for child in get_children():
		if child is GameFurniture:
			var furn_label := LocaleManager.world_text(child.furniture_name)
			_wlm.create_label(furn_label, child.position + Vector2(-60, -child.furniture_size.y - 60), 40, Color(0.5, 0.5, 0.5, 0.0))

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(0, 136)
	player.collision_layer = 1
	player.collision_mask = 5
	player.set_script(load("res://scripts/player/player.gd"))

	# 玩家精灵（色块代替）
	var sprite = Sprite2D.new()
	sprite.texture = GameManager.load_char_texture("sister", 16, 20)
	GameManager.fit_character_sprite(sprite, "sister")
	# 在序章房间中将主角放大到 4/3 倍
	sprite.scale *= 4.0 / 3.0
	player.add_child(sprite)
	player.sprite = sprite

	# 碰撞体
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = GameManager.PLAYER_COLLISION_SIZE * 4.0 / 3.0
	col.shape = shape
	col.position = GameManager.PLAYER_COLLISION_OFFSET * 4.0 / 3.0
	player.add_child(col)
	player.collision = col
	player.add_child(GameManager.create_character_shadow_occluder("sister"))

	var shadow = player.get_node("CharacterShadow")
	if shadow:
		shadow.scale *= 4.0 / 3.0

	# 交互区域
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 22
	var area_col = CollisionShape2D.new()
	var area_shape = CircleShape2D.new()
	area_shape.radius = 60.0 * 4.0 / 3.0
	area_col.shape = area_shape
	area.add_child(area_col)
	player.add_child(area)
	player.interaction_area = area

	# 摄像机
	var cam = Camera2D.new()
	cam.zoom = Vector2(6.0, 6.0)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	player.camera = cam

	# 灯光
	var light = PointLight2D.new()
	light.color = Color(0.95, 0.9, 0.75)
	light.energy = 0.6
	# 需要一个光照纹理
	var light_img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for x in 128:
		for y in 128:
			var dist = Vector2(x - 64, y - 64).length() / 64.0
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			light_img.set_pixel(x, y, Color(1, 1, 1, alpha))
	light.texture = ImageTexture.create_from_image(light_img)
	light.texture_scale = 6.0 * 4.0 / 3.0
	player.add_child(light)
	player.point_light = light

	# 所有子节点就绪后再加入场景树
	add_child(player)
	# 在 player._ready() 执行后恢复默认布局，确保放大不会被预览帧覆盖
	player.call_deferred("_apply_default_sprite_layout")
	call_deferred("_finish_prologue_player_setup", player)

func _build_phone_area() -> void:
	phone_area = Area2D.new()
	phone_area.position = Vector2(140, -156)
	phone_area.collision_layer = 16
	phone_area.add_to_group("interactable")
	add_child(phone_area)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 24)
	col.shape = shape
	phone_area.add_child(col)

	# 手机视觉（贴图）
	var phone_tex = "res://assets/sprites/_0000_手机.png"
	if ResourceLoader.exists(phone_tex):
		var phone_sprite = Sprite2D.new()
		phone_sprite.texture = load(phone_tex)
		phone_sprite.position = Vector2(-10, -8)
		var ptex_size = phone_sprite.texture.get_size()
		phone_sprite.scale = Vector2(20.0 / ptex_size.x, 16.0 / ptex_size.y)
		phone_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		phone_area.add_child(phone_sprite)

	# "按E拾取"提示（靠近才显示）
	_interact_prompt = _wlm.create_label(LocaleManager.t("prompt_pick_phone") % InputDevice.hint("interact"), Vector2(80, -204), 40, Color(1.0, 1.0, 0.7))
	_interact_prompt.visible = false

func _finish_prologue_player_setup(p: CharacterBody2D) -> void:
	if not is_instance_valid(p):
		return
	var shadow = p.get_node_or_null("CharacterShadow")
	if shadow:
		shadow.scale *= 4.0 / 3.0
	if p.collision and p.collision.shape and p.collision.shape is RectangleShape2D:
		p.collision.shape.size = GameManager.PLAYER_COLLISION_SIZE * 4.0 / 3.0
		p.collision.position = GameManager.PLAYER_COLLISION_OFFSET * 4.0 / 3.0
	if p.interaction_area and p.interaction_area.get_child_count() > 0:
		var col_node = p.interaction_area.get_child(0)
		if col_node and col_node.shape and col_node.shape is CircleShape2D:
			col_node.shape.radius = 60.0 * 4.0 / 3.0
	if p.point_light and p.point_light is PointLight2D:
		p.point_light.texture_scale = 6.0 * 4.0 / 3.0

func _build_door() -> void:
	door_area = Area2D.new()
	door_area.position = Vector2(0, 216)
	door_area.collision_layer = 32
	add_child(door_area)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 20)
	col.shape = shape
	door_area.add_child(col)

	# 门的视觉
	var door_rect = ColorRect.new()
	door_rect.color = Color(0.35, 0.22, 0.12)
	door_rect.position = Vector2(-40, -10)
	door_rect.size = Vector2(80, 20)
	door_area.add_child(door_rect)

	_wlm.create_label(LocaleManager.world_text("出门"), Vector2(-24, 176), 40, Color(0.6, 0.6, 0.4))

	door_area.body_entered.connect(_on_door_entered)

func _build_ui() -> void:
	# HUD
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 60
	top_bar.offset_top = 30
	top_bar.offset_right = -60
	top_bar.offset_bottom = 120
	hud_layer.add_child(top_bar)

	var floor_label = Label.new()
	floor_label.text = LocaleManager.t("floor_prologue_room")
	floor_label.add_theme_font_size_override("font_size", 60)
	floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_bar.add_child(floor_label)

	# ===== 体力 + 理智条 =====
	var status_vbox = VBoxContainer.new()
	status_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_vbox.offset_left = 60
	status_vbox.offset_top = 114
	status_vbox.offset_right = 480
	status_vbox.add_theme_constant_override("separation", 8)
	hud_layer.add_child(status_vbox)

	# 体力条
	var stamina_label = Label.new()
	stamina_label.text = LocaleManager.t("stat_stamina")
	stamina_label.add_theme_font_size_override("font_size", 44)
	stamina_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	status_vbox.add_child(stamina_label)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(360, 24)
	_stamina_bar.max_value = PlayerStats.max_stamina
	_stamina_bar.value = PlayerStats.stamina
	_stamina_bar.show_percentage = false
	var stam_bg = StyleBoxFlat.new()
	stam_bg.bg_color = Color(0.15, 0.12, 0.12)
	stam_bg.corner_radius_top_left = 4; stam_bg.corner_radius_top_right = 4
	stam_bg.corner_radius_bottom_left = 4; stam_bg.corner_radius_bottom_right = 4
	_stamina_bar.add_theme_stylebox_override("background", stam_bg)
	var stam_fill = StyleBoxFlat.new()
	stam_fill.bg_color = Color(0.4, 0.8, 0.3)
	stam_fill.corner_radius_top_left = 4; stam_fill.corner_radius_top_right = 4
	stam_fill.corner_radius_bottom_left = 4; stam_fill.corner_radius_bottom_right = 4
	_stamina_bar.add_theme_stylebox_override("fill", stam_fill)
	status_vbox.add_child(_stamina_bar)

	# 理智条
	var sanity_label = Label.new()
	sanity_label.text = LocaleManager.t("stat_sanity")
	sanity_label.add_theme_font_size_override("font_size", 44)
	sanity_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.9))
	status_vbox.add_child(sanity_label)

	_sanity_bar = ProgressBar.new()
	_sanity_bar.custom_minimum_size = Vector2(360, 24)
	_sanity_bar.max_value = PlayerStats.max_sanity
	_sanity_bar.value = PlayerStats.sanity
	_sanity_bar.show_percentage = false
	var san_bg = StyleBoxFlat.new()
	san_bg.bg_color = Color(0.12, 0.1, 0.15)
	san_bg.corner_radius_top_left = 4; san_bg.corner_radius_top_right = 4
	san_bg.corner_radius_bottom_left = 4; san_bg.corner_radius_bottom_right = 4
	_sanity_bar.add_theme_stylebox_override("background", san_bg)
	var san_fill = StyleBoxFlat.new()
	san_fill.bg_color = Color(0.5, 0.4, 0.9)
	san_fill.corner_radius_top_left = 4; san_fill.corner_radius_top_right = 4
	san_fill.corner_radius_bottom_left = 4; san_fill.corner_radius_bottom_right = 4
	_sanity_bar.add_theme_stylebox_override("fill", san_fill)
	status_vbox.add_child(_sanity_bar)

	# 启用体力系统
	PlayerStats.stamina_enabled = true

	# 信号连接
	var _stam_cb = func(current: float, max_val: float):
		if _stamina_bar:
			_stamina_bar.value = current
			var fill_s: StyleBoxFlat = _stamina_bar.get_theme_stylebox("fill")
			if current / max_val < 0.25:
				fill_s.bg_color = Color(0.9, 0.2, 0.2)
			elif current / max_val < 0.5:
				fill_s.bg_color = Color(0.9, 0.6, 0.2)
			else:
				fill_s.bg_color = Color(0.4, 0.8, 0.3)
	PlayerStats.stamina_changed.connect(_stam_cb)
	_signal_callbacks.append({"signal": PlayerStats.stamina_changed, "callable": _stam_cb})

	var _san_cb = func(current: float, max_val: float):
		if _sanity_bar:
			_sanity_bar.value = current
			var fill_s: StyleBoxFlat = _sanity_bar.get_theme_stylebox("fill")
			if current / max_val < 0.3:
				fill_s.bg_color = Color(0.9, 0.2, 0.3)
			elif current / max_val < 0.5:
				fill_s.bg_color = Color(0.7, 0.4, 0.7)
			else:
				fill_s.bg_color = Color(0.5, 0.4, 0.9)
	PlayerStats.sanity_changed.connect(_san_cb)
	_signal_callbacks.append({"signal": PlayerStats.sanity_changed, "callable": _san_cb})

	# 对话UI
	_build_dialogue_ui()

	# 背包UI
	var inv_layer = CanvasLayer.new()
	inv_layer.layer = 15
	inv_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inv_layer)
	var inv_ui = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	inv_layer.add_child(inv_ui)
	inv_ui.phone_viewed.connect(_on_phone_viewed)

func _build_dialogue_ui() -> void:
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	dialogue_layer = dlg_scene.instantiate()
	add_child(dialogue_layer)

var _hint_labels: Array[Dictionary] = []
const HINT_DURATION: float = 4.0
const HINT_FADE_TIME: float = 1.0
const HINT_LINE_HEIGHT: int = 80

func _show_hint(text: String, duration: float = HINT_DURATION) -> void:
	for entry in _hint_labels:
		var lbl = entry.get("label")
		if is_instance_valid(lbl):
			lbl.position.y -= HINT_LINE_HEIGHT

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -600
	label.offset_right = 600
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

	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(label, "modulate:a", 0.0, HINT_FADE_TIME)
	tw.tween_callback(_remove_hint.bind(entry))

func _remove_hint(entry: Dictionary) -> void:
	var lbl: Label = entry.get("label")
	var idx = _hint_labels.find(entry)
	if idx >= 0:
		_hint_labels.remove_at(idx)
	if is_instance_valid(lbl):
		lbl.queue_free()
	for remaining in _hint_labels:
		var rlbl = remaining.get("label")
		if is_instance_valid(rlbl):
			rlbl.position.y += HINT_LINE_HEIGHT

func _on_phone_interact() -> void:
	if phone_checked:
		return
	phone_checked = true

	# 拾取手机（手机从地图消失）
	InventoryManager.add_item("phone")

	# 手机消失动画
	var tween = create_tween()
	tween.tween_property(phone_area, "modulate:a", 0.0, 0.3)
	tween.tween_property(phone_area, "position:y", phone_area.position.y - 30, 0.3)
	await tween.finished
	phone_area.queue_free()
	phone_area = null
	if _interact_prompt and is_instance_valid(_interact_prompt):
		_interact_prompt.queue_free()
	_interact_prompt = null

	# 提示玩家打开背包查看手机
	_show_hint(LocaleManager.t("hint_open_phone_inventory") % InputDevice.get_hint("open_inventory"), 8.0)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _wlm and player and player.camera:
		_wlm.set_camera(player.camera)
		_wlm.update_positions()
	# 靠近手机时显示拾取提示（动态更新按键）
	if phone_area and player and _interact_prompt and not phone_checked:
		var dist = player.global_position.distance_to(phone_area.global_position)
		if dist < 70.0:
			_interact_prompt.text = LocaleManager.t("prompt_pick_phone") % InputDevice.hint("interact")
			_interact_prompt.visible = true
		else:
			_interact_prompt.visible = false

func _exit_tree() -> void:
	for entry in _signal_callbacks:
		if entry["signal"].is_connected(entry["callable"]):
			entry["signal"].disconnect(entry["callable"])
	_signal_callbacks.clear()

func _on_door_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not InventoryManager.has_item("phone"):
			_show_hint(LocaleManager.t("hint_check_phone_first"))
			return
		TransitionManager.transition_to_scene("res://scenes/levels/prologue_street.tscn")

func _on_phone_viewed() -> void:
	if not _phone_opened_once:
		_phone_opened_once = true
		_show_hint(LocaleManager.t("hint_find_sister"), 5.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and GameManager.current_state == GameManager.GameState.PLAYING:
		if player and phone_area:
			if player.global_position.distance_to(phone_area.global_position) < 70.0:
				_on_phone_interact()
