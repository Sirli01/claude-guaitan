@tool
extends Node2D
## 序章 - 夏桐的房间
## 墙壁、家具、窗户光效、手机/门交互区、玩家与 HUD 均在 .tscn 场景文件中定义
## 脚本只负责：运行时数据绑定（贴图/文本/数值）、信号连接与开场流程控制
## 流程：黑屏渐亮 → 姐姐独白（带头像） → 操作提示 → 拾取手机 → 背包教程 → 出门

## 序章房间中主角相对标准尺寸的放大倍数
const PROLOGUE_SCALE: float = 4.0 / 3.0

@onready var player: CharacterBody2D = %Player
@onready var phone_area: Area2D = %PhoneArea
@onready var door_area: Area2D = %DoorArea
@onready var hud_layer: CanvasLayer = %HUDLayer
@onready var floor_label: Label = %FloorLabel
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var sanity_label: Label = %SanityLabel
@onready var sanity_bar: ProgressBar = %SanityBar

## 玩家是否已拾取手机（防止重复触发）
var phone_checked: bool = false
## "按E拾取"提示标签（WorldLabelManager 管理，靠近手机才显示）
var _interact_prompt: Label
## 玩家是否已从背包打开过手机
var _phone_opened_once: bool = false
## WorldLabelManager 引用（管理家具/门等世界空间标签）
var _wlm: Node

# 存储信号回调以便场景退出时断开
var _signal_callbacks: Array[Dictionary] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	GameManager.set_state(GameManager.GameState.CUTSCENE)
	GameManager.change_floor(GameManager.Floor.PROLOGUE)

	var is_returning: bool = InventoryManager.has_item("phone")

	_wlm = load("res://scripts/utils/world_label_manager.gd").new()
	_wlm.setup(self, 4.0)
	_setup_furniture_labels()
	_setup_player()
	if is_returning and phone_area:
		# 从街道返回时手机已拾取，移除场景中的手机交互区
		phone_area.queue_free()
		phone_area = null
	else:
		_create_phone_prompt()
	door_area.body_entered.connect(_on_door_entered)
	_setup_ui()
	LevelBaseV2.fix_label_filter(self)

	if is_returning:
		# 从街道返回 — 跳过独白，简单渐入即可
		_fade_from_black(1.0)
		GameManager.set_state(GameManager.GameState.PLAYING)
		player.unfreeze_player()
		_show_hint(LocaleManager.t("hint_back_in_room"), 3.0)
		return

	# 玩家初始冻结（开场过场期间不可移动）
	player.freeze_player()

	# === 开场序列 ===
	# 1. 黑屏渐亮（2秒）
	_fade_from_black(1.0)

	DialogueManager.start_dialogue(StoryText.lines("prologue", "intro"))
	await DialogueManager.dialogue_ended

	# 3. 对话结束，切换到自由操控
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()

	# 4. 操作提示
	var move_key := InputDevice.get_hint("move")
	var run_key := InputDevice.get_hint("run")
	_show_hint(LocaleManager.t("hint_controls") % [move_key, run_key, run_key], 5.0)

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

## 为场景中的 GameFurniture 节点创建世界标签
func _setup_furniture_labels() -> void:
	for child in get_children():
		if child is GameFurniture:
			var furn_label := LocaleManager.world_text(child.furniture_name)
			_wlm.create_label(furn_label, child.position + Vector2(-60, -child.furniture_size.y - 60), 40, Color(0.5, 0.5, 0.5, 0.0))

## 配置场景中实例化的玩家：加载贴图、按序章比例放大碰撞/交互/灯光。
## 节点结构来自 player.tscn，这里只做运行时数据绑定。
func _setup_player() -> void:
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = GameManager.load_char_texture("sister", 16, 20)
		GameManager.fit_character_sprite(sprite, "sister")
		sprite.scale *= PROLOGUE_SCALE
		player.sprite = sprite

	var col: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if col:
		player.collision = col

	var area: Area2D = player.get_node_or_null("InteractionArea")
	if area:
		player.interaction_area = area

	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		player.camera = cam

	var light: PointLight2D = player.get_node_or_null("PointLight2D")
	if light:
		light.texture_scale = 6.0 * PROLOGUE_SCALE
		player.point_light = light

	# 角色阴影遮挡体（GameManager 提供的运行时组件）
	player.add_child(GameManager.create_character_shadow_occluder("sister"))

	# 延迟再次应用序章放大，覆盖 player._ready() 可能重置的尺寸
	call_deferred("_finish_prologue_player_setup")

