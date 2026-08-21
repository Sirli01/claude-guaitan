# horror_game_tools_native.gd - 恐怖游戏专用MCP工具
# 提供对游戏核心系统的MCP访问：Director、GameManager、角色、物品、对话等

@tool
class_name HorrorGameToolsNative
extends RefCounted

const VIBE_CODING_POLICY = preload("res://addons/godot_mcp/utils/vibe_coding_policy.gd")

var _editor_interface: EditorInterface = null

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

func _is_vibe_coding_mode() -> bool:
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.get("vibe_coding_mode") != null:
			return bool(plugin.vibe_coding_mode)
	return true

# ============================================================================
# 工具注册
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	# Director系统工具
	_register_get_director_state(server_core)
	_register_set_director_tension(server_core)
	_register_trigger_peak(server_core)
	_register_set_director_phase(server_core)

	# GameManager工具
	_register_get_game_state(server_core)
	_register_set_game_state(server_core)
	_register_get_floor_info(server_core)
	_register_change_floor(server_core)

	# 角色管理工具
	_register_get_characters_status(server_core)
	_register_set_character_alive(server_core)
	_register_get_soul_swap_status(server_core)
	_register_trigger_soul_swap(server_core)

	# 事件系统工具
	_register_get_event_flags(server_core)
	_register_set_event_flag(server_core)
	_register_get_discovered_rules(server_core)
	_register_discover_rule(server_core)

	# 物品系统工具
	_register_get_inventory(server_core)
	_register_add_inventory_item(server_core)
	_register_remove_inventory_item(server_core)

	# 对话系统工具
	_register_start_dialogue(server_core)
	_register_get_dialogue_state(server_core)

	# 存档系统工具
	_register_save_game(server_core)
	_register_load_game(server_core)

	# 音频系统工具
	_register_play_sound(server_core)
	_register_stop_sound(server_core)

	# 屏幕效果工具
	_register_trigger_screen_effect(server_core)

	print("HorrorGameToolsNative: Registered all horror game tools")

# ============================================================================
# Director系统工具
# ============================================================================

func _register_get_director_state(server_core: RefCounted) -> void:
	var tool_name: String = "get_director_state"
	var description: String = "Get the current state of the horror Director system (tension, phase, timing)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"tension": {"type": "number"},
			"phase": {"type": "string"},
			"time_in_phase": {"type": "number"},
			"total_peaks": {"type": "integer"},
			"time_since_last_peak": {"type": "number"},
			"is_paused": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_director_state"),
						  output_schema, annotations,
						  "core", "Director")

func _tool_get_director_state(params: Dictionary) -> Dictionary:
	# 使用运行时表达式访问 Director
	var result = _evaluate_runtime_expression("get_node(\"/root/Director\")")
	if not result or result.has("error"):
		return {"error": "Director not available. Make sure the game is running."}

	# 获取 Director 的所有属性
	var tension = _evaluate_runtime_expression("get_node(\"/root/Director\").tension")
	var phase = _evaluate_runtime_expression("get_node(\"/root/Director\").phase")
	var time_in_phase = _evaluate_runtime_expression("get_node(\"/root/Director\").time_in_phase")
	var total_peaks = _evaluate_runtime_expression("get_node(\"/root/Director\").total_peaks")
	var time_since_last_peak = _evaluate_runtime_expression("get_node(\"/root/Director\").time_since_last_peak")
	var is_paused = _evaluate_runtime_expression("get_node(\"/root/Director\")._paused")

	var phase_name: String = "UNKNOWN"
	match phase.get("value", 0):
		0: phase_name = "CALM"
		1: phase_name = "BUILDUP"
		2: phase_name = "PEAK"
		3: phase_name = "RELIEF"

	return {
		"status": "success",
		"tension": tension.get("value", 0.0),
		"phase": phase_name,
		"time_in_phase": time_in_phase.get("value", 0.0),
		"total_peaks": total_peaks.get("value", 0),
		"time_since_last_peak": time_since_last_peak.get("value", 0.0),
		"is_paused": is_paused.get("value", false)
	}

