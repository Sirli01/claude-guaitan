extends Area2D
## 可搜索的家具容器 - 玩家交互后打开小面板显示内容物
## 用法: 由楼层场景的 _place_container() 自动创建

class_name FurnitureContainer

var furniture_name: String = "柜子"
var contained_item_id: String = ""  # 空字符串 = 空容器
var contained_item_name: String = ""
var _level: Node
var _name_label: Label
var _searched: bool = false  # 是否已被搜索过
var _item_taken: bool = false  # 物品是否已被拿走
var search_action_method: String = ""  # 无物品时触发的场景回调
var post_take_action_method: String = ""  # 拿到物品后触发的场景回调

func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _name_label:
		if _searched and (_item_taken or contained_item_id == ""):
			_name_label.text = LocaleManager.searched_label(furniture_name)
		else:
			_name_label.text = "%s %s" % [LocaleManager.world_text(furniture_name), InputDevice.hint("interact")]
		_name_label.visible = true
		if not body.nearby_interactables.has(self):
			body.nearby_interactables.append(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _name_label:
		_name_label.visible = false
		body.nearby_interactables.erase(self)

func interact() -> void:
	_searched = true
	if contained_item_id == "" and not _item_taken and search_action_method != "" and _level and _level.has_method(search_action_method):
		InputDevice.vibrate_light()
		_item_taken = true
		if _name_label:
			_name_label.text = LocaleManager.searched_label(furniture_name)
		_level.call_deferred(search_action_method)
		return
	if contained_item_id == "" or _item_taken:
		# 空容器
		if _level and _level.has_method("show_hint"):
			_level.show_hint(LocaleManager.container_empty_text(furniture_name))
		if _name_label:
			_name_label.text = LocaleManager.searched_label(furniture_name)
		return
	
	# 有物品 → 直接获取
	InventoryManager.add_item(contained_item_id)
	AudioManager.play_pickup_sfx()
	InputDevice.vibrate_light()
	_item_taken = true
	if _level and _level.has_method("show_hint"):
		var item_name = InventoryManager.get_item_data(contained_item_id).get("name", contained_item_name)
		_level.show_hint(LocaleManager.container_found_text(furniture_name, item_name))
	if _name_label:
		_name_label.text = LocaleManager.searched_label(furniture_name)
	if post_take_action_method != "" and _level and _level.has_method(post_take_action_method):
		_level.call_deferred(post_take_action_method, contained_item_id)
