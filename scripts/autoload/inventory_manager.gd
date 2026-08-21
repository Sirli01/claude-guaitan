extends Node
## 物品栏管理器 - 支持效果系统
## 新增物品只需在 ITEM_DATA 里添加一行，填入 effects 数组即可
## effects 格式: [{"type": "stamina", "value": 30}, {"type": "sanity", "value": 20}]

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_changed
signal consumable_used(item_id: String)

# ====== 物品数据（所有物品，新增物品只改这里）======
var ITEM_DATA := {
	# === 剧情道具 ===
	"earplug": {"name": "耳塞", "description": "能屏蔽声音的耳塞", "icon": "earplug", "category": "key"},
	"rope": {"name": "绳子", "description": "一段结实的绳子", "icon": "rope", "category": "key"},
	"elevator_card": {"name": "电梯卡", "description": "可以召唤电梯的磁卡", "icon": "elevator_card", "category": "key"},
	"phone": {"name": "手机", "description": "夏桐的手机，和妹妹的聊天记录还在", "icon": "phone", "category": "key"},
	"rule_paper": {"name": "规则纸条", "description": "一张诡异的纸条，上面的字迹会自动出现", "icon": "rule_paper", "category": "key"},
	"master_key": {"name": "万能钥匙", "description": "一把锈迹斑斑的万能钥匙，可以打开公寓里上锁的房间", "icon": "master_key", "category": "key"},
	"room_304_key": {"name": "304房间钥匙", "description": "周锐的房间钥匙，上面刻着「304」", "icon": "master_key", "category": "key"},
	# === 照明道具 ===
	"flashlight": {"name": "手电筒", "description": "一支老旧的手电筒，能照亮前方较大区域", "icon": "flashlight", "category": "key"},
	"match": {"name": "火柴", "description": "一根火柴，点燃后能照亮周围一小片区域，持续10秒", "icon": "match", "category": "special", "consumable": true, "stackable": true},
	"battery": {"name": "电池", "description": "手电筒电池，可以恢复50%电量", "icon": "battery", "category": "special", "consumable": true, "stackable": true},
	# === 消耗品 ===
	"energy_drink": {"name": "能量饮料", "description": "喝了能恢复不少体力", "icon": "energy_drink", "category": "food", "consumable": true, "effects": [{"type": "stamina", "value": 40}]},
	"sedative": {"name": "镇定剂", "description": "能缓解恐慌，恢复理智", "icon": "sedative", "category": "medicine", "consumable": true, "effects": [{"type": "sanity", "value": 25}]},
	"sweets": {"name": "糖果", "description": "甜甜的糖果，能稍微安抚精神", "icon": "sweets", "category": "food", "consumable": true, "effects": [{"type": "sanity", "value": 10}]},
	# === 新增消耗品 ===
	"energy_bar": {"name": "能量棒", "description": "便利店卖的能量棒，能恢复一些体力", "icon": "energy_bar", "category": "food", "consumable": true, "effects": [{"type": "stamina", "value": 30}]},
	"coffee": {"name": "咖啡", "description": "罐装咖啡，微苦，能同时恢复一点体力和理智", "icon": "coffee", "category": "food", "consumable": true, "effects": [{"type": "stamina", "value": 15}, {"type": "sanity", "value": 5}]},
	"bandage": {"name": "绷带", "description": "急救箱里的绷带，包扎后能让心情安定一些", "icon": "bandage", "category": "medicine", "consumable": true, "effects": [{"type": "sanity", "value": 20}]},
}

var inventory: Array[String] = []
var item_counts: Dictionary = {}          # 叠加物品数量 {item_id: count}
var discovered_items: Array[String] = []  # 曾经获得过的物品（用于图鉴）

## 初始化物品栏管理器（当前无额外初始化逻辑）。
func _ready() -> void:
	pass

## 运行时注册新物品数据（供关卡脚本动态扩展）。
## [param item_id] 物品唯一标识。
## [param data] 物品数据字典，字段格式与 ITEM_DATA 条目一致。
func register_item(item_id: String, data: Dictionary) -> void:
	## 运行时注册新物品（给关卡脚本用，不用改这个文件）
	ITEM_DATA[item_id] = data

