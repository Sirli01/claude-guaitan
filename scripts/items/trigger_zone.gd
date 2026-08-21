extends Area2D
## 场景触发区域 - 用于触发剧情、切换场景等

signal triggered

@export var one_shot: bool = true
@export var trigger_dialogue: Array = []  # 可选的触发对话

var has_triggered: bool = false

func _ready() -> void:
	add_to_group("trigger")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if has_triggered and one_shot:
		return
	if body.is_in_group("player"):
		has_triggered = true
		triggered.emit()
		if not trigger_dialogue.is_empty():
			DialogueManager.start_dialogue(trigger_dialogue)