## 延迟再次应用序章 4/3 放大，覆盖 player._ready() 可能重置的尺寸。
func _finish_prologue_player_setup() -> void:
	if not is_instance_valid(player):
		return
	var shadow := player.get_node_or_null("CharacterShadow")
	if shadow:
		shadow.scale *= PROLOGUE_SCALE
	if player.collision and player.collision.shape and player.collision.shape is RectangleShape2D:
		player.collision.shape.size = GameManager.PLAYER_COLLISION_SIZE * PROLOGUE_SCALE
		player.collision.position = GameManager.PLAYER_COLLISION_OFFSET * PROLOGUE_SCALE
	if player.interaction_area and player.interaction_area.get_child_count() > 0:
		var col_node: CollisionShape2D = player.interaction_area.get_child(0)
		if col_node and col_node.shape and col_node.shape is CircleShape2D:
			col_node.shape.radius = 60.0 * PROLOGUE_SCALE
	if player.point_light and player.point_light is PointLight2D:
		player.point_light.texture_scale = 6.0 * PROLOGUE_SCALE

## 创建"按E拾取"世界提示标签（由 WorldLabelManager 运行时管理，默认隐藏）
func _create_phone_prompt() -> void:
	_interact_prompt = _wlm.create_label(LocaleManager.t("prompt_pick_phone") % InputDevice.hint("interact"), Vector2(80, -204), 40, Color(1.0, 1.0, 0.7))
	_interact_prompt.visible = false

## 绑定 HUD 数据：多语言文本、体力/理智条数值与信号。UI 结构已在 .tscn 中定义。
func _setup_ui() -> void:
	floor_label.text = LocaleManager.t("floor_prologue_room")
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
	var dialogue_layer: Node = dlg_scene.instantiate()
	add_child(dialogue_layer)

	# 背包UI（实例化已有 inventory_ui.tscn 场景）
	var inv_layer := CanvasLayer.new()
	inv_layer.layer = 15
	inv_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inv_layer)
	var inv_ui: Control = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	inv_layer.add_child(inv_ui)
	inv_ui.phone_viewed.connect(_on_phone_viewed)

var _hint_labels: Array[Dictionary] = []
const HINT_DURATION: float = 4.0
const HINT_FADE_TIME: float = 1.0
const HINT_LINE_HEIGHT: int = 80

## 显示底部操作提示（多条时向上堆叠，超时淡出）。
## [param text] 提示内容。[param duration] 停留秒数。提示为瞬时 UI，故动态创建。
func _show_hint(text: String, duration: float = HINT_DURATION) -> void:
	for entry in _hint_labels:
		var lbl: Label = entry.get("label")
		if is_instance_valid(lbl):
			lbl.position.y -= HINT_LINE_HEIGHT

	var label := Label.new()
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

	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(label, "modulate:a", 0.0, HINT_FADE_TIME)
	tw.tween_callback(_remove_hint.bind(entry))

## 移除过期提示并让上方提示回落。
## [param entry] _show_hint 中登记的提示条目。
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

## 拾取手机：加入背包、播放消失动画、清理交互区并提示打开背包。
func _on_phone_interact() -> void:
	if phone_checked:
		return
	phone_checked = true

	# 拾取手机（手机从地图消失）
	InventoryManager.add_item("phone")

	# 手机消失动画
	var tween := create_tween()
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

## 每帧更新世界标签位置与手机拾取提示的显隐。
## [param _delta] 帧间隔（未使用）。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _wlm and player and player.camera:
		_wlm.set_camera(player.camera)
		_wlm.update_positions()
	# 靠近手机时显示拾取提示（动态更新按键）
	if phone_area and player and _interact_prompt and not phone_checked:
		var dist: float = player.global_position.distance_to(phone_area.global_position)
		if dist < 70.0:
			_interact_prompt.text = LocaleManager.t("prompt_pick_phone") % InputDevice.hint("interact")
			_interact_prompt.visible = true
		else:
			_interact_prompt.visible = false

## 场景退出时断开所有运行时连接的信号
func _exit_tree() -> void:
	for entry in _signal_callbacks:
		if entry["signal"].is_connected(entry["callable"]):
			entry["signal"].disconnect(entry["callable"])
	_signal_callbacks.clear()

## 玩家踩到门口触发区域：未拿手机则提示，否则切换到街道场景。
## [param body] 进入区域的物理体。
func _on_door_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not InventoryManager.has_item("phone"):
			_show_hint(LocaleManager.t("hint_check_phone_first"))
			return
		TransitionManager.transition_to_scene("res://scenes/levels/prologue_street.tscn")

## 玩家首次从背包查看手机后给出寻找姐姐的提示
func _on_phone_viewed() -> void:
	if not _phone_opened_once:
		_phone_opened_once = true
		_show_hint(LocaleManager.t("hint_find_sister"), 5.0)

## 交互键按下时若靠近手机则拾取。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and GameManager.current_state == GameManager.GameState.PLAYING:
		if player and phone_area:
			if player.global_position.distance_to(phone_area.global_position) < 70.0:
				_on_phone_interact()
