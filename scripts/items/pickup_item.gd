extends Area2D
## 可拾取物品

@export var item_id: String = ""
@export var item_display_name: String = ""
@export var hint_text: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var hint_label: Label = $HintLabel

var _player_nearby: bool = false

func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if hint_label:
		hint_label.text = hint_text if hint_text != "" else LocaleManager.pickup_prompt_text()
		hint_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if hint_label:
			hint_label.text = hint_text if hint_text != "" else LocaleManager.pickup_prompt_text()
			hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if hint_label:
			hint_label.visible = false

func interact() -> void:
	if item_id.is_empty():
		return
	InventoryManager.add_item(item_id)
	InventoryManager.auto_apply_pickup_effects(item_id)
	InputDevice.vibrate_light()
	# 拾取效果
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - 20, 0.3)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
