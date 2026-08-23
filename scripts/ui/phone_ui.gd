extends Control
## 手机聊天界面 — 模拟手机对话框
## 从背包中点击"手机"道具时打开
## 用法:
##   var phone = load("res://scenes/ui/phone_ui.tscn").instantiate()
##   ui_layer.add_child(phone)
##   phone.open_chat("prologue_chat")
##   await phone.phone_closed

signal phone_closed

## 聊天记录配置（新增对话只改这里）
## sender: "self"=姐姐发的（右侧绿色气泡），其他=对方发的（左侧白色气泡）
static var CHAT_DATA := {
	"prologue_chat": {
		"contact_name": "夏澈（妹妹）",
		"messages": [
			{"sender": "夏澈", "text": "姐！我找到一个超便宜的公寓！", "time": "上周五 09:30"},
			{"sender": "self", "text": "哪里啊？便宜的地方你得多留个心眼。", "time": "上周五 09:32"},
			{"sender": "夏澈", "text": "叫归栖公寓，月租才800！而且离学校特别近", "time": "上周五 09:33"},
			{"sender": "夏澈", "text": "就是稍微有点旧……不过房间还挺大的", "time": "上周五 09:34"},
			{"sender": "self", "text": "你先拍几张照片给我看看", "time": "上周五 09:35"},
			{"sender": "夏澈", "text": "好嘞！晚上搬完东西拍给你~", "time": "上周五 09:36"},
			{"sender": "self", "text": "搬好了吗？照片呢？", "time": "上周五 20:14"},
			{"sender": "夏澈", "text": "搬好了！手机快没电了，明天拍给你看。", "time": "上周五 21:02"},
			{"sender": "夏澈", "text": "姐这里的邻居都好安静哦，整层楼都没什么声音", "time": "上周五 23:15"},
			{"sender": "self", "text": "大晚上的别乱跑啊，早点睡", "time": "上周五 23:17"},
			{"sender": "夏澈", "text": "知道啦晚安！", "time": "上周五 23:18"},
			{"sender": "self", "text": "妹妹？照片呢", "time": "周六 12:30"},
			{"sender": "self", "text": "又在睡懒觉？", "time": "周六 15:20"},
			{"sender": "self", "text": "妹妹你手机又没电了？", "time": "周日 10:00"},
			{"sender": "self", "text": "你怎么不回消息啊", "time": "周日 18:45"},
			{"sender": "self", "text": "夏澈？？", "time": "周一 09:12"},
			{"sender": "self", "text": "你到底在不在？打电话也不接", "time": "周一 14:30"},
			{"sender": "self", "text": "妹妹你在哪里……", "time": "周一 22:00"},
			{"sender": "self", "text": "……我来找你。", "time": "周二 08:00"},
		],
	},
}

@onready var close_btn: Button = $PhoneFrame/VBox/HeaderPanel/HeaderHBox/BackButton
@onready var contact_label: Label = $PhoneFrame/VBox/HeaderPanel/HeaderHBox/ContactLabel
@onready var scroll: ScrollContainer = $PhoneFrame/VBox/Scroll
@onready var chat_container: VBoxContainer = $PhoneFrame/VBox/Scroll/ChatContainer
@onready var bottom_hint: Label = $PhoneFrame/VBox/BottomHint

var _current_chat_id: String = ""
var _msg_index: int = 0
var _all_shown: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_btn.pressed.connect(_on_close)

	_apply_locale()
	LocaleManager.locale_changed.connect(func(_l): _apply_locale())
	AudioManager.wire_button_clicks(self)

	# 应用UI缩放
	_apply_ui_scale()
	# 窗口分辨率变化时同步重排
	UIScaleManager.scale_changed.connect(func(_s: float) -> void: _apply_ui_scale())


## 应用UI缩放。
## 注意：不能用 Control.scale 缩放——它会绕节点左上角缩放导致面板偏离屏幕中心；
## 正确做法是按缩放系数扩大居中锚点的 offsets，面板始终保持在屏幕正中。
func _apply_ui_scale() -> void:
	# 获取缩放因子
	var s := UIScaleManager.scale_factor

	# 以中心锚点为基准扩展手机外框（设计尺寸 560x720）
	var frame := $PhoneFrame as PanelContainer
	if frame:
		frame.offset_left = -280.0 * s
		frame.offset_top = -360.0 * s
		frame.offset_right = 280.0 * s
		frame.offset_bottom = 360.0 * s

	# 按钮和文字大小
	close_btn.add_theme_font_size_override("font_size", UIScaleManager.get_scaled_font_size(24))
	contact_label.add_theme_font_size_override("font_size", UIScaleManager.get_scaled_font_size(26))
	bottom_hint.add_theme_font_size_override("font_size", UIScaleManager.get_scaled_font_size(20))


## 应用多语言文本。
func _apply_locale() -> void:
	close_btn.text = LocaleManager.t("phone_back")
	bottom_hint.text = LocaleManager.t("phone_tap_next")


