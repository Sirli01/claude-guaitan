extends Node2D
## 序章 - 街道场景（温馨→恐怖的转折点）
## 流程：黑屏渐亮 + 城市BGM渐入 → 姐姐独白动画演出 → 自由探索（BGM继续播放）

var player: CharacterBody2D
var hud_layer: CanvasLayer
var _hint_labels: Array[Dictionary] = []
const HINT_DURATION: float = 4.0
const HINT_FADE_TIME: float = 1.0
const HINT_LINE_HEIGHT: int = 40
var _stamina_bar: ProgressBar
var _sanity_bar: ProgressBar
var _signal_callbacks: Array[Dictionary] = []
var _loop_tweens: Array[Tween] = []  # 无限循环tween，场景切换前需kill
var _apt_entrance: Area2D  # 公寓入口区域
var _apt_prompt: Label     # 公寓"按E进入"提示
var _home_entrance: Area2D  # 姐姐家入口
var _home_prompt: Label     # 姐姐家"按E进入"提示
var _wlm: Node  # WorldLabelManager
var _fg_buildings: Node2D  # 前景建筑容器（手动视差）
var _parallax_bg: ParallaxBackground

# 隐藏道具映射：装饰物名称 → 包含的道具
var _street_containers: Array[Area2D] = []

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	GameManager.change_floor(GameManager.Floor.STREET)
	
	var is_returning = GameManager.has_meta("street_intro_played")
	
	_build_street()
	_build_player()
	_wlm = load("res://scripts/utils/world_label_manager.gd").new()
	_wlm.setup(self, 2.0)
	_build_hidden_items()
	_build_home_entrance()
	_build_apartment_entrance()
	_build_ui()
	LevelBaseV2.fix_label_filter(self)
	
	if is_returning:
		# 从房间返回街道 — 跳过镜头演出，在家门口出生
		player.position = Vector2(-410, 0)
		
		var fade_rect = ColorRect.new()
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color.BLACK
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_layer.add_child(fade_rect)
		
		# 恢复城市BGM（如果已在播放则不重启）
		var city_bgm = "res://assets/audio/bgm/城市散步.mp3"
		if ResourceLoader.exists(city_bgm):
			var bgm_stream = load(city_bgm)
			if not AudioManager.bgm_player.playing or AudioManager.bgm_player.stream != bgm_stream:
				AudioManager.play_bgm(bgm_stream, 1.5)
		
		var fade_tw = create_tween()
		fade_tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
		await fade_tw.finished
		fade_rect.queue_free()
		
		GameManager.set_state(GameManager.GameState.PLAYING)
		player.unfreeze_player()
		return
	
	# 玩家先冻结（动画演出期间不能动）
	player.freeze_player()
	
	# === 开场演出 ===
	# 1. 黑屏 + 城市BGM开始渐入（音乐和画面同时开始）
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fade_rect)
	
	# 播放城市BGM（渐入2秒）— 动画结束后音乐继续
	var city_bgm = "res://assets/audio/bgm/城市散步.mp3"
	if ResourceLoader.exists(city_bgm):
		AudioManager.play_bgm(load(city_bgm), 2.0)
	
	# 2. 画面渐亮（2秒）
	var fade_tw = create_tween()
	fade_tw.tween_property(fade_rect, "color:a", 0.0, 2.0)
	await fade_tw.finished
	fade_rect.queue_free()
	
	# 3. 镜头动画演出 — 从街道左侧慢慢平移到右侧展示整条街
	#    玩家角色站在左边不动，用摄像机 offset 偏移
	var cam = player.camera as Camera2D
	if cam:
		cam.position_smoothing_enabled = false
		
		# 镜头1：向下平移展示街道（2秒）
		var pan_down = create_tween()
		pan_down.tween_property(cam, "offset", Vector2(0, 120), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await pan_down.finished
		await get_tree().create_timer(0.8).timeout
		
		# 镜头2：向右平移看到公寓入口（3秒）
		var pan_right = create_tween()
		pan_right.tween_property(cam, "offset", Vector2(750, 50), 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await pan_right.finished
		await get_tree().create_timer(1.5).timeout
		
		# 镜头回到玩家身上
		var return_tw = create_tween()
		return_tw.tween_property(cam, "offset", Vector2.ZERO, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await return_tw.finished
		
		# 恢复摄像机跟随
		cam.position_smoothing_enabled = true
	
	# 4. 演出结束 → 玩家自由操控（BGM继续播放不中断）
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.set_meta("street_intro_played", true)
	player.unfreeze_player()
	show_hint(LocaleManager.t("hint_explore_street"), 5.0)
	
	# 5. 第一首BGM播完后，停顿3秒，自动播第二首城市BGM
	var city_bgm2 = "res://assets/audio/bgm/城市散步2.mp3"
	if ResourceLoader.exists(city_bgm) and ResourceLoader.exists(city_bgm2):
		# 用播放列表实现自动轮播
		AudioManager._bgm_playlist = [load(city_bgm), load(city_bgm2)]
		AudioManager._bgm_playlist_index = 0  # 当前正在播第一首
		AudioManager._bgm_playlist_pause = 3.0
		AudioManager._bgm_playlist_fade = 1.5
		AudioManager._bgm_playlist_active = true
		if not AudioManager.bgm_player.finished.is_connected(AudioManager._on_playlist_track_finished):
			AudioManager.bgm_player.finished.connect(AudioManager._on_playlist_track_finished)

func _build_street() -> void:
	# ===== 温馨城市街道（斜俯视角） =====
	# 布局：上方=远景北侧建筑，中间=马路，下方=前景南侧建筑
	# 全部色块覆盖，不留黑色空白
	
	var W = 2400  # 场景视觉宽度
	var HW = W / 2  # 半宽
	
	# ==================== 夜空背景 ====================
	var sky = ColorRect.new()
	sky.color = Color(0.08, 0.07, 0.14)
	sky.position = Vector2(-HW, -800)
	sky.size = Vector2(W, 600)
	sky.z_index = -10
	add_child(sky)

	# ==================== 远景建筑（贴图）====================
	const STREET_TEX = "res://assets/sprites/street/后景楼和马路.png"
	if ResourceLoader.exists(STREET_TEX):
		var street_tex = load(STREET_TEX)
		var street_scale = 170.0 / 436.0  # 马路部分保持原高度≈170px
		var street_spr_w = street_tex.get_width() * street_scale
		var street_start_x = -HW - 400
		var street_copies = int(ceil((W + 800) / street_spr_w)) + 1
		var road_top_in_tex = street_tex.get_height() - 436.0  # 马路在贴图底部≈436px
		for c in range(street_copies):
			var spr = Sprite2D.new()
			spr.texture = street_tex
			spr.scale = Vector2(street_scale, street_scale)
			spr.centered = false
			spr.position = Vector2(street_start_x + c * street_spr_w, -52 - road_top_in_tex * street_scale)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.z_index = -8
			add_child(spr)
	
	for x in [-450, -200, 50, 250, 450]:
		_add_streetlamp(Vector2(x, -10))
	
	# ==================== 行道树 ====================
	for x in [-350, -100, 150, 350]:
		_add_tree(Vector2(x, -10))
	
	# ==================== 街边装饰物（可探索）====================
	_build_street_props()
	
	# ==================== 全局月光（夜景）====================
	var sun = PointLight2D.new()
	sun.position = Vector2(200, -250)
	sun.color = Color(0.55, 0.65, 0.85)
	sun.energy = 0.15
	var sun_img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for px in 128:
		for py in 128:
			var dist = Vector2(px - 64, py - 64).length() / 64.0
			var alpha = clampf(1.0 - dist * 0.7, 0.0, 1.0)
			sun_img.set_pixel(px, py, Color(1, 1, 1, alpha * alpha))
	sun.texture = ImageTexture.create_from_image(sun_img)
	sun.texture_scale = 10.0
	sun.z_index = -1
	add_child(sun)
	
	# ==================== 光尘粒子 ====================
	_add_dust_particles()
	
	# ==================== 天空视差（仅天空有轻微视差）====================
	_parallax_bg = ParallaxBackground.new()
	_parallax_bg.layer = -1
	add_child(_parallax_bg)

	var sky_layer = ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.05, 0.05)
	_parallax_bg.add_child(sky_layer)
	sky.reparent(sky_layer)
	
	# ==================== 前景南侧建筑（贴图，手动视差）====================
	_fg_buildings = Node2D.new()
	_fg_buildings.z_index = 5
	add_child(_fg_buildings)

	const FG_TEX = "res://assets/sprites/street/前景楼.png"
	# 【手动调节】数值越小（越负）= 建筑越靠上，露出的可玩区域越多
	const FG_TOP_Y = -100.0
	const FG_SCALE_MULTIPLIER = 2.0
	var fg_base_y = 320  # 建筑底部对齐线
	if ResourceLoader.exists(FG_TEX):
		var fg_tex = load(FG_TEX)
		var fg_scale = (fg_base_y - FG_TOP_Y) / fg_tex.get_height() * FG_SCALE_MULTIPLIER
		var fg_spr_w = fg_tex.get_width() * fg_scale
		var fg_start_x = -HW - 400
		var fg_top_y = FG_TOP_Y
		var fg_copies = int(ceil((W + 800) / fg_spr_w)) + 1
		for c in range(fg_copies):
			var fg_spr = Sprite2D.new()
			fg_spr.texture = fg_tex
			fg_spr.scale = Vector2(fg_scale, fg_scale)
			fg_spr.centered = false
			fg_spr.position = Vector2(fg_start_x + c * fg_spr_w, fg_top_y)
			fg_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_fg_buildings.add_child(fg_spr)
	# 前景底部填充（建筑下方地面）
	var fg_ground = ColorRect.new()
	fg_ground.color = Color(0.12, 0.10, 0.10)
	fg_ground.position = Vector2(-HW, fg_base_y + 3)
	fg_ground.size = Vector2(W, 600)
	_fg_buildings.add_child(fg_ground)
	
	
	# ==================== 边界墙 + 提示 ====================
	var walls = StaticBody2D.new()
	walls.collision_layer = 4
	add_child(walls)
	_add_wall(walls, Vector2(0, -10), Vector2(1220, 10))  # 北侧墙壁（与杂物对齐）
	_add_wall(walls, Vector2(0, 90), Vector2(1220, 10))   # 南侧路缘石
	_add_wall(walls, Vector2(-605, 0), Vector2(10, 160))
	_add_wall(walls, Vector2(605, 0), Vector2(10, 160))
	
	# 左侧边界提示
	var left_border = Area2D.new()
	left_border.position = Vector2(-580, 0)
	left_border.collision_layer = 0
	left_border.collision_mask = 1
	add_child(left_border)
	var lb_col = CollisionShape2D.new()
	var lb_shape = RectangleShape2D.new()
	lb_shape.size = Vector2(40, 160)
	lb_col.shape = lb_shape
	left_border.add_child(lb_col)
	left_border.body_entered.connect(func(body):
		if body.is_in_group("player"):
			show_hint(LocaleManager.t("hint_dead_end"), 3.0)
	)
	
	# 右侧边界提示
	var right_border = Area2D.new()
	right_border.position = Vector2(580, 0)
	right_border.collision_layer = 0
	right_border.collision_mask = 1
	add_child(right_border)
	var rb_col = CollisionShape2D.new()
	var rb_shape = RectangleShape2D.new()
	rb_shape.size = Vector2(40, 160)
	rb_col.shape = rb_shape
	right_border.add_child(rb_col)
	right_border.body_entered.connect(func(body):
		if body.is_in_group("player"):
			show_hint(LocaleManager.t("hint_wrong_way"), 3.0)
	)

func _add_streetlamp(pos: Vector2) -> void:
	const TEX = "res://assets/sprites/street/户外_0004_路灯.png"
	var lamp_height: float = 107.0
	if ResourceLoader.exists(TEX):
		var tex = load(TEX)
		var sc = 107.0 / tex.get_height()  # 路灯≈2.5x玩家
		lamp_height = tex.get_height() * sc
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(sc, sc)
		spr.centered = false
		spr.position = pos + Vector2(0, -lamp_height)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
	# 灯光效果（暖黄色）
	var light = PointLight2D.new()
	light.position = pos + Vector2(0, -lamp_height * 0.5)
	light.color = Color(1.0, 0.88, 0.55)
	light.energy = 0.25
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 64:
			var dist = Vector2(x - 32, y - 32).length() / 32.0
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	light.texture = ImageTexture.create_from_image(img)
	light.texture_scale = 3.5
	add_child(light)

func _add_tree(pos: Vector2) -> void:
	const TEX = "res://assets/sprites/street/户外_0005_树.png"
	if ResourceLoader.exists(TEX):
		var tex = load(TEX)
		var sc = 100.0 / tex.get_height()  # 树≈2.4x玩家
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(sc, sc)
		spr.centered = false
		spr.position = pos + Vector2(0, -tex.get_height() * sc)
		spr.z_index = -2
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)

func _add_dust_particles() -> void:
	# 空气中飘浮的暖色光尘
	var particles = GPUParticles2D.new()
	particles.position = Vector2(0, -50)
	particles.z_index = 2
	particles.amount = 30
	particles.lifetime = 6.0
	particles.speed_scale = 0.5
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, -0.3, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3(0, -2, 0)  # 微微上浮
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(500, 100, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = Color(0.7, 0.75, 0.9, 0.3)
	
	# 透明度渐变（出现时淡入，消失时淡出）
	var alpha_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	
	particles.process_material = mat
	
	# 粒子贴图（小圆点）
	var pimg = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for px in 8:
		for py in 8:
			var dist = Vector2(px - 4, py - 4).length() / 4.0
			var a = clampf(1.0 - dist, 0.0, 1.0)
			pimg.set_pixel(px, py, Color(1, 1, 1, a))
	particles.texture = ImageTexture.create_from_image(pimg)
	
	add_child(particles)

func _add_wall(parent: Node2D, pos: Vector2, size: Vector2) -> void:
	var shape = CollisionShape2D.new()
	shape.position = pos
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	parent.add_child(shape)

func _build_street_props() -> void:
	# ===== 街边装饰物（贴图）=====
	_add_prop_sprite(Vector2(320, -10), "res://assets/sprites/street/户外_0000_邮箱.png", 30.0)  # 邮箱（手电筒）
	_add_prop_sprite(Vector2(-200, -10), "res://assets/sprites/street/户外_0000_草丛.png", 28.0)  # 草丛A（糖果）
	_add_prop_sprite(Vector2(-50, -10), "res://assets/sprites/street/户外_0002_垃圾桶.png", 30.0)  # 垃圾桶1
	_add_prop_sprite(Vector2(-380, -10), "res://assets/sprites/street/户外_0002_垃圾桶.png", 30.0)  # 垃圾桶2
	_add_prop_sprite(Vector2(100, -10), "res://assets/sprites/street/户外_0001_长椅.png", 20.0, 56.0)  # 长椅1（底部大量透明留白）
	_add_prop_sprite(Vector2(-300, -10), "res://assets/sprites/street/户外_0001_长椅.png", 20.0, 56.0)  # 长椅2（底部大量透明留白）
	_add_prop_sprite(Vector2(430, -10), "res://assets/sprites/street/户外_0000_草丛.png", 28.0)  # 草丛B（纯装饰）
	_add_prop_sprite(Vector2(220, -10), "res://assets/sprites/street/户外_0006_消防栓.png", 22.0)  # 消防栓
	_add_prop_sprite(Vector2(0, -10), "res://assets/sprites/street/户外_0003_报刊架-.png", 42.0)  # 报刊架

func _add_prop_sprite(pos: Vector2, tex_path: String, target_height: float, bottom_pad_px: float = 0.0) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var tex = load(tex_path)
	var sc = target_height / tex.get_height()
	var pad_offset = bottom_pad_px * sc  # 补偿贴图底部透明留白
	var spr = Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(sc, sc)
	spr.centered = false
	spr.position = pos + Vector2(0, -target_height + pad_offset)
	spr.z_index = -2
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(-400, 0)
	player.collision_layer = 1
	player.collision_mask = 5
	player.set_script(load("res://scripts/player/player.gd"))
	
	var sprite = Sprite2D.new()
	sprite.texture = GameManager.load_char_texture("sister", 16, 20)
	GameManager.fit_character_sprite(sprite, "sister")
	player.add_child(sprite)
	player.sprite = sprite
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = GameManager.PLAYER_COLLISION_SIZE
	col.shape = shape
	col.position = GameManager.PLAYER_COLLISION_OFFSET
	player.add_child(col)
	player.collision = col
	
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 22
	var area_col = CollisionShape2D.new()
	var area_shape = CircleShape2D.new()
	area_shape.radius = 30.0
	area_col.shape = area_shape
	area.add_child(area_col)
	player.add_child(area)
	player.interaction_area = area
	
	var cam = Camera2D.new()
	cam.zoom = Vector2(3.0, 3.0)
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	player.camera = cam
	
	var light = PointLight2D.new()
	light.color = Color(0.75, 0.8, 0.95)
	light.energy = 0.25  # 夜景角色光（冷色调）
	var limg = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for x in 128:
		for y in 128:
			var dist = Vector2(x - 64, y - 64).length() / 64.0
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			limg.set_pixel(x, y, Color(1, 1, 1, alpha))
	light.texture = ImageTexture.create_from_image(limg)
	light.texture_scale = 3.0
	player.add_child(light)
	player.point_light = light
	
	# 所有子节点就绪后再加入场景树
	add_child(player)

func _build_hidden_items() -> void:
	# 用 furniture_container 方式创建可探索的街边物件
	# 邮箱 → 手电筒
	_place_street_container(Vector2(320, -10), "邮箱", "flashlight", "手电筒")
	# 草丛A → 电池
	_place_street_container(Vector2(-200, -10), "草丛", "sweets", "糖果")
	# 垃圾桶1 → 空
	_place_street_container(Vector2(-50, -10), "垃圾桶", "", "")
	# 垃圾桶2 → 空
	_place_street_container(Vector2(-380, -10), "垃圾桶", "", "")
	# 长椅1 → 空
	_place_rest_bench(Vector2(100, -10))
	# 报刊架 → 空
	_place_street_container(Vector2(0, -10), "报刊架", "", "")
	# 消防栓 → 空
	_place_street_container(Vector2(220, -10), "消防栓", "", "")
	# 长椅2 → 空
	_place_rest_bench(Vector2(-300, -10))
	# 草丛B → 空
	_place_street_container(Vector2(430, -10), "草丛", "", "")

func _place_rest_bench(pos: Vector2) -> void:
	## 可休息的长椅 — 坐下2秒快速恢复全部体力
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/rest_bench.gd"))
	area.position = pos
	area.collision_layer = 16
	area.collision_mask = 1
	area._level = self
	add_child(area)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	area.add_child(col)
	
	var label = _wlm.create_label(LocaleManager.bench_prompt_text(), pos + Vector2(-35, -28), 18, Color(0.0, 0.0, 0.0))
	label.visible = false
	area._name_label = label
	area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())

func _place_street_container(pos: Vector2, fname: String, item_id: String, item_name: String) -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/furniture_container.gd"))
	area.position = pos
	area.collision_layer = 16
	area.furniture_name = fname
	area.contained_item_id = item_id
	area.contained_item_name = item_name
	area._level = self
	add_child(area)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	area.add_child(col)
	
	# 名称标签（靠近时显示）
	var label = _wlm.create_label("%s %s" % [LocaleManager.world_text(fname), InputDevice.hint("interact")], pos + Vector2(-25, -28), 18, Color(0.0, 0.0, 0.0))
	label.visible = false
	area._name_label = label
	area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())
	_street_containers.append(area)

