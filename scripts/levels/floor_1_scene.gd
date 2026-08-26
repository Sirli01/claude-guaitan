extends LevelBaseV2
## 第一层 - 诡异初现与致命伏笔
## 规则："23:00 - 07:00，禁止对视"
## 核心事件：女伴被镜子吸引对视→灵魂互换伏笔→找电梯卡→电梯只能向上

# ====== 预加载资源 ======
const _SFX_BLACKOUT := preload("res://assets/audio/sfx/断电.mp3")

# NPC引用
var cool_npc: CharacterBody2D      # 高冷NPC
var cheerful_npc: CharacterBody2D  # 开朗NPC
var male_npc: CharacterBody2D      # 男伴
var female_npc: CharacterBody2D    # 女伴
var timid_npc: CharacterBody2D     # 胆小男

var elevator_card_found: bool = false
var _event_23_triggered: bool = false
var _elevator_door: GameElevatorDoor = null  # .tscn 中的电梯门引用
var _corridor_lights: Array[PointLight2D] = []
var _door_leak_lights: Array[PointLight2D] = []

const FLOOR_1_WANDER_POINTS := [
	Vector2(-760, 636),
	Vector2(-600, 644),
	Vector2(-440, 636),
	Vector2(-280, 644),
	Vector2(-80, 636),
	Vector2(120, 644),
	Vector2(320, 636),
	Vector2(420, 636),
	Vector2(420, 450),
	Vector2(420, 280),
	Vector2(420, 120),
	Vector2(240, 110),
	Vector2(40, 110),
	Vector2(-160, 110),
	Vector2(-360, 90),
	Vector2(-420, -70),
	Vector2(-420, -250),
	Vector2(-220, -260),
	Vector2(20, -260),
	Vector2(280, -260),
	Vector2(560, -260),
	Vector2(680, -260),
]

## 第一层初始化：设置楼层状态、收集灯光与电梯门引用、布置NPC并启动入场剧情链。
func _ready() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.change_floor(GameManager.Floor.FLOOR_1)
	AudioManager.exit_silence_mode()  # 解除街道→公寓的静音状态
	
	# 静态几何体（墙壁、地板、家具、灯光）从 .tscn 加载
	discover_scene_nodes()
	# 构建房间系统：房间墙/门/天花板/标签（v1 设计，坐标 ×2 适配当前世界）
	_build_room_system()
	# 收集 .tscn 中的走廊灯光引用（停电事件需要控制）
	for child in get_children():
		if child is PointLight2D and child.name.begins_with("Corridor"):
			_corridor_lights.append(child)
	# 收集 .tscn 中的电梯门引用
	for child in get_children():
		if child is GameElevatorDoor and not child.is_arrival:
			_elevator_door = child
	# 动态灯光效果（闪烁灯、灰尘、门缝漏光）
	_place_dynamic_lights()
	camera_bounds = Rect2(-920, -620, 1840, 1360)
	setup_player(Vector2(-780, 620), 3.0)  # 蛇形走廊入口
	_spawn_npcs()
	# 读档时如果已有电梯卡或已触发23点事件，恢复状态
	if GameManager.event_flags.get("floor1_23_triggered", false):
		_event_23_triggered = true
	if InventoryManager.has_item("elevator_card"):
		elevator_card_found = true
	setup_ui("第一层")

	# 第一层开场必须先是黑的，不能先全亮再渐暗。
	if darkness:
		darkness.set_darkness(0.06)
	PlayerStats.darkness_environment = true
	if player_lighting:
		player_lighting.phone_has_power = false
		player_lighting._cone_light.visible = false
	# 等物理帧完成后再开启房间检测，防止初始化时误触发
	await get_tree().physics_frame
	_room_detection_enabled = true

	# 启用体力系统
	enable_stamina()

	# 连接 Director 和自适应音频
	AudioManager.connect_director()
	Director.peak_reached.connect(_on_director_peak)
	Director.relief_started.connect(_on_director_relief)

	# 第一层BGM播放列表（3首轮播）
	var bgm_tracks: Array[AudioStream] = []
	for path in ["res://assets/audio/bgm/第一层bgm.mp3", "res://assets/audio/bgm/第一层bgm2.mp3", "res://assets/audio/bgm/第一层bgm3.mp3"]:
		if ResourceLoader.exists(path):
			bgm_tracks.append(load(path))
	if not bgm_tracks.is_empty():
		AudioManager.play_playlist(bgm_tracks, 1.0, 1.5)

	# 注册规则纸条
	if not InventoryManager.has_item("rule_paper"):
		InventoryManager.add_item("rule_paper")

	# 读档时跳过初始等待延迟，但仍然运行入场剧情（NPC徘徊和事件链从此启动）
	if SaveManager.is_loading_save:
		if player_lighting:
			player_lighting.phone_has_power = false
			player_lighting._cone_light.visible = false
		_phone_light_intro()
		return

	# 入场：先关掉手机光，演出后再打开
	if player_lighting:
		player_lighting.phone_has_power = false  # 暂时关灯
		player_lighting._cone_light.visible = false

	await get_tree().create_timer(1.0).timeout
	_phone_light_intro()

