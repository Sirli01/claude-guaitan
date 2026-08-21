class_name RbDialogueRunner
extends Node
## rebuild 对话推进器 —— 只负责"当前播到第几行"，不碰任何 UI 节点。
##
## UI 通过监听信号来更新显示；关卡通过监听信号来冻结/恢复玩家输入。
## 这样对话逻辑可以脱离 UI 单独测试。

signal dialogue_started(dialogue_id: String)
signal line_changed(speaker: String, text: String, index: int, total: int)
signal dialogue_finished(dialogue_id: String)

var _lines: Array[RbDialogueLine] = []
var _index: int = -1
var _active_id: String = ""
## 记录开始播放的帧号，防止"触发交互的那一次按键"同帧又推进了对话。
var _started_frame: int = -1


func is_active() -> bool:
	return _active_id != ""


func get_active_id() -> String:
	return _active_id


## 开始一段对话。返回是否成功启动。
func start(dialogue_id: String) -> bool:
	if is_active():
		push_warning("[RbDialogueRunner] 已有对话进行中: %s，忽略 %s" % [_active_id, dialogue_id])
		return false
	if not RbDialogueDb.has_dialogue(dialogue_id):
		return false

	_lines = RbDialogueDb.get_lines(dialogue_id)
	if _lines.is_empty():
		return false

	_active_id = dialogue_id
	_index = 0
	_started_frame = Engine.get_process_frames()
	dialogue_started.emit(_active_id)
	_emit_current_line()
	return true


## 推进到下一行；已是最后一行则结束对话。
func advance() -> void:
	if not is_active():
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_emit_current_line()


## 立即结束当前对话（用于场景切换等强制中断）。
func stop() -> void:
	if not is_active():
		return
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if Engine.get_process_frames() == _started_frame:
		return
	if not (event.is_action_pressed(&"dialogue_advance") or event.is_action_pressed(&"interact")):
		return
	advance()
	get_viewport().set_input_as_handled()


func _emit_current_line() -> void:
	var line: RbDialogueLine = _lines[_index]
	line_changed.emit(line.speaker, line.text, _index + 1, _lines.size())


func _finish() -> void:
	var finished_id: String = _active_id
	_active_id = ""
	_index = -1
	_lines.clear()
	dialogue_finished.emit(finished_id)
