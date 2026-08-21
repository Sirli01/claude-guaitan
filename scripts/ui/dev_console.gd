extends CanvasLayer
## 运行时开发者控制台 —— F3 打开/关闭
## 功能：跳转楼层/阶段、给道具、调属性、管角色、无敌模式

var _panel: PanelContainer
var _visible := false
var _invincible := false

# ── 生命周期 ──

## 初始化控制台层级与处理模式，构建UI后默认隐藏。
func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false

## 监听 F3 键切换开发者控制台的显示与隐藏。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_toggle()
		get_viewport().set_input_as_handled()

## 无敌模式开启时每帧把体力与理智回满。
## [param _delta] 帧间隔时间（未使用）。
func _process(_delta: float) -> void:
	if _invincible:
		PlayerStats.stamina = PlayerStats.max_stamina
		PlayerStats.sanity = PlayerStats.max_sanity

## 切换控制台显示状态，并在打开时暂停游戏、关闭时恢复。
func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	get_tree().paused = _visible

# ── UI 构建 ──

## 构建控制台全部界面：场景跳转、道具给予、属性调节与快捷功能按钮。
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(920, 120)
	_panel.size = Vector2(2000, 1400)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1976, 1376)
	_panel.add_child(scroll)
	
	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	
	# 标题
	_add_label(root, "开发者控制台 (F3)", 44, Color(0.4, 0.8, 1.0))
	_add_separator(root)
	
	# ====== 场景跳转 ======
	_add_label(root, "场景跳转", 36, Color(1.0, 0.9, 0.4))
	var scene_grid = _add_grid(root, 4)
	_add_scene_btn(scene_grid, "序章-房间", "res://scenes/levels/prologue_room.tscn", GameManager.Floor.PROLOGUE, [])
	_add_scene_btn(scene_grid, "序章-街道", "res://scenes/levels/prologue_street.tscn", GameManager.Floor.STREET, ["phone"])
	_add_scene_btn(scene_grid, "第一层", "res://scenes/levels/floor_1.tscn", GameManager.Floor.FLOOR_1, ["rule_paper"])
	_add_scene_btn(scene_grid, "第二层", "res://scenes/levels/floor_2.tscn", GameManager.Floor.FLOOR_2, ["rule_paper"])
	_add_scene_btn(scene_grid, "第二层(有耳塞)", "res://scenes/levels/floor_2.tscn", GameManager.Floor.FLOOR_2, ["rule_paper", "earplug"])
	_add_scene_btn(scene_grid, "第三层", "res://scenes/levels/floor_3.tscn", GameManager.Floor.FLOOR_3, ["rule_paper"], ["timid_male", "female_npc"])
	_add_scene_btn(scene_grid, "F2电梯内", "res://scenes/levels/elevator_f2_interior.tscn", GameManager.Floor.FLOOR_2, ["rule_paper"], ["timid_male", "female_npc"])
	_add_scene_btn(scene_grid, "F1电梯内", "res://scenes/levels/elevator_f1_interior.tscn", GameManager.Floor.FLOOR_1, ["rule_paper"])
	_add_scene_btn(scene_grid, "结局", "res://scenes/levels/ending.tscn", GameManager.Floor.ENDING, ["rule_paper"], [], ["23:00 - 07:00，禁止对视", "禁止离群 — 第二层", "禁止跑步 — 第三层"])
	_add_separator(root)
	
	# ====== 道具管理 ======
	_add_label(root, "给予道具（点击添加到背包）", 36, Color(0.4, 1.0, 0.6))
	var item_grid = _add_grid(root, 5)
	var items = [
		["phone", "手机"], ["flashlight", "手电筒"], ["battery", "电池"],
		["match", "火柴"], ["earplug", "耳塞"], ["rope", "绳子"],
		["elevator_card", "电梯卡"], ["master_key", "万能钥匙"],
		["room_304_key", "304钥匙"], ["rule_paper", "规则纸条"],
		["energy_drink", "能量饮料"], ["sedative", "镇定剂"],
		["sweets", "糖果"], ["energy_bar", "能量棒"],
		["coffee", "咖啡"], ["bandage", "绷带"],
	]
	for item in items:
		_add_item_btn(item_grid, item[1], item[0])
	_add_separator(root)
	
	# ====== 属性调节 ======
	_add_label(root, "属性调节", 36, Color(1.0, 0.6, 0.4))
	var stat_grid = _add_grid(root, 4)
	_add_stat_btn(stat_grid, "体力满", func(): PlayerStats.stamina = PlayerStats.max_stamina; PlayerStats.stamina_changed.emit(PlayerStats.stamina, PlayerStats.max_stamina))
	_add_stat_btn(stat_grid, "体力=10", func(): PlayerStats.stamina = 10.0; PlayerStats.stamina_changed.emit(10.0, PlayerStats.max_stamina))
	_add_stat_btn(stat_grid, "理智满", func(): PlayerStats.sanity = PlayerStats.max_sanity; PlayerStats.sanity_changed.emit(PlayerStats.sanity, PlayerStats.max_sanity))
	_add_stat_btn(stat_grid, "理智=10", func(): PlayerStats.sanity = 10.0; PlayerStats.sanity_changed.emit(10.0, PlayerStats.max_sanity))
	_add_stat_btn(stat_grid, "无敌开/关", func(): _invincible = not _invincible; _show_toast("无敌: " + ("ON" if _invincible else "OFF")))
	_add_stat_btn(stat_grid, "手电满电", func():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			for child in player.get_children():
				if child is Node2D and child.has_method("add_battery"):
					child.add_battery(child.max_battery)
					break
		_show_toast("手电已充满"))
	_add_separator(root)

	# ====== 快捷功能 ======
	_add_label(root, "快捷功能", 36, Color(0.7, 0.7, 0.7))
	var misc_grid = _add_grid(root, 4)
	_add_stat_btn(misc_grid, "跳过对话", func():
		if DialogueManager.is_dialogue_active:
			DialogueManager.end_dialogue()
		_show_toast("已跳过"))
	_add_stat_btn(misc_grid, "解冻玩家", func():
		var p = get_tree().get_first_node_in_group("player")
		if p: p.unfreeze_player()
		GameManager.set_state(GameManager.GameState.PLAYING)
		_show_toast("已解冻"))
	_add_stat_btn(misc_grid, "截图全图", func():
		var p = get_tree().get_first_node_in_group("player")
		if p:
			_toggle()
			MapCaptureTool.capture_full_map(p)
		_show_toast("截图中..."))
	_add_stat_btn(misc_grid, "跳到换魂", func(): _run_scene_debug_skip())
	
	add_child(_panel)

