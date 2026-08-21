extends Area2D
## 简单拾取物品 - 靠近显示名称和交互键提示，按当前互动键拾取
## 用法: 由楼层场景的 _place_room_item() 自动创建

class_name SimplePickup

signal picked_up

var item_id: String
var item_name: String
var _name_label: Label
var _level: Node  # 引用关卡场景（用于show_hint）
var auto_collect: bool = false  # true = 走近自动拾取（无需按E），用于掉落物

func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 延迟一帧检查是否已有玩家在范围内（生成时重叠不触发 body_entered）
	call_deferred("_check_initial_overlap")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if auto_collect:
			# 自动拾取：走到就收
			interact()
			return
		if _name_label:
			var display_name: String = InventoryManager.get_item_data(item_id).get("name", item_name)
			_name_label.text = "%s %s" % [display_name, InputDevice.hint("interact")]
			_name_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _name_label:
		_name_label.visible = false

func _check_initial_overlap() -> void:
	# 等两帧物理帧确保重叠检测完全就绪（过场动画中途生成时1帧不够）
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)
			break
	# 也需要让玩家的交互区域感知到本物品（area_entered 不会对已重叠的触发）
	if is_in_group("interactable"):
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node and player_node.interaction_area:
			if player_node.interaction_area.get_overlapping_areas().has(self) and not player_node.nearby_interactables.has(self):
				player_node.nearby_interactables.append(self)

func interact() -> void:
	InventoryManager.add_item(item_id)
	AudioManager.play_pickup_sfx()
	InputDevice.vibrate_light()
	var locale_name: String = InventoryManager.get_item_data(item_id).get("name", item_name)
	var hint_text: String = LocaleManager.t("item_got") % locale_name
	if _level and _level.has_method("show_hint"):
		_level.show_hint(hint_text)
	picked_up.emit()
	queue_free()