## Director 高峰回调 — 灯光闪烁、音效压迫
func _on_director_peak() -> void:
	# 走廊灯闪烁
	for light in _corridor_lights:
		if is_instance_valid(light):
			var tw := create_tween()
			tw.tween_property(light, "energy", light.energy * 0.2, 0.05)
			tw.tween_property(light, "energy", light.energy, 0.1)
			tw.tween_property(light, "energy", light.energy * 0.1, 0.03)
			tw.tween_property(light, "energy", light.energy * 0.8, 0.08)

## Director 释放回调 — 恢复正常
func _on_director_relief() -> void:
	# 确保所有走廊灯恢复正常亮度
	for light in _corridor_lights:
		if is_instance_valid(light):
			var tw := create_tween()
			tw.tween_property(light, "energy", light.energy, 2.0)

## 在世界坐标处创建本地化的房间名称标签。
## [param text] 房间名称（经 LocaleManager 翻译）。
## [param pos] 标签的世界坐标。
func _add_room_label(text: String, pos: Vector2) -> void:
	create_world_label(LocaleManager.world_text(text), pos, 22, Color(0.3, 0.25, 0.2))

## 在横向走廊上方搭建一个带朝走廊门的房间（墙体、碰撞与门）。
## [param walls] 承载墙体节点的父节点。
## [param top_left] 房间左上角坐标。
## [param room_size] 房间尺寸。
## [param door_center_x] 门中心的 X 坐标。
## [param locked] 门是否上锁。
## [param show_south_face] 是否绘制朝向走廊的南面墙（false 时贴图由外部绘制）。
func _build_room_above_corridor(walls: Node2D, top_left: Vector2, room_size: Vector2, door_center_x: float, locked: bool = false, show_south_face: bool = true) -> void:
	var wall_color = Color(0.1, 0.07, 0.05)
	var door_width = 44.0 * world_scale
	# 顶墙是外墙，背对走廊，不需要正面
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y), Vector2(room_size.x, 8), wall_color, true, false, false)
	add_visible_wall(walls, Vector2(top_left.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false, Vector2.RIGHT)
	add_visible_wall(walls, Vector2(top_left.x + room_size.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false, Vector2.LEFT)
	var left_width = door_center_x - door_width / 2.0 - top_left.x
	if left_width > 8.0:
		# show_south_face=false 时不加旧y=245碰撞墙，避免双层门卡人；只加隐形停止线
		if show_south_face:
			add_visible_wall(walls, Vector2(top_left.x + left_width / 2.0, top_left.y + room_size.y), Vector2(left_width, 8), wall_color, true, show_south_face, false, Vector2.DOWN)
	var right_start = door_center_x + door_width / 2.0
	var right_width = top_left.x + room_size.x - right_start
	if right_width > 8.0:
		if show_south_face:
			add_visible_wall(walls, Vector2(right_start + right_width / 2.0, top_left.y + room_size.y), Vector2(right_width, 8), wall_color, true, show_south_face, false, Vector2.DOWN)
	# show_south_face=false 时贴图由外部直接调用(pos.y=C=286, K=-12)
	# 碰撞体与房间底边对齐；墙面贴图由外部 _add_horizontal_wall_face_dir 另行绘制
	if not show_south_face:
		var stop_y = top_left.y + room_size.y + 49.0
		if left_width > 8.0:
			add_wall(walls, Vector2(top_left.x + left_width / 2.0, stop_y), Vector2(left_width, 8))
		if right_width > 8.0:
			add_wall(walls, Vector2(right_start + right_width / 2.0, stop_y), Vector2(right_width, 8))
		add_door(walls, Vector2(door_center_x, stop_y), Vector2(door_width, 8), locked, Vector2.UP, 1)
		# 视觉隔断条（无碰撞）：遮住走廊看向房间天花板的视线
		var cap := ColorRect.new()
		cap.position = Vector2(top_left.x, top_left.y + room_size.y - 4.0)
		cap.size = Vector2(room_size.x, 8.0)
		cap.color = wall_color.lightened(0.05)
		cap.z_index = 4
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cap)
	else:
		add_door(walls, Vector2(door_center_x, top_left.y + room_size.y), Vector2(door_width, 8), locked, Vector2.UP)

## 在横向走廊下方搭建一个带朝走廊门的房间（墙体、碰撞与门）。
## [param walls] 承载墙体节点的父节点。
## [param top_left] 房间左上角坐标。
## [param room_size] 房间尺寸。
## [param door_center_x] 门中心的 X 坐标。
## [param locked] 门是否上锁。
func _build_room_below_corridor(walls: Node2D, top_left: Vector2, room_size: Vector2, door_center_x: float, locked: bool = false) -> void:
	var wall_color = Color(0.1, 0.07, 0.05)
	var door_width = 44.0 * world_scale
	add_visible_wall(walls, Vector2(top_left.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false, Vector2.RIGHT)
	add_visible_wall(walls, Vector2(top_left.x + room_size.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false, Vector2.LEFT)
	# 底墙是外墙，背对走廊，不需要正面
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y + room_size.y), Vector2(room_size.x, 8), wall_color, true, false, false)
	var left_width = door_center_x - door_width / 2.0 - top_left.x
	if left_width > 8.0:
		add_visible_wall(walls, Vector2(top_left.x + left_width / 2.0, top_left.y), Vector2(left_width, 8), wall_color, true, true, false, Vector2.DOWN)
	var right_start = door_center_x + door_width / 2.0
	var right_width = top_left.x + room_size.x - right_start
	if right_width > 8.0:
		add_visible_wall(walls, Vector2(right_start + right_width / 2.0, top_left.y), Vector2(right_width, 8), wall_color, true, true, false, Vector2.DOWN)
	add_door(walls, Vector2(door_center_x, top_left.y), Vector2(door_width, 8), locked, Vector2.DOWN)

## 在纵向走廊左侧搭建一个带朝走廊门的房间（墙体、碰撞与门）。
## [param walls] 承载墙体节点的父节点。
## [param top_left] 房间左上角坐标。
## [param room_size] 房间尺寸。
## [param door_center_y] 门中心的 Y 坐标。
## [param locked] 门是否上锁。
func _build_room_left_of_vertical_corridor(walls: Node2D, top_left: Vector2, room_size: Vector2, door_center_y: float, locked: bool = false) -> void:
	var wall_color = Color(0.1, 0.07, 0.05)
	var door_height = 44.0 * world_scale
	# 顶/底墙是外墙，不需要正面
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y), Vector2(room_size.x, 8), wall_color, true, false, false)
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y + room_size.y), Vector2(room_size.x, 8), wall_color, false, false, false)
	# 左墙是外墙，不需要正面
	add_visible_wall(walls, Vector2(top_left.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false)
	var upper_height = door_center_y - door_height / 2.0 - top_left.y
	if upper_height > 8.0:
		add_visible_wall(walls, Vector2(top_left.x + room_size.x, top_left.y + upper_height / 2.0), Vector2(8, upper_height), wall_color, false, false, true, Vector2.RIGHT)
	var lower_start = door_center_y + door_height / 2.0
	var lower_height = top_left.y + room_size.y - lower_start
	if lower_height > 8.0:
		add_visible_wall(walls, Vector2(top_left.x + room_size.x, lower_start + lower_height / 2.0), Vector2(8, lower_height), wall_color, false, false, true, Vector2.RIGHT)
	add_door(walls, Vector2(top_left.x + room_size.x, door_center_y), Vector2(8, door_height), locked, Vector2.LEFT)

## 在纵向走廊右侧搭建一个带朝走廊门的房间（墙体、碰撞与门）。
## [param walls] 承载墙体节点的父节点。
## [param top_left] 房间左上角坐标。
## [param room_size] 房间尺寸。
## [param door_center_y] 门中心的 Y 坐标。
## [param locked] 门是否上锁。
func _build_room_right_of_vertical_corridor(walls: Node2D, top_left: Vector2, room_size: Vector2, door_center_y: float, locked: bool = false) -> void:
	var wall_color = Color(0.1, 0.07, 0.05)
	var door_height = 44.0 * world_scale
	# 顶/底墙是外墙，不需要正面
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y), Vector2(room_size.x, 8), wall_color, true, false, false)
	add_visible_wall(walls, Vector2(top_left.x + room_size.x / 2.0, top_left.y + room_size.y), Vector2(room_size.x, 8), wall_color, true, false, false)
	# 右墙是外墙，不需要正面
	add_visible_wall(walls, Vector2(top_left.x + room_size.x, top_left.y + room_size.y / 2.0), Vector2(8, room_size.y), wall_color, true, false, false)
	var upper_height = door_center_y - door_height / 2.0 - top_left.y
	if upper_height > 8.0:
		add_visible_wall(walls, Vector2(top_left.x, top_left.y + upper_height / 2.0), Vector2(8, upper_height), wall_color, false, false, true, Vector2.LEFT)
	var lower_start = door_center_y + door_height / 2.0
	var lower_height = top_left.y + room_size.y - lower_start
	if lower_height > 8.0:
		add_visible_wall(walls, Vector2(top_left.x, lower_start + lower_height / 2.0), Vector2(8, lower_height), wall_color, false, false, true, Vector2.LEFT)
	add_door(walls, Vector2(top_left.x, door_center_y), Vector2(8, door_height), locked, Vector2.RIGHT)

