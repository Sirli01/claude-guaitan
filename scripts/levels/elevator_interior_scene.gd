extends Node2D
## 电梯内部场景 — 第三层离开时的电梯对话

var _cam: Camera2D
var _shaking: bool = false
var _monster_alive: bool = false
var cool_npc: Node2D
var cheerful_npc: Node2D

## 电梯贴图额外缩放倍率（场景中已烘焙，保留供参考）
const ELEV_SCALE_FACTOR: float = 1.2

## 本场景无玩家节点，自行处理对话推进输入。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	# 电梯场景没有player，需要自己处理对话推进
	if DialogueManager.is_dialogue_active:
		if event.is_action_pressed("dialogue_advance") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()

## 初始化：设置演出状态、绑定角色、加载对话UI并启动电梯剧情。
func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)

	# 从 event_flags 读取怪物是否存活
	_monster_alive = GameManager.event_flags.get("floor3_monster_alive", true)

	# 绑定场景中的角色贴图与名牌（节点结构已在 .tscn 中定义）
	_setup_characters()
	_cam = %Camera
	_cam.make_current()

	# 加载对话UI（必须！否则看不到台词）
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var dialogue_layer = dlg_scene.instantiate()
	add_child(dialogue_layer)

	# 等待TransitionManager淡入完成后再开始对话
	await get_tree().create_timer(1.5).timeout
	_start_elevator_dialogue()

## 为场景中的角色占位节点绑定贴图与名牌。
func _setup_characters() -> void:
	_setup_character(%CharSister, "sister")
	_setup_character(%CharCool, "cool_npc")
	cool_npc = %CharCool
	_setup_character(%CharCheerful, "cheerful_npc")
	cheerful_npc = %CharCheerful

## 配置单个角色：加载朝下贴图、按电梯比例放大并添加名牌。
## [param node] 角色占位节点。[param char_id] 角色ID。
func _setup_character(node: Node2D, char_id: String) -> void:
	const S := 5.0
	var sprite = Sprite2D.new()
	var down_path = GameConfig.CHARACTER_SPRITES.get(char_id, "")
	var up_path = down_path.replace("idle_down", "idle_up") if down_path != "" else ""
	if up_path != "" and ResourceLoader.exists(up_path):
		sprite.texture = load(up_path)
	else:
		sprite.texture = GameManager.load_char_texture(char_id, 14, 18)
	GameManager.fit_character_sprite(sprite, char_id)
	sprite.scale *= S
	node.add_child(sprite)

	var display_name = GameManager.NAMES.get(char_id, char_id)
	var label = Label.new()
	label.text = display_name
	label.position = Vector2(-14 * S * 2, (-GameManager.get_character_visual_height(char_id) - 8.0) * S * 2)
	label.add_theme_font_size_override("font_size", int(5 * S * 2))
	label.add_theme_color_override("font_color", GameManager.CHAR_COLORS.get(char_id, Color.WHITE).lightened(0.3))
	node.add_child(label)

## 电梯震动期间随机抖动摄像机偏移。
## [param _delta] 帧间隔（未使用）。
func _process(_delta: float) -> void:
	if _shaking and _cam:
		_cam.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

## 播放电梯运行声与震动，按怪物存活与否走对应分支，最后转入结局场景。
func _start_elevator_dialogue() -> void:
	# 电梯运行声
	AudioManager.play_sfx(load("res://assets/audio/sfx/电梯运行声.wav"), 0.0)
	_shaking = true
	if _monster_alive:
		await _monster_alive_route()
	else:
		await _monster_dead_route()
	_shaking = false
	_cam.offset = Vector2.ZERO

	await get_tree().create_timer(0.5).timeout
	TransitionManager.transition_to_scene("res://scenes/levels/ending.tscn")

## 怪物存活分支：撞击声+三段紧张对话。
func _monster_alive_route() -> void:
	# 怪物还在追——紧张版
	await get_tree().create_timer(0.3).timeout

	# 撞门声
	AudioManager.play_sfx(preload("res://scripts/utils/procedural_sfx.gd").ground_rumble(), 0.0)
	ScreenEffects.hit_impact()

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_alive_impact"))
	await DialogueManager.dialogue_ended

	# 第二次撞击（更轻）
	await get_tree().create_timer(0.8).timeout
	ScreenEffects.shake(4.0, 0.3)
	InputDevice.vibrate_rumble(0.4)

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_alive_relief"))
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.5).timeout

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_alive_descent"))
	await DialogueManager.dialogue_ended

## 怪物已被消灭分支：两段平静对话。
func _monster_dead_route() -> void:
	# 怪物已消灭——平静版
	await get_tree().create_timer(0.5).timeout

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_dead_reflection"))
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.5).timeout

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_dead_descent"))
	await DialogueManager.dialogue_ended

