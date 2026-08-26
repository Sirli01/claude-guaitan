extends Node2D
## 序章 - 街道场景（温馨→恐怖的转折点）
## 街道视觉（天空视差/建筑/路灯/树/装饰物）、交互容器、入口、玩家与 HUD 均在 .tscn 中定义
## 脚本只负责：运行时数据绑定、世界标签创建、信号连接与开场镜头演出
## 流程：黑屏渐亮 + 城市BGM渐入 → 姐姐独白动画演出 → 自由探索（BGM继续播放）

@onready var player: CharacterBody2D = %Player
@onready var hud_layer: CanvasLayer = %HUDLayer
@onready var floor_label: Label = %FloorLabel
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var sanity_label: Label = %SanityLabel
@onready var sanity_bar: ProgressBar = %SanityBar
@onready var parallax_bg: ParallaxBackground = %ParallaxBG
@onready var fg_buildings: Node2D = %FgBuildings

@onready var left_border: Area2D = %LeftBorder
@onready var right_border: Area2D = %RightBorder
@onready var home_entrance: Area2D = %HomeEntrance
@onready var apartment_entrance: Area2D = %ApartmentEntrance
@onready var interactables: Node2D = %Interactables
@onready var inventory_layer: CanvasLayer = %InventoryLayer

var _hint_labels: Array[Dictionary] = []
const HINT_DURATION: float = 4.0
const HINT_FADE_TIME: float = 1.0
const HINT_LINE_HEIGHT: int = 40
var _signal_callbacks: Array[Dictionary] = []
var _loop_tweens: Array[Tween] = []  # 无限循环tween，场景切换前需kill
var _apt_prompt: Label     # 公寓"按E进入"提示
var _home_prompt: Label    # 姐姐家"按E进入"提示
var _wlm: Node  # WorldLabelManager

