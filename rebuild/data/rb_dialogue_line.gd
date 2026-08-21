class_name RbDialogueLine
extends RefCounted
## 一行对话的数据结构。故意做成显式类型，避免到处传裸 Dictionary。

var speaker: String = ""
var text: String = ""


func _init(p_speaker: String = "", p_text: String = "") -> void:
	speaker = p_speaker
	text = p_text
