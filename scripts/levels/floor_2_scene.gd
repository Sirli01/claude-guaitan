@tool
extends LevelBaseV2
## 第二层 - 听觉压迫与生死抉择
## 规则："禁止离群 — 第二层"
## 威胁：天花板上的巨大高跟鞋，锁定离群者
## 流程：
##   胆小男留电梯口→高跟鞋锁定→死亡
##   发现规则「禁止离群」→众人慌张→发现女伴已离群
##   女伴听到高跟鞋逼近→大喊→被杀
##   众人冲向女伴方向时，开朗NPC跑得慢落后→被锁定→玩家抉择
##   存活者紧靠在一起找电梯卡→找到后离开

var cool_npc: CharacterBody2D
var cheerful_npc: CharacterBody2D
var male_npc: CharacterBody2D
var female_npc: CharacterBody2D
var timid_npc: CharacterBody2D

## 高跟鞋怪物视觉（场景实例，初始隐藏，事件触发时显示）
@onready var high_heel_visual: Node2D = %HighHeel
var elevator_card_found: bool = false
var _wander_tweens: Dictionary = {}  # NPC -> bool，用于标记仍在徘徊
var _timid_walk_tween: Tween = null
var _used_earplug: bool = false  # 是否用了耳塞救鹿可
var _earplug_branch_pending: bool = false
var _heel_sfx: AudioStream  # 程序化高跟鞋音效
var _rumble_sfx: AudioStream  # 地鸣音效
var _waiting_for_female_proximity: bool = false  # 等待玩家接近沈薇
var _timid_pacing_active: bool = false
var _waiting_for_timid_distance: bool = false

const HIGH_HEEL_TEX_PATH := "res://assets/sprites/monsters/high_heel.png"
const HIGH_HEEL_WORLD_HEIGHT := 300.0
const FLOOR_2_ARRIVAL_POS := Vector2(-680, 450)
const FLOOR_2_PARTY_SPAWN_POS := Vector2(-680, 516)
const TIMID_GUARD_POS := Vector2(-640, 510)
const TIMID_SOUND_POS := Vector2(-660, 490)
const PARTY_WANDER_MIN := Vector2(-280, -160)
const PARTY_WANDER_MAX := Vector2(660, 480)
const ITEM_LOSS_POOL := ["sweets", "sedative", "energy_drink", "energy_bar", "battery", "match"]

enum Phase { EXPLORE, TIMID_DEATH, RULE_DISCOVER, FEMALE_DEATH, CHEERFUL_DANGER, RESCUE, SEARCH, DONE }
var current_phase: Phase = Phase.EXPLORE

## 初始化第二层：注册楼层、预生成音效、搭建场景元素与NPC，并启动入场剧情。
func _ready() -> void:
	# 编辑器模式：几何与灯光已在 .tscn 中定义，无需生成
	if Engine.is_editor_hint():
		return

	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.change_floor(GameManager.Floor.FLOOR_2)
	scene_audio_id = "floor_2"

	# 预生成程序化音效
	var _sfx_gen = preload("res://scripts/utils/procedural_sfx.gd")
	_heel_sfx = _sfx_gen.high_heel_step()
	_rumble_sfx = _sfx_gen.ground_rumble()

	discover_scene_nodes()
	_add_room_labels()
	_add_ceiling_cracks()
	camera_bounds = Rect2(-820, -620, 1640, 1240)
	setup_player(FLOOR_2_PARTY_SPAWN_POS, 3.0)
	_build_arrival_elevator(FLOOR_2_ARRIVAL_POS)
	_spawn_npcs()
	_build_elevator()
	setup_ui("第二层")
	# 等物理帧完成后再开启房间检测，避免初始化阶段误判。
	await get_tree().physics_frame
	_room_detection_enabled = true
	
	# 启用体力系统和黑暗
	enable_stamina()
	enable_darkness(0.06, 2.0)
	
	# 第二层起手机没电
	if player_lighting:
		player_lighting.disable_phone_power()
	
	# 第二层BGM播放列表（2首轮播）
	var bgm_tracks: Array[AudioStream] = []
	for path in ["res://assets/audio/bgm/第二层bgm.mp3", "res://assets/audio/bgm/第二层bgm2.mp3"]:
		if ResourceLoader.exists(path):
			bgm_tracks.append(load(path))
	if not bgm_tracks.is_empty():
		AudioManager.play_playlist(bgm_tracks, 1.0, 1.5)
	
	# 读档时跳过入场等待，但仍然运行入场剧情（楼层事件必须重新触发）
	if SaveManager.is_loading_save:
		_entry_sequence()
		return
	
	await get_tree().create_timer(1.0).timeout
	_entry_sequence()

