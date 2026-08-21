extends Control
## 规则纸条UI - 动态显示已发现的规则

@onready var background: NinePatchRect = $Background
@onready var title_label: Label = $Background/TitleLabel
@onready var rules_container: VBoxContainer = $Background/ScrollContainer/RulesContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_open: bool = false
var _pending_rules: Array[String] = []
signal closed  # 纸条关闭时发出

## 初始化纸条界面：加入组、生成纸张底色、绑定楼层信号并创建关闭按钮。
func _ready() -> void:
	add_to_group("rules_ui")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	title_label.text = LocaleManager.t("rules_title")
	# 给纸条添加纸张背景色（待替换为实际纸条美术素材）
	var paper_img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	paper_img.fill(Color(0.92, 0.87, 0.75))
	background.texture = ImageTexture.create_from_image(paper_img)
	GameManager.connect("floor_changed", _on_floor_changed)
	# 关闭按钮（右上角×）
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 32)
	close_btn.add_theme_color_override("font_color", Color(0.4, 0.2, 0.2))
	close_btn.position = Vector2(480, 8)
	close_btn.size = Vector2(48, 48)
	close_btn.pressed.connect(close)
	close_btn.z_index = 10
	background.add_child(close_btn)
	AudioManager.wire_button_clicks(self)

## 切换规则纸条的开关状态；过场动画状态下禁止手动打开。
func toggle() -> void:
	if is_open:
		close()
	else:
		# 玩家手动打开，检查游戏状态
		if GameManager.current_state == GameManager.GameState.CUTSCENE:
			return
		open()

## 纸条打开时监听关闭按键与纸条外区域点击，触发关闭。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("open_rules") or event.is_action_pressed("ui_close") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	# 点击纸条外区域关闭（触屏/鼠标）
	if is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if background and not background.get_global_rect().has_point(event.position):
			close()
			get_viewport().set_input_as_handled()

## 打开规则纸条：暂停游戏、刷新规则列表并播放淡入动画。
func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	AudioManager.play_system_open()
	_refresh_rules()
	# 淡入动画
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

## 关闭规则纸条：播放淡出动画后取消暂停并发送 closed 信号。
func close() -> void:
	if not is_open:
		return
	is_open = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false
	get_tree().paused = false
	closed.emit()

## 登记一条新规则；若纸条正打开则立即播放逐字浮现动画。
## [param rule_text] 规则文本。
func add_rule_with_effect(rule_text: String) -> void:
	GameManager.add_rule(rule_text)
	_pending_rules.append(rule_text)
	# 如果纸条是打开的，实时添加
	if is_open:
		_animate_new_rule(rule_text)

## 清空并按已发现规则重建列表，底部附上随设备变化的关闭提示。
func _refresh_rules() -> void:
	# 清除旧的
	for child in rules_container.get_children():
		child.queue_free()
	# 重建
	for rule in GameManager.discovered_rules:
		_add_rule_label(rule)
	# 底部关闭提示（动态显示当前设备按键）
	var close_key = InputDevice.get_hint("open_rules") if not InputDevice.using_gamepad else InputDevice.get_hint("ui_close")
	var hint = Label.new()
	hint.text = LocaleManager.t("rules_close_hint") % close_key
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.4, 0.3, 0.3, 0.6))
	hint.add_theme_font_size_override("font_size", 18)
	rules_container.add_child(hint)

## 在规则列表末尾添加一条自动换行的红色规则文本。
## [param text] 规则文本。
## [return] 新创建的 Label 节点。
func _add_rule_label(text: String) -> Label:
	var label = Label.new()
	label.text = "• " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.7, 0.05, 0.05))
	label.add_theme_font_size_override("font_size", 30)
	rules_container.add_child(label)
	return label

## 在纸条打开时插入新规则并播放逐字浮现动画与诡异音效。
## [param text] 规则文本。
func _animate_new_rule(text: String) -> void:
	# 先移除底部提示（临时）
	var hint: Node = null
	if rules_container.get_child_count() > 0:
		hint = rules_container.get_child(rules_container.get_child_count() - 1)
		rules_container.remove_child(hint)
	
	var label = _add_rule_label(text)
	label.modulate.a = 1.0
	label.visible_characters = 0
	
	# 重新加回底部提示
	if hint:
		rules_container.add_child(hint)
	
	# 规则音效（诡异低频嗡鸣）
	var sfx = preload("res://scripts/utils/procedural_sfx.gd")
	AudioManager.play_sfx(sfx.ground_rumble(), -10.0)
	
	# 逐字浮现效果（像字迹慢慢渗出）
	var total_chars = label.text.length()
	var tween = create_tween()
	tween.tween_property(label, "visible_characters", total_chars, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## 楼层变化信号回调（当前无额外处理）。
## [param _new_floor] 新楼层枚举值（未使用）。
func _on_floor_changed(_new_floor: GameManager.Floor) -> void:
	pass