func show_hint(text: String, duration: float = HINT_DURATION) -> void:
	for entry in _hint_labels:
		var lbl = entry.get("label")
		if is_instance_valid(lbl):
			lbl.position.y -= HINT_LINE_HEIGHT

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = -90
	label.offset_bottom = -45
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
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

func _build_home_entrance() -> void:
	# ===== 夏桐的家 — 左侧建筑群中的一栋，门可返回房间 =====
	var home_x = -460.0
	var home_w = 100.0
	var home_h = 120.0
	
	# 门牌
	var home_label = _wlm.create_label(LocaleManager.world_text("夏桐的家"), Vector2(home_x + home_w/2 - 28, -58), 14, Color(0.7, 0.55, 0.35))
	
	# 触发区域 — 需按E进入
	_home_entrance = Area2D.new()
	_home_entrance.position = Vector2(home_x + home_w/2, -25)
	_home_entrance.collision_layer = 0
	_home_entrance.collision_mask = 1
	add_child(_home_entrance)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 35)
	col.shape = shape
	_home_entrance.add_child(col)
	
	_home_prompt = _wlm.create_label(LocaleManager.t("prompt_go_home") % InputDevice.hint("interact"), Vector2(home_x + home_w/2, -25) + Vector2(-25, -45), 16, Color(1.0, 1.0, 0.7))
	_home_prompt.visible = false