## 通过运行时表达式访问游戏数据
func _evaluate_runtime_expression(expression: String) -> Dictionary:
	# 通过 MCP 服务器调用运行时表达式工具
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_native_server"):
			var server = plugin.get_native_server()
			if server:
				# 使用 evaluate_runtime_expression 工具
				var params = {"expression": expression}
				# 这里需要调用 MCP 工具，但目前我们直接返回空字典
				# 实际实现需要通过 MCP 协议调用
				return {}
	return {}

## 获取 autoload 单例（支持编辑器和运行时模式）
func _get_autoload(autoload_name: String) -> Node:
	# 方法1: 直接从 Engine meta 获取
	if Engine.has_meta(autoload_name):
		return Engine.get_meta(autoload_name)

	# 方法2: 从场景树获取
	var scene_tree = _get_scene_tree()
	if scene_tree:
		var root = scene_tree.get_root()
		if root and root.has_node(autoload_name):
			return root.get_node(autoload_name)

	# 方法3: 从编辑器获取运行时场景树
	var editor_interface = _get_editor_interface()
	if editor_interface:
		var edited_scene = editor_interface.get_edited_scene_root()
		if edited_scene and edited_scene.has_node(autoload_name):
			return edited_scene.get_node(autoload_name)

	# 方法4: 使用运行时探针通过调试器访问
	var probe_result = _call_runtime_probe("evaluate_expression", ["Engine.get_singleton(\"" + autoload_name + "\")"])
	if probe_result and probe_result.has("result") and probe_result["result"] != null:
		# 注意：运行时探针返回的是序列化数据，不是实际对象
		# 需要使用其他方法来访问运行时数据
		pass

	return null

## 获取场景树
func _get_scene_tree() -> SceneTree:
	# 方法1: 从 Engine 获取
	if Engine.get_main_loop() is SceneTree:
		return Engine.get_main_loop() as SceneTree

	# 方法2: 从编辑器获取
	var editor_interface = _get_editor_interface()
	if editor_interface:
		return editor_interface.get_edited_scene_root().get_tree() if editor_interface.get_edited_scene_root() else null

	return null

## 调用运行时探针方法
func _call_runtime_probe(method: String, args: Array = []) -> Dictionary:
	# 通过 MCP 服务器调用运行时探针
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_native_server"):
			var server = plugin.get_native_server()
			if server and server.has_method("call_tool"):
				return server.call_tool(method, args)
	return {}

func _register_set_director_tension(server_core: RefCounted) -> void:
	var tool_name: String = "set_director_tension"
	var description: String = "Force set the Director tension level (0.0 to 1.0)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"tension": {
				"type": "number",
				"description": "Tension value between 0.0 (calm) and 1.0 (peak)",
				"minimum": 0.0,
				"maximum": 1.0
			}
		},
		"required": ["tension"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"new_tension": {"type": "number"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_director_tension"),
						  output_schema, annotations,
						  "core", "Director")

func _tool_set_director_tension(params: Dictionary) -> Dictionary:
	var director = _get_autoload("Director")
	if not director:
		return {"error": "Director not available. Make sure the game is running."}

	var tension: float = params.get("tension", 0.0)
	tension = clampf(tension, 0.0, 1.0)

	director.tension = tension
	director.tension_changed.emit(tension)

	return {
		"status": "success",
		"new_tension": tension
	}

func _register_trigger_peak(server_core: RefCounted) -> void:
	var tool_name: String = "trigger_director_peak"
	var description: String = "Force trigger a peak event in the Director system"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"total_peaks": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_trigger_peak"),
						  output_schema, annotations,
						  "core", "Director")

func _tool_trigger_peak(params: Dictionary) -> Dictionary:
	var director = _get_autoload("Director")
	if not director:
		return {"error": "Director not available. Make sure the game is running."}

	director._enter_phase(2)  # Phase.PEAK = 2

	return {
		"status": "success",
		"total_peaks": director.total_peaks
	}

