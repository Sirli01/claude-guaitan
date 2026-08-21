extends Node
## 事件模板 - 数据驱动的恐怖事件触发器
## 用法:
##   var evt = EventTemplate.new()
##   evt.event_config = {
##       "id": "room_301_scare",
##       "type": "scare",           # scare / dialogue / pickup / ambush / cutscene
##       "one_shot": true,
##       "conditions": {             # 可选：触发条件
##           "has_item": "phone",    # 需要持有某物品
##           "flag": "found_diary",  # 需要某事件标记
##           "floor": 3,            # 需要在某楼层
##           "stamina_below": 30,   # 体力低于
##           "sanity_below": 50,    # 理智低于
##       },
##       "actions": [                # 触发后执行的动作序列
##           {"type": "dialogue", "lines": [{"speaker": "???", "text": "你听到了什么..."}]},
##           {"type": "sfx", "path": "res://assets/audio/sfx/scare1.ogg"},
##           {"type": "screen_shake", "intensity": 5, "duration": 0.5},
##           {"type": "wait", "duration": 1.0},
##           {"type": "set_flag", "flag": "room301_scared"},
##           {"type": "give_item", "item_id": "key_301"},
##           {"type": "apply_effect", "effects": [{"type": "frightened", "duration": 5}]},
##           {"type": "change_ambience", "path": "res://assets/audio/ambience/tense.ogg"},
##           {"type": "spawn_monster", "monster_id": "shadow"},  # 关卡脚本处理
##       ],
##   }
##   level.add_child(evt)

class_name EventTemplate

var event_config: Dictionary = {}
var _triggered: bool = false
var _running: bool = false

signal event_started(event_id: String)
signal event_ended(event_id: String)
signal custom_action(action_type: String, action_data: Dictionary)

func try_trigger() -> bool:
	## 检查条件并尝试触发事件，返回是否成功
	if _running:
		return false
	if event_config.get("one_shot", true) and _triggered:
		return false
	if not _check_conditions():
		return false
	_triggered = true
	execute()
	return true

func _check_conditions() -> bool:
	var cond = event_config.get("conditions", {})
	if cond.is_empty():
		return true
	
	if cond.has("has_item"):
		if not InventoryManager.has_item(cond["has_item"]):
			return false
	
	if cond.has("no_item"):
		if InventoryManager.has_item(cond["no_item"]):
			return false
	
	if cond.has("flag"):
		if not GameManager.get_flag(cond["flag"]):
			return false
	
	if cond.has("no_flag"):
		if GameManager.get_flag(cond["no_flag"]):
			return false
	
	if cond.has("stamina_below"):
		if PlayerStats.stamina > cond["stamina_below"]:
			return false
	
	if cond.has("stamina_above"):
		if PlayerStats.stamina < cond["stamina_above"]:
			return false
	
	if cond.has("sanity_below"):
		if PlayerStats.sanity > cond["sanity_below"]:
			return false
	
	if cond.has("sanity_above"):
		if PlayerStats.sanity < cond["sanity_above"]:
			return false
	
	if cond.has("character_alive"):
		if not GameManager.is_character_alive(cond["character_alive"]):
			return false
	
	if cond.has("character_dead"):
		if GameManager.is_character_alive(cond["character_dead"]):
			return false
	
	return true

func execute() -> void:
	## 执行事件动作序列
	_running = true
	var event_id = event_config.get("id", "unknown")
	event_started.emit(event_id)
	
	var actions = event_config.get("actions", [])
	for action in actions:
		await _execute_action(action)
	
	_running = false
	event_ended.emit(event_id)

func _execute_action(action: Dictionary) -> void:
	var type: String = action.get("type", "")
	match type:
		"dialogue":
			var lines = action.get("lines", [])
			if lines.size() > 0:
				DialogueManager.start_dialogue(lines)
				await DialogueManager.dialogue_ended
		
		"sfx":
			var path = action.get("path", "")
			if path != "" and ResourceLoader.exists(path):
				AudioManager.play_sfx(load(path), action.get("volume", 0.0))
		
		"bgm":
			var path = action.get("path", "")
			if path == "":
				AudioManager.stop_bgm(action.get("fade", 1.0))
			elif ResourceLoader.exists(path):
				AudioManager.play_bgm(load(path), action.get("fade", 1.0))
		
		"ambience":
			var path = action.get("path", "")
			if path == "":
				AudioManager.stop_ambience()
			elif ResourceLoader.exists(path):
				AudioManager.play_ambience(load(path))
		
		"wait":
			await get_tree().create_timer(action.get("duration", 1.0)).timeout
		
		"set_flag":
			GameManager.set_flag(action.get("flag", ""), action.get("value", true))
		
		"give_item":
			InventoryManager.add_item(action.get("item_id", ""))
		
		"remove_item":
			InventoryManager.remove_item(action.get("item_id", ""))
		
		"apply_effect":
			var effects = action.get("effects", [])
			PlayerStats.apply_item_effects(effects)
		
		"screen_shake":
			_do_screen_shake(action.get("intensity", 5.0), action.get("duration", 0.5))
		
		"freeze_player":
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("freeze_player"):
				player.freeze_player()
		
		"unfreeze_player":
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("unfreeze_player"):
				player.unfreeze_player()
		
		"hint":
			# 需要关卡有 show_hint 方法
			var level = get_parent()
			if level and level.has_method("show_hint"):
				level.show_hint(action.get("text", ""), action.get("duration", 4.0))
		
		"reduce_sanity":
			PlayerStats.reduce_sanity(action.get("amount", 10.0))
		
		"restore_sanity":
			PlayerStats.restore_sanity(action.get("amount", 10.0))
		
		"change_stamina":
			PlayerStats.change_stamina(action.get("amount", 0.0))
		
		"cutscene":
			# 播放剧情演出（需要场景中有 CutscenePlayer）
			var cutscene_player = get_tree().get_first_node_in_group("cutscene_player")
			if not cutscene_player:
				cutscene_player = load("res://scripts/ui/cutscene_player.gd").new()
				cutscene_player.add_to_group("cutscene_player")
				get_tree().current_scene.add_child(cutscene_player)
			var steps = action.get("steps", [])
			var auto = action.get("auto", false)
			cutscene_player.play_cutscene(steps, auto)
			await cutscene_player.cutscene_finished
		
		_:
			# 未知类型交给关卡脚本处理（如 spawn_monster 等）
			custom_action.emit(type, action)

func _do_screen_shake(intensity: float, duration: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var original_offset = camera.offset
	var elapsed := 0.0
	while elapsed < duration:
		var dt = get_process_delta_time()
		elapsed += dt
		var strength = intensity * (1.0 - elapsed / duration)
		camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().process_frame
	camera.offset = original_offset