## 放置仍需动态创建的灯光效果：闪烁走廊灯、环境灰尘与各房门门缝漏光。
func _place_dynamic_lights() -> void:
	# 房间灯光和走廊灯光已迁移到 .tscn 场景树（PointLight2D 节点）。
	# 以下仅保留仍需动态创建的灯光效果。

	# 闪烁走廊灯（23:00 断电前额外闪烁提示）
	_corridor_lights.append(add_flickering_light(Vector2(320, -130), 1.5, 2.4))

	# 环境灰尘（转角和走廊尽头）
	add_dust_ambient(Vector2(-360, 220), Vector2(40, 28))
	add_dust_ambient(Vector2(210, 125), Vector2(30, 24))
	add_dust_ambient(Vector2(-215, -135), Vector2(30, 24))
	add_dust_ambient(Vector2(300, -130), Vector2(35, 25))

	# 门缝漏光
	_door_leak_lights.append(add_door_light_leak(Vector2(-250, -105), 24.0, "left"))  # 100门侧
	_door_leak_lights.append(add_door_light_leak(Vector2(-165, -170), 25.0))  # 101门底
	_door_leak_lights.append(add_door_light_leak(Vector2(35, -170), 25.0))    # 102门底
	_door_leak_lights.append(add_door_light_leak(Vector2(244, -170), 28.0))   # 106门底
	_door_leak_lights.append(add_door_light_leak(Vector2(411, -170), 18.0))   # 107门底
	_door_leak_lights.append(add_door_light_leak(Vector2(260, 165), 24.0, "right"))  # 108门侧