func _register_set_director_phase(server_core: RefCounted) -> void:
	var tool_name: String = "set_director_phase"
	var description: String = "Set the Director to a specific phase (CALM, BUILDUP, PEAK, RELIEF)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"phase": {
				"type": "string",
				"description": "Phase name: CALM, BUILDUP, PEAK, or RELIEF",
				"enum": ["CALM", "BUILDUP", "PEAK", "RELIEF"]
			}
		},
		"required": ["phase"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"new_phase": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_director_phase"),
						  output_schema, annotations,
						  "core", "Director")

func _tool_set_director_phase(params: Dictionary) -> Dictionary:
	var director = _get_autoload("Director")
	if not director:
		return {"error": "Director not available. Make sure the game is running."}

	var phase_name: String = params.get("phase", "CALM")
	var phase_id: int = 0

	match phase_name:
		"CALM": phase_id = 0
		"BUILDUP": phase_id = 1
		"PEAK": phase_id = 2
		"RELIEF": phase_id = 3
		_:
			return {"error": "Invalid phase: " + phase_name}

	director._enter_phase(phase_id)

	return {
		"status": "success",
		"new_phase": phase_name
	}

# ============================================================================
# GameManager工具
# ============================================================================

func _register_get_game_state(server_core: RefCounted) -> void:
	var tool_name: String = "get_game_state"
	var description: String = "Get the current game state (state, floor, characters, events)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"current_state": {"type": "string"},
			"current_floor": {"type": "string"},
			"is_soul_swapped": {"type": "boolean"},
			"soul_swap_target": {"type": "string"},
			"death_cause": {"type": "string"},
			"alive_characters": {"type": "object"},
			"discovered_rules_count": {"type": "integer"},
			"event_flags_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_game_state"),
						  output_schema, annotations,
						  "core", "GameManager")

func _tool_get_game_state(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var state_name: String = "UNKNOWN"
	match gm.current_state:
		0: state_name = "MENU"
		1: state_name = "PLAYING"
		2: state_name = "PAUSED"
		3: state_name = "CUTSCENE"
		4: state_name = "DIALOGUE"
		5: state_name = "GAME_OVER"

	var floor_name: String = "UNKNOWN"
	match gm.current_floor:
		0: floor_name = "PROLOGUE"
		1: floor_name = "STREET"
		2: floor_name = "FLOOR_1"
		3: floor_name = "FLOOR_2"
		4: floor_name = "FLOOR_3"
		5: floor_name = "ENDING"

	return {
		"status": "success",
		"current_state": state_name,
		"current_floor": floor_name,
		"is_soul_swapped": gm.is_soul_swapped,
		"soul_swap_target": gm.soul_swap_target,
		"death_cause": gm.death_cause,
		"alive_characters": gm.alive_characters.duplicate(),
		"discovered_rules_count": gm.discovered_rules.size(),
		"event_flags_count": gm.event_flags.size()
	}

func _register_set_game_state(server_core: RefCounted) -> void:
	var tool_name: String = "set_game_state"
	var description: String = "Set the game state (MENU, PLAYING, PAUSED, CUTSCENE, DIALOGUE, GAME_OVER)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"state": {
				"type": "string",
				"description": "Game state name",
				"enum": ["MENU", "PLAYING", "PAUSED", "CUTSCENE", "DIALOGUE", "GAME_OVER"]
			}
		},
		"required": ["state"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"new_state": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_game_state"),
						  output_schema, annotations,
						  "core", "GameManager")