func _enter_home() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 杀掉循环tween
	for tw in _loop_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	
	TransitionManager.transition_to_scene("res://scenes/levels/prologue_room.tscn", 0.5)

func _build_apartment_entrance() -> void:
	# ===== 归栖公寓 — 街道最右边的一栋楼，门可以进入 =====
	var apt_x = 470.0
	var apt_w = 120.0
	var apt_h = 150.0
	
	var apt_label = _wlm.create_label(LocaleManager.world_text("归栖公寓"), Vector2(apt_x + apt_w/2 - 30, -66), 16, Color(0.95, 0.85, 0.6))
	
	# 门上方小灯
	var door_light = PointLight2D.new()
	door_light.position = Vector2(apt_x + apt_w/2, -55)
	door_light.color = Color(1.0, 0.85, 0.5)
	door_light.energy = 0.25
	var dl_img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for px in 32:
		for py in 32:
			var dist = Vector2(px - 16, py - 16).length() / 16.0
			var a = clampf(1.0 - dist, 0.0, 1.0)
			dl_img.set_pixel(px, py, Color(1, 1, 1, a))
	door_light.texture = ImageTexture.create_from_image(dl_img)
	door_light.texture_scale = 3.5
	add_child(door_light)
	
	# 进入触发区域（在门的位置）— 需按E进入
	_apt_entrance = Area2D.new()
	_apt_entrance.position = Vector2(apt_x + apt_w/2, -20)
	_apt_entrance.collision_layer = 0
	_apt_entrance.collision_mask = 1  # 检测玩家
	add_child(_apt_entrance)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(30, 40)
	col.shape = shape
	_apt_entrance.add_child(col)
	
	# "按E进入"提示标签
	_apt_prompt = _wlm.create_label(LocaleManager.t("prompt_enter_apartment") % InputDevice.hint("interact"), Vector2(apt_x + apt_w/2, -20) + Vector2(-40, -30), 16, Color(1.0, 1.0, 0.7))
	_apt_prompt.visible = false