## 在玩家出生点附近生成五名同伴NPC并先设为不可见（黑暗中看不到）。
func _spawn_npcs() -> void:
	# 开手机后的第一眼先看到身边同伴，之后再沿蛇形走廊分散行动
	cool_npc = create_npc_visual(Vector2(-352, 316), "cool_npc")
	cheerful_npc = create_npc_visual(Vector2(-312, 324), "cheerful_npc")
	male_npc = create_npc_visual(Vector2(-198, 318), "male_npc")
	female_npc = create_npc_visual(Vector2(-154, 326), "female_npc")
	timid_npc = create_npc_visual(Vector2(-384, 324), "timid_male")
	# 黑暗中看不到NPC
	for npc in [cool_npc, cheerful_npc, male_npc, female_npc, timid_npc]:
		if npc:
			npc.visible = false

## 入场演出：自言自语后点亮手机光、显现周围NPC，随后进入正式入场对话。
func _phone_light_intro() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 自言自语：好黑
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "dark_intro"))
	await DialogueManager.dialogue_ended
	
	# 手机光亮起
	if player_lighting:
		player_lighting.phone_has_power = true
		player_lighting._apply_phone_mode()
	
	# 亮灯后看到周围的人
	for npc in [cool_npc, cheerful_npc, male_npc, female_npc, timid_npc]:
		if npc:
			npc.visible = true
	
	await get_tree().create_timer(0.5).timeout
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	
	# 继续入场对话
	await get_tree().create_timer(1.0).timeout
	_entry_dialogue()