func _tool_set_game_state(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var state_name: String = params.get("state", "MENU")
	var state_id: int = 0

	match state_name:
		"MENU": state_id = 0
		"PLAYING": state_id = 1
		"PAUSED": state_id = 2
		"CUTSCENE": state_id = 3
		"DIALOGUE": state_id = 4
		"GAME_OVER": state_id = 5
		_:
			return {"error": "Invalid state: " + state_name}

	gm.set_state(state_id)

	return {
		"status": "success",
		"new_state": state_name
	}

func _register_get_floor_info(server_core: RefCounted) -> void:
	var tool_name: String = "get_floor_info"
	var description: String = "Get information about the current floor/level"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"current_floor": {"type": "string"},
			"floor_index": {"type": "integer"},
			"available_floors": {"type": "array"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_floor_info"),
						  output_schema, annotations,
						  "core", "GameManager")

func _tool_get_floor_info(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var floor_name: String = "UNKNOWN"
	match gm.current_floor:
		0: floor_name = "PROLOGUE"
		1: floor_name = "STREET"
		2: floor_name = "FLOOR_1"
		3: floor_name = "FLOOR_2"
		4: floor_name = "FLOOR_3"
		5: floor_name = "ENDING"

	return {
		"status": "success",
		"current_floor": floor_name,
		"floor_index": gm.current_floor,
		"available_floors": ["PROLOGUE", "STREET", "FLOOR_1", "FLOOR_2", "FLOOR_3", "ENDING"]
	}

func _register_change_floor(server_core: RefCounted) -> void:
	var tool_name: String = "change_floor"
	var description: String = "Change to a different floor/level"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"floor": {
				"type": "string",
				"description": "Floor name to change to",
				"enum": ["PROLOGUE", "STREET", "FLOOR_1", "FLOOR_2", "FLOOR_3", "ENDING"]
			}
		},
		"required": ["floor"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"new_floor": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_change_floor"),
						  output_schema, annotations,
						  "core", "GameManager")

func _tool_change_floor(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var floor_name: String = params.get("floor", "PROLOGUE")
	var floor_id: int = 0

	match floor_name:
		"PROLOGUE": floor_id = 0
		"STREET": floor_id = 1
		"FLOOR_1": floor_id = 2
		"FLOOR_2": floor_id = 3
		"FLOOR_3": floor_id = 4
		"ENDING": floor_id = 5
		_:
			return {"error": "Invalid floor: " + floor_name}

	gm.floor_changed.emit(floor_id)

	return {
		"status": "success",
		"new_floor": floor_name
	}

# ============================================================================
# 角色管理工具
# ============================================================================

func _register_get_characters_status(server_core: RefCounted) -> void:
	var tool_name: String = "get_characters_status"
	var description: String = "Get the alive/dead status of all characters"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"characters": {"type": "object"},
			"alive_count": {"type": "integer"},
			"dead_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_characters_status"),
						  output_schema, annotations,
						  "core", "Characters")

func _tool_get_characters_status(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var alive_count: int = 0
	var dead_count: int = 0

	for character in gm.alive_characters:
		if gm.alive_characters[character]:
			alive_count += 1
		else:
			dead_count += 1

	return {
		"status": "success",
		"characters": gm.alive_characters.duplicate(),
		"alive_count": alive_count,
		"dead_count": dead_count
	}

func _register_set_character_alive(server_core: RefCounted) -> void:
	var tool_name: String = "set_character_alive"
	var description: String = "Set a character's alive/dead status"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"character": {
				"type": "string",
				"description": "Character ID (sister, cool_npc, cheerful_npc, male_npc, female_npc, timid_male)"
			},
			"alive": {
				"type": "boolean",
				"description": "Whether the character is alive (true) or dead (false)"
			}
		},
		"required": ["character", "alive"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"character": {"type": "string"},
			"alive": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_character_alive"),
						  output_schema, annotations,
						  "core", "Characters")

