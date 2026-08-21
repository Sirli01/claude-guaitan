class_name RbGameUi
extends CanvasLayer
## rebuild 关卡内 UI 层的门面（Facade）。
##
## 关卡根节点只跟这个类打交道，不去碰它内部的子控件，
## 以后换 UI 实现不影响关卡代码。

@onready var interact_prompt: RbInteractPrompt = $InteractPrompt
@onready var dialogue_box: RbDialogueBox = $DialogueBox


func show_interact_prompt(action_text: String) -> void:
	interact_prompt.show_prompt(action_text)


func hide_interact_prompt() -> void:
	interact_prompt.hide_prompt()


func open_dialogue() -> void:
	dialogue_box.open()


func close_dialogue() -> void:
	dialogue_box.close()


func display_dialogue_line(speaker: String, text: String, index: int, total: int) -> void:
	dialogue_box.display_line(speaker, text, index, total)