## 每帧检查剧情触发条件：余凡离开视野即触发其死亡、玩家接近沈薇触发女伴之死、以及重试耳塞救援分支。
## [param _delta] 帧间隔时间（未使用）。
func _physics_process(_delta: float) -> void:
	if _waiting_for_timid_distance and timid_npc and player:
		if not _is_world_pos_on_screen(timid_npc.global_position, 36.0):
			_waiting_for_timid_distance = false
			_timid_death_event()
	if _waiting_for_female_proximity and female_npc and player:
		var dist = player.global_position.distance_to(female_npc.global_position)
		# 沈薇一旦出现在玩家屏幕里就朝玩家跑（玩家必须在走廊，避免隔墙撞墙）
		if _is_world_pos_on_screen(female_npc.global_position) and _current_room_id == "":
			set_npc_speed_v1(female_npc, 65.0)
			female_npc.walk_to(player.global_position)
		if dist < 560.0 and _is_world_pos_on_screen(female_npc.global_position) and _current_room_id == "":
			_waiting_for_female_proximity = false
			_female_death_event()
	if current_phase == Phase.CHEERFUL_DANGER and not _used_earplug:
		# 每帧重试：拿到耳塞且条件合适时触发给鹿可耳塞的分支
		_trigger_earplug_branch()

## 判断世界坐标是否处于当前相机可视范围内。
## [param pos] 待检测的世界坐标。
## [param padding] 判定矩形的外扩边距（像素）。
## [return] 在可视范围内时为 true。
func _is_world_pos_on_screen(pos: Vector2, padding: float = 0.0) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var viewport_size = get_viewport().get_visible_rect().size
	# Camera2D.zoom 越大，实际可见世界范围越小。
	var zoom = Vector2(max(cam.zoom.x, 0.001), max(cam.zoom.y, 0.001))
	var world_size = viewport_size / zoom
	var screen_rect = Rect2(
		cam.get_screen_center_position() - world_size * 0.5 - Vector2.ONE * padding,
		world_size + Vector2.ONE * padding * 2.0
	)
	return screen_rect.has_point(pos)

## 判断世界坐标是否处于屏幕中央的清晰可见区域（四周各留280px边距，排除屏幕边缘）。
## [param pos] 待检测的世界坐标。
## [return] 处于清晰可见区域时为 true。
func _is_world_pos_clearly_visible(pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = Vector2(max(cam.zoom.x, 0.001), max(cam.zoom.y, 0.001))
	var world_size = viewport_size / zoom
	var margin = Vector2(280, 280)
	var rect = Rect2(cam.get_screen_center_position() - world_size * 0.5 + margin, world_size - margin * 2.0)
	return rect.has_point(pos)

## 创建各房间名称的世界标签（多语言文本需运行时解析，故由代码创建）
func _add_room_labels() -> void:
	_add_room_label("201", Vector2(-740, -540))
	_add_room_label("202", Vector2(280, -540))
	_add_room_label("203", Vector2(280, 300))
	_add_room_label("储藏室", Vector2(-780, -124))

## 创建单个房间名称标签。
## [param text] 房间名。[param pos] 标签世界坐标。
func _add_room_label(text: String, pos: Vector2) -> void:
	var label_text := text if Engine.is_editor_hint() else LocaleManager.world_text(text)
	create_world_label(label_text, pos, 22, Color(0.3, 0.25, 0.2))

## 天花板裂缝装饰（每次进入随机位置/长度，属运行时氛围特效，故动态创建）
func _add_ceiling_cracks() -> void:
	for i in range(5):
		var crack := ColorRect.new()
		crack.color = Color(0.03, 0.02, 0.02)
		crack.position = Vector2(-600 + i * 260 + randf() * 80, -596)
		crack.size = Vector2(4, randi_range(10, 30))
		add_child(crack)

## 在指定位置放置可拾取的地面道具（如余凡死后掉落的耳塞），带名称标签与闪烁提示。
## [param pos] 道具世界坐标。
## [param item_id] 物品ID。
## [param item_name] 物品显示名。
## [param color] 道具视觉颜色。
func _place_room_item(pos: Vector2, item_id: String, item_name: String, color: Color) -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/simple_pickup.gd"))
	area.position = pos
	area.collision_layer = 16
	area.item_id = item_id
	area.item_name = item_name
	area._level = self
	add_child(area)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	area.add_child(col)
	var visual = ColorRect.new()
	visual.color = color
	visual.position = Vector2(-10, -10)
	visual.size = Vector2(20, 20)
	area.add_child(visual)
	var display_name: String = item_name
	if not Engine.is_editor_hint():
		display_name = InventoryManager.get_item_data(item_id).get("name", item_name)
	var hint_text := "" if Engine.is_editor_hint() else InputDevice.hint("interact")
	var label = create_world_label("%s %s" % [display_name, hint_text], pos + Vector2(-40, -44), 18, color.lightened(0.3))
	label.visible = false
	area._name_label = label
	area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())
	if not Engine.is_editor_hint():
		var tw = create_tween().set_loops()
		_loop_tweens.append(tw)
		tw.tween_property(visual, "modulate:a", 0.4, 1.2)
		tw.tween_property(visual, "modulate:a", 1.0, 1.2)
	if item_id == "earplug":
		area.picked_up.connect(func():
			_trigger_earplug_branch()
			# 确保在可能的时机再次尝试（异步下一帧）
			call_deferred("_trigger_earplug_branch")
		)