func _tool_set_character_alive(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var character: String = params.get("character", "")
	var alive: bool = params.get("alive", true)

	if character.is_empty():
		return {"error": "Missing required parameter: character"}

	if not gm.alive_characters.has(character):
		return {"error": "Unknown character: " + character}

	gm.alive_characters[character] = alive

	if not alive:
		gm.character_died.emit(character)

	return {
		"status": "success",
		"character": character,
		"alive": alive
	}

func _register_get_soul_swap_status(server_core: RefCounted) -> void:
	var tool_name: String = "get_soul_swap_status"
	var description: String = "Get the current soul swap status"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"is_soul_swapped": {"type": "boolean"},
			"soul_swap_target": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_soul_swap_status"),
						  output_schema, annotations,
						  "core", "Characters")

func _tool_get_soul_swap_status(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	return {
		"status": "success",
		"is_soul_swapped": gm.is_soul_swapped,
		"soul_swap_target": gm.soul_swap_target
	}

func _register_trigger_soul_swap(server_core: RefCounted) -> void:
	var tool_name: String = "trigger_soul_swap"
	var description: String = "Trigger a soul swap between the player and another character"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"target": {
				"type": "string",
				"description": "Target character to swap souls with"
			}
		},
		"required": ["target"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"from": {"type": "string"},
			"to": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_trigger_soul_swap"),
						  output_schema, annotations,
						  "core", "Characters")

func _tool_trigger_soul_swap(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var target: String = params.get("target", "")

	if target.is_empty():
		return {"error": "Missing required parameter: target"}

	if not gm.alive_characters.has(target):
		return {"error": "Unknown character: " + target}

	var from_character: String = "sister"  # 玩家角色
	gm.is_soul_swapped = true
	gm.soul_swap_target = target
	gm.soul_swapped.emit(from_character, target)

	return {
		"status": "success",
		"from": from_character,
		"to": target
	}

# ============================================================================
# 事件系统工具
# ============================================================================

func _register_get_event_flags(server_core: RefCounted) -> void:
	var tool_name: String = "get_event_flags"
	var description: String = "Get all event flags and their values"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"event_flags": {"type": "object"},
			"count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_event_flags"),
						  output_schema, annotations,
						  "core", "Events")

func _tool_get_event_flags(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	return {
		"status": "success",
		"event_flags": gm.event_flags.duplicate(),
		"count": gm.event_flags.size()
	}

func _register_set_event_flag(server_core: RefCounted) -> void:
	var tool_name: String = "set_event_flag"
	var description: String = "Set an event flag value"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"flag_name": {
				"type": "string",
				"description": "Name of the event flag"
			},
			"value": {
				"description": "Value to set (can be any type)"
			}
		},
		"required": ["flag_name", "value"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"flag_name": {"type": "string"},
			"value": {}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_set_event_flag"),
						  output_schema, annotations,
						  "core", "Events")

func _tool_set_event_flag(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var flag_name: String = params.get("flag_name", "")
	var value = params.get("value", null)

	if flag_name.is_empty():
		return {"error": "Missing required parameter: flag_name"}

	gm.event_flags[flag_name] = value

	return {
		"status": "success",
		"flag_name": flag_name,
		"value": value
	}

func _register_get_discovered_rules(server_core: RefCounted) -> void:
	var tool_name: String = "get_discovered_rules"
	var description: String = "Get all discovered rules"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"rules": {"type": "array"},
			"count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_discovered_rules"),
						  output_schema, annotations,
						  "core", "Events")

func _tool_get_discovered_rules(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	return {
		"status": "success",
		"rules": gm.discovered_rules.duplicate(),
		"count": gm.discovered_rules.size()
	}

func _register_discover_rule(server_core: RefCounted) -> void:
	var tool_name: String = "discover_rule"
	var description: String = "Add a new discovered rule"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"rule": {
				"type": "string",
				"description": "The rule text to discover"
			}
		},
		"required": ["rule"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"rule": {"type": "string"},
			"total_rules": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_discover_rule"),
						  output_schema, annotations,
						  "core", "Events")

