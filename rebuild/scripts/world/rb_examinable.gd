class_name RbExaminable
extends RbInteractable
## rebuild 可查看物品 —— 交互后播放一段对话。
##
## 支持"第一次看"和"重复看"两套文本，避免关卡脚本写 if 判断。

## 第一次交互播放的对话 id。
@export var dialogue_id: String = ""
## 之后重复交互播放的对话 id；留空则一直播放 dialogue_id。
@export var repeat_dialogue_id: String = ""
## 交互一次后自动禁用。
@export var disable_after_first: bool = false
## 第一次交互后写入 RbGameState 的剧情标记；留空表示不写。
@export var flag_on_examine: String = ""

var _examined: bool = false


func has_been_examined() -> bool:
	return _examined


func _do_interact(_by: Node) -> void:
	var target_id: String = dialogue_id
	if _examined and repeat_dialogue_id != "":
		target_id = repeat_dialogue_id

	if not _examined:
		_examined = true
		if flag_on_examine != "":
			RbGameState.set_flag(flag_on_examine)
		if disable_after_first:
			enabled = false

	if target_id != "":
		dialogue_requested.emit(target_id)