## 街道场景入口：初始化玩家/交互/入口/UI，并按是否首次进入播放开场镜头演出
func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	GameManager.change_floor(GameManager.Floor.STREET)

	var is_returning: bool = GameManager.has_meta("street_intro_played")

	_wlm = load("res://scripts/utils/world_label_manager.gd").new()
	_wlm.setup(self, 2.0)
	_setup_player()
	_setup_interactables()
	_setup_entrances()
	_setup_ui()
	LevelBaseV2.fix_label_filter(self)

	if is_returning:
		# 从房间返回街道 — 跳过镜头演出，在家门口出生
		player.position = Vector2(-410, 0)

		# 恢复城市BGM（如果已在播放则不重启）
		var city_bgm := "res://assets/audio/bgm/城市散步.mp3"
		if ResourceLoader.exists(city_bgm):
			var bgm_stream: AudioStream = load(city_bgm)
			if not AudioManager.bgm_player.playing or AudioManager.bgm_player.stream != bgm_stream:
				AudioManager.play_bgm(bgm_stream, 1.5)

		_fade_from_black(1.0)
		GameManager.set_state(GameManager.GameState.PLAYING)
		player.unfreeze_player()
		return

	# 玩家先冻结（动画演出期间不能动）
	player.freeze_player()

	# === 开场演出 ===
	# 1. 黑屏 + 城市BGM开始渐入（音乐和画面同时开始）
	# 播放城市BGM（渐入2秒）— 动画结束后音乐继续
	var city_bgm := "res://assets/audio/bgm/城市散步.mp3"
	if ResourceLoader.exists(city_bgm):
		AudioManager.play_bgm(load(city_bgm), 2.0)

	# 2. 画面渐亮（2秒）
	_fade_from_black(2.0)

	# 3. 镜头动画演出 — 从街道左侧慢慢平移到右侧展示整条街
	#    玩家角色站在左边不动，用摄像机 offset 偏移
	var cam := player.camera as Camera2D
	if cam:
		cam.position_smoothing_enabled = false

		# 镜头1：向下平移展示街道（2秒）
		var pan_down := create_tween()
		pan_down.tween_property(cam, "offset", Vector2(0, 120), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await pan_down.finished
		await get_tree().create_timer(0.8).timeout

		# 镜头2：向右平移看到公寓入口（3秒）
		var pan_right := create_tween()
		pan_right.tween_property(cam, "offset", Vector2(750, 50), 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await pan_right.finished
		await get_tree().create_timer(1.5).timeout

		# 镜头回到玩家身上
		var return_tw := create_tween()
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
	var city_bgm2 := "res://assets/audio/bgm/城市散步2.mp3"
	if ResourceLoader.exists(city_bgm) and ResourceLoader.exists(city_bgm2):
		# 用播放列表实现自动轮播
		AudioManager._bgm_playlist = [load(city_bgm), load(city_bgm2)]
		AudioManager._bgm_playlist_index = 0  # 当前正在播第一首
		AudioManager._bgm_playlist_pause = 3.0
		AudioManager._bgm_playlist_fade = 1.5
		AudioManager._bgm_playlist_active = true
		if not AudioManager.bgm_player.finished.is_connected(AudioManager._on_playlist_track_finished):
			AudioManager.bgm_player.finished.connect(AudioManager._on_playlist_track_finished)

## 黑屏渐入过渡（全屏黑色 ColorRect 淡出后销毁）。
## [param duration] 淡出时长（秒）。属于运行时过渡特效，故动态创建。
func _fade_from_black(duration: float) -> void:
	var fade_rect := ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fade_rect)

	var fade_tw := create_tween()
	fade_tw.tween_property(fade_rect, "color:a", 0.0, duration)
	await fade_tw.finished
	fade_rect.queue_free()

## 配置场景中实例化的玩家：加载贴图、设置街道摄像机缩放与交互半径。
## 节点结构来自 player.tscn，这里只做运行时数据绑定。
## 街道世界为 v1 尺度，角色贴图已全局放大 2 倍，故缩回 0.5 保持 v1 比例。
func _setup_player() -> void:
	const CHAR_SCALE := 0.5
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = GameManager.load_char_texture("sister", 16, 20)
		GameManager.fit_character_sprite(sprite, "sister")
		player.sprite = sprite

	var col: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if col:
		GameManager.fit_character_collision(col, "sister")
		# 世界未翻倍，碰撞体同步缩回（duplicate 防止污染共享资源）
		if col.shape is RectangleShape2D:
			col.shape = col.shape.duplicate()
			col.shape.size *= CHAR_SCALE
		col.position *= CHAR_SCALE
		player.collision = col

	var area: Area2D = player.get_node_or_null("InteractionArea")
	if area:
		player.interaction_area = area
		# 街道使用更小的交互半径；新建形状避免修改 player.tscn 的共享资源
		if area.get_child_count() > 0:
			var area_col := area.get_child(0) as CollisionShape2D
			if area_col:
				var circle := CircleShape2D.new()
				circle.radius = 30.0
				area_col.shape = circle

	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.zoom = Vector2(3.0, 3.0)
		# 街道横向范围有限，宽屏下限制相机不看到两端外
		cam.limit_left = -620
		cam.limit_right = 620
		cam.limit_top = -300
		cam.limit_bottom = 400
		player.camera = cam

	var light: PointLight2D = player.get_node_or_null("PointLight2D")
	if light:
		player.point_light = light

	# tscn 实例化时 sprite 晚于玩家 _ready 赋值，需补建帧动画组件
	player.ensure_frame_animator()
	# 在帧目录预览布局的基础上缩回街道 v1 比例（位置偏移同步缩放）
	if sprite:
		sprite.scale *= CHAR_SCALE
		sprite.position *= CHAR_SCALE

## 绑定街边交互容器与长椅：挂接关卡引用并创建靠近时显示的世界标签。
func _setup_interactables() -> void:
	var container_script: Script = load("res://scripts/items/furniture_container.gd")
	var bench_script: Script = load("res://scripts/items/rest_bench.gd")
	for area in interactables.get_children():
		var area_script: Script = area.get_script()
		if area_script == container_script:
			area._level = self
			var text := "%s %s" % [LocaleManager.world_text(area.furniture_name), InputDevice.hint("interact")]
			var label: Label = _wlm.create_label(text, area.position + Vector2(-25, -28), 18, Color(0.0, 0.0, 0.0))
			label.visible = false
			area._name_label = label
			area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())
		elif area_script == bench_script:
			area._level = self
			var bench_label: Label = _wlm.create_label(LocaleManager.bench_prompt_text(), area.position + Vector2(-35, -28), 18, Color(0.0, 0.0, 0.0))
			bench_label.visible = false
			area._name_label = bench_label
			area.tree_exiting.connect(func(): if is_instance_valid(bench_label): bench_label.queue_free())