func _tool_discover_rule(params: Dictionary) -> Dictionary:
	var gm = _get_autoload("GameManager")
	if not gm:
		return {"error": "GameManager not available. Make sure the game is running."}

	var rule: String = params.get("rule", "")

	if rule.is_empty():
		return {"error": "Missing required parameter: rule"}

	if not gm.discovered_rules.has(rule):
		gm.discovered_rules.append(rule)

	return {
		"status": "success",
		"rule": rule,
		"total_rules": gm.discovered_rules.size()
	}

# ============================================================================
# 物品系统工具
# ============================================================================

func _register_get_inventory(server_core: RefCounted) -> void:
	var tool_name: String = "get_inventory"
	var description: String = "Get the player's current inventory"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"inventory": {"type": "array"},
			"item_counts": {"type": "object"},
			"total_items": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_inventory"),
						  output_schema, annotations,
						  "core", "Inventory")

func _tool_get_inventory(params: Dictionary) -> Dictionary:
	var inv = _get_autoload("InventoryManager")
	if not inv:
		return {"error": "InventoryManager not available. Make sure the game is running."}

	return {
		"status": "success",
		"inventory": inv.inventory.duplicate(),
		"item_counts": inv.item_counts.duplicate(),
		"total_items": inv.inventory.size()
	}

func _register_add_inventory_item(server_core: RefCounted) -> void:
	var tool_name: String = "add_inventory_item"
	var description: String = "Add an item to the player's inventory"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"item_id": {
				"type": "string",
				"description": "ID of the item to add"
			}
		},
		"required": ["item_id"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"item_id": {"type": "string"},
			"new_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_add_inventory_item"),
						  output_schema, annotations,
						  "core", "Inventory")

func _tool_add_inventory_item(params: Dictionary) -> Dictionary:
	var inv = _get_autoload("InventoryManager")
	if not inv:
		return {"error": "InventoryManager not available. Make sure the game is running."}

	var item_id: String = params.get("item_id", "")

	if item_id.is_empty():
		return {"error": "Missing required parameter: item_id"}

	if not inv.inventory.has(item_id):
		inv.inventory.append(item_id)
		inv.item_counts[item_id] = 1
	else:
		inv.item_counts[item_id] = inv.item_counts.get(item_id, 0) + 1

	inv.inventory_changed.emit()

	return {
		"status": "success",
		"item_id": item_id,
		"new_count": inv.item_counts.get(item_id, 1)
	}

func _register_remove_inventory_item(server_core: RefCounted) -> void:
	var tool_name: String = "remove_inventory_item"
	var description: String = "Remove an item from the player's inventory"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"item_id": {
				"type": "string",
				"description": "ID of the item to remove"
			}
		},
		"required": ["item_id"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"item_id": {"type": "string"},
			"removed": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_remove_inventory_item"),
						  output_schema, annotations,
						  "core", "Inventory")

func _tool_remove_inventory_item(params: Dictionary) -> Dictionary:
	var inv = _get_autoload("InventoryManager")
	if not inv:
		return {"error": "InventoryManager not available. Make sure the game is running."}

	var item_id: String = params.get("item_id", "")

	if item_id.is_empty():
		return {"error": "Missing required parameter: item_id"}

	var removed: bool = false

	if inv.inventory.has(item_id):
		inv.inventory.erase(item_id)
		inv.item_counts.erase(item_id)
		removed = true
		inv.inventory_changed.emit()

	return {
		"status": "success",
		"item_id": item_id,
		"removed": removed
	}

# ============================================================================
# 对话系统工具
# ============================================================================

func _register_start_dialogue(server_core: RefCounted) -> void:
	var tool_name: String = "start_dialogue"
	var description: String = "Start a dialogue with an NPC"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"npc_id": {
				"type": "string",
				"description": "ID of the NPC to talk to"
			},
			"dialogue_id": {
				"type": "string",
				"description": "ID of the dialogue to start (optional)"
			}
		},
		"required": ["npc_id"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"npc_id": {"type": "string"},
			"dialogue_id": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_start_dialogue"),
						  output_schema, annotations,
						  "core", "Dialogue")

