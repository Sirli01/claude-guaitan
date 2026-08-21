extends Node2D
## 电梯内部场景 — 第三层离开时的电梯对话

# === 可调节参数 ===
const ELEV_SCALE_FACTOR: float = 1.2      # 电梯贴图额外缩放倍率
const ELEV_OFFSET: Vector2 = Vector2(0, 0) # 电梯贴图位置偏移

var _cam: Camera2D
var _shaking: bool = false
var _monster_alive: bool = false
var cool_npc: Node2D
var cheerful_npc: Node2D

func _input(event: InputEvent) -> void:
	# 电梯场景没有player，需要自己处理对话推进
	if DialogueManager.is_dialogue_active:
		if event.is_action_pressed("dialogue_advance") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)

	# 从 event_flags 读取怪物是否存活
	_monster_alive = GameManager.event_flags.get("floor3_monster_alive", true)

	_build_elevator_interior()

	# 加载对话UI（必须！否则看不到台词）
	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	var dialogue_layer = dlg_scene.instantiate()
	add_child(dialogue_layer)

	# 等待TransitionManager淡入完成后再开始对话
	await get_tree().create_timer(1.5).timeout
	_start_elevator_dialogue()

func _build_elevator_interior() -> void:
	const S := 5.0
	# 电梯场景贴图
	var elevator_tex = load("res://assets/sprites/电梯.png")
	var elev_scale = 140.0 / elevator_tex.get_width() * S * ELEV_SCALE_FACTOR
	var elevator_sprite = Sprite2D.new()
	elevator_sprite.texture = elevator_tex
	elevator_sprite.centered = true
	elevator_sprite.position = ELEV_OFFSET
	elevator_sprite.scale = Vector2(elev_scale * 2, elev_scale * 2)
	elevator_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(elevator_sprite)

	# 天花板灯光（微弱）
	var ceiling_light = PointLight2D.new()
	ceiling_light.position = Vector2(0, -70 * S * 2)
	ceiling_light.color = Color(0.85, 0.8, 0.65)
	ceiling_light.energy = 0.7
	ceiling_light.texture_scale = 1.8 * S * 2
	ceiling_light.texture = _create_light_texture()
	add_child(ceiling_light)

	# 角色（NPC站在电梯里）
	var sister_vis = _create_simple_character(Vector2(-5 * S * 2, 40 * S * 2), "sister", Color(0.9, 0.7, 0.6))
	cool_npc = _create_simple_character(Vector2(-40 * S * 2, 35 * S * 2), "cool_npc", Color(0.4, 0.5, 0.7))
	cheerful_npc = _create_simple_character(Vector2(30 * S * 2, 38 * S * 2), "cheerful_npc", Color(0.9, 0.6, 0.5))

	# 摄像机
	_cam = Camera2D.new()
	_cam.position = Vector2(0, 0)
	_cam.zoom = Vector2(3.5 / S, 3.5 / S)
	_cam.make_current()
	add_child(_cam)

func _process(_delta: float) -> void:
	if _shaking and _cam:
		_cam.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

func _create_simple_character(pos: Vector2, char_id: String, _color: Color) -> Node2D:
	const S := 5.0
	var node = Node2D.new()
	node.position = pos
	add_child(node)

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

	return node

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

func _monster_dead_route() -> void:
	# 怪物已消灭——平静版
	await get_tree().create_timer(0.5).timeout

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_dead_reflection"))
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.5).timeout

	DialogueManager.start_dialogue(StoryText.lines("ending", "elevator_dead_descent"))
	await DialogueManager.dialogue_ended

func _create_light_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center = Vector2(64, 64)
	for x in 128:
		for y in 128:
			var dist = Vector2(x, y).distance_to(center) / 64.0
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)