func _process(_delta: float) -> void:
	if _wlm and player and player.camera:
		_wlm.set_camera(player.camera)
		_wlm.update_positions()
	# 视差背景跟随相机
	if _parallax_bg and player and player.camera:
		_parallax_bg.scroll_offset = player.camera.get_screen_center_position()
	# 前景建筑手动视差：相对相机偏移，移动速度 > 1.0 产生前景感
	if _fg_buildings and player and player.camera:
		var cam_center = player.camera.get_screen_center_position()
		# 前景额外偏移 = 相机位置 × (视差系数 - 1.0)
		# 视差系数 1.35 → 前景比主场景多移动 35%
		_fg_buildings.position = -cam_center * 0.35
	# 入口提示显示/隐藏（动态更新按键）
	if player:
		if _apt_entrance and _apt_prompt:
			var near_apt = player.global_position.distance_to(_apt_entrance.global_position) < 35.0
			if near_apt:
				_apt_prompt.text = LocaleManager.t("prompt_enter_apartment") % InputDevice.hint("interact")
			_apt_prompt.visible = near_apt
		if _home_entrance and _home_prompt:
			var near_home = player.global_position.distance_to(_home_entrance.global_position) < 35.0
			if near_home:
				_home_prompt.text = LocaleManager.t("prompt_go_home") % InputDevice.hint("interact")
			_home_prompt.visible = near_home

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and GameManager.current_state == GameManager.GameState.PLAYING:
		if not player:
			return
		if _apt_entrance and player.global_position.distance_to(_apt_entrance.global_position) < 35.0:
			_enter_apartment()
		elif _home_entrance and player.global_position.distance_to(_home_entrance.global_position) < 35.0:
			_enter_home()

