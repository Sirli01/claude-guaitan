extends CanvasLayer
## 对话UI - Galgame风格，头像显示在对话框上方

@onready var panel: PanelContainer = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel
@onready var continue_indicator: Label = $DialoguePanel/ContinueIndicator

var typewriter_speed: float = 0.03
var _is_typing: bool = false
var _full_text: String = ""
var _tween: Tween = null

# 对话历史
var _history: Array = []  # [{speaker:String, text:String}, ...]
var _history_panel: PanelContainer = null
var _history_scroll: ScrollContainer = null
var _history_vbox: VBoxContainer = null
var _history_visible: bool = false

# 头像系统
var _portrait: TextureRect  # 当前说话者头像（显示在对话框上方）
var _portrait_container: Control  # 头像的父容器

# 头像位置/大小（在Godot编辑器Inspector面板中调整）
@export var portrait_pos := Vector2(100, 0)  # 相对于屏幕的绝对坐标
@export var portrait_size := Vector2(735, 735)
const CONFIG_PATH := "user://portrait_config.cfg"

# 调试工具
var _debug_mode := false
var _debug_dragging := false
var _debug_drag_offset := Vector2.ZERO
var _debug_label: Label  # 显示坐标信息
var _debug_border: ColorRect  # 边框指示

# 角色 → 头像路径映射
# 格式：无表情时用 "角色名" → 默认图；有表情时用 "角色名/表情ID" → 对应图
# 例：PORTRAIT_MAP["夏桐/happy"] = "res://assets/sprites/portraits/夏桐_happy.png"
# 剧本用法：["sister", "台词", "happy"]  （第3个元素为表情ID）
const PORTRAIT_MAP := {
	"夏桐": "res://assets/sprites/portraits/夏桐.png",
	"夏桐/happy":    "res://assets/sprites/portraits/夏桐_happy.png",
	"夏桐/sad":      "res://assets/sprites/portraits/夏桐_sad.png",
	"夏桐/scared":   "res://assets/sprites/portraits/夏桐_scared.png",
	"夏桐/serious":  "res://assets/sprites/portraits/夏桐_serious.png",
	"夏桐/surprised":"res://assets/sprites/portraits/夏桐_surprised.png",
	"夏桐/angry":    "res://assets/sprites/portraits/夏桐_angry.png",
	"夏桐/nervous":  "res://assets/sprites/portraits/夏桐_nervous.png",
	"夏桐/crying":   "res://assets/sprites/portraits/夏桐_crying.png",
	"林佳语": "res://assets/sprites/portraits/林佳语.png",
	"林佳语/serious": "res://assets/sprites/portraits/林佳语_serious.png",
	"林佳语/nervous": "res://assets/sprites/portraits/林佳语_nervous.png",
	"鹿可": "res://assets/sprites/portraits/鹿可.png",
	"鹿可/happy":     "res://assets/sprites/portraits/鹿可_happy.png",
	"鹿可/scared":    "res://assets/sprites/portraits/鹿可_scared.png",
	"鹿可/crying":    "res://assets/sprites/portraits/鹿可_crying.png",
	"鹿可/surprised": "res://assets/sprites/portraits/鹿可_surprised.png",
	"周锐": "res://assets/sprites/portraits/周锐.png",
	"周锐/angry":    "res://assets/sprites/portraits/周锐_angry.png",
	"周锐/nervous":  "res://assets/sprites/portraits/周锐_nervous.png",
	"周锐/scared":   "res://assets/sprites/portraits/周锐_scared.png",
	"周锐/serious":  "res://assets/sprites/portraits/周锐_serious.png",
	"沈薇": "res://assets/sprites/portraits/沈薇.png",
	"沈薇/nervous":  "res://assets/sprites/portraits/沈薇_nervous.png",
	"沈薇/scared":   "res://assets/sprites/portraits/沈薇_scared.png",
	"沈薇/serious":  "res://assets/sprites/portraits/沈薇_serious.png",
	"沈薇/surprised":"res://assets/sprites/portraits/沈薇_surprised.png",
	"余凡": "res://assets/sprites/portraits/余凡.png",
	"余凡/nervous":  "res://assets/sprites/portraits/余凡_nervous.png",
	"余凡/scared":   "res://assets/sprites/portraits/余凡_scared.png",
	"余凡/surprised":"res://assets/sprites/portraits/余凡_surprised.png",
}

