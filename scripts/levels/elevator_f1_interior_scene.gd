extends Node2D
## 第一层→第二层 电梯内部场景

# === 可调节参数 ===
const ELEV_SCALE_FACTOR: float = 1.2      # 电梯贴图额外缩放倍率（场景中已烘焙，保留供参考）

var _cam: Camera2D
var _shaking: bool = false

## 本场景无玩家节点，自行处理对话推进输入。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if DialogueManager.is_dialogue_active:
		if event.is_action_pressed("dialogue_advance") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()

## 初始化：设置演出状态、绑定角色、加载对话UI并启动电梯对话。
func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)

	# 绑定场景中的角色贴图与名牌（节点结构已在 .tscn 中定义）
	_setup_characters()
	_cam = %Camera
	_cam.make_current()

	# 加载对话UI
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	add_child(dlg_scene.instantiate())

	# 等TransitionManager淡入完成
	await get_tree().create_timer(1.5).timeout
	_start_dialogue()

## 为场景中的角色占位节点绑定贴图与名牌。
func _setup_characters() -> void:
	for entry in [["CharSister", "sister"], ["CharCool", "cool_npc"], ["CharCheerful", "cheerful_npc"], ["CharMale", "male_npc"], ["CharFemale", "female_npc"], ["CharTimid", "timid_male"]]:
		_setup_character(get_node("%" + entry[0]), entry[1])

## 配置单个角色：加载朝下贴图、按电梯比例放大并添加名牌。
## 电梯内部世界为 v1 尺度，角色贴图已全局放大 2 倍，故额外乘 0.5 抵消。
## [param node] 角色占位节点。[param char_id] 角色ID。
func _setup_character(node: Node2D, char_id: String) -> void:
	const S := 5.0
	const CHAR_SCALE := 0.5
	var sprite = Sprite2D.new()
	var down_path = GameConfig.CHARACTER_SPRITES.get(char_id, "")
	var up_path = down_path.replace("idle_down", "idle_up") if down_path != "" else ""
	if up_path != "" and ResourceLoader.exists(up_path):
		sprite.texture = load(up_path)
	else:
		sprite.texture = GameManager.load_char_texture(char_id, 14, 18)
	GameManager.fit_character_sprite(sprite, char_id)
	sprite.scale *= S * CHAR_SCALE
	node.add_child(sprite)

	var display_name = GameManager.NAMES.get(char_id, char_id)
	var label = Label.new()
	label.text = display_name
	label.position = Vector2(-14 * S * 2, (-GameManager.get_character_visual_height(char_id) * CHAR_SCALE - 8.0) * S * 2)
	label.add_theme_font_size_override("font_size", int(5 * S * 2))
	label.add_theme_color_override("font_color", GameManager.CHAR_COLORS.get(char_id, Color.WHITE).lightened(0.3))
	node.add_child(label)

## 电梯震动期间随机抖动摄像机偏移。
## [param _delta] 帧间隔（未使用）。
func _process(_delta: float) -> void:
	if _shaking and _cam:
		_cam.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

## 播放电梯运行声与震动、执行一层→二层对话，到达后转入第二层场景。
func _start_dialogue() -> void:
	# 电梯运行声 + 轻微震动
	AudioManager.play_sfx(load("res://assets/audio/sfx/电梯运行声.wav"), 0.0)
	_shaking = true
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "elevator"))
	await DialogueManager.dialogue_ended

	# 电梯到达，停止震动
	_shaking = false
	_cam.offset = Vector2.ZERO
	AudioManager.play_sfx(load("res://assets/audio/sfx/电梯到达声.mp3"), 0.0)
	await get_tree().create_timer(0.5).timeout
	TransitionManager.transition_to_scene("res://scenes/levels/floor_2.tscn")

