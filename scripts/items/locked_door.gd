extends Area2D
## 上锁的门 - 需要万能钥匙才能打开

var _unlocked: bool = false

func interact() -> void:
	if _unlocked:
		return
	var required_key: String = get_meta("required_key") if has_meta("required_key") else "master_key"
	if InventoryManager.has_item(required_key):
		# 开门
		_unlocked = true
		InputDevice.vibrate_light()
		var door_body = get_meta("door_body")
		var door_visual = get_meta("door_visual")
		var lock_label = get_meta("lock_label")
		var level = get_meta("level")
		
		# 移除碰撞
		if door_body and is_instance_valid(door_body):
			door_body.queue_free()
		
		# 改变门视觉
		if door_visual and is_instance_valid(door_visual):
			door_visual.color = Color(0.12, 0.08, 0.05, 0.5)
		
		# 移除锁图标
		if lock_label and is_instance_valid(lock_label):
			lock_label.queue_free()
		
		# 提示
		var key_data = InventoryManager.get_item_data(required_key)
		var key_name = key_data.get("name", "钥匙") if key_data else "钥匙"
		if level and level.has_method("show_hint"):
			level.show_hint(LocaleManager.door_unlocked_text(required_key, key_name))
		
		# 钥匙使用后消耗（拔不出来了）
		InventoryManager.remove_item(required_key)
		
		# 隐藏交互提示（包括UI层的标签和子节点Label）
		for child in get_children():
			if child is Label:
				child.visible = false
	else:
		# 没有钥匙
		var level = get_meta("level")
		if level and level.has_method("show_hint"):
			level.show_hint(LocaleManager.door_need_key_text())