## 初始化对话UI：隐藏面板、注册到 DialogueManager 并连接对话信号。
func _ready() -> void:
	panel.visible = false
	# TSCN已通过offset定义了正确的panel位置和大小(40,800,1880,1060)
	# 不再用代码覆盖，避免与布局系统冲突
	# Debug prints removed for production
	DialogueManager.register_ui(self)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_line_shown.connect(_on_line_shown)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_load_portrait_config()
	_setup_portraits()
	_setup_history_panel()
	_setup_debug_ui()

## 节点移出场景树时断开与 DialogueManager 的所有信号连接。
func _exit_tree() -> void:
	if DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.disconnect(_on_dialogue_started)
	if DialogueManager.dialogue_line_shown.is_connected(_on_line_shown):
		DialogueManager.dialogue_line_shown.disconnect(_on_line_shown)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

## 对话开始回调：显示对话框并隐藏头像与继续指示符。
## [param _speaker] 开始对话的说话者名（未使用）。
func _on_dialogue_started(_speaker: String) -> void:
	panel.visible = true
	panel.focus_mode = Control.FOCUS_NONE  # 禁止焦点，消除紫粉色框
	# Debug print removed for production
	continue_indicator.visible = false
	_portrait.visible = false

## 显示一行对话：记录历史、更新说话者与头像，并用打字机效果逐字显示文本。
## [param speaker] 说话者名字，空字符串表示旁白。
## [param text] 本行台词内容。
## [param emotion] 表情ID，用于选择角色头像（可为空）。
func _on_line_shown(speaker: String, text: String, emotion: String = "") -> void:
	# 记录到历史
	_history.append({"speaker": speaker, "text": text})
	
	if speaker == "":
		speaker_label.text = ""
		speaker_label.visible = false
		_portrait.visible = false
	else:
		speaker_label.text = speaker
		speaker_label.visible = true
		_set_speaker_color(speaker)
		_show_portrait(speaker, emotion)
	
	_full_text = text
	text_label.text = text
	text_label.visible_ratio = 0.0
	continue_indicator.visible = false
	_is_typing = true
	
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	var duration = text.length() * typewriter_speed
	_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_tween.tween_callback(_on_typing_finished)

## 打字机效果结束回调：标记输入完成并显示继续指示符。
func _on_typing_finished() -> void:
	_is_typing = false
	continue_indicator.visible = true

## 对话结束回调：隐藏对话框、头像和对话历史面板。
func _on_dialogue_ended() -> void:
	panel.visible = false
	_portrait.visible = false
	if _history_visible:
		_history_panel.visible = false
		_history_visible = false

## 构建对话历史面板（半透明背景 + 滚动容器 + 垂直列表）。
func _setup_history_panel() -> void:
	# 半透明黑色背景面板，覆盖屏幕上半部分
	_history_panel = PanelContainer.new()
	_history_panel.visible = false
	_history_panel.position = Vector2(40, 40)
	_history_panel.size = Vector2(1840, 720)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	_history_panel.add_theme_stylebox_override("panel", style)
	_history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_history_panel)
	
	_history_scroll = ScrollContainer.new()
	_history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_panel.add_child(_history_scroll)
	
	_history_vbox = VBoxContainer.new()
	_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_scroll.add_child(_history_vbox)

## 打开或关闭对话历史面板；打开时按说话者颜色重建全部历史条目并滚动到底部。
func _toggle_history() -> void:
	if _history_visible:
		_history_panel.visible = false
		_history_visible = false
		return
	
	if _history.is_empty():
		return
	
	# 清除旧内容
	for child in _history_vbox.get_children():
		child.queue_free()
	
	# 标题
	var title = Label.new()
	title.text = LocaleManager.t("dialogue_history_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_history_vbox.add_child(title)
	
	# 分隔
	var sep = HSeparator.new()
	_history_vbox.add_child(sep)
	
	# 历史条目
	for entry in _history:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if entry.speaker != "":
			var name_lbl = Label.new()
			name_lbl.text = entry.speaker + "："
			name_lbl.add_theme_font_size_override("font_size", 24)
			name_lbl.custom_minimum_size.x = 120
			# 颜色与角色对应
			var color := Color(0.8, 0.8, 0.8)
			match entry.speaker:
				"夏桐": color = Color(0.9, 0.7, 0.8)
				"林佳语": color = Color(0.6, 0.7, 0.9)
				"鹿可": color = Color(0.9, 0.8, 0.4)
				"周锐": color = Color(0.5, 0.8, 0.6)
				"沈薇": color = Color(0.9, 0.5, 0.6)
				"余凡": color = Color(0.7, 0.7, 0.5)
			name_lbl.add_theme_color_override("font_color", color)
			hbox.add_child(name_lbl)
		
		var text_lbl = Label.new()
		text_lbl.text = entry.text
		text_lbl.add_theme_font_size_override("font_size", 24)
		text_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_lbl)
		
		_history_vbox.add_child(hbox)
	
	_history_panel.visible = true
	_history_visible = true
	
	# 滚动到底部
	await get_tree().process_frame
	_history_scroll.scroll_vertical = _history_scroll.get_v_scroll_bar().max_value

## 创建头像容器与 TextureRect，并根据对话框顶部位置计算头像初始坐标。
func _setup_portraits() -> void:
	# 全屏容器
	_portrait_container = Control.new()
	_portrait_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_container)
	
	# 计算Y位置（头像底部对齐对话框顶部，panel.offset_top=800）
	portrait_pos.y = panel.offset_top - portrait_size.y
	
	# 头像
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = portrait_size
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.visible = false
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.position = portrait_pos
	_portrait.size = portrait_size
	# 去除白边：用 shader 在采样时丢弃 alpha 边缘的白色溢出
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tc.rgb *= c.a;\n\tCOLOR = c;\n}"
	mat.shader = shader
	_portrait.material = mat
	_portrait_container.add_child(_portrait)

## 根据说话者与表情ID查找并显示对应头像，找不到时回退默认头像或警告。
## [param speaker] 说话者名字。
## [param emotion] 表情ID，优先匹配"角色名/表情"组合头像（可为空）。
func _show_portrait(speaker: String, emotion: String = "") -> void:
	_portrait.visible = false
	
	# 优先查找 "角色名/表情" 组合，找不到则回退到默认头像
	var path := ""
	if emotion != "":
		path = PORTRAIT_MAP.get(speaker + "/" + emotion, "")
	if path == "":
		path = PORTRAIT_MAP.get(speaker, "")
	if path == "":
		push_warning("[DialogueUI] portrait not in PORTRAIT_MAP: '%s'" % speaker)
		return
	
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path) as Texture2D
	if not tex:
		push_warning("[DialogueUI] portrait load failed: ", path)
		return
	
	_portrait.texture = tex
	_portrait.visible = true
	# Portrait display debug removed for production

## 按角色设置说话者名字标签的字体颜色，未知角色使用灰色。
## [param speaker] 说话者名字。
func _set_speaker_color(speaker: String) -> void:
	match speaker:
		"夏桐":
			speaker_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.8))
		"林佳语":
			speaker_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		"鹿可":
			speaker_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		"周锐":
			speaker_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
		"沈薇":
			speaker_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.6))
		"余凡":
			speaker_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		_:
			speaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

## 跳过正在进行的打字机效果，立即显示完整台词。
## [return] 若确实跳过了打字过程返回 true，否则返回 false。
func skip_typewriter() -> bool:
	if _is_typing and _tween:
		_tween.kill()
		text_label.visible_ratio = 1.0
		_on_typing_finished()
		return true
	return false

# ===== 头像配置 =====
## 从用户目录配置文件加载头像的位置与大小，并保证不超出左边界。
func _load_portrait_config() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		portrait_pos.x = config.get_value("portrait", "x", portrait_pos.x)
		portrait_pos.y = config.get_value("portrait", "y", portrait_pos.y)
		portrait_size.x = config.get_value("portrait", "w", portrait_size.x)
		portrait_size.y = config.get_value("portrait", "h", portrait_size.y)
	# 确保头像不超出左边界
	portrait_pos.x = max(portrait_pos.x, 0.0)

## 将当前头像位置与大小保存到用户目录配置文件。
func _save_portrait_config() -> void:
	var config = ConfigFile.new()
	config.set_value("portrait", "x", portrait_pos.x)
	config.set_value("portrait", "y", portrait_pos.y)
	config.set_value("portrait", "w", portrait_size.x)
	config.set_value("portrait", "h", portrait_size.y)
	config.save(CONFIG_PATH)

## 把 portrait_pos / portrait_size 应用到头像节点上。
func _apply_portrait_transform() -> void:
	if _portrait:
		_portrait.position = portrait_pos
		_portrait.size = portrait_size
		_portrait.custom_minimum_size = portrait_size

# ===== 头像调试工具（F9 切换）=====
## 创建头像调试用的坐标信息标签与黄色边框指示（默认隐藏）。
func _setup_debug_ui() -> void:
	# 坐标信息标签
	_debug_label = Label.new()
	_debug_label.visible = false
	_debug_label.position = Vector2(10, 10)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color.YELLOW)
	_debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_debug_label)
	
	# 边框
	_debug_border = ColorRect.new()
	_debug_border.visible = false
	_debug_border.color = Color(1, 1, 0, 0.3)
	_debug_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_container.add_child(_debug_border)

## 进入或退出头像调试模式；进入时显示测试头像供拖动缩放，退出时保存配置。
func _toggle_debug_mode() -> void:
	_debug_mode = not _debug_mode
	if _debug_mode:
		# 进入调试模式
		panel.visible = true
		speaker_label.text = "调试预览"
		speaker_label.visible = true
		text_label.text = "按住鼠标左键拖动头像 | 滚轮缩放 | F10 保存退出"
		text_label.visible_ratio = 1.0
		continue_indicator.visible = false
		
		# 显示测试头像
		var test_path = PORTRAIT_MAP.get("夏桐", "")
		if test_path != "" and ResourceLoader.exists(test_path):
			_portrait.texture = load(test_path)
		else:
			# 没有头像就用纯色占位
			var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.8, 0.5, 0.6))
			_portrait.texture = ImageTexture.create_from_image(img)
		_portrait.visible = true
		_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		
		_debug_label.visible = true
		_debug_border.visible = true
		_update_debug_info()
	else:
		# 退出调试模式 → 保存
		_save_portrait_config()
		_portrait.visible = false
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		_debug_label.visible = false
		_debug_border.visible = false
		_debug_dragging = false
		push_warning("[DialogueUI] portrait config saved: pos=%s size=%s" % [str(portrait_pos), str(portrait_size)])

## 刷新调试标签上的坐标文字与边框位置大小。
func _update_debug_info() -> void:
	_debug_label.text = "【头像调试】 位置: (%d, %d)  大小: %dx%d\n拖动=移动 | 滚轮=缩放 | F10=保存退出" % [
		int(portrait_pos.x), int(portrait_pos.y),
		int(portrait_size.x), int(portrait_size.y)
	]
	_debug_border.position = portrait_pos - Vector2(2, 2)
	_debug_border.size = portrait_size + Vector2(4, 4)

## 处理全局输入：F10 切换调试模式、滚轮开合对话历史、调试模式下拖动/缩放头像。
## [param event] 输入事件。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		_toggle_debug_mode()
		get_viewport().set_input_as_handled()
		return
	
	# 对话历史：鼠标滚轮上开启，任意点击/滚轮下/Esc关闭
	if not _debug_mode and DialogueManager.is_dialogue_active:
		if event is InputEventMouseButton and event.pressed:
			var mb = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and not _history_visible:
				_toggle_history()
				get_viewport().set_input_as_handled()
				return
			elif _history_visible:
				if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_toggle_history()
					get_viewport().set_input_as_handled()
					return
		if _history_visible and event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
				_toggle_history()
				get_viewport().set_input_as_handled()
				return
	
	if not _debug_mode:
		return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 检查是否在头像区域内
				var rect = Rect2(portrait_pos, portrait_size)
				if rect.has_point(mb.position):
					_debug_dragging = true
					_debug_drag_offset = mb.position - portrait_pos
			else:
				_debug_dragging = false
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			portrait_size += Vector2(10, 10)
			_apply_portrait_transform()
			_update_debug_info()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			portrait_size -= Vector2(10, 10)
			portrait_size = portrait_size.clamp(Vector2(80, 80), Vector2(1600, 1600))
			_apply_portrait_transform()
			_update_debug_info()
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and _debug_dragging:
		var mm = event as InputEventMouseMotion
		portrait_pos = mm.position - _debug_drag_offset
		_apply_portrait_transform()
		_update_debug_info()
		get_viewport().set_input_as_handled()