## 向物品栏添加物品，叠加物品累加计数，并记录到图鉴。
## [param item_id] 物品 ID。
func add_item(item_id: String) -> void:
	var data = get_item_data(item_id)
	if data.get("stackable", false):
		# 叠加物品：允许多个，用 item_counts 记数量
		if item_id not in inventory:
			inventory.append(item_id)
		item_counts[item_id] = item_counts.get(item_id, 0) + 1
		item_added.emit(item_id)
		inventory_changed.emit()
	else:
		if item_id not in inventory:
			inventory.append(item_id)
			item_added.emit(item_id)
			inventory_changed.emit()
	if item_id not in discovered_items:
		discovered_items.append(item_id)

## 从物品栏移除物品，叠加物品仅减少一个数量。
## [param item_id] 物品 ID。
func remove_item(item_id: String) -> void:
	if item_id in inventory:
		var data = get_item_data(item_id)
		if data.get("stackable", false) and item_counts.get(item_id, 1) > 1:
			item_counts[item_id] -= 1
		else:
			inventory.erase(item_id)
			item_counts.erase(item_id)
		item_removed.emit(item_id)
		inventory_changed.emit()

## 判断物品栏中是否拥有指定物品。
## [return] 拥有返回 true。
func has_item(item_id: String) -> bool:
	return item_id in inventory

## 获取物品在物品栏中的持有数量。
## [param item_id] 物品 ID。
## [return] 叠加物品返回持有数量，非叠加物品持有为 1、未持有为 0。
func get_item_count(item_id: String) -> int:
	## 获取物品数量（叠加物品返回数量，非叠加返回0或1）
	var data = get_item_data(item_id)
	if data.get("stackable", false):
		return item_counts.get(item_id, 0)
	return 1 if has_item(item_id) else 0

## 获取物品数据副本并合并本地化文本。
## [param item_id] 物品 ID。
## [return] 合并本地化后的物品数据字典，物品不存在时返回空字典。
func get_item_data(item_id: String) -> Dictionary:
	var base: Dictionary = ITEM_DATA.get(item_id, {}).duplicate()
	if base.is_empty():
		return base
	var loc: Dictionary = LocaleManager.item_locale(item_id)
	if not loc.is_empty():
		base.merge(loc, true)
	return base

## 使用物品：火柴/电池走特殊照明逻辑，其余应用 effects 效果，消耗品随后移除。
## [param item_id] 物品 ID。
## [return] 使用成功返回 true，物品不在物品栏时返回 false。
func use_item(item_id: String) -> bool:
	## 使用物品 - 如果有效果则应用，consumable则消耗
	if not has_item(item_id):
		return false
	InputDevice.vibrate_medium()
	var data = get_item_data(item_id)
	
	# 火柴特殊处理：触发照明系统
	if item_id == "match":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var lighting = player.get_node_or_null("PlayerLighting")
			if not lighting:
				for child in player.get_children():
					if child.has_method("use_match"):
						lighting = child
						break
			if lighting and lighting.has_method("use_match"):
				lighting.use_match()
		remove_item(item_id)
		consumable_used.emit(item_id)
		return true
	
	# 电池特殊处理：补充手电筒电量
	if item_id == "battery":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var lighting = player.get_node_or_null("PlayerLighting")
			if not lighting:
				for child in player.get_children():
					if child.has_method("add_battery"):
						lighting = child
						break
			if lighting and lighting.has_method("add_battery"):
				lighting.add_battery(50.0)
		remove_item(item_id)
		consumable_used.emit(item_id)
		return true
	
	var effects = data.get("effects", [])
	if effects.size() > 0:
		PlayerStats.apply_item_effects(effects)
	if data.get("consumable", false):
		remove_item(item_id)
	consumable_used.emit(item_id)
	return true

## 拾取物品时自动应用其 pickup_effects 被动效果。
## [param item_id] 物品 ID。
func auto_apply_pickup_effects(item_id: String) -> void:
	## 拾取时自动触发效果（非消耗品拾取也能有被动触发）
	var data = get_item_data(item_id)
	var effects = data.get("pickup_effects", [])
	if effects.size() > 0:
		PlayerStats.apply_item_effects(effects)

## 清空物品栏与叠加计数并发出变更信号（不影响图鉴记录）。
func clear() -> void:
	inventory.clear()
	item_counts.clear()
	inventory_changed.emit()