## 按存活状态生成本层NPC：夏桐、林佳语、周锐随队伍出发，沈薇同行，余凡留守到达电梯口。
func _spawn_npcs() -> void:
	if GameManager.is_character_alive("cool_npc"):
		cool_npc = create_npc_visual(FLOOR_2_PARTY_SPAWN_POS + Vector2(-60, 16), "cool_npc")
	
	if GameManager.is_character_alive("cheerful_npc"):
		cheerful_npc = create_npc_visual(FLOOR_2_PARTY_SPAWN_POS + Vector2(36, 24), "cheerful_npc")
	
	if GameManager.is_character_alive("male_npc"):
		male_npc = create_npc_visual(FLOOR_2_PARTY_SPAWN_POS + Vector2(80, 4), "male_npc")
	
	if GameManager.is_character_alive("female_npc"):
		# 女伴和大家一起出发，之后会因吵架离群
		female_npc = create_npc_visual(FLOOR_2_PARTY_SPAWN_POS + Vector2(-12, -36), "female_npc")
	
	if GameManager.is_character_alive("timid_male"):
		# 余凡留在到达电梯旁，稍微偏离队伍（原地不动，等待其他人回来）
		timid_npc = create_npc_visual(TIMID_GUARD_POS, "timid_male")
		set_npc_speed_v1(timid_npc, 20.0)

## 判断鹿可是否正处于被锁定待救援状态（尚未被耳塞救下且仍在原地等待）。
## [return] 鹿可正在等待救援时为 true。
func _is_cheerful_waiting_for_rescue() -> bool:
	return cheerful_npc != null \
		and is_instance_valid(cheerful_npc) \
		and cheerful_npc.visible \
		and not cheerful_npc.is_following \
		and not _used_earplug \
		and (current_phase == Phase.CHEERFUL_DANGER or current_phase == Phase.DONE)

## 根据当前剧情阶段刷新各NPC的故事对话内容。
func _refresh_floor_2_npc_dialogues() -> void:
	if current_phase == Phase.EXPLORE:
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_explore_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_2", "talk_explore_cheerful")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_explore_male")
		set_npc_story_dialogue(timid_npc, "floor_2", "talk_explore_timid")
		return
	if current_phase == Phase.RULE_DISCOVER:
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_rule_discover_cool")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_rule_discover_male")
		set_npc_story_dialogue(female_npc, "floor_2", "talk_rule_discover_female")
		return
	if _is_cheerful_waiting_for_rescue():
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_cheerful_danger_cool")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_cheerful_danger_male")
		return
	if current_phase == Phase.SEARCH:
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_search_cool")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_search_male")
		set_npc_story_dialogue(cheerful_npc, "floor_2", "talk_search_cheerful")
		return
	if current_phase == Phase.DONE and elevator_card_found:
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_done_cool")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_done_male")
		set_npc_story_dialogue(cheerful_npc, "floor_2", "talk_done_cheerful")
		return
	if current_phase == Phase.DONE:
		set_npc_story_dialogue(cool_npc, "floor_2", "talk_search_cool")
		set_npc_story_dialogue(male_npc, "floor_2", "talk_search_male")
		set_npc_story_dialogue(cheerful_npc, "floor_2", "talk_search_cheerful")