# ── UI 辅助 ──

## 在指定父控件下创建一个带字号与颜色的标签。
## [param parent] 父容器控件。
## [param text] 标签文字。
## [param size] 字体大小。
## [param color] 字体颜色。
## [return] 新创建的 Label 节点。
func _add_label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

## 在指定父控件下添加一条水平分隔线。
## [param parent] 父容器控件。
func _add_separator(parent: Control) -> void:
	var s = HSeparator.new()
	s.add_theme_constant_override("separation", 8)
	parent.add_child(s)

## 在指定父控件下创建指定列数的网格容器。
## [param parent] 父容器控件。
## [param columns] 网格列数。
## [return] 新创建的 GridContainer 节点。
func _add_grid(parent: Control, columns: int) -> GridContainer:
	var g = GridContainer.new()
	g.columns = columns
	parent.add_child(g)
	return g

## 创建一个统一样式（底色、圆角、悬停提亮）的功能按钮并绑定点击回调。
## [param text] 按钮文字。
## [param color] 按钮底色。
## [param callback] 点击时调用的回调。
## [return] 新创建的 Button 节点。
func _make_btn(text: String, color: Color, callback: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 76)
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", s)
	var hover = s.duplicate()
	hover.bg_color = color.lightened(0.2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(callback)
	return b

## 添加一个场景跳转按钮：重置全局状态、发放道具/规则、击杀指定角色后切换场景。
## [param parent] 父容器控件。
## [param label] 按钮文字。
## [param scene_path] 目标场景文件路径。
## [param floor_id] 跳转后的楼层ID。
## [param items] 进入场景前添加到背包的道具ID列表。
## [param kill] 需要标记死亡的角色ID列表。
## [param rules] 进入场景前注册的规则文本列表。
func _add_scene_btn(parent: Control, label: String, scene_path: String, floor_id, items: Array, kill: Array = [], rules: Array = []) -> void:
	var btn = _make_btn(label, Color(0.15, 0.25, 0.4), func():
		_toggle()
		get_tree().paused = false
		# 杀掉当前场景中所有无限循环 tween，防止场景切换时崩溃
		_kill_all_tweens(get_tree().current_scene)
		GameManager._reset_all_state()
		GameManager.change_floor(floor_id)
		for rule_text in rules:
			GameManager.add_rule(rule_text)
		for item_id in items:
			InventoryManager.add_item(item_id)
		for char_id in kill:
			GameManager.kill_character(char_id)
		get_tree().change_scene_to_file(scene_path))
	parent.add_child(btn)

## 添加一个道具按钮，点击后将对应道具加入背包并弹出提示。
## [param parent] 父容器控件。
## [param label] 按钮显示的道具中文名。
## [param item_id] 道具ID。
func _add_item_btn(parent: Control, label: String, item_id: String) -> void:
	var btn = _make_btn(label, Color(0.15, 0.35, 0.2), func():
		InventoryManager.add_item(item_id)
		_show_toast("已添加: " + label))
	parent.add_child(btn)

## 添加一个属性调节/快捷功能按钮，点击时执行传入回调。
## [param parent] 父容器控件。
## [param label] 按钮文字。
## [param callback] 点击时调用的回调。
func _add_stat_btn(parent: Control, label: String, callback: Callable) -> void:
	var btn = _make_btn(label, Color(0.35, 0.2, 0.15), callback)
	parent.add_child(btn)

## 在屏幕右上角弹出一条短暂提示文字，停留后自动淡出销毁。
## [param text] 提示内容。
func _show_toast(text: String) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", Color(1, 1, 0.5))
	l.position = Vector2(1720, 40)
	l.z_index = 999
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)

## 调用当前场景的 debug_skip_to_soul_swap 直接跳到换魂剧情，不支持时弹提示。
func _run_scene_debug_skip() -> void:
	var scene = get_tree().current_scene
	if scene == null or not scene.has_method("debug_skip_to_soul_swap"):
		_show_toast("当前场景不支持跳到换魂")
		return
	_toggle()
	get_tree().paused = false
	scene.call_deferred("debug_skip_to_soul_swap")

## 递归遍历节点树并终止所有正在处理的补间动画，防止场景切换时崩溃。
## [param node] 起始遍历的节点。
func _kill_all_tweens(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		_kill_all_tweens(child)
	# 通过 SceneTree 获取所有处理中的 tween 并 kill
	for tw in get_tree().get_processed_tweens():
		tw.kill()
