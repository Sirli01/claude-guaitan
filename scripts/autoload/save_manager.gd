extends Node
## 存档管理器 — 存档/读档 + 开发者模式场景跳转

const SAVE_PATH := "user://save.dat"
var is_loading_save: bool = false  # 读档中标志，场景用来跳过入场动画
var _saved_player_pos: Vector2 = Vector2.ZERO  # 读档时恢复的玩家位置

signal game_saved  # 存档成功信号

# 自动存档：每次换楼层时存档
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.floor_changed.connect(_on_floor_changed)
	game_saved.connect(_show_save_notification)

func _on_floor_changed(_new_floor: GameManager.Floor) -> void:
	# 延迟一帧让场景完成切换
	await get_tree().process_frame
	save_game()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		var success = load_game()
		if success:
			_show_notification(LocaleManager.t("load_success"))
		else:
			_show_notification(LocaleManager.t("no_save"))
		get_viewport().set_input_as_handled()

# 场景路径映射（开发者模式 + 存档用）
const SCENE_MAP := {
	"prologue_room": "res://scenes/levels/prologue_room.tscn",
	"prologue_street": "res://scenes/levels/prologue_street.tscn",
	"floor_1": "res://scenes/levels/floor_1.tscn",
	"floor_2": "res://scenes/levels/floor_2.tscn",
	"floor_3": "res://scenes/levels/floor_3.tscn",
	"ending": "res://scenes/levels/ending.tscn",
}