## 为所有存活NPC点亮手机灯光。
func _enable_npc_phone_lights() -> void:
	for npc in [cool_npc, cheerful_npc, male_npc, female_npc, timid_npc]:
		if npc and is_instance_valid(npc) and npc.is_alive:
			npc.enable_phone_light()

## 点亮NPC手机灯并让队伍成员在走廊内随机徘徊探索（沈薇已离队、余凡留守电梯口，均不参与）。
func _start_npc_wandering() -> void:
	_enable_npc_phone_lights()
	var wandering_npcs: Array[Node2D] = []
	if cool_npc:
		wandering_npcs.append(cool_npc)
	if cheerful_npc:
		wandering_npcs.append(cheerful_npc)
	if male_npc:
		wandering_npcs.append(male_npc)
	# 沈薇已离队，不参与闲逛
	for npc in wandering_npcs:
		_wander_loop(npc)
	# 余凡留在电梯口，不移动（起点就是电梯口，他就站在原地）

## 停止所有NPC的徘徊移动，并让余凡停止踱步。
func _stop_all_wandering() -> void:
	for npc_ref in _wander_tweens:
		if is_instance_valid(npc_ref):
			npc_ref.stop_walking()
	_wander_tweens.clear()
	_stop_timid_guard_pacing()

## 让胆小男余凡回到电梯口守卫位并开始小范围踱步等待队友。
func _start_timid_guard_pacing() -> void:
	if timid_npc == null or not is_instance_valid(timid_npc):
		return
	_stop_timid_guard_pacing()
	timid_npc.global_position = TIMID_GUARD_POS
	_timid_pacing_active = true
	_timid_guard_pacing_loop()

## 停止余凡在电梯口的踱步。
func _stop_timid_guard_pacing() -> void:
	_timid_pacing_active = false
	if timid_npc and is_instance_valid(timid_npc):
		timid_npc.stop_walking()

## 余凡的踱步循环：绕电梯口附近的几个点位缓慢走动，走完一轮后自动重复。
func _timid_guard_pacing_loop() -> void:
	if not _timid_pacing_active or timid_npc == null or not is_instance_valid(timid_npc):
		return
	var targets = [
		TIMID_GUARD_POS + Vector2(0, -16),
		TIMID_GUARD_POS + Vector2(16, -4),
		TIMID_GUARD_POS + Vector2(12, 16),
		TIMID_GUARD_POS + Vector2(-8, 20),
		TIMID_GUARD_POS + Vector2(-18, 2),
	]
	for target in targets:
		if not _timid_pacing_active or timid_npc == null or not is_instance_valid(timid_npc):
			return
		timid_npc.walk_to(target)
		await timid_npc.walk_completed
		await get_tree().create_timer(0.35).timeout
	if _timid_pacing_active:
		_timid_guard_pacing_loop()

## 停止指定NPC的徘徊并将其移出徘徊记录。
## [param npc] 要停止徘徊的NPC节点。
func _stop_npc_wander(npc: Node2D) -> void:
	if _wander_tweens.has(npc):
		if is_instance_valid(npc):
			npc.stop_walking()
		_wander_tweens.erase(npc)

## 单个NPC的徘徊循环：随机取走廊内目标点走过去，停留数秒后继续，直到被停止或场景退出。
## [param npc] 执行徘徊的NPC节点。
func _wander_loop(npc: Node2D) -> void:
	if not is_instance_valid(npc) or not npc.is_inside_tree():
		return
	if _exiting:
		return
	var target = Vector2(
		randf_range(PARTY_WANDER_MIN.x, PARTY_WANDER_MAX.x),
		randf_range(PARTY_WANDER_MIN.y, PARTY_WANDER_MAX.y)
	)
	_wander_tweens[npc] = true
	npc.walk_to(target)
	await npc.walk_completed
	if _exiting or not is_instance_valid(npc) or not _wander_tweens.has(npc):
		return
	await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
	if not _exiting and is_instance_valid(npc) and _wander_tweens.has(npc):
		_wander_loop(npc)