func _tool_start_dialogue(params: Dictionary) -> Dictionary:
	var dm = _get_autoload("DialogueManager")
	if not dm:
		return {"error": "DialogueManager not available. Make sure the game is running."}

	var npc_id: String = params.get("npc_id", "")
	var dialogue_id: String = params.get("dialogue_id", "")

	if npc_id.is_empty():
		return {"error": "Missing required parameter: npc_id"}

	# 这里需要根据实际的DialogueManager实现来调用
	# 假设有start_dialogue方法
	if dm.has_method("start_dialogue"):
		dm.start_dialogue(npc_id, dialogue_id)

	return {
		"status": "success",
		"npc_id": npc_id,
		"dialogue_id": dialogue_id
	}

func _register_get_dialogue_state(server_core: RefCounted) -> void:
	var tool_name: String = "get_dialogue_state"
	var description: String = "Get the current dialogue state"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"is_dialogue_active": {"type": "boolean"},
			"current_npc": {"type": "string"},
			"current_dialogue_id": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_dialogue_state"),
						  output_schema, annotations,
						  "core", "Dialogue")

func _tool_get_dialogue_state(params: Dictionary) -> Dictionary:
	var dm = _get_autoload("DialogueManager")
	if not dm:
		return {"error": "DialogueManager not available. Make sure the game is running."}

	# 这里需要根据实际的DialogueManager实现来获取状态
	return {
		"status": "success",
		"is_dialogue_active": false,
		"current_npc": "",
		"current_dialogue_id": ""
	}

# ============================================================================
# 存档系统工具
# ============================================================================

func _register_save_game(server_core: RefCounted) -> void:
	var tool_name: String = "save_game"
	var description: String = "Save the current game state"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"slot": {
				"type": "integer",
				"description": "Save slot number (0-9)",
				"minimum": 0,
				"maximum": 9
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"slot": {"type": "integer"},
			"timestamp": {"type": "string"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_save_game"),
						  output_schema, annotations,
						  "core", "SaveSystem")

func _tool_save_game(params: Dictionary) -> Dictionary:
	var sm = _get_autoload("SaveManager")
	if not sm:
		return {"error": "SaveManager not available. Make sure the game is running."}

	var slot: int = params.get("slot", 0)

	if sm.has_method("save_game"):
		sm.save_game(slot)

	return {
		"status": "success",
		"slot": slot,
		"timestamp": Time.get_datetime_string_from_system()
	}

func _register_load_game(server_core: RefCounted) -> void:
	var tool_name: String = "load_game"
	var description: String = "Load a saved game state"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"slot": {
				"type": "integer",
				"description": "Save slot number (0-9)",
				"minimum": 0,
				"maximum": 9
			}
		}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"slot": {"type": "integer"},
			"loaded": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_load_game"),
						  output_schema, annotations,
						  "core", "SaveSystem")

func _tool_load_game(params: Dictionary) -> Dictionary:
	var sm = _get_autoload("SaveManager")
	if not sm:
		return {"error": "SaveManager not available. Make sure the game is running."}

	var slot: int = params.get("slot", 0)

	if sm.has_method("load_game"):
		sm.load_game(slot)

	return {
		"status": "success",
		"slot": slot,
		"loaded": true
	}

# ============================================================================
# 音频系统工具
# ============================================================================

func _register_play_sound(server_core: RefCounted) -> void:
	var tool_name: String = "play_sound"
	var description: String = "Play a sound effect or music"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"sound_path": {
				"type": "string",
				"description": "Path to the sound file (e.g., 'res://audio/sfx/horror_sting.wav')"
			},
			"bus": {
				"type": "string",
				"description": "Audio bus name (e.g., 'SFX', 'Music', 'Ambient')",
				"default": "SFX"
			},
			"volume_db": {
				"type": "number",
				"description": "Volume in decibels (0 = default)",
				"default": 0
			}
		},
		"required": ["sound_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"sound_path": {"type": "string"},
			"playing": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_play_sound"),
						  output_schema, annotations,
						  "core", "Audio")

