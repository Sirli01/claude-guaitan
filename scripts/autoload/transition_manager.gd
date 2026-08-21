extends Node
## 场景转换管理器 - 处理黑屏过渡、淡入淡出

signal transition_midpoint  # 转场到最黑时触发
signal transition_completed

var transition_layer: CanvasLayer = null
var color_rect: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_transition_layer()

func _create_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)
	
	color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(color_rect)

func fade_to_black(duration: float = 1.0) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_from_black(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func transition_to_scene(scene_path: String, fade_duration: float = 1.0) -> void:
	# 强制关闭已打开的UI（防止背包暂停导致黑屏）
	get_tree().paused = false
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.is_open:
		inv_ui.close()
	var rules_ui = get_tree().get_first_node_in_group("rules_ui")
	if rules_ui and rules_ui.is_open:
		rules_ui.close()
	# 强制结束对话，防止对话框卡在界面上
	if DialogueManager.is_dialogue_active:
		DialogueManager.end_dialogue()
	await fade_to_black(fade_duration)
	transition_midpoint.emit()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_from_black(fade_duration)
	transition_completed.emit()

func flash_black(duration: float = 0.1) -> void:
	color_rect.color.a = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 用于进入公寓时的"所有声音瞬间切断"效果
func hard_cut_to_black() -> void:
	color_rect.color.a = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

func hold_black(duration: float = 2.0) -> void:
	color_rect.color.a = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(duration).timeout