## 播放巨型高跟鞋从天而降砸向目标点的致命一击演出（急速坠落→轰然落地→淡出消失）。
## [param world_pos] 高跟鞋落点的世界坐标。
func _play_heel_strike(world_pos: Vector2) -> void:
	if high_heel_visual == null:
		return
	high_heel_visual.visible = true
	high_heel_visual.modulate = Color(1.0, 1.0, 1.0, 0.0)
	high_heel_visual.scale = Vector2(0.72, 0.72)
	high_heel_visual.global_position = world_pos + Vector2(0, -480)
	var drop_tw = create_tween()
	drop_tw.tween_property(high_heel_visual, "modulate:a", 1.0, 0.03)
	drop_tw.parallel().tween_property(high_heel_visual, "global_position", world_pos + Vector2(0, -12), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	drop_tw.parallel().tween_property(high_heel_visual, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop_tw.finished
	AudioManager.play_sfx(_heel_sfx, 2.0)
	ScreenEffects.death_impact()
	var vanish_tw = create_tween()
	vanish_tw.tween_interval(0.03)
	vanish_tw.tween_property(high_heel_visual, "modulate:a", 0.0, 0.07)
	vanish_tw.parallel().tween_property(high_heel_visual, "scale", Vector2(0.92, 0.92), 0.07)
	await vanish_tw.finished
	high_heel_visual.visible = false
	high_heel_visual.scale = Vector2.ONE

## 在指定位置放置电梯卡拾取物，玩家捡到后标记本层通关并刷新NPC对话。
## [param pos] 电梯卡掉落的世界坐标。
func _place_elevator_card(pos: Vector2) -> void:
	var card_area = create_elevator_card_pickup(pos)
	card_area.picked_up.connect(func():
		elevator_card_found = true
		current_phase = Phase.DONE
		_refresh_floor_2_npc_dialogues()
	)

## 搭建离开第二层的电梯：门体视觉、阻挡与触发区，需持有电梯卡且剧情推进到位才能进入。
func _build_elevator() -> void:
	var door_center := Vector2(740, 80)
	var door_size := Vector2(144, 120)
	var elevator_area = create_trigger_area(door_center + Vector2(0, 80), Vector2(door_size.x, 48))
	add_elevator_door_visual(door_center, door_size)
	add_elevator_door_blocker(door_center, door_size)
	
	var elev_label = create_world_label(LocaleManager.world_text("电梯"), Vector2(716, 36), 20, Color(0.5, 0.5, 0.5))
	
	elevator_area.body_entered.connect(func(body):
		if body.is_in_group("player") and elevator_card_found and current_phase >= Phase.CHEERFUL_DANGER:
			_enter_elevator()
	)

# ===== 入场 =====
## 入场剧情：手机没电的抱怨、与沈薇争吵致其赌气离队，随后众人自由探索并启动余凡的死亡倒计时。
func _entry_sequence() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 手机没电提示
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "phone_dead"))
	await DialogueManager.dialogue_ended
	
	# 第一段对话：到沈薇说"真可笑"
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "entry"))
	await DialogueManager.dialogue_ended
	
	# 沈薇吵完赌气离队，边对话边走
	if female_npc:
		_stop_npc_wander(female_npc)
		female_npc.walk_to(Vector2(0, -700))  # 走向地图上方消失
	
	# 第二段对话：沈薇甩手走人 + 剩余角色反应（沈薇边走边说）
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "entry_after"))
	await DialogueManager.dialogue_ended
	
	# 对话结束后隐藏沈薇
	if female_npc and is_instance_valid(female_npc):
		female_npc.stop_walking()
		female_npc.visible = false
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	
	# 对话结束后NPC才开始探索（余凡原地不动）
	_start_npc_wandering()
	_start_timid_guard_pacing()
	_refresh_floor_2_npc_dialogues()
	
	# 先给玩家一点探索时间，之后只有真正离开余凡一段距离才触发死亡剧情
	await get_tree().create_timer(5.0).timeout
	_waiting_for_timid_distance = true

# ===== 胆小男之死 =====
## 胆小男余凡被高跟鞋杀死的剧情事件：咔哒声由远及近→对话铺垫→高跟鞋落下将他踩杀→掉落耳塞→规则「禁止离群」浮现。
func _timid_death_event() -> void:
	if current_phase != Phase.EXPLORE:
		return
	current_phase = Phase.TIMID_DEATH
	
	# 脚步声阶段玩家可以自由移动
	# 高跟鞋声由远及近（3次咔哒）
	_play_heel_approach(3, TIMID_SOUND_POS, true)
	await get_tree().create_timer(2.0).timeout
	
	# 对话/心理活动时冻结
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "timid_death"))
	await DialogueManager.dialogue_ended
	
	# 记录余凡死亡位置，用于掉落耳塞
	var timid_death_pos: Vector2 = timid_npc.global_position if timid_npc else Vector2(700, 260)
	if timid_npc:
		_stop_timid_guard_pacing()
		await _kill_with_heel(timid_npc)
	
	# 余凡死后，耳塞从他身上掉落（玩家回去查看才能捡到）
	_place_room_item(timid_death_pos + Vector2(30, 20), "earplug", "耳塞", Color(0.85, 0.85, 0.7))
	
	await get_tree().create_timer(1.0).timeout
	
	# 其他人听到了高跟鞋落地的巨响
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "sound_event"))
	await DialogueManager.dialogue_ended
	
	await get_tree().create_timer(1.0).timeout
	
	# 众人没有发现——但规则出现了
	ScreenEffects.rule_appear()
	GameManager.add_rule(LocaleManager.t("rule_floor_2"))
	await show_rule_paper_and_wait()
	_rule_discover_event()