## 入场对话流程：NPC分头行动、规则纸条出现并展示、主角询问纸条。
func _entry_dialogue() -> void:
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "entry"))
	await DialogueManager.dialogue_ended
	
	# 对话结束后NPC分头行动
	_start_npc_wandering()
	_refresh_floor_1_npc_dialogues()
	
	# 规则纸条出现
	await get_tree().create_timer(2.0).timeout
	show_hint(LocaleManager.t("hint_rule_paper") % InputDevice.get_hint("open_rules"))
	ScreenEffects.rule_appear()
	GameManager.add_rule(LocaleManager.t("rule_floor_1"))
	await show_rule_paper_and_wait()
	
	# 主角询问纸条
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "rule_question"))
	await DialogueManager.dialogue_ended

## 为所有存活NPC开启手机光源。
func _enable_npc_phone_lights() -> void:
	for npc in [cool_npc, cheerful_npc, male_npc, female_npc, timid_npc]:
		if npc and is_instance_valid(npc) and npc.is_alive:
			npc.enable_phone_light()

## 收集全部有效NPC并为每个启动独立的徘徊循环。
func _start_npc_wandering() -> void:
	_enable_npc_phone_lights()
	var wandering_npcs: Array[Node2D] = []
	if cool_npc:
		wandering_npcs.append(cool_npc)
	if cheerful_npc:
		wandering_npcs.append(cheerful_npc)
	if male_npc:
		wandering_npcs.append(male_npc)
	if female_npc:
		wandering_npcs.append(female_npc)
	if timid_npc:
		wandering_npcs.append(timid_npc)
	for npc in wandering_npcs:
		_wander_loop(npc)

## 按是否已触发23点镜子事件，刷新五名NPC的闲聊故事对话。
func _refresh_floor_1_npc_dialogues() -> void:
	if _event_23_triggered:
		set_npc_story_dialogue(cool_npc, "floor_1", "talk_post_mirror_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_1", "talk_post_mirror_cheerful")
		set_npc_story_dialogue(male_npc, "floor_1", "talk_post_mirror_male")
		set_npc_story_dialogue(female_npc, "floor_1", "talk_post_mirror_female")
		set_npc_story_dialogue(timid_npc, "floor_1", "talk_post_mirror_timid")
		return
	set_npc_story_dialogue(cool_npc, "floor_1", "talk_explore_cool")
	set_npc_story_dialogue(cheerful_npc, "floor_1", "talk_explore_cheerful")
	set_npc_story_dialogue(male_npc, "floor_1", "talk_explore_male")
	set_npc_story_dialogue(female_npc, "floor_1", "talk_explore_female")
	set_npc_story_dialogue(timid_npc, "floor_1", "talk_explore_timid")

## NPC徘徊循环：走向随机点、随机停顿后递归继续，直到场景退出或NPC失效。
## [param npc] 要徘徊的NPC节点。
func _wander_loop(npc: Node2D) -> void:
	if not is_instance_valid(npc) or not npc.is_inside_tree():
		return
	if _exiting:
		return
	var target = _random_wander_point(npc.global_position)
	npc.walk_to(target)
	await npc.walk_completed
	if _exiting or not is_instance_valid(npc):
		return
	await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
	if not _exiting and is_instance_valid(npc):
		_wander_loop(npc)

