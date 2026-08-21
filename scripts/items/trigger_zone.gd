extends Area2D
## 场景触发区域 - 用于触发剧情、切换场景等

signal triggered

@export var one_shot: bool = true
@export var trigger_dialogue: Array = []  # 可选的触发对话

var has_triggered: bool = false

## 加入 trigger 分组并连接进入信号。
func _ready() -> void:
	add_to_group("trigger")
	body_entered.connect(_on_body_entered)

## 玩家进入时发出 triggered 信号并可选拨放对话。
## [param body] 进入区域的物理体。
func _on_body_entered(body: Node2D) -> void:
	if has_triggered and one_shot:
		return
	if body.is_in_group("player"):
		has_triggered = true
		triggered.emit()
		if not trigger_dialogue.is_empty():
			DialogueManager.start_dialogue(trigger_dialogue)
