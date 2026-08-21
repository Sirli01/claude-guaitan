extends Node2D
## 第二层→第三层 电梯内部场景（无耳塞分支，鹿可被拽入后）

# === 可调节参数 ===
const ELEV_SCALE_FACTOR: float = 1.2      # 电梯贴图额外缩放倍率
const ELEV_OFFSET: Vector2 = Vector2(0, 0) # 电梯贴图位置偏移

var _cam: Camera2D
var _shaking: bool = false
var _heel_sfx: AudioStream

func _input(event: InputEvent) -> void:
	if DialogueManager.is_dialogue_active:
		if event.is_action_pressed("dialogue_advance") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
			get_viewport().set_input_as_handled()

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	AudioManager.stop_playlist(0.05)
	AudioManager.stop_ambience()
	AudioManager.bgm_player.stop()

	# 生成高跟鞋音效
	var sfx_gen = preload("res://scripts/utils/procedural_sfx.gd")
	_heel_sfx = sfx_gen.high_heel_step()

	_build_elevator_interior()

	var dlg_scene = load("res://scenes/ui/dialogue_ui.tscn")
	add_child(dlg_scene.instantiate())

	await get_tree().create_timer(1.0).timeout
	_start_sequence()

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

	# 天花板灯
	var light = PointLight2D.new()
	light.position = Vector2(0, -70 * S * 2)
	light.color = Color(0.85, 0.8, 0.65)
	light.energy = 0.7
	light.texture_scale = 1.8 * S * 2
	light.texture = _create_light_texture()
	add_child(light)

	# 存活角色（无耳塞分支：余凡、沈薇已死）
	_create_character(Vector2(-5 * S * 2, 40 * S * 2), "sister")
	_create_character(Vector2(-40 * S * 2, 35 * S * 2), "cool_npc")
	_create_character(Vector2(30 * S * 2, 38 * S * 2), "cheerful_npc")
	_create_character(Vector2(-30 * S * 2, 10 * S * 2), "male_npc")

	# 摄像机
	_cam = Camera2D.new()
	_cam.position = Vector2(0, 0)
	_cam.zoom = Vector2(3.5 / S, 3.5 / S)
	_cam.make_current()
	add_child(_cam)

func _process(_delta: float) -> void:
	if _shaking and _cam:
		_cam.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

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

func _add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var r = ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	add_child(r)

func _create_character(pos: Vector2, char_id: String) -> Node2D:
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

func _create_light_texture() -> ImageTexture:
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var center = Vector2(64, 64)
	for x in 128:
		for y in 128:
			var dist = Vector2(x, y).distance_to(center) / 64.0
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)
