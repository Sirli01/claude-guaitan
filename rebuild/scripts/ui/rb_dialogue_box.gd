class_name RbDialogueBox
extends Control
## rebuild 对话框显示层。
##
## 只做"把文字放进已有的 Label"，不推进对话、不判断输入。
## 所有布局与样式在 rb_dialogue_box.tscn 中定义。

@onready var _speaker_label: Label = $Panel/Margin/Layout/Speaker
@onready var _body_label: Label = $Panel/Margin/Layout/Body
@onready var _progress_label: Label = $Panel/Margin/Layout/Progress


func _ready() -> void:
	close()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func display_line(speaker: String, text: String, index: int, total: int) -> void:
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_body_label.text = text
	_progress_label.text = "%d / %d  ▶" % [index, total]
