extends Node2D
## 第二层→第三层 电梯内部场景（无耳塞分支，鹿可被拽入后）

# === 可调节参数 ===
const ELEV_SCALE_FACTOR: float = 1.2      # 电梯贴图额外缩放倍率（场景中已烘焙，保留供参考）

var _cam: Camera2D
var _shaking: bool = false
var _heel_sfx: AudioStream

## 本场景无玩家节点，自行处理对话推进输入。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	if DialogueManager.is_dialogue_active:
		if event.is_action_pressed("dialogue_advance") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()

## 初始化：停止音乐、生成高跟鞋音效、绑定角色并启动演出序列。
func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	AudioManager.stop_playlist(0.05)
	AudioManager.stop_ambience()
	AudioManager.bgm_player.stop()

	# 生成高跟鞋音效
	var sfx_gen = preload("res://scripts/utils/procedural_sfx.gd")
	_heel_sfx = sfx_gen.high_heel_step()

	# 绑定场景中的角色贴图与名牌（节点结构已在 .tscn 中定义）
	_setup_characters()
	_cam = %Camera
	_cam.make_current()

	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	add_child(dlg_scene.instantiate())

	await get_tree().create_timer(1.0).timeout
	_start_sequence()

## 为场景中的角色占位节点绑定贴图与名牌。
func _setup_characters() -> void:
	for entry in [["CharSister", "sister"], ["CharCool", "cool_npc"], ["CharCheerful", "cheerful_npc"], ["CharMale", "male_npc"]]:
		_setup_character(get_node("%" + entry[0]), entry[1])

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

## 主演出流程：震颤、高跟鞋砸地、丢失物品与上升对话，最后转入第三层。
func _start_sequence() -> void:
	# 刚拉进电梯的瞬间——电梯震颤
	await _shake_elevator(0.4, 3.0)

	# 高跟鞋砸地！
	AudioManager.play_sfx(_heel_sfx, 2.0)
	ScreenEffects.death_impact()
	InputDevice.vibrate_heavy()
	await _shake_elevator(0.6, 5.0)

	await get_tree().create_timer(0.3).timeout

	var item_loss_dialogue := _build_item_loss_dialogue()
	if not item_loss_dialogue.is_empty():
		DialogueManager.start_dialogue(item_loss_dialogue)
		await DialogueManager.dialogue_ended
		await get_tree().create_timer(0.2).timeout

	DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_aftermath"))
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.5).timeout

	# 公共电梯上升对话
	AudioManager.play_sfx(load("res://assets/audio/sfx/电梯运行声.wav"), 0.0)
	_shaking = true
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_up"))
	await DialogueManager.dialogue_ended
	_shaking = false
	_cam.offset = Vector2.ZERO

	# 电梯到达
	AudioManager.play_sfx(load("res://assets/audio/sfx/电梯到达声.mp3"), 0.0)
	await get_tree().create_timer(1.0).timeout
	TransitionManager.transition_to_scene("res://scenes/levels/floor_3.tscn")

## 根据待丢失物品列表按当前语言构造丢失物品对话。
## [return] 对话行数组，无丢失物品时为空数组。
func _build_item_loss_dialogue() -> Array:
	var lost_items: Array[String] = GameManager.pending_item_loss.duplicate()
	GameManager.pending_item_loss.clear()
	if lost_items.is_empty():
		return []

	var display_names: Array[String] = []
	for item_id in lost_items:
		var item_name: String = InventoryManager.get_item_data(item_id).get("name", item_id)
		display_names.append(item_name)

	var text := ""
	match LocaleManager.current_locale:
		"en":
			if display_names.size() == 1:
				text = "In the chaos, you lost \"%s\"." % display_names[0]
			else:
				text = "In the chaos, you lost \"%s\" and \"%s\"." % [display_names[0], display_names[1]]
		"ja":
			if display_names.size() == 1:
				text = "混乱の中で、「%s」をなくしてしまった。" % display_names[0]
			else:
				text = "混乱の中で、「%s」と「%s」をなくしてしまった。" % [display_names[0], display_names[1]]
		_:
			if display_names.size() == 1:
				text = "混乱中，你弄丢了「%s」。" % display_names[0]
			else:
				text = "混乱中，你弄丢了「%s」和「%s」。" % [display_names[0], display_names[1]]
	return [GameManager.say("", text)]

## 电梯震颤效果
func _shake_elevator(duration: float, intensity: float) -> void:
	var original_pos = _cam.position
	var elapsed := 0.0
	while elapsed < duration:
		var offset = Vector2(randf_range(-intensity * 2, intensity * 2), randf_range(-intensity * 2, intensity * 2))
		_cam.position = original_pos + offset
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_cam.position = original_pos