func _enter_apartment() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 杀掉所有无限循环tween，避免场景切换时崩溃
	for tw in _loop_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	
	# 【核心转折】所有声音瞬间切断
	AudioManager.stop_playlist(0.0)
	AudioManager.bgm_player.stop()
	AudioManager.enter_silence_mode()
	TransitionManager.hard_cut_to_black()
	
	await get_tree().create_timer(2.0).timeout
	
	# 切换到第一层
	TransitionManager.transition_to_scene("res://scenes/levels/floor_1.tscn")

func _build_ui() -> void:
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
	
	var floor_label = Label.new()
	floor_label.text = LocaleManager.t("floor_prologue_street")
	floor_label.add_theme_font_size_override("font_size", 30)
	floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_bar.add_child(floor_label)
	
	# ===== 体力 + 理智条 =====
	var status_vbox = VBoxContainer.new()
	status_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_vbox.offset_left = 30
	status_vbox.offset_top = 57
	status_vbox.offset_right = 240
	status_vbox.add_theme_constant_override("separation", 6)
	hud_layer.add_child(status_vbox)
	
	# 体力条
	var stamina_label = Label.new()
	stamina_label.text = LocaleManager.t("stat_stamina")
	stamina_label.add_theme_font_size_override("font_size", 22)
	stamina_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	status_vbox.add_child(stamina_label)
	
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(180, 12)
	_stamina_bar.max_value = PlayerStats.max_stamina
	_stamina_bar.value = PlayerStats.stamina
	_stamina_bar.show_percentage = false
	var stam_bg = StyleBoxFlat.new()
	stam_bg.bg_color = Color(0.15, 0.12, 0.12)
	stam_bg.corner_radius_top_left = 2; stam_bg.corner_radius_top_right = 2
	stam_bg.corner_radius_bottom_left = 2; stam_bg.corner_radius_bottom_right = 2
	_stamina_bar.add_theme_stylebox_override("background", stam_bg)
	var stam_fill = StyleBoxFlat.new()
	stam_fill.bg_color = Color(0.4, 0.8, 0.3)
	stam_fill.corner_radius_top_left = 2; stam_fill.corner_radius_top_right = 2
	stam_fill.corner_radius_bottom_left = 2; stam_fill.corner_radius_bottom_right = 2
	_stamina_bar.add_theme_stylebox_override("fill", stam_fill)
	status_vbox.add_child(_stamina_bar)
	
	# 理智条
	var sanity_label = Label.new()
	sanity_label.text = LocaleManager.t("stat_sanity")
	sanity_label.add_theme_font_size_override("font_size", 22)
	sanity_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.9))
	status_vbox.add_child(sanity_label)
	
	_sanity_bar = ProgressBar.new()
	_sanity_bar.custom_minimum_size = Vector2(180, 12)
	_sanity_bar.max_value = PlayerStats.max_sanity
	_sanity_bar.value = PlayerStats.sanity
	_sanity_bar.show_percentage = false
	var san_bg = StyleBoxFlat.new()
	san_bg.bg_color = Color(0.12, 0.1, 0.15)
	san_bg.corner_radius_top_left = 2; san_bg.corner_radius_top_right = 2
	san_bg.corner_radius_bottom_left = 2; san_bg.corner_radius_bottom_right = 2
	_sanity_bar.add_theme_stylebox_override("background", san_bg)
	var san_fill = StyleBoxFlat.new()
	san_fill.bg_color = Color(0.5, 0.4, 0.9)
	san_fill.corner_radius_top_left = 2; san_fill.corner_radius_top_right = 2
	san_fill.corner_radius_bottom_left = 2; san_fill.corner_radius_bottom_right = 2
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
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var dialogue_ui = dlg_scene.instantiate()
	add_child(dialogue_ui)
	
	# 背包UI
	var inv_layer = CanvasLayer.new()
	inv_layer.layer = 15
	inv_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inv_layer)
	var inv_ui = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	inv_layer.add_child(inv_ui)

func _exit_tree() -> void:
	# 杀掉所有无限循环tween
	for tw in _loop_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	for entry in _signal_callbacks:
		if entry["signal"].is_connected(entry["callable"]):
			entry["signal"].disconnect(entry["callable"])
	_signal_callbacks.clear()

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