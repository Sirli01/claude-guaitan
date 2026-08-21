extends CanvasLayer
## 剧情演出系统 - 插图 + 文字的剧情演出框架
## 用法:
##   var cutscene = CutscenePlayer.new()
##   level.add_child(cutscene)
##   cutscene.play_cutscene([
##       {"image": "res://assets/sprites/cutscenes/scene1.png", "text": "那天晚上，一切都变了...", "duration": 4.0},
##       {"image": "res://assets/sprites/cutscenes/scene2.png", "text": "姐姐收到了一条来自妹妹的短信。", "duration": 3.5},
##       {"text": "（没有图片时只显示文字，黑色背景）", "duration": 3.0},
##       {"image": "res://assets/sprites/cutscenes/scene3.png", "speaker": "夏桐", "text": "夏澈？你在哪里？"},
##   ])
##   await cutscene.cutscene_finished

class_name CutscenePlayer

signal cutscene_finished

var _bg: ColorRect
var _image_rect: TextureRect
var _text_panel: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _advance_hint: Label
var _is_playing: bool = false
var _auto_advance: bool = false  # true=按时间自动推进，false=需要按键
var _current_step: int = 0
var _steps: Array = []
var _text_finished: bool = false

func _ready() -> void:
	layer = 50  # 在游戏UI之上
	visible = false
	
	# 全屏黑色背景
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0)
	add_child(_bg)
	
	# 插图区域（居中）
	_image_rect = TextureRect.new()
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image_rect)
	
	# 底部文字面板
	_text_panel = PanelContainer.new()
	_text_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_text_panel.offset_left = 90
	_text_panel.offset_top = -240
	_text_panel.offset_right = -90
	_text_panel.offset_bottom = -45
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_text_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_text_panel)
	
	var vbox = VBoxContainer.new()
	_text_panel.add_child(vbox)
	
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 27)
	_speaker_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_speaker_label.visible = false
	vbox.add_child(_speaker_label)
	
	_text_label = RichTextLabel.new()
	_text_label.custom_minimum_size = Vector2(0, 90)
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(_text_label)
	
	# 按键提示
	_advance_hint = Label.new()
	_advance_hint.text = LocaleManager.t("cutscene_advance_hint")
	_advance_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_advance_hint.offset_left = -150
	_advance_hint.offset_top = -30
	_advance_hint.add_theme_font_size_override("font_size", 16)
	_advance_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_advance_hint.visible = false
	_text_panel.add_child(_advance_hint)

func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	if _auto_advance:
		return
	if event.is_action_pressed("dialogue_advance") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _text_finished:
			_advance_step()
		else:
			# 快速显示当前文字
			_text_label.visible_ratio = 1.0
			_text_finished = true
			_advance_hint.visible = true

func play_cutscene(steps: Array, auto: bool = false) -> void:
	## 播放剧情演出
	## steps: 步骤数组，每步可包含：
	##   image: 插图路径（可选，不填则黑屏+文字）
	##   text: 显示文字
	##   speaker: 说话人名字（可选）
	##   duration: 自动推进时间（仅auto=true时有效）
	##   fade_in: 淡入时间（默认0.5）
	##   fade_out: 淡出时间（默认0.3）
	_steps = steps
	_auto_advance = auto
	_current_step = 0
	_is_playing = true
	visible = true
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	_show_step(_current_step)

func _show_step(index: int) -> void:
	if index >= _steps.size():
		_end_cutscene()
		return
	
	var step = _steps[index]
	_text_finished = false
	_advance_hint.visible = false
	
	# 淡入
	var fade_in = step.get("fade_in", 0.5)
	modulate.a = 0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, fade_in)
	
	# 插图
	var image_path: String = step.get("image", "")
	if image_path != "" and ResourceLoader.exists(image_path):
		_image_rect.texture = load(image_path)
		_image_rect.visible = true
	else:
		_image_rect.texture = null
		_image_rect.visible = false
	
	# 说话人
	var speaker: String = step.get("speaker", "")
	if speaker != "":
		_speaker_label.text = speaker
		_speaker_label.visible = true
	else:
		_speaker_label.visible = false
	
	# 文字（逐字显示）
	var text: String = step.get("text", "")
	_text_label.text = text
	if text != "":
		_text_panel.visible = true
		_text_label.visible_ratio = 0.0
		var type_duration = len(text) * 0.04
		var text_tw = create_tween()
		text_tw.tween_property(_text_label, "visible_ratio", 1.0, type_duration)
		text_tw.tween_callback(func():
			_text_finished = true
			_advance_hint.visible = not _auto_advance
		)
	else:
		_text_panel.visible = false
		_text_finished = true
	
	# 自动推进
	if _auto_advance:
		var duration = step.get("duration", 4.0)
		await get_tree().create_timer(duration).timeout
		_advance_step()

func _advance_step() -> void:
	var fade_out = 0.3
	if _current_step < _steps.size():
		fade_out = _steps[_current_step].get("fade_out", 0.3)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_out)
	await tw.finished
	
	_current_step += 1
	_show_step(_current_step)

func _end_cutscene() -> void:
	_is_playing = false
	visible = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	cutscene_finished.emit()

func skip_cutscene() -> void:
	## 跳过整个剧情演出
	_end_cutscene()