## 获取聊天数据（合并本地化数据）。
## [param chat_id] 聊天记录ID。
## [return] 聊天数据字典。
func _get_chat_data(chat_id: String) -> Dictionary:
	var data: Dictionary = CHAT_DATA.get(chat_id, {}).duplicate()
	var loc := LocaleManager.phone_chat_locale(chat_id)
	if not loc.is_empty():
		data.merge(loc, true)
	return data


## 获取聊天进度的 flag key。
## [param chat_id] 聊天记录ID。
## [return] flag key 字符串。
func _progress_flag_key(chat_id: String) -> String:
	return "phone_chat_progress_%s" % chat_id


## 获取已查看消息数量。
## [param chat_id] 聊天记录ID。
## [param total_messages] 总消息数。
## [return] 已查看数量。
func _get_seen_count(chat_id: String, total_messages: int) -> int:
	var seen_count := int(GameManager.get_flag(_progress_flag_key(chat_id), 0))
	return clampi(seen_count, 0, total_messages)


## 保存已查看消息数量。
## [param chat_id] 聊天记录ID。
## [param seen_count] 已查看数量。
func _set_seen_count(chat_id: String, seen_count: int) -> void:
	GameManager.set_flag(_progress_flag_key(chat_id), seen_count)


## 输入处理 — ESC关闭，空格/点击显示下一条。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dialogue_advance"):
		if _all_shown:
			_on_close()
		else:
			_show_next_message()
		get_viewport().set_input_as_handled()
		return
	# 鼠标左键点击显示下一条
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_btn and close_btn.get_global_rect().has_point(event.global_position):
			return
		if _all_shown:
			_on_close()
		else:
			_show_next_message()
		get_viewport().set_input_as_handled()


## 打开指定聊天记录。
## [param chat_id] 聊天记录ID。
func open_chat(chat_id: String) -> void:
	_current_chat_id = chat_id
	# 清空旧消息
	for child in chat_container.get_children():
		child.queue_free()

	var data := _get_chat_data(chat_id)
	var messages: Array = data.get("messages", [])
	_msg_index = _get_seen_count(chat_id, messages.size())
	_all_shown = _msg_index >= messages.size()
	contact_label.text = data.get("contact_name", "未知联系人")

	visible = true
	get_tree().paused = true
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	AudioManager.play_system_open()

	await get_tree().process_frame
	if _msg_index > 0:
		for i in range(_msg_index):
			_add_chat_bubble(messages[i], false)
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
	elif not messages.is_empty():
		_show_next_message()


## 显示下一条消息。
func _show_next_message() -> void:
	if _all_shown:
		return
	var data := _get_chat_data(_current_chat_id)
	var messages: Array = data.get("messages", [])
	if _msg_index >= messages.size():
		_all_shown = true
		return

	var msg: Dictionary = messages[_msg_index]
	_add_chat_bubble(msg)
	_msg_index += 1
	_set_seen_count(_current_chat_id, _msg_index)

	if _msg_index >= messages.size():
		_all_shown = true

	# 滚动到底部
	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


## 添加聊天气泡。
## [param msg] 消息字典 {sender, text, time}。
## [param animate] 是否播放淡入动画。
func _add_chat_bubble(msg: Dictionary, animate: bool = true) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var is_self: bool = (msg.get("sender", "") == "self")

	# 气泡
	var bubble := PanelContainer.new()
	var bubble_style := StyleBoxFlat.new()
	bubble_style.set_corner_radius_all(8)
	bubble_style.content_margin_left = 10
	bubble_style.content_margin_right = 10
	bubble_style.content_margin_top = 6
	bubble_style.content_margin_bottom = 6

	var text_label := Label.new()
	text_label.text = msg.get("text", "")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x = 300
	text_label.add_theme_font_size_override("font_size", 22)
	bubble.custom_minimum_size.x = 80
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bubble.add_child(text_label)

	# 时间标签
	var time_label := Label.new()
	time_label.text = msg.get("time", "")
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	if is_self:
		# 自己的消息 — 右对齐，绿色气泡
		bubble_style.bg_color = Color(0.2, 0.45, 0.25)
		text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)
		hbox.add_child(time_label)
		hbox.add_child(bubble)
	else:
		# 对方的消息 — 左对齐，暗色气泡
		bubble_style.bg_color = Color(0.22, 0.22, 0.26)
		text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		hbox.add_child(bubble)
		hbox.add_child(time_label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

	bubble.add_theme_stylebox_override("panel", bubble_style)

	chat_container.add_child(hbox)
	if animate:
		hbox.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(hbox, "modulate:a", 1.0, 0.25)


## 关闭手机界面。
func _on_close() -> void:
	visible = false
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	phone_closed.emit()


## 添加新聊天记录（供关卡脚本运行时扩展）。
## [param chat_id] 聊天记录ID。
## [param contact_name] 联系人名称。
## [param messages] 消息数组。
static func register_chat(chat_id: String, contact_name: String, messages: Array) -> void:
	CHAT_DATA[chat_id] = {
		"contact_name": contact_name,
		"messages": messages,
	}