## 创建家门口/公寓口的名称标签与提示标签，连接左右边界提示信号。
func _setup_entrances() -> void:
	# 门牌
	_wlm.create_label(LocaleManager.world_text("夏桐的家"), Vector2(-410, -58), 14, Color(0.7, 0.55, 0.35))
	_home_prompt = _wlm.create_label(LocaleManager.t("prompt_go_home") % InputDevice.hint("interact"), home_entrance.position + Vector2(-25, -45), 16, Color(1.0, 1.0, 0.7))
	_home_prompt.visible = false

	_wlm.create_label(LocaleManager.world_text("归栖公寓"), Vector2(500, -66), 16, Color(0.95, 0.85, 0.6))
	_apt_prompt = _wlm.create_label(LocaleManager.t("prompt_enter_apartment") % InputDevice.hint("interact"), apartment_entrance.position + Vector2(-40, -30), 16, Color(1.0, 1.0, 0.7))
	_apt_prompt.visible = false

	left_border.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			show_hint(LocaleManager.t("hint_dead_end"), 3.0)
	)
	right_border.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			show_hint(LocaleManager.t("hint_wrong_way"), 3.0)
	)

## 绑定 HUD 数据：多语言文本、体力/理智条数值与信号。UI 结构已在 .tscn 中定义。
func _setup_ui() -> void:
	floor_label.text = LocaleManager.t("floor_prologue_street")
	stamina_label.text = LocaleManager.t("stat_stamina")
	sanity_label.text = LocaleManager.t("stat_sanity")

	stamina_bar.max_value = PlayerStats.max_stamina
	stamina_bar.value = PlayerStats.stamina
	sanity_bar.max_value = PlayerStats.max_sanity
	sanity_bar.value = PlayerStats.sanity

	# 启用体力系统
	PlayerStats.stamina_enabled = true

	# 信号连接
	var _stam_cb := func(current: float, max_val: float) -> void:
		if stamina_bar:
			stamina_bar.value = current
			var fill_s: StyleBoxFlat = stamina_bar.get_theme_stylebox("fill")
			if current / max_val < 0.25:
				fill_s.bg_color = Color(0.9, 0.2, 0.2)
			elif current / max_val < 0.5:
				fill_s.bg_color = Color(0.9, 0.6, 0.2)
			else:
				fill_s.bg_color = Color(0.4, 0.8, 0.3)
	PlayerStats.stamina_changed.connect(_stam_cb)
	_signal_callbacks.append({"signal": PlayerStats.stamina_changed, "callable": _stam_cb})

	var _san_cb := func(current: float, max_val: float) -> void:
		if sanity_bar:
			sanity_bar.value = current
			var fill_s: StyleBoxFlat = sanity_bar.get_theme_stylebox("fill")
			if current / max_val < 0.3:
				fill_s.bg_color = Color(0.9, 0.2, 0.3)
			elif current / max_val < 0.5:
				fill_s.bg_color = Color(0.7, 0.4, 0.7)
			else:
				fill_s.bg_color = Color(0.5, 0.4, 0.9)
	PlayerStats.sanity_changed.connect(_san_cb)
	_signal_callbacks.append({"signal": PlayerStats.sanity_changed, "callable": _san_cb})

	# 对话UI（实例化已有 dialogue_ui.tscn 场景）
	var dlg_scene: PackedScene = load("res://scenes/ui/dialogue_ui.tscn")
	var dialogue_ui: Node = dlg_scene.instantiate()
	add_child(dialogue_ui)

	# 背包UI（实例化已有 inventory_ui.tscn 场景到预置的 InventoryLayer）
	var inv_ui: Control = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	inventory_layer.add_child(inv_ui)