## 从徘徊点列表中选取距起点最近的点附近的相邻候选点之一。
## [param origin] NPC当前位置。
## [return] 选中的徘徊目标点坐标。
func _random_wander_point(origin: Vector2) -> Vector2:
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(FLOOR_1_WANDER_POINTS.size()):
		var point: Vector2 = FLOOR_1_WANDER_POINTS[index]
		var distance_sq := origin.distance_squared_to(point)
		if distance_sq < nearest_distance:
			nearest_distance = distance_sq
			nearest_index = index

	var candidate_indices: Array[int] = []
	for offset in [-2, -1, 1, 2]:
		var candidate_index = clampi(nearest_index + offset, 0, FLOOR_1_WANDER_POINTS.size() - 1)
		if candidate_index != nearest_index and candidate_index not in candidate_indices:
			candidate_indices.append(candidate_index)

	if candidate_indices.is_empty():
		return FLOOR_1_WANDER_POINTS[nearest_index]
	return FLOOR_1_WANDER_POINTS[candidate_indices[randi() % candidate_indices.size()]]

## 23点异变事件：女伴走向镜子对视、断电熄灯并推进主线对话，之后给出找电梯卡提示。
func _on_23_oclock() -> void:
	if _event_23_triggered:
		return
	_event_23_triggered = true
	GameManager.event_flags["floor1_23_triggered"] = true

	# Director 强制高峰
	Director.force_peak()

	# 23:00异变开始
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	await get_tree().create_timer(0.5).timeout

	# 沈薇边说边走向镜子（不阻塞对话）
	if is_instance_valid(female_npc):
		female_npc.walk_to(Vector2(160, -130))  # 顶端镜子前方

	# 先准备暗色叠加层（隐藏，等停电叙述句时再显示）
	var dark_overlay = ColorRect.new()
	dark_overlay.color = Color(0, 0, 0, 0)
	dark_overlay.position = Vector2(-450, -300)
	dark_overlay.size = Vector2(900, 600)
	dark_overlay.z_index = -1
	add_child(dark_overlay)

	# 镜子事件：先开始对话，在第5行（停电叙述）触发电力和灯光效果
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "mirror"))

	# 监听对话行，到第5行（index=4，停电叙述）时触发效果
	var line_count := 0
	var effects_triggered := false
	var _on_line = func(_speaker: String, _text: String, _emotion: String):
		line_count += 1
		if line_count == 5 and not effects_triggered:
			effects_triggered = true
			# 咚——走廊灯全灭
			AudioManager.play_sfx(_SFX_BLACKOUT, 0.0)
			ScreenEffects.shake(3.0, 0.2)
			for light in _corridor_lights:
				if is_instance_valid(light):
					light.visible = false
			for light in _door_leak_lights:
				if is_instance_valid(light):
					light.visible = false
			# 环境变暗
			var tw2 = create_tween()
			tw2.tween_property(dark_overlay, "color:a", 0.3, 2.0)
	DialogueManager.dialogue_line_shown.connect(_on_line)
	await DialogueManager.dialogue_ended
	DialogueManager.dialogue_line_shown.disconnect(_on_line)	
	await get_tree().create_timer(1.0).timeout
	
	# 恢复控制（左撇子发现已移至电梯场景）
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	_refresh_floor_1_npc_dialogues()
	
	if elevator_card_found:
		show_hint(LocaleManager.t("hint_go_elevator"))
	else:
		show_hint(LocaleManager.t("hint_need_card"))

## 刷卡进电梯流程：开门、播放进电梯对话后转场到电梯内场景。
func _enter_elevator() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 电梯门变为打开状态
	if _elevator_door and is_instance_valid(_elevator_door):
		_elevator_door.open_door()
	
	# 刷卡进入电梯
	DialogueManager.start_dialogue(StoryText.lines("floor_1", "enter_elevator_scene"))
	await DialogueManager.dialogue_ended
	
	await get_tree().create_timer(0.5).timeout
	TransitionManager.transition_to_scene("res://scenes/levels/elevator_f1_interior.tscn")


