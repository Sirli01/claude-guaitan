extends Area2D
## 可拾取物品

@export var item_id: String = ""
@export var item_display_name: String = ""
@export var hint_text: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var hint_label: Label = $HintLabel

var _player_nearby: bool = false

## 初始化交互分组、信号连接与提示文字。
func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if hint_label:
		hint_label.text = hint_text if hint_text != "" else LocaleManager.pickup_prompt_text()
		hint_label.visible = false

## 玩家进入范围时显示拾取提示。
## [param body] 进入区域的物理体。
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if hint_label:
			hint_label.text = hint_text if hint_text != "" else LocaleManager.pickup_prompt_text()
			hint_label.visible = true

## 玩家离开范围时隐藏拾取提示。
## [param body] 离开区域的物理体。
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if hint_label:
			hint_label.visible = false

## 拾取物品：加入背包、应用效果、震动反馈并播放淡出动画后自毁。
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