# ===== 发现规则 → 发现女伴独自一人 =====
## 发现规则后的剧情：众人惊慌改为跟随玩家，鹿可暂时掉队隐藏，离队的沈薇现身上方区域，等待玩家接近触发她的死亡。
func _rule_discover_event() -> void:
	current_phase = Phase.RULE_DISCOVER
	
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "rule_discover"))
	await DialogueManager.dialogue_ended
	
	show_hint(LocaleManager.t("hint_f2_scream"), 6.0)
	
	# 停止所有徘徊，切换为跟随模式
	_stop_all_wandering()
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	
	# NPC跟随玩家
	if cool_npc:
		cool_npc.start_following(player, Vector2(-60, 20))
	if male_npc:
		male_npc.start_following(player, Vector2(-80, 40))
	if cheerful_npc:
		# 鹿可暂时隐藏（迟到）
		cheerful_npc.visible = false
		cheerful_npc.set_physics_process(false)
	
	# 沈薇出现在地图上方（房间区域），开始往下走
	if female_npc:
		female_npc.global_position = Vector2(0, -520)
		female_npc.visible = true
		female_npc.walk_to(Vector2(0, -200))
	
	# 上方传来高跟鞋声，进一步暗示沈薇所在方向
	_refresh_floor_2_npc_dialogues()
	_play_heel_approach(2)

	# 等待玩家接近沈薇（距离 < 200px 触发）
	_waiting_for_female_proximity = true

# ===== 女伴之死 =====
## 女伴沈薇之死的剧情事件：高跟鞋声逼近→她朝玩家狂奔呼救却在半途被踩杀→掉落电梯卡→迟到的鹿可登场。
func _female_death_event() -> void:
	current_phase = Phase.FEMALE_DEATH
	
	# 冻结玩家进入剧情
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 高跟鞋声由远及近
	_play_heel_approach(4)
	
	# 第一段对话：沈薇听到声音、恐慌、众人喊"快跑过来"
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "female_death_hear"))
	await DialogueManager.dialogue_ended
	
	# 对话结束——沈薇朝玩家冲过来，但还没靠近就被杀死了
	var fallback_pos = player.global_position + Vector2(0, -120)
	
	if female_npc:
		set_npc_speed_v1(female_npc, 90.0)
		female_npc.walk_to(player.global_position)  # 直接向玩家跑
	
	# 第二段对话：描述奔跑+高跟鞋落下（与奔跑同时进行）
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "female_death_run"))
	
	# 沈薇跑一小段后被高跟鞋杀死——还没到玩家身边
	await get_tree().create_timer(2.2).timeout
	var death_pos: Vector2 = female_npc.global_position if female_npc else fallback_pos
	
	if female_npc:
		female_npc.stop_walking()
		await _kill_with_heel(female_npc)
	
	# 等对话播完再继续
	if DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_ended
	
	# 沈薇死后，电梯卡从她身上掉落
	_place_elevator_card(death_pos)
	show_hint(LocaleManager.t("hint_f2_item_dropped"), 5.0)
	
	await get_tree().create_timer(2.0).timeout
	
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "female_death_aftermath"))
	await DialogueManager.dialogue_ended
	
		# 鹿可迟到登场（从她之前徘徊的位置走过来，不重置位置）
	if cheerful_npc:
		cheerful_npc.visible = true
		cheerful_npc.set_physics_process(true)
		cheerful_npc.walk_to(player.global_position + Vector2(-80, 20))
		await cheerful_npc.walk_completed
		DialogueManager.start_dialogue(StoryText.lines("floor_2", "cheerful_waiting"))
		await DialogueManager.dialogue_ended
	
	await get_tree().create_timer(1.5).timeout
	_cheerful_danger_event()