## ---- Debug helpers for investigating/removing accidental colliders ----
func debug_list_colliders_in_rect(rect: Rect2) -> void:
	var walls_node := get_node_or_null("Walls")
	if not walls_node:
		for c in get_children():
			if c is StaticBody2D:
				walls_node = c
				break
		if not walls_node:
			push_warning("debug: no Walls node found")
			return
	var found := 0
	for i in range(walls_node.get_child_count()):
		var child = walls_node.get_child(i)
		if child is CollisionShape2D:
			var shp = child.shape
			if shp is RectangleShape2D:
				var center = child.position
				var size = shp.size
				var r = Rect2(center - size / 2.0, size)
				if r.intersects(rect):
					push_warning("debug collider[%d] pos=%s size=%s rect=%s" % [i, center, size, r])
					found += 1
	if found == 0:
		push_warning("debug: no colliders intersecting %s" % rect)

## 调试用：删除 Walls 下与指定矩形相交的所有矩形碰撞体。
## [param rect] 检测范围矩形。
## [return] 实际删除的碰撞体数量。
func debug_remove_colliders_in_rect(rect: Rect2) -> int:
	var walls_node := get_node_or_null("Walls")
	if not walls_node:
		for c in get_children():
			if c is StaticBody2D:
				walls_node = c
				break
		if not walls_node:
			push_warning("debug: no Walls node found")
			return 0
	var removed := 0
	var children = walls_node.get_children()
	for child in children:
		if child is CollisionShape2D:
			var shp = child.shape
			if shp is RectangleShape2D:
				var center = child.position
				var size = shp.size
				var r = Rect2(center - size / 2.0, size)
				if r.intersects(rect):
					push_warning("debug: removing collider at %s size=%s" % [center, size])
					child.queue_free()
					removed += 1
	push_warning("debug: removed %d colliders intersecting %s" % [removed, rect])
	return removed

## 调试辅助：列出103房间附近疑似阻挡区域的碰撞体以便排查。
func _debug_clear_103_area() -> void:
	# Convenience: list colliders in likely blocking area for room 103
	var probe = Rect2(Vector2(-280, 80), Vector2(300, 260))
	debug_list_colliders_in_rect(probe)
	# To remove, call debug_remove_colliders_in_rect(probe) from the editor/console if you confirm


# ====== 房间系统（v1 设计还原，坐标 ×2 适配当前世界）======

