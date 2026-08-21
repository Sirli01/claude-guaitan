class_name RbInteractPrompt
extends Control
## rebuild 交互提示条。
##
## 布局、配色、字号全部在 rb_interact_prompt.tscn 中定义，脚本只改文本和可见性。

## 按键名，在场景中配置，便于以后接手柄/触屏。
@export var key_label: String = "空格"

@onready var _label: Label = $Panel/Label


func _ready() -> void:
	hide_prompt()


func show_prompt(action_text: String) -> void:
	_label.text = "[%s] %s" % [key_label, action_text]
	visible = true


func hide_prompt() -> void:
	visible = false