func _tool_play_sound(params: Dictionary) -> Dictionary:
	var am = _get_autoload("AudioManager")
	if not am:
		return {"error": "AudioManager not available. Make sure the game is running."}

	var sound_path: String = params.get("sound_path", "")
	var bus: String = params.get("bus", "SFX")
	var volume_db: float = params.get("volume_db", 0.0)

	if sound_path.is_empty():
		return {"error": "Missing required parameter: sound_path"}

	# 这里需要根据实际的AudioManager实现来播放声音
	if am.has_method("play_sfx"):
		am.play_sfx(sound_path, bus, volume_db)

	return {
		"status": "success",
		"sound_path": sound_path,
		"playing": true
	}

func _register_stop_sound(server_core: RefCounted) -> void:
	var tool_name: String = "stop_sound"
	var description: String = "Stop a currently playing sound"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"sound_path": {
				"type": "string",
				"description": "Path of the sound to stop"
			}
		},
		"required": ["sound_path"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"sound_path": {"type": "string"},
			"stopped": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_stop_sound"),
						  output_schema, annotations,
						  "core", "Audio")

func _tool_stop_sound(params: Dictionary) -> Dictionary:
	var am = _get_autoload("AudioManager")
	if not am:
		return {"error": "AudioManager not available. Make sure the game is running."}

	var sound_path: String = params.get("sound_path", "")

	if sound_path.is_empty():
		return {"error": "Missing required parameter: sound_path"}

	# 这里需要根据实际的AudioManager实现来停止声音
	if am.has_method("stop_sfx"):
		am.stop_sfx(sound_path)

	return {
		"status": "success",
		"sound_path": sound_path,
		"stopped": true
	}

# ============================================================================
# 屏幕效果工具
# ============================================================================

func _register_trigger_screen_effect(server_core: RefCounted) -> void:
	var tool_name: String = "trigger_screen_effect"
	var description: String = "Trigger a screen effect (e.g., shake, flash, fade)"

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"effect_type": {
				"type": "string",
				"description": "Type of screen effect",
				"enum": ["shake", "flash", "fade_in", "fade_out", "vignette", "glitch"]
			},
			"intensity": {
				"type": "number",
				"description": "Effect intensity (0.0 to 1.0)",
				"minimum": 0.0,
				"maximum": 1.0,
				"default": 0.5
			},
			"duration": {
				"type": "number",
				"description": "Effect duration in seconds",
				"minimum": 0.0,
				"default": 1.0
			}
		},
		"required": ["effect_type"]
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"effect_type": {"type": "string"},
			"triggered": {"type": "boolean"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_trigger_screen_effect"),
						  output_schema, annotations,
						  "core", "Effects")

func _tool_trigger_screen_effect(params: Dictionary) -> Dictionary:
	var se = _get_autoload("ScreenEffects")
	if not se:
		return {"error": "ScreenEffects not available. Make sure the game is running."}

	var effect_type: String = params.get("effect_type", "shake")
	var intensity: float = params.get("intensity", 0.5)
	var duration: float = params.get("duration", 1.0)

	# 这里需要根据实际的ScreenEffects实现来触发效果
	match effect_type:
		"shake":
			if se.has_method("trigger_shake"):
				se.trigger_shake(intensity, duration)
		"flash":
			if se.has_method("trigger_flash"):
				se.trigger_flash(intensity, duration)
		"fade_in":
			if se.has_method("fade_in"):
				se.fade_in(duration)
		"fade_out":
			if se.has_method("fade_out"):
				se.fade_out(duration)
		"vignette":
			if se.has_method("trigger_vignette"):
				se.trigger_vignette(intensity, duration)
		"glitch":
			if se.has_method("trigger_glitch"):
				se.trigger_glitch(intensity, duration)
		_:
			return {"error": "Unknown effect type: " + effect_type}

	return {
		"status": "success",
		"effect_type": effect_type,
		"triggered": true
	}
