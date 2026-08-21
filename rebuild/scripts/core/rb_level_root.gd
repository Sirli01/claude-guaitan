class_name RbLevelRoot
extends Node2D
## rebuild 关卡根节点 —— 唯一的"装配者"。
##
## 职责：
## 1. 把玩家放到正确的出生点（移动已有节点，不创建节点）；
## 2. 把交互物的信号接到对话推进器 / 场景加载器；
## 3. 把对话推进器的信号接到 UI；
## 4. 处理返回主菜单。
##
## 它不创建 UI、不创建玩家、不创建房间——这些都在 .tscn 中搭好。
## 所有节点引用都是从自身出发的确定路径，没有 "../../.." 这种写法。

## 关卡标识，用于日志与后续存档。
@export var level_id: String = ""
## 没有指定出生点时使用的 Marker2D 名称。
@export var default_spawn_id: String = "default"
## 进入关卡后自动播放的对话 id，留空表示不播。
@export var intro_dialogue_id: String = ""
## 按 ESC 返回的场景 key。
@export var escape_scene_key: String = RbSceneRegistry.MAIN_MENU

@onready var world: Node2D = $World
@onready var props: Node2D = $World/Props
@onready var player: RbPlayerController = $World/Actors/Player
@onready var spawn_points: Node2D = $SpawnPoints
@onready var dialogue_runner: RbDialogueRunner = $DialogueRunner
@onready var game_ui: RbGameUi = $GameUi

## 正在等待处理的场景切换请求，避免一帧内触发多次。
var _scene_change_pending: bool = false


func _ready() -> void:
	RbGameState.set_state(RbGameState.State.PLAYING)
	_place_player()
	_bind_player()
	_bind_dialogue_runner()
	_bind_interactables(world)

	if intro_dialogue_id != "":
		_start_dialogue(intro_dialogue_id)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if dialogue_runner.is_active():
		# 对话中按 ESC 先结束对话，不直接退出关卡。
		dialogue_runner.stop()
		get_viewport().set_input_as_handled()
		return
	if not RbGameState.is_gameplay_active():
		return
	get_viewport().set_input_as_handled()
	_request_scene_change(escape_scene_key, "")


# ---------------------------------------------------------------- 装配

func _place_player() -> void:
	var spawn_id: String = RbGameState.consume_pending_spawn_id()
	if spawn_id == "":
		spawn_id = default_spawn_id

	var marker := spawn_points.get_node_or_null(NodePath(spawn_id)) as Marker2D
	if marker == null:
		push_warning("[RbLevelRoot] 关卡 %s 找不到出生点 '%s'，玩家保持场景中的默认位置" % [level_id, spawn_id])
		return
	player.global_position = marker.global_position


func _bind_player() -> void:
	var sensor: RbInteractionSensor = player.interaction_sensor
	sensor.target_changed.connect(_on_interact_target_changed)
	sensor.interact_requested.connect(_on_interact_requested)


func _bind_dialogue_runner() -> void:
	dialogue_runner.dialogue_started.connect(_on_dialogue_started)
	dialogue_runner.line_changed.connect(_on_dialogue_line_changed)
	dialogue_runner.dialogue_finished.connect(_on_dialogue_finished)


## 递归扫描关卡世界层，把交互物接进来。
## 只扫描 world 子树，不使用全局 group，作用域明确。
func _bind_interactables(node: Node) -> void:
	for child: Node in node.get_children():
		var interactable := child as RbInteractable
		if interactable != null:
			interactable.dialogue_requested.connect(_on_dialogue_requested)
			var door := interactable as RbDoor
			if door != null:
				door.scene_change_requested.connect(_on_scene_change_requested)
		_bind_interactables(child)


# ---------------------------------------------------------------- 交互

func _on_interact_target_changed(target: RbInteractable) -> void:
	if dialogue_runner.is_active() or _scene_change_pending:
		game_ui.hide_interact_prompt()
		return
	if target == null:
		game_ui.hide_interact_prompt()
		return
	game_ui.show_interact_prompt(target.prompt_text)


func _on_interact_requested(target: RbInteractable) -> void:
	if _scene_change_pending:
		return
	target.interact(player)


# ---------------------------------------------------------------- 对话

func _on_dialogue_requested(dialogue_id: String) -> void:
	_start_dialogue(dialogue_id)


func _start_dialogue(dialogue_id: String) -> void:
	if not dialogue_runner.start(dialogue_id):
		return


func _on_dialogue_started(_dialogue_id: String) -> void:
	RbGameState.set_state(RbGameState.State.DIALOGUE)
	player.set_movement_enabled(false)
	game_ui.hide_interact_prompt()
	game_ui.open_dialogue()


func _on_dialogue_line_changed(speaker: String, text: String, index: int, total: int) -> void:
	game_ui.display_dialogue_line(speaker, text, index, total)


func _on_dialogue_finished(_dialogue_id: String) -> void:
	game_ui.close_dialogue()
	if _scene_change_pending:
		return
	RbGameState.set_state(RbGameState.State.PLAYING)
	player.set_movement_enabled(true)
	player.interaction_sensor.force_refresh()


# ---------------------------------------------------------------- 场景切换

func _on_scene_change_requested(scene_key: String, spawn_id: String) -> void:
	_request_scene_change(scene_key, spawn_id)


func _request_scene_change(scene_key: String, spawn_id: String) -> void:
	if _scene_change_pending:
		return
	if dialogue_runner.is_active():
		dialogue_runner.stop()

	_scene_change_pending = true
	game_ui.hide_interact_prompt()
	player.set_movement_enabled(false)

	if not RbSceneLoader.change_to(self, scene_key, spawn_id):
		# 切换失败则恢复可玩状态，不要把玩家卡死。
		_scene_change_pending = false
		player.set_movement_enabled(true)
		RbGameState.set_state(RbGameState.State.PLAYING)
