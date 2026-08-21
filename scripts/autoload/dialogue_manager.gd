extends Node
## 对话管理器 - 管理NPC对话、叙事文本显示
## 负责控制对话流程、显示对话内容、处理对话状态

signal dialogue_started(speaker: String)
signal dialogue_line_shown(speaker: String, text: String, emotion: String)
signal dialogue_ended
signal choice_presented(choices: Array)
signal choice_made(index: int)

## 是否有对话正在进行
var is_dialogue_active: bool = false
## 当前对话数据（Array of {speaker, text, portrait}）
var current_dialogue: Array = []
## 当前显示的对话行索引
var current_line_index: int = 0
## 对话 UI 节点引用
var dialogue_ui: Node = null
## 对话前的游戏状态（用于对话结束后恢复）
var _pre_dialogue_state: GameManager.GameState = GameManager.GameState.PLAYING

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 注册对话 UI 节点。
## [param ui_node] 对话 UI 节点引用。
func register_ui(ui_node: Node) -> void:
	dialogue_ui = ui_node

## 开始对话。
## [param dialogue_data] 对话数据数组，每项包含 speaker, text, emotion 等字段。
func start_dialogue(dialogue_data: Array) -> void:
	if dialogue_data.is_empty():
		return
	if not is_dialogue_active:
		_pre_dialogue_state = GameManager.current_state
	current_dialogue = dialogue_data
	current_line_index = 0
	is_dialogue_active = true
	GameManager.set_state(GameManager.GameState.DIALOGUE)
	dialogue_started.emit(dialogue_data[0].get("speaker", ""))
	_show_current_line()

## 显示当前对话行。
func _show_current_line() -> void:
	if current_line_index >= current_dialogue.size():
		end_dialogue()
		return
	var line = current_dialogue[current_line_index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")
	var emotion = line.get("emotion", "")
	dialogue_line_shown.emit(speaker, text, emotion)

## 推进到下一行对话。
func advance() -> void:
	if not is_dialogue_active:
		return
	if dialogue_ui and dialogue_ui.has_method("skip_typewriter") and dialogue_ui.skip_typewriter():
		return
	current_line_index += 1
	_show_current_line()

## 跳过当前对话。
func skip_current_dialogue() -> void:
	if not is_dialogue_active:
		return
	end_dialogue()

## 结束对话，恢复对话前的游戏状态。
func end_dialogue() -> void:
	is_dialogue_active = false
	current_dialogue.clear()
	current_line_index = 0
	GameManager.set_state(_pre_dialogue_state)
	dialogue_ended.emit()

## 显示叙事文本（无说话人）。
## [param text] 叙事文本内容。
## [param _duration] 显示时长（暂未使用）。
func show_narration(text: String, _duration: float = 3.0) -> void:
	start_dialogue([{"speaker": "", "text": text}])

## 创建对话行数据。
## [param speaker] 说话人名称。
## [param text] 对话文本。
## [return] 对话行字典。
static func make_line(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}

## 创建对话数据数组。
## [param lines] 对话行数组。
## [return] 对话数据数组。
static func make_dialogue(lines: Array) -> Array:
	return lines