# 场景显示名
const SCENE_NAMES := {
	"prologue_room": "序章 - 房间",
	"prologue_street": "序章 - 街道",
	"floor_1": "第一层",
	"floor_2": "第二层",
	"floor_3": "第三层",
	"ending": "结局",
}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var scene_path := ""
	var tree := get_tree()
	if tree.current_scene:
		scene_path = tree.current_scene.scene_file_path

	# 获取玩家位置
	var player_pos := Vector2.ZERO
	if tree.current_scene and tree.current_scene.has_method("get") and tree.current_scene.get("player") != null:
		var player_node = tree.current_scene.get("player")
		if is_instance_valid(player_node):
			player_pos = player_node.global_position

	var data := {
		"version": 2,
		"scene_path": scene_path,
		# 玩家位置
		"player_pos_x": player_pos.x,
		"player_pos_y": player_pos.y,
		# GameManager
		"current_floor": GameManager.current_floor,
		"is_soul_swapped": GameManager.is_soul_swapped,
		"soul_swap_target": GameManager.soul_swap_target,
		"alive_characters": GameManager.alive_characters.duplicate(),
		"discovered_rules": GameManager.discovered_rules.duplicate(),
		"event_flags": GameManager.event_flags.duplicate(),
		"pending_item_loss": GameManager.pending_item_loss.duplicate(),
		# InventoryManager
		"inventory": InventoryManager.inventory.duplicate(),
		"item_counts": InventoryManager.item_counts.duplicate(),
		"discovered_items": InventoryManager.discovered_items.duplicate(),
		# PlayerStats
		"stamina": PlayerStats.stamina,
		"sanity": PlayerStats.sanity,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		push_warning("[SaveManager] 存档成功: " + scene_path)
		game_saved.emit()

func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var data: Variant = file.get_var()
	file.close()

	if not data is Dictionary:
		return false

	# GameManager
	GameManager.current_floor = data.get("current_floor", GameManager.Floor.PROLOGUE)
	GameManager.is_soul_swapped = data.get("is_soul_swapped", false)
	GameManager.soul_swap_target = data.get("soul_swap_target", "")
	GameManager.alive_characters = data.get("alive_characters", {})
	GameManager.discovered_rules.assign(data.get("discovered_rules", []))
	GameManager.event_flags = data.get("event_flags", {})
	GameManager.pending_item_loss.assign(data.get("pending_item_loss", []))

	# InventoryManager
	InventoryManager.inventory.assign(data.get("inventory", []))
	InventoryManager.item_counts = data.get("item_counts", {})
	# 老存档兼容：如果没有 item_counts，为叠加物品默认置1
	if not data.has("item_counts"):
		for item_id in InventoryManager.inventory:
			var item_data = InventoryManager.get_item_data(item_id)
			if item_data.get("stackable", false):
				InventoryManager.item_counts[item_id] = 1
	InventoryManager.discovered_items.assign(data.get("discovered_items", []))

	# PlayerStats
	PlayerStats.stamina = data.get("stamina", PlayerStats.max_stamina)
	PlayerStats.sanity = data.get("sanity", PlayerStats.max_sanity)

	# 保存玩家位置供场景恢复
	_saved_player_pos = Vector2(data.get("player_pos_x", 0.0), data.get("player_pos_y", 0.0))

	# 强制结束旧场景的对话，防止对话框卡在新场景
	if DialogueManager.is_dialogue_active:
		DialogueManager.end_dialogue()

	# 切换到存档场景
	GameManager.current_state = GameManager.GameState.PLAYING
	is_loading_save = true
	var scene_path: String = data.get("scene_path", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		# change_scene_to_file 是延迟执行的，新场景的 _ready 会在下一帧运行
		# 用 call_deferred 在 _ready 之后清除标志
		call_deferred("_clear_loading_flag")
		return true

	is_loading_save = false
	return false

func _clear_loading_flag() -> void:
	# 等两帧确保场景初始化完成
	await get_tree().process_frame
	await get_tree().process_frame
	# 恢复玩家位置
	if _saved_player_pos != Vector2.ZERO:
		var scene = get_tree().current_scene
		if scene and scene.get("player"):
			var p = scene.player
			if is_instance_valid(p):
				p.global_position = _saved_player_pos
		_saved_player_pos = Vector2.ZERO
	is_loading_save = false

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

# ===== 开发者模式：跳转到任意场景 =====
func dev_jump_to(scene_key: String, setup: Dictionary = {}) -> void:
	# 先重置所有状态（不切换场景）
	GameManager._reset_all_state()

	# 应用开发者设置
	if setup.has("floor"):
		GameManager.current_floor = setup["floor"]
	if setup.has("items"):
		for item in setup["items"]:
			InventoryManager.add_item(item)
	if setup.has("rules"):
		for rule in setup["rules"]:
			GameManager.add_rule(rule)
	if setup.has("kill"):
		for char_id in setup["kill"]:
			GameManager.kill_character(char_id)

	# 跳转场景
	var path: String = SCENE_MAP.get(scene_key, "")
	if path != "" and ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
		push_warning("[Dev] 跳转到: " + scene_key)

# 预设开发者快捷配置
func dev_presets() -> Dictionary:
	return {
		"prologue_room": {},
		"prologue_street": {
			"items": ["phone"],
		},
		"floor_1": {
			"floor": GameManager.Floor.FLOOR_1,
			"hour": 21,
			"items": ["rule_paper"],
		},
		"floor_2": {
			"floor": GameManager.Floor.FLOOR_2,
			"hour": 23, "minute": 30,
			"items": ["rule_paper", "earplug"],
			"rules": ["23:00 - 07:00，禁止对视"],
		},
		"floor_3": {
			"floor": GameManager.Floor.FLOOR_3,
			"hour": 0,
			"items": ["rule_paper"],
			"rules": ["23:00 - 07:00，禁止对视", "禁止离群 — 第二层"],
			"kill": ["timid_male", "female_npc"],
		},
		"ending": {
			"floor": GameManager.Floor.ENDING,
			"hour": 6,
			"items": ["rule_paper"],
			"rules": ["23:00 - 07:00，禁止对视", "禁止离群 — 第二层", "禁止跑步 — 第三层"],
			"kill": ["timid_male", "female_npc", "male_npc"],
		},
	}

func _show_save_notification() -> void:
	_show_notification(LocaleManager.t("saved"))

## 显示通知消息。
## [param text] 通知文本内容。
func _show_notification(text: String) -> void:
	## 实例化通知场景
	var notification_scene = preload("res://scenes/ui/notification.tscn")
	var notification = notification_scene.instantiate()
	add_child(notification)

	## 设置通知文本
	var label = notification.get_node("Label")
	label.text = text

	## 1.5秒后渐隐消失
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(notification.queue_free)