# ===== 开朗NPC被锁定（跑得慢，掉队）=====
## 开朗NPC鹿可因跑得慢掉队被高跟鞋锁定的剧情：她吓得原地不敢动，等待玩家送来耳塞救援。
func _cheerful_danger_event() -> void:
	current_phase = Phase.CHEERFUL_DANGER
	
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "cheerful_danger"))
	await DialogueManager.dialogue_ended
	
	# 告诉鹿可先不要动
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "freeze_rescue"))
	await DialogueManager.dialogue_ended
	
	# 鹿可原地不动，设为可交互（玩家拿到耳塞后可以给她）
	if cheerful_npc:
		cheerful_npc.stop_walking()
		cheerful_npc.velocity = Vector2.ZERO
		cheerful_npc.set_dialogue([])  # 清空默认对话，用自定义interact
		_setup_cheerful_interact()
	
	# NPC跟随（鹿可除外）
	if cool_npc:
		cool_npc.start_following(player, Vector2(-50, 16))
	if male_npc:
		male_npc.start_following(player, Vector2(-70, 30))
	_refresh_floor_2_npc_dialogues()
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	show_hint(LocaleManager.t("hint_f2_cheerful_safe"), 6.0)
	_trigger_earplug_branch()

## 设置鹿可的求助对话，并在每次对话结束后检查耳塞救援条件。
func _setup_cheerful_interact() -> void:
	# 鹿可已在 interactable group，玩家按E会调 cheerful_npc.interact()
	# 设置对话 → 对话结束后检查耳塞
	if not cheerful_npc or not is_instance_valid(cheerful_npc):
		return
	cheerful_npc.set_dialogue(StoryText.lines("floor_2", "cheerful_worried"))
	# 对话结束后检查
	var _cb = func():
		if _used_earplug:
			return
		if not is_instance_valid(cheerful_npc):
			return
		if current_phase != Phase.CHEERFUL_DANGER:
			return
		# 对话结束后的下一帧检查耳塞
		await get_tree().create_timer(0.2).timeout
		_trigger_earplug_branch()
	DialogueManager.dialogue_ended.connect(_cb)
	_signal_callbacks.append({"signal": DialogueManager.dialogue_ended, "callable": _cb})

# 捡起耳塞 / 对话结束 / 鹿可原地等待后 调用，条件满足就触发耳塞分支
## 检查耳塞救援条件（持有耳塞、鹿可待救、无对话与状态冲突），全部满足则冻结玩家并进入耳塞分支。
func _trigger_earplug_branch() -> void:
	if _used_earplug or _earplug_branch_pending:
		return
	if not _is_cheerful_waiting_for_rescue():
		return
	if not InventoryManager.has_item("earplug"):
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if DialogueManager.is_dialogue_active:
		return
	_earplug_branch_pending = true
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	_earplug_branch.call_deferred()

## 耳塞救援分支：把耳塞给鹿可隔绝高跟鞋声助她脱险，她加入队伍并进入搜索阶段。
func _earplug_branch() -> void:
	if _used_earplug:
		_earplug_branch_pending = false
		return
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "earplug_branch"))
	await DialogueManager.dialogue_ended
	InventoryManager.remove_item("earplug")
	_used_earplug = true
	_earplug_branch_pending = false
	# 鹿可加入队伍
	if cheerful_npc:
		cheerful_npc.start_following(player, Vector2(-40, -24))
		set_npc_speed_v1(cheerful_npc, 80.0)
	_rescue_complete()

# ===== 救援后 → 找电梯卡 =====
## 救援结束的过渡：按电梯卡是否已被拾取分别进入完成或搜索阶段，并给出对应提示。
func _rescue_complete() -> void:
	# 如果玩家已经捡过电梯卡，直接进入DONE阶段
	if elevator_card_found:
		current_phase = Phase.DONE
		DialogueManager.start_dialogue(StoryText.lines("floor_2", "earplug_thanks"))
	else:
		current_phase = Phase.SEARCH
		DialogueManager.start_dialogue(StoryText.lines("floor_2", "rescue_complete"))
	await DialogueManager.dialogue_ended
	_refresh_floor_2_npc_dialogues()
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	if elevator_card_found:
		show_hint(LocaleManager.t("hint_f2_go_elevator"), 5.0)
	else:
		show_hint(LocaleManager.t("hint_f2_find_card"), 8.0)