## 显示底部操作提示（多条时向上堆叠，超时淡出）。
## [param text] 提示内容。[param duration] 停留秒数。提示为瞬时 UI，故动态创建。
func show_hint(text: String, duration: float = HINT_DURATION) -> void:
	for entry in _hint_labels:
		var lbl: Label = entry.get("label")
		if is_instance_valid(lbl):
			lbl.position.y -= HINT_LINE_HEIGHT

	var label := Label.new()
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

	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(label, "modulate:a", 0.0, HINT_FADE_TIME)
	tw.tween_callback(_remove_hint.bind(entry))

## 移除过期提示并让上方提示回落。
## [param entry] show_hint 中登记的提示条目。
func _remove_hint(entry: Dictionary) -> void:
	var lbl: Label = entry.get("label")
	var idx := _hint_labels.find(entry)
	if idx >= 0:
		_hint_labels.remove_at(idx)
	if is_instance_valid(lbl):
		lbl.queue_free()
	for remaining in _hint_labels:
		var rlbl: Label = remaining.get("label")
		if is_instance_valid(rlbl):
			rlbl.position.y += HINT_LINE_HEIGHT

## 进入夏桐的家：冻结玩家、清理循环动画后切换到房间场景
func _enter_home() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)

	# 杀掉循环tween
	_kill_loop_tweens()

	TransitionManager.transition_to_scene("res://scenes/levels/prologue_room.tscn", 0.5)

## 每帧更新世界标签、视差背景与入口提示显隐。
## [param _delta] 帧间隔（未使用）。
func _process(_delta: float) -> void:
	if _wlm and player and player.camera:
		_wlm.set_camera(player.camera)
		_wlm.update_positions()
	# 视差背景跟随相机
	if parallax_bg and player and player.camera:
		parallax_bg.scroll_offset = player.camera.get_screen_center_position()
	# 前景楼手动视差：相对相机反向偏移，产生前景纵深感（前景楼在玩家图层之前）
	if fg_buildings and player and player.camera:
		fg_buildings.position = -player.camera.get_screen_center_position() * 0.35
	# 入口提示显示/隐藏（动态更新按键）
	if player:
		if apartment_entrance and _apt_prompt:
			var near_apt: bool = player.global_position.distance_to(apartment_entrance.global_position) < 35.0
			if near_apt:
				_apt_prompt.text = LocaleManager.t("prompt_enter_apartment") % InputDevice.hint("interact")
			_apt_prompt.visible = near_apt
		if home_entrance and _home_prompt:
			var near_home: bool = player.global_position.distance_to(home_entrance.global_position) < 35.0
			if near_home:
				_home_prompt.text = LocaleManager.t("prompt_go_home") % InputDevice.hint("interact")
			_home_prompt.visible = near_home

## 交互键按下时根据距离进入公寓或回家。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and GameManager.current_state == GameManager.GameState.PLAYING:
		if not player:
			return
		if apartment_entrance and player.global_position.distance_to(apartment_entrance.global_position) < 35.0:
			_enter_apartment()
		elif home_entrance and player.global_position.distance_to(home_entrance.global_position) < 35.0:
			_enter_home()

## 进入归栖公寓：声音瞬间切断（核心转折）后切换到第一层
func _enter_apartment() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)

	# 杀掉所有无限循环tween，避免场景切换时崩溃
	_kill_loop_tweens()

	# 【核心转折】所有声音瞬间切断
	AudioManager.stop_playlist(0.0)
	AudioManager.bgm_player.stop()
	AudioManager.enter_silence_mode()
	TransitionManager.hard_cut_to_black()

	await get_tree().create_timer(2.0).timeout

	# 切换到第一层
	TransitionManager.transition_to_scene("res://scenes/levels/floor_1.tscn")

## 停止并清空所有无限循环 tween
func _kill_loop_tweens() -> void:
	for tw in _loop_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()

## 场景退出时清理循环动画与运行时信号
func _exit_tree() -> void:
	# 杀掉所有无限循环tween
	_kill_loop_tweens()
	for entry in _signal_callbacks:
		if entry["signal"].is_connected(entry["callable"]):
			entry["signal"].disconnect(entry["callable"])
	_signal_callbacks.clear()
