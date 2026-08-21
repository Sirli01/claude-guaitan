extends CanvasLayer
## 触屏虚拟控件 —— 虚拟摇杆 + 操作按钮
## 仅在 Android / iOS / 触屏设备上自动显示

const JOY_RADIUS := 200.0
const KNOB_RADIUS := 80.0
const DEAD_ZONE := 0.2

var _joy_pos: Vector2
var _joy_bg: Panel
var _joy_knob: Panel
var _joy_finger: int = -1

var _btns: Array = []               # [{center, radius, action, is_hold, node}]
var _btn_fingers: Dictionary = {}   # finger_index → btn dict

# ── 生命周期 ──

## 初始化层级与处理模式，非触屏设备直接自毁，触屏设备则构建虚拟控件。
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也要响应菜单按钮
	if not _is_touch():
		queue_free()
		return
	_build()

## 判断当前运行环境是否为触屏设备。
## [return] Android/iOS 或存在触摸屏时返回 true。
func _is_touch() -> bool:
	var n := OS.get_name()
	return n == "Android" or n == "iOS" or DisplayServer.is_touchscreen_available()

# ── UI 构建 ──

## 按屏幕尺寸构建左下角虚拟摇杆与各操作按钮。
func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var R := vp.x
	var B := vp.y

	# 摇杆（左下角）
	_joy_pos = Vector2(180, B - 200)
	_joy_bg = _circle_panel(_joy_pos, JOY_RADIUS, Color(1, 1, 1, 0.12))
	add_child(_joy_bg)
	_joy_knob = _circle_panel(_joy_pos, KNOB_RADIUS, Color(1, 1, 1, 0.4))
	add_child(_joy_knob)

	# 操作按钮
	_add_btn(Vector2(R - 160, B - 170), 60.0, "interact", "互动", Color(0.3, 0.8, 0.4, 0.55), false)
	_add_btn(Vector2(R - 310, B - 310), 48.0, "run", "跑", Color(0.4, 0.6, 0.9, 0.55), true)
	_add_btn(Vector2(R - 120, 80), 38.0, "open_rules", "规则", Color(0.9, 0.8, 0.3, 0.45), false)
	_add_btn(Vector2(R - 240, 80), 38.0, "open_inventory", "物品", Color(0.8, 0.5, 0.9, 0.45), false)
	_add_btn(Vector2(80, 80), 38.0, "ui_cancel", "菜单", Color(0.7, 0.7, 0.7, 0.45), false)

## 创建一个以 center 为圆心、指定半径和颜色的圆形面板。
## [param center] 圆心坐标。
## [param radius] 圆的半径（像素）。
## [param color] 填充颜色。
## [return] 新创建的 Panel 节点。
func _circle_panel(center: Vector2, radius: float, color: Color) -> Panel:
	var p := Panel.new()
	p.position = center - Vector2(radius, radius)
	p.size = Vector2(radius * 2, radius * 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	var ri := int(radius)
	s.corner_radius_top_left = ri
	s.corner_radius_top_right = ri
	s.corner_radius_bottom_left = ri
	s.corner_radius_bottom_right = ri
	p.add_theme_stylebox_override("panel", s)
	return p

## 在指定位置添加一个圆形操作按钮并登记到按钮列表。
## [param center] 按钮中心坐标。
## [param radius] 按钮半径（像素）。
## [param action] 触发的输入动作名。
## [param label_text] 按钮上显示的文字。
## [param color] 按钮填充颜色。
## [param is_hold] 是否为长按型按钮（按住持续触发动作）。
func _add_btn(center: Vector2, radius: float, action: String, label_text: String, color: Color, is_hold: bool) -> void:
	var node := _circle_panel(center, radius, color)
	add_child(node)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", maxi(int(radius * 0.6), 12))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(lbl)
	_btns.append({center = center, radius = radius, action = action, is_hold = is_hold, node = node})

# ── 输入处理 ──

## 处理触摸按下/拖动/抬起事件驱动摇杆与按钮，并屏蔽控件区域的鼠标仿真点击。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_finger_down(event.index, event.position)
		else:
			_finger_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joy_finger:
			_joy_update(event.position)
			get_viewport().set_input_as_handled()
		elif event.index in _btn_fingers:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		# 屏蔽控件区域的触屏→鼠标仿真事件，防止误触发对话推进
		if _in_zone(event.position):
			get_viewport().set_input_as_handled()

## 手指按下处理：优先判定摇杆区域，其次判定按钮区域并触发对应动作。
## [param finger] 手指索引。
## [param pos] 按下位置。
func _finger_down(finger: int, pos: Vector2) -> void:
	# 摇杆
	if _joy_finger == -1 and pos.distance_to(_joy_pos) < JOY_RADIUS * 1.8:
		_joy_finger = finger
		_joy_update(pos)
		get_viewport().set_input_as_handled()
		return
	# 按钮
	for btn in _btns:
		if pos.distance_to(btn.center) < btn.radius * 1.4:
			_btn_fingers[finger] = btn
			if btn.is_hold:
				Input.action_press(btn.action)
			else:
				_fire.call_deferred(btn.action, true)
			btn.node.modulate = Color(1.5, 1.5, 1.5)
			get_viewport().set_input_as_handled()
			return

## 手指抬起处理：释放摇杆或按钮占用的手指并复位对应控件状态。
## [param finger] 手指索引。
func _finger_up(finger: int) -> void:
	if finger == _joy_finger:
		_joy_finger = -1
		_joy_reset()
		get_viewport().set_input_as_handled()
	if finger in _btn_fingers:
		var btn: Dictionary = _btn_fingers[finger]
		if btn.is_hold:
			Input.action_release(btn.action)
		else:
			_fire.call_deferred(btn.action, false)
		btn.node.modulate = Color.WHITE
		_btn_fingers.erase(finger)
		get_viewport().set_input_as_handled()

## 判断某坐标是否落在摇杆或任一按钮的响应区域内。
## [param pos] 待检测的坐标。
## [return] 在控件区域内返回 true。
func _in_zone(pos: Vector2) -> bool:
	if pos.distance_to(_joy_pos) < JOY_RADIUS * 1.8:
		return true
	for btn in _btns:
		if pos.distance_to(btn.center) < btn.radius * 1.4:
			return true
	return false

# ── 摇杆逻辑 ──

## 根据手指位置更新摇杆旋钮偏移，并把归一化方向映射到四向移动动作。
## [param pos] 当前手指位置。
func _joy_update(pos: Vector2) -> void:
	var diff := pos - _joy_pos
	if diff.length() > JOY_RADIUS:
		diff = diff.normalized() * JOY_RADIUS
	_joy_knob.position = _joy_pos + diff - Vector2(KNOB_RADIUS, KNOB_RADIUS)

	var norm := diff / JOY_RADIUS
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if norm.length() > DEAD_ZONE:
		if norm.x < -DEAD_ZONE: Input.action_press("move_left", -norm.x)
		if norm.x > DEAD_ZONE:  Input.action_press("move_right", norm.x)
		if norm.y < -DEAD_ZONE: Input.action_press("move_up", -norm.y)
		if norm.y > DEAD_ZONE:  Input.action_press("move_down", norm.y)

## 复位摇杆旋钮到中心并释放全部移动动作。
func _joy_reset() -> void:
	_joy_knob.position = _joy_pos - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

# ── 动作事件模拟（用于非长按按钮，通过 call_deferred 避免递归）──

## 以延迟方式合成并派发一个 InputEventAction，模拟非长按按钮的动作触发。
## [param action] 输入动作名。
## [param pressed] 是否为按下事件。
func _fire(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