## 未用耳塞路线的代价抽取：从常用物品池随机扣除最多两件，记入待损失清单供电梯内剧情结算。
func _roll_no_earplug_item_loss() -> void:
	var candidates: Array[String] = []
	for item_id in ITEM_LOSS_POOL:
		if InventoryManager.has_item(item_id):
			candidates.append(item_id)
	if candidates.is_empty():
		GameManager.pending_item_loss.clear()
		return
	candidates.shuffle()
	var removed_items: Array[String] = []
	var remove_count: int = min(2, candidates.size())
	for i in range(remove_count):
		var item_id = candidates[i]
		InventoryManager.remove_item(item_id)
		removed_items.append(item_id)
	GameManager.pending_item_loss = removed_items

## 用高跟鞋踩杀指定NPC：播放砸落演出、登记角色死亡并将尸体淡出移除。
## [param npc] 被高跟鞋杀死的NPC。
func _kill_with_heel(npc: CharacterBody2D) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var death_pos := npc.global_position
	await _play_heel_strike(death_pos)
	GameManager.kill_character(npc.npc_id)
	var tw = create_tween()
	tw.tween_property(npc, "modulate", Color(0.8, 0, 0), 0.08)
	tw.tween_property(npc, "modulate:a", 0.0, 0.16)
	await tw.finished
	npc.queue_free()

## 进入电梯剧情：刷卡开门；无耳塞路线中鹿可在渐强的高跟鞋声中一步步挪向电梯，千钧一发被拉入；有耳塞则直接乘梯前往第三层。
func _enter_elevator() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 刷卡进入电梯
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_card_use"))
	await DialogueManager.dialogue_ended
	
	# NPC停止跟随
	if cool_npc: cool_npc.stop_following()
	if cheerful_npc and _used_earplug: cheerful_npc.stop_following()
	if male_npc: male_npc.stop_following()
	
	if not _used_earplug and cheerful_npc:
		# 无耳塞：鹿可一直站在原地，叫她过来
		DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_no_earplug"))
		await DialogueManager.dialogue_ended
		
		# 鹿可一步一步缓缓走向电梯（分段移动 + 高跟鞋声渐强）
		var elevator_pos = Vector2(700, 200)
		var start_pos = cheerful_npc.position
		var step_count := 6
		
		for i in step_count:
			var t := float(i + 1) / step_count
			var step_target = start_pos.lerp(elevator_pos, t)
			
			# 每一步移动
			cheerful_npc.walk_to(step_target)
			await cheerful_npc.walk_completed
			
			# 高跟鞋声随步数渐强
			var vol := lerpf(-15.0, 0.0, t)
			AudioManager.play_sfx(_heel_sfx, vol)
			
			# 最后一步前——鹿可停下来
			if i == step_count - 2:
				DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_last_step"))
				await DialogueManager.dialogue_ended
			
			await get_tree().create_timer(0.3).timeout
		
		# 高跟鞋声骤然加速——逼近！
		_play_heel_approach(3)
		
		# 夏桐和林佳语同时拉住鹿可
		DialogueManager.start_dialogue(StoryText.lines("floor_2", "elevator_pull_in"))
		await DialogueManager.dialogue_ended
		_roll_no_earplug_item_loss()
		AudioManager.stop_playlist(0.15)
		AudioManager.stop_ambience()
		
		# 切到电梯内部场景，剩余剧情在里面播放
		TransitionManager.transition_to_scene("res://scenes/levels/elevator_f2_interior.tscn")
		return
	
	DialogueManager.start_dialogue(StoryText.lines("floor_2", "enter_elevator"))
	await DialogueManager.dialogue_ended
	
	await get_tree().create_timer(1.0).timeout
	AudioManager.stop_playlist(0.15)
	AudioManager.stop_ambience()
	TransitionManager.transition_to_scene("res://scenes/levels/floor_3.tscn")

## 高跟鞋由远及近音效（steps次咔哒，音量渐大，间隔渐短）
func _play_heel_approach(steps: int, sound_pos_override: Vector2 = Vector2.ZERO, use_override: bool = false) -> void:
	for i in steps:
		var vol := lerpf(-18.0, 0.0, float(i) / (steps - 1)) if steps > 1 else 0.0
		# 从沈薇位置播放（有左右声道空间感）
		var sound_pos := sound_pos_override if use_override else (female_npc.global_position if female_npc and is_instance_valid(female_npc) else Vector2(800, 160))
		AudioManager.play_sfx_at_position(sound_pos, _heel_sfx, vol)
		var interval := lerpf(0.8, 0.4, float(i) / (steps - 1)) if steps > 1 else 0.6
		await get_tree().create_timer(interval).timeout
