class_name RbInteractable
extends Area2D
## rebuild 可交互物基类。
##
## 约定：
## - 交互物自己不知道 UI、不知道场景加载器，只发信号说"我想要什么"。
## - 由关卡根节点（RbLevelRoot）决定如何响应。

## 玩家真正按下交互键之后触发。
signal interacted(by: Node)
## 请求播放一段对话（RbDialogueDb 中的 id）。
signal dialogue_requested(dialogue_id: String)

## 显示在交互提示条上的动词，例如 "查看" / "开门"。
@export var prompt_text: String = "查看"
## 关掉之后不再被交互探测器选中。
@export var enabled: bool = true


func can_interact() -> bool:
	return enabled


## 由 RbLevelRoot 调用，不要在别处直接调 _do_interact。
func interact(by: Node) -> void:
	if not can_interact():
		return
	_do_interact(by)
	interacted.emit(by)


## 子类重写这里实现具体行为。
func _do_interact(_by: Node) -> void:
	pass