## 构建全部房间的墙体、门、天花板与标签。
## 九个房间：100/101/102/103/104/105/106/107/108。
func _build_room_system() -> void:
	var walls = StaticBody2D.new()
	walls.name = "RoomWalls"
	walls.collision_layer = 4
	add_child(walls)

	# 电梯井左侧遮挡墙
	add_visible_wall(walls, Vector2(-880, 644), Vector2(30, 64), Color(0.12, 0.08, 0.06), true, false, false)
	# 底部区域墙体（引导"家→公寓"路线）
	add_visible_wall(walls, Vector2(120, 730), Vector2(1560, 60), Color(0.1, 0.07, 0.05), false, true, false, Vector2.UP)
	# 108 房下方区域
	add_visible_wall(walls, Vector2(690, 610), Vector2(360, 100), Color(0.1, 0.07, 0.05), false, true, false, Vector2.UP)
	# 底部走廊两侧房墙（103~105 房间隔墙向下延伸）
	add_visible_wall(walls, Vector2(-475, 345), Vector2(70, 310), Color(0.1, 0.07, 0.05), false, false, true, Vector2.RIGHT)
	add_visible_wall(walls, Vector2(-55, 345), Vector2(70, 310), Color(0.1, 0.07, 0.05), false, false, true, Vector2.RIGHT)
	# 补墙面缝隙
	var seam_size := Vector2(70.0, 80.0)
	var seam_pos1 := Vector2(-475.0, 540.0)
	var seam_pos2 := Vector2(-55.0, 540.0)
	var seam_color := Color(0.1, 0.07, 0.05).lightened(0.05)
	add_child(_make_wall_rect(seam_pos1 - seam_size / 2.0, seam_size, seam_color, 4))
	add_child(_make_wall_rect(seam_pos2 - seam_size / 2.0, seam_size, seam_color, 4))
	add_wall(walls, Vector2(-475.0, 588.0), Vector2(70, 16))
	add_wall(walls, Vector2(-55.0, 588.0), Vector2(70, 16))
	add_visible_wall(walls, Vector2(285.0, -80.0), Vector2(1250, 200), Color(0.1, 0.07, 0.05), false, true, false, Vector2.DOWN)
	add_visible_wall(walls, Vector2(-700.0, 66.0), Vector2(400, 28), Color(0.1, 0.07, 0.05), false, true, false, Vector2.DOWN)
	add_visible_wall(walls, Vector2(700.0, 686.0), Vector2(400, 28), Color(0.1, 0.07, 0.05), false, true, false, Vector2.UP)

	# === 房间 100（左上角，垂直走廊左侧）===
	_build_room_left_of_vertical_corridor(walls, Vector2(-860, -600), Vector2(360, 660), -210.0)
	_add_room_label("100", Vector2(-840, -576))

	# === 房间 103（底部走廊上方左侧）===
	_build_room_above_corridor(walls, Vector2(-860, 190), Vector2(350, 300), -685.0, false, false)
	_add_room_label("103", Vector2(-840, 196))

	# === 房间 104（底部走廊上方中段）===
	_build_room_above_corridor(walls, Vector2(-440, 190), Vector2(350, 300), -265.0, false, false)
	_add_room_label("104", Vector2(-420, 196))

	# === 房间 105（底部走廊上方右侧储藏间）===
	_build_room_above_corridor(walls, Vector2(-20, 190), Vector2(320, 300), 140.0, false, false)
	add_visible_wall(walls, Vector2(300.0, 539.0), Vector2(16, 114), Color(0.1, 0.07, 0.05), false, false, true, Vector2.RIGHT)
	_add_horizontal_wall_face_dir(Vector2(-280.0, 604.0), Vector2(1160.0, 16.0), Color(0.1, 0.07, 0.05), 1.0)
	_add_room_label("105", Vector2(0, 196))

	# === 房间 101（上部走廊左侧）===
	_build_room_above_corridor(walls, Vector2(-480, -600), Vector2(300, 260), -330.0)
	_add_room_label("101", Vector2(-460, -580))

	# === 房间 102（上部走廊中段，锁住）===
	_build_room_above_corridor(walls, Vector2(-80, -600), Vector2(300, 260), 70.0, true)
	_add_room_label("102", Vector2(-60, -580))

	# === 房间 106（上部走廊右侧，双床房）===
	_build_room_above_corridor(walls, Vector2(236, -600), Vector2(504, 260), 488.0)
	_add_room_label("106", Vector2(256, -580))

	# === 房间 107（上部走廊右侧工具房）===
	_build_room_above_corridor(walls, Vector2(756, -600), Vector2(132, 260), 822.0)
	_add_room_label("107", Vector2(772, -580))

	# === 房间 108（右下角，垂直走廊右侧储藏间）===
	_build_room_right_of_vertical_corridor(walls, Vector2(520, 80), Vector2(340, 480), 330.0)
	_add_room_label("108", Vector2(548, 104))

	# === 房间天花板（进门时走廊压暗、房间揭示）===
	add_room_ceiling("100", Vector2(-860, -600), Vector2(360, 588), Rect2(Vector2(-860, -600), Vector2(360, 660)))
	add_room_ceiling("103", Vector2(-860, 190), Vector2(350, 300), Rect2(Vector2(-860, 190), Vector2(350, 406)))
	add_room_ceiling("104", Vector2(-440, 190), Vector2(350, 300), Rect2(Vector2(-440, 190), Vector2(350, 406)))
	add_room_ceiling("105", Vector2(-20, 190), Vector2(320, 300), Rect2(Vector2(-20, 190), Vector2(320, 406)))
	add_room_ceiling("101", Vector2(-480, -600), Vector2(300, 260), Rect2(Vector2(-480, -600), Vector2(300, 260)))
	add_room_ceiling("102", Vector2(-80, -600), Vector2(300, 260), Rect2(Vector2(-80, -600), Vector2(300, 260)))
	add_room_ceiling("106", Vector2(236, -600), Vector2(504, 260), Rect2(Vector2(236, -600), Vector2(504, 260)))
	add_room_ceiling("107", Vector2(756, -600), Vector2(132, 260), Rect2(Vector2(756, -600), Vector2(132, 260)))
	add_room_ceiling("108", Vector2(520, 80), Vector2(340, 480))

