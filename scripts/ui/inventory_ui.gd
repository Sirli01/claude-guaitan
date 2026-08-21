extends Control
## 物品栏UI — 支持点击使用物品 & 手机聊天界面

signal phone_viewed  ## 玩家从背包查看手机后关闭时发出

@onready var bg: ColorRect = $Background
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var close_btn: Button = $Panel/VBox/Header/CloseButton
@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var empty_hint: Label = $Panel/VBox/EmptyHint
@onready var detail_label: Label = $Panel/VBox/DetailLabel

var is_open: bool = false
var _phone_ui: Control = null


func _ready() -> void:
	add_to_group("inventory_ui")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_btn.pressed.connect(close)
	InventoryManager.inventory_changed.connect(_refresh)
	AudioManager.wire_button_clicks(self)

	_apply_locale()
	LocaleManager.locale_changed.connect(func(_l): _apply_locale())


## 应用多语言文本。
func _apply_locale() -> void:
	title_label.text = LocaleManager.t("backpack_title")
	empty_hint.text = LocaleManager.t("backpack_empty")
	detail_label.text = LocaleManager.t("item_detail_hint")


## 输入处理 — 关闭背包。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_close"):
		close()
		get_viewport().set_input_as_handled()


## 切换背包显示/隐藏。
func toggle() -> void:
	if is_open:
		close()
	elif GameManager.current_state != GameManager.GameState.CUTSCENE:
		open()


## 打开背包。
func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	AudioManager.play_system_open()
	_refresh()


## 关闭背包。
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


## 刷新物品网格显示。
func _refresh() -> void:
	# 立即移除旧节点（避免 queue_free 延迟导致焦点混乱）
	while grid.get_child_count() > 0:
		var child := grid.get_child(0)
		grid.remove_child(child)
		child.queue_free()

	var items := InventoryManager.inventory
	empty_hint.visible = items.is_empty()

	for item_id in items:
		var data: Dictionary = InventoryManager.get_item_data(item_id)
		var slot := _create_item_slot(item_id, data)
		grid.add_child(slot)
	AudioManager.wire_button_clicks(self)

	# 延迟一帧设置焦点导航（确保节点完全就绪）
	call_deferred("_setup_focus_navigation")


## 创建单个物品格子。
## [param item_id] 物品ID。
## [param data] 物品数据字典。
## [return] 物品格子 PanelContainer。
func _create_item_slot(item_id: String, data: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(192, 192)

	# 使面板可点击
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.tooltip_text = data.get("description", "")
	btn.pressed.connect(_on_item_clicked.bind(item_id))
	btn.focus_entered.connect(_on_slot_focus.bind(item_id))
	btn.mouse_entered.connect(_on_slot_focus.bind(item_id))

	# 手柄焦点高亮边框
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.2, 0.18, 0.1, 0.3)
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(0.9, 0.8, 0.3)
	focus_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("focus", focus_style)
	slot.add_child(btn)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	var name_label := Label.new()
	name_label.text = data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 60)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 叠加数量显示
	if data.get("stackable", false):
		var count := InventoryManager.get_item_count(item_id)
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 48)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(count_label)

	# 可消耗/装备/查看标记
	var use_label := _create_use_label(item_id, data)
	if use_label:
		vbox.add_child(use_label)

	return slot


## 创建物品操作提示标签。
## [param item_id] 物品ID。
## [param data] 物品数据字典。
## [return] Label 节点，如果不需要提示则返回 null。
func _create_use_label(item_id: String, data: Dictionary) -> Label:
	var text := ""
	var color := Color(0.5, 0.8, 0.5)

	if data.get("consumable", false):
		text = LocaleManager.t("item_use")
	elif item_id == "flashlight":
		text = LocaleManager.t("item_equip")
		color = Color(0.9, 0.8, 0.45)
	elif item_id == "phone":
		text = LocaleManager.t("item_examine")
		color = Color(0.5, 0.6, 0.9)

	if text.is_empty():
		return null

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 设置手柄焦点导航（网格内方向键导航）。
func _setup_focus_navigation() -> void:
	var buttons: Array = []
	for slot in grid.get_children():
		for child in slot.get_children():
			if child is Button:
				buttons.append(child)
				break
	if buttons.is_empty():
		return

	var cols := grid.columns
	for i in buttons.size():
		var btn: Button = buttons[i]
		var row := i / cols
		var col := i % cols
		if col > 0:
			btn.focus_neighbor_left = buttons[i - 1].get_path()
		if col < cols - 1 and i + 1 < buttons.size():
			btn.focus_neighbor_right = buttons[i + 1].get_path()
		if row > 0:
			btn.focus_neighbor_top = buttons[i - cols].get_path()
		if i + cols < buttons.size():
			btn.focus_neighbor_bottom = buttons[i + cols].get_path()

	if buttons[0].is_inside_tree():
		buttons[0].grab_focus()
	else:
		buttons[0].ready.connect(buttons[0].grab_focus, CONNECT_ONE_SHOT)


## 获取玩家灯光组件。
## [return] 灯光节点，未找到返回 null。
func _get_player_lighting() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return null
	var lighting := player.get_node_or_null("PlayerLighting")
	if lighting:
		return lighting
	for child in player.get_children():
		if child.has_method("toggle_flashlight"):
			return child
	return null


## 物品格子获得焦点时更新详情区。
## [param item_id] 物品ID。
func _on_slot_focus(item_id: String) -> void:
	if not is_instance_valid(detail_label):
		return
	var data: Dictionary = InventoryManager.get_item_data(item_id)
	var desc: String = data.get("description", "")
	if desc.is_empty():
		detail_label.text = data.get("name", "")
		detail_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	else:
		detail_label.text = desc
		detail_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))


## 物品格子点击处理。
## [param item_id] 物品ID。
func _on_item_clicked(item_id: String) -> void:
	match item_id:
		"phone":
			_open_phone_chat()
		"flashlight":
			var lighting := _get_player_lighting()
			if lighting and lighting.has_method("toggle_flashlight"):
				lighting.toggle_flashlight()
				_refresh()
		_:
			var data: Dictionary = InventoryManager.get_item_data(item_id)
			if data.get("consumable", false):
				InventoryManager.use_item(item_id)
				_refresh()


## 打开手机聊天界面。
func _open_phone_chat() -> void:
	close()
	# 创建或复用手机UI
	if _phone_ui == null or not is_instance_valid(_phone_ui):
		_phone_ui = load("res://scenes/ui/phone_ui.tscn").instantiate()
		var ui_layer := CanvasLayer.new()
		ui_layer.layer = 20
		get_tree().current_scene.add_child(ui_layer)
		ui_layer.add_child(_phone_ui)

	var latest_chat: String = GameManager.get_flag("current_phone_chat", "prologue_chat")
	_phone_ui.open_chat(latest_chat)

	if not _phone_ui.phone_closed.is_connected(_on_phone_closed):
		_phone_ui.phone_closed.connect(_on_phone_closed)


## 手机关闭回调。
func _on_phone_closed() -> void:
	phone_viewed.emit()
