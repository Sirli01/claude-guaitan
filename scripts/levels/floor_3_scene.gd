@tool
extends LevelBaseV2
## 第三层 - 绝境逆转，借刀杀鬼
## 规则："禁止跑步 — 第三层"
## 威胁：人形怪物（缓步追杀）+ 深渊巨口（跑步触发）
## 高光：灵魂互换→操控怪物跑步→巨口吞噬→07:00灵魂回归

var cool_npc: CharacterBody2D
var cheerful_npc: CharacterBody2D
var male_npc: CharacterBody2D
var humanoid_monster: CharacterBody2D
var _monster_nav_agent: NavigationAgent2D = null

var monster_speed: float = 55.0
var monster_active: bool = false
var abyss_mouth_active: bool = false
var player_run_death_active: bool = false  # 玩家跑步死亡检测
var _run_detect_timer: float = 0.0
const RUN_DEATH_DELAY: float = 0.2  # 跑步后0.2秒触发死亡（快速惩罚，保留视觉反馈）
var _monster_hit_cooldown: float = 0.0  # 怪物碰撞冷却
var _entry_monster_seen: bool = false  # 是否已触发发现怪物的剧情
var _vending_kicks: int = 0  # 贩卖机已踢次数

# 怪物绕墙辅助（备用卡墙解除）
var _monster_stuck_timer: float = 0.0
var _monster_steer_dir: int = 0   # 0=直行, 1=左绕, -1=右绕
var _monster_steer_timer: float = 0.0
const MONSTER_STUCK_THRESHOLD: float = 0.5   # 0.5s 连续碰墙视为卡墙
const MONSTER_STEER_DURATION: float = 1.5    # 绕行持续 1.5s

# 音效
var _monster_step_sfx: AudioStream
var _rumble_sfx: AudioStream
var _monster_step_timer: float = 0.0
var _monster_wander_target: Vector2 = Vector2.ZERO
var _monster_wander_timer: float = 0.0

# 巨嘴音效
var _mouth_bite_sfx: AudioStream
var _mouth_move_sfx: AudioStream
var _mouth_move_timer: float = 0.0
const MOUTH_MOVE_INTERVAL: float = 1.2

# 追逐战变量
var chase_mouth: CharacterBody2D = null
var chase_mouth_speed: float = 90.0
var chase_timer: float = 0.0
var chase_duration: float = 20.0
var chase_active: bool = false
var _waiting_for_shift: bool = false
var chase_obstacles: Array[StaticBody2D] = []
var original_player_texture: Texture2D = null
var chase_countdown_label: Label = null
var _run_rule_revealed: bool = false  # 周瑞死后规则"禁止跑步"已揭示

const ABYSS_MOUTH_TEX_PATH := "res://assets/sprites/monsters/abyss_mouth.png"
const SHADOW_DISTORTION_SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform float sway_strength = 0.028;
uniform float ripple_strength = 0.014;
uniform float vertical_wobble = 0.010;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 2.7;
	uv.x += sin(uv.y * 11.0 + t * 2.4) * sway_strength;
	uv.x += sin(uv.y * 25.0 - t * 3.2) * ripple_strength;
	uv.y += sin(uv.x * 17.0 + t * 1.8) * vertical_wobble;
	vec4 col = texture(TEXTURE, uv) * COLOR;
	if (col.a < 0.02) {
		discard;
	}
	col.a *= 0.92 + 0.08 * sin(t * 1.4 + uv.y * 22.0);
	COLOR = col;
}
"""

enum Phase { EXPLORE, MALE_DEATH, MONSTER_CHASE, SOUL_SWAP_CUTSCENE, MONSTER_CONTROL, DAWN_RETURN, DONE }
var current_phase: Phase = Phase.EXPLORE
var elevator_card_found: bool = false

## 初始化第三层：注册楼层、预生成音效、构建怪物与场景元素，启用全游戏最暗的黑暗与「禁止跑步」规则，并启动入场流程。
func _ready() -> void:
	# 编辑器模式：几何与灯光已在 .tscn 中定义，无需生成
	if Engine.is_editor_hint():
		return

	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.change_floor(GameManager.Floor.FLOOR_3)
	GameManager.save_floor_entry_inventory()
	scene_audio_id = "floor_3"

	# 预生成程序化音效
	var _sfx_gen = preload("res://scripts/utils/procedural_sfx.gd")
	_monster_step_sfx = _sfx_gen.monster_step()
	_rumble_sfx = _sfx_gen.ground_rumble()
	_mouth_bite_sfx = load("res://assets/audio/sfx/巨嘴吼声.mp3")
	_mouth_move_sfx = load("res://assets/audio/sfx/巨嘴移动.wav")

	discover_scene_nodes()
	_setup_door_keys()
	_setup_container_actions()
	_add_room_labels()
	_add_floor_cracks()
	_place_search_prop(Vector2(-332, -248), Vector2(18, 10), "残破日记", Color(0.5, 0.45, 0.3, 0.75), "_on_diary_found")
	_build_corridor_obstacles()
	camera_bounds = Rect2(-465, -315, 930, 630)
	setup_player(Vector2(0, 220), 1.5)
	_shrink_player_to_v1()
	_build_arrival_elevator(Vector2(0, 220))
	player.walk_speed = 180.0  # 第三层步行稍慢，增加压迫感
	player.set_can_run(true)  # 允许跑但跑了会死
	_spawn_npcs()
	_build_monster()
	_build_abyss_mouths()
	_build_elevator()
	_place_exploration_items()
	_build_vending_machine(null)
	setup_ui("第三层")
	# 等物理帧完成后再开启房间检测，避免初始化阶段误判。
	await get_tree().physics_frame
	_room_detection_enabled = true
	# 所有墙壁生成完毕后烘焙导航网格（让怪物和NPC能绕过墙壁）
	setup_navigation(Rect2(-920, -620, 1840, 1240))
	
	# 启用体力系统和黑暗（第三层最暗）
	enable_stamina()
	enable_darkness(0.06, 2.0)
	
	# 手机没电
	if player_lighting:
		player_lighting.disable_phone_power()
	
	# 第三层BGM播放列表（2首轮播）
	var bgm_tracks: Array[AudioStream] = []
	for path in ["res://assets/audio/bgm/第三层bgm.mp3", "res://assets/audio/bgm/第三层bgm2.mp3"]:
		if ResourceLoader.exists(path):
			bgm_tracks.append(load(path))
	if not bgm_tracks.is_empty():
		AudioManager.play_playlist(bgm_tracks, 1.0, 1.5)
	
	# 第三层规则「禁止跑步」从进入就生效
	player_run_death_active = true
	
	# 读档时跳过入场动画，直接可以行动，NPC跟随玩家
	if SaveManager.is_loading_save:
		monster_active = true
		# NPC跟随玩家（同入场后状态一致）
		if male_npc:
			male_npc.start_following(player, Vector2(40, -20))
		if cool_npc:
			cool_npc.start_following(player, Vector2(-60, 30))
		if cheerful_npc:
			cheerful_npc.start_following(player, Vector2(-50, -40))
		_refresh_floor_3_npc_dialogues()
		return
	
	# 入场前冻结玩家，防止按住Shift冲出去
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 入场：先播放电梯开门短对话，然后玩家自由探索
	await get_tree().create_timer(0.5).timeout
	_entry_intro()

## 为 304 门设置所需钥匙（门由 GameDoor 场景节点在 discover 时构建）
func _setup_door_keys() -> void:
	var dc_script: Script = load("res://scripts/items/door_controller.gd")
	for child in get_children():
		if child is Area2D and child.get_script() == dc_script and child.position == Vector2(280, -149):
			child.set_meta("required_key", "room_304_key")

## 为电梯卡容器挂接拿到卡后的剧情回调
func _setup_container_actions() -> void:
	var fc_script: Script = load("res://scripts/items/furniture_container.gd")
	for child in get_children():
		if child is Area2D and child.get_script() == fc_script and child.contained_item_id == "elevator_card":
			child.post_take_action_method = "_on_elevator_card_container_taken"

## 创建各房间名称的世界标签（多语言文本需运行时解析，故由代码创建）
func _add_room_labels() -> void:
	_add_room_label("301", Vector2(-420, -270))
	_add_room_label("304", Vector2(330, -270))
	_add_room_label("302", Vector2(70, -2))

## 创建单个房间名称标签（静态文字 Label，与原实现一致）。
## [param text] 房间名。[param pos] 标签位置。
func _add_room_label(text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.15))
	add_child(label)

## 地板裂缝装饰（随机长度，暗示深渊巨口；属运行时氛围特效，故动态创建）
func _add_floor_cracks() -> void:
	for i in range(4):
		var crack := ColorRect.new()
		crack.color = Color(0.02, 0.0, 0.02)
		crack.position = Vector2(-150 + i * 100, -150 + i * 80)
		crack.size = Vector2(randi_range(30, 60), 3)
		add_child(crack)

## 按存活状态生成本层NPC：夏桐、林佳语与周锐。
func _spawn_npcs() -> void:
	if GameManager.is_character_alive("cool_npc"):
		cool_npc = create_npc_visual(Vector2(30, 230), "cool_npc", 0.5)

	if GameManager.is_character_alive("cheerful_npc"):
		cheerful_npc = create_npc_visual(Vector2(-30, 215), "cheerful_npc", 0.5)

	if GameManager.is_character_alive("male_npc"):
		male_npc = create_npc_visual(Vector2(15, 205), "male_npc", 0.5)

## 为所有存活NPC点亮手机灯光。
func _enable_npc_phone_lights() -> void:
	for npc in [cool_npc, cheerful_npc, male_npc]:
		if npc and is_instance_valid(npc) and npc.is_alive:
			npc.enable_phone_light()

## 根据当前剧情阶段刷新各NPC的故事对话（入场介绍、探索、逃离与胜利各有不同台词）。
func _refresh_floor_3_npc_dialogues() -> void:
	if current_phase == Phase.EXPLORE and male_npc and is_instance_valid(male_npc) and not _entry_monster_seen:
		set_npc_story_dialogue(cool_npc, "floor_3", "talk_intro_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_3", "talk_intro_cheerful")
		set_npc_story_dialogue(male_npc, "floor_3", "talk_intro_male")
		return
	if current_phase == Phase.EXPLORE:
		set_npc_story_dialogue(cool_npc, "floor_3", "talk_explore_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_3", "talk_explore_cheerful")
		return
	if current_phase == Phase.DONE and (monster_active or (humanoid_monster and is_instance_valid(humanoid_monster))):
		set_npc_story_dialogue(cool_npc, "floor_3", "talk_escape_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_3", "talk_escape_cheerful")
		return
	if current_phase == Phase.DONE:
		set_npc_story_dialogue(cool_npc, "floor_3", "talk_victory_cool")
		set_npc_story_dialogue(cheerful_npc, "floor_3", "talk_victory_cheerful")

## 构建人形怪物：闪烁红眼、脉动红光与导航寻路代理，激活后将在黑暗中缓步追杀玩家。
func _build_monster() -> void:
	humanoid_monster = CharacterBody2D.new()
	humanoid_monster.position = Vector2(0, -260)
	humanoid_monster.collision_layer = 16
	humanoid_monster.collision_mask = 5
	add_child(humanoid_monster)
	
	# ART: 怪物精灵（替换素材请改 SPRITE_PATHS["humanoid_monster"]）
	var sprite = Sprite2D.new()
	sprite.texture = GameManager.load_char_texture("humanoid_monster", 18, 26)
	GameManager.fit_character_sprite(sprite, "humanoid_monster")
	_apply_shadow_distortion(sprite)
	# 第三层世界为 v1 尺度，角色贴图已全局放大 2 倍，此处缩回
	sprite.scale *= 0.5
	humanoid_monster.add_child(sprite)
	var using_custom_monster_art := GameManager.get_character_sprite_path("humanoid_monster") != "" and ResourceLoader.exists(GameManager.get_character_sprite_path("humanoid_monster"))
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 10)
	col.shape = shape
	humanoid_monster.add_child(col)
	
	if not using_custom_monster_art:
		# 怪物眼睛闪烁（本层世界为 v1 尺度，位置随角色缩回）
		var eye = ColorRect.new()
		eye.color = Color(0.9, 0.1, 0.1)
		eye.position = Vector2(-1.5, -9)
		eye.size = Vector2(1, 1)
		humanoid_monster.add_child(eye)
		var eye2 = ColorRect.new()
		eye2.color = Color(0.9, 0.1, 0.1)
		eye2.position = Vector2(1.5, -9)
		eye2.size = Vector2(1, 1)
		humanoid_monster.add_child(eye2)
		var tw = create_tween().set_loops()
		_loop_tweens.append(tw)
		tw.tween_property(eye, "modulate:a", 0.3, 0.5)
		tw.tween_property(eye, "modulate:a", 1.0, 0.5)
	
	# 怪物红光（让玩家在黑暗中能看到它的位置）
	var light = PointLight2D.new()
	light.color = Color(0.8, 0.1, 0.05)
	light.energy = 2.5
	var light_tex_path = "res://assets/sprites/effects/light_gradient.png"
	if ResourceLoader.exists(light_tex_path):
		light.texture = load(light_tex_path)
	else:
		light.texture = _create_light_texture()
	light.texture_scale = 2.0
	light.position = Vector2(0, -7.5)
	humanoid_monster.add_child(light)
	
	# 红光微弱脉动
	var light_tw = create_tween().set_loops()
	_loop_tweens.append(light_tw)
	light_tw.tween_property(light, "energy", 1.5, 1.2)
	light_tw.tween_property(light, "energy", 2.5, 1.2)
	
	# 寻路代理（让怪物能绕过墙壁追玩家）
	_monster_nav_agent = NavigationAgent2D.new()
	_monster_nav_agent.path_desired_distance = 10.0
	_monster_nav_agent.target_desired_distance = 18.0
	_monster_nav_agent.avoidance_enabled = false
	humanoid_monster.add_child(_monster_nav_agent)

## 将玩家贴图与碰撞缩回 v1 比例（本层世界未随全局放大）。
func _shrink_player_to_v1() -> void:
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale *= 0.5
	var col: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	if col and col.shape:
		col.shape = col.shape.duplicate()
		col.shape.size *= 0.5
		col.position *= 0.5

## 深渊巨口的预留构建入口（跑步触发的检测实际由 _physics_process 完成）。
func _build_abyss_mouths() -> void:
	# 地板下的深渊巨口触发区域（整个走廊都是）
	# 只有跑步时才会触发
	pass  # 在_physics_process中检测

## 搭建离开第三层的电梯：门体视觉与交互区，靠近时按有无电梯卡显示不同提示。
func _build_elevator() -> void:
	var elevator_area = create_trigger_area(Vector2(-380, 220), Vector2(30, 40))
	
	add_elevator_door_visual(Vector2(-380, 220), Vector2(30, 40))
	
	var elev_label = create_world_label(LocaleManager.world_text("电梯"), Vector2(-392, 190), 20, Color(0.5, 0.5, 0.5))
	
	# 电梯交互区域（玩家靠近时可按 E 进入）
	var elev_interact = Area2D.new()
	elev_interact.position = Vector2(-380, 220)
	elev_interact.collision_layer = 16
	elev_interact.add_to_group("interactable")
	add_child(elev_interact)
	
	var elev_col = CollisionShape2D.new()
	var elev_shape = RectangleShape2D.new()
	elev_shape.size = Vector2(40, 50)
	elev_col.shape = elev_shape
	elev_interact.add_child(elev_col)
	
	var elev_hint = create_world_label(LocaleManager.t("elevator_label_has_card") % InputDevice.hint("interact"), Vector2(-400, 190), 18, Color(0.9, 0.8, 0.5))
	elev_hint.visible = false
	
	elev_interact.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if elevator_card_found:
				elev_hint.text = LocaleManager.t("elevator_label_has_card") % InputDevice.hint("interact")
				elev_hint.visible = true
			else:
				elev_hint.text = LocaleManager.t("elevator_label_no_card")
				elev_hint.visible = true
	)
	elev_interact.body_exited.connect(func(body):
		if body.is_in_group("player"):
			elev_hint.visible = false
	)
	
	# 定义interact方法
	var level_ref = self
	elev_interact.set_meta("level", level_ref)
	elev_interact.set_meta("hint_label", elev_hint)
	var interact_script = GDScript.new()
	interact_script.source_code = """extends Area2D

func interact() -> void:
	var level = get_meta("level")
	if level.elevator_card_found:
		level._enter_elevator()
	else:
		level.show_hint(LocaleManager.t("hint_need_card"))
"""
	interact_script.reload()
	elev_interact.set_script(interact_script)

## 每帧驱动本层核心逻辑：怪物入镜触发发现剧情、玩家跑步致死检测、怪物导航追踪与距离音效、追逐战中巨口的追击与胜负判定。
## [param delta] 帧间隔时间（秒）。
func _physics_process(delta: float) -> void:
	# === 怪物进入视野 → 触发发现剧情 ===
	if not _entry_monster_seen and humanoid_monster and player and player.camera:
		if GameManager.current_state == GameManager.GameState.PLAYING:
			if _is_monster_on_screen():
				_entry_monster_seen = true
				_entry_sequence()
	
	# === 等待玩家长按奔跑后生成巨口 ===
	if _waiting_for_shift and player and player.is_running:
		_waiting_for_shift = false
		_spawn_chase_mouth()
		chase_active = true
		chase_timer = 0.0
	
	# === 玩家跑步死亡检测（持续跑0.5秒后触发）===
	if player_run_death_active and player:
		# 只在PLAYING状态下检测，避免和入场剧情/其他对话冲突
		if GameManager.current_state != GameManager.GameState.PLAYING:
			_run_detect_timer = 0.0
		elif player.is_running:
			_run_detect_timer += delta
			if _run_detect_timer >= RUN_DEATH_DELAY:
				_player_run_death()
				return
		else:
			_run_detect_timer = 0.0
	
	if monster_active and humanoid_monster and player:
		# 碰撞冷却计时
		if _monster_hit_cooldown > 0:
			_monster_hit_cooldown -= delta
		
		# 对话/过场期间怪物暂停并保持距离
		if GameManager.current_state == GameManager.GameState.CUTSCENE or GameManager.current_state == GameManager.GameState.DIALOGUE:
			humanoid_monster.velocity = Vector2.ZERO
			var dist = humanoid_monster.global_position.distance_to(player.global_position)
			if dist < 60.0:
				var away = (humanoid_monster.global_position - player.global_position).normalized()
				humanoid_monster.global_position += away * (60.0 - dist)
		else:
			# 怪物追踪玩家（NavigationAgent2D 绕墙 + 碰撞撞墙检测备用）
			var to_player = player.global_position - humanoid_monster.global_position
			var desired_dir = to_player.normalized()
			var move_dir: Vector2


			# ��������뷿�䣬��򶪳�תΪ������䣨���ⶾ�������棩
			var _in_room := _current_room_id != ""
			if _in_room:
				# ��������ģʽ
				_monster_wander_timer -= delta
				if _monster_wander_target == Vector2.ZERO or _monster_wander_timer <= 0.0 or humanoid_monster.global_position.distance_to(_monster_wander_target) < 30.0:
					_monster_wander_target = Vector2(randf_range(-380.0, 380.0), randf_range(-280.0, 200.0))
					_monster_wander_timer = randf_range(2.0, 5.0)
				if _monster_nav_agent:
					_monster_nav_agent.target_position = _monster_wander_target
					var next_pos = _monster_nav_agent.get_next_path_position()
					if next_pos.distance_squared_to(humanoid_monster.global_position) > 4.0:
						move_dir = (next_pos - humanoid_monster.global_position).normalized()
					else:
						move_dir = (_monster_wander_target - humanoid_monster.global_position).normalized()
				else:
					move_dir = (_monster_wander_target - humanoid_monster.global_position).normalized()
			else:
				# ����ģʽ��׷�����
				if _monster_nav_agent:
					_monster_nav_agent.target_position = player.global_position
					var next_pos = _monster_nav_agent.get_next_path_position()
					if next_pos.distance_squared_to(humanoid_monster.global_position) > 4.0:
						move_dir = (next_pos - humanoid_monster.global_position).normalized()
					else:
						move_dir = desired_dir
				else:
					move_dir = desired_dir
			# 正在绕行：叠加侧向分量
			if _monster_steer_dir != 0:
				var perp = Vector2(-desired_dir.y, desired_dir.x) * _monster_steer_dir
				move_dir = (desired_dir + perp * 1.5).normalized()
				_monster_steer_timer += delta
				if _monster_steer_timer >= MONSTER_STEER_DURATION:
					_monster_steer_dir = 0
					_monster_steer_timer = 0.0
			
			humanoid_monster.velocity = move_dir * monster_speed
			humanoid_monster.move_and_slide()
			
			# 卡墙检测：连续撞墙 0.5s 后随机选方向绕行
			if _monster_steer_dir == 0 and to_player.length() > 40.0:
				if humanoid_monster.get_slide_collision_count() > 0:
					_monster_stuck_timer += delta
					if _monster_stuck_timer >= MONSTER_STUCK_THRESHOLD:
						_monster_steer_dir = 1 if randf() > 0.5 else -1
						_monster_steer_timer = 0.0
						_monster_stuck_timer = 0.0
				else:
					_monster_stuck_timer = 0.0
			
			# 怪物距离音效：越近越响、越频繁
			var dist_to_player = humanoid_monster.global_position.distance_to(player.global_position)
			_monster_step_timer += delta
			var step_interval := lerpf(1.2, 0.4, clampf(1.0 - dist_to_player / 300.0, 0.0, 1.0))
			if _monster_step_timer >= step_interval:
				_monster_step_timer = 0.0
				var vol := lerpf(-25.0, -3.0, clampf(1.0 - dist_to_player / 300.0, 0.0, 1.0))
				AudioManager.play_sfx(_monster_step_sfx, vol)
				# 怪物脚步震动：越近越强
				var rumble_str := clampf(1.0 - dist_to_player / 250.0, 0.0, 1.0)
				if rumble_str > 0.1:
					InputDevice.vibrate(rumble_str * 0.15, rumble_str * 0.4, step_interval * 0.8)
			
			# 怪物靠近时信号干扰效果
			if atmosphere and dist_to_player < 200.0:
				var interference_str = clampf((200.0 - dist_to_player) / 200.0, 0.0, 1.0)
				atmosphere.set_interference(interference_str * 0.6, 0.2)
			elif atmosphere:
				atmosphere.stop_interference(0.3)
			
			# 检测怪物是否接近玩家
			if dist_to_player < 28.0:
				if current_phase == Phase.MONSTER_CHASE:
					_trigger_soul_swap_cutscene()
				elif (current_phase == Phase.EXPLORE or current_phase == Phase.DONE) and _monster_hit_cooldown <= 0:
					# 碰到怪物：理智伤害 + 玩家被击退 + 2秒冷却
					_monster_hit_cooldown = 2.0
					var knockback = (player.global_position - humanoid_monster.global_position).normalized()
					player.on_monster_hit(knockback, 40.0)
					ScreenEffects.hit_impact()
	
	# === 追逐战逻辑 ===
	if chase_active and chase_mouth and player:
		chase_timer += delta
		_mouth_move_timer -= delta
		if _mouth_move_timer <= 0.0:
			AudioManager.play_sfx(_mouth_move_sfx, -3.0)
			_mouth_move_timer = MOUTH_MOVE_INTERVAL

		# 巨口加速追赶：越到后面越快
		var speed_mult = 1.0 + chase_timer / chase_duration * 0.6
		var effective_speed = chase_mouth_speed * speed_mult

		# 巨口直接朝玩家移动（不碰撞墙壁，避免被卡在房间里）
		var to_player = player.global_position - chase_mouth.global_position
		var move_dist = effective_speed * delta

		var new_pos: Vector2
		if to_player.length() > 30:
			new_pos = chase_mouth.global_position.move_toward(player.global_position, move_dist)
		else:
			new_pos = chase_mouth.global_position.move_toward(player.global_position, move_dist * 0.5)

		# 贩卖机碰撞检测（保留大厅障碍物阻挡）
		var vm_body = get_node_or_null("VendingMachineBody")
		if vm_body:
			var vm_half = Vector2(14, 22)
			var vm_box = Rect2(vm_body.global_position - vm_half, vm_half * 2)
			var mouth_r = 20.0
			if vm_box.has_point(new_pos) or vm_box.grow(mouth_r).has_point(new_pos):
				# 尝试水平/垂直滑动绕过贩卖机
				var slide_x = chase_mouth.global_position + Vector2(sign(to_player.x) * move_dist, 0)
				var slide_y = chase_mouth.global_position + Vector2(0, sign(to_player.y) * move_dist)
				var slide_box = vm_box.grow(mouth_r)
				if not slide_box.has_point(slide_x):
					new_pos = slide_x
				elif not slide_box.has_point(slide_y):
					new_pos = slide_y
				else:
					new_pos = chase_mouth.global_position  # 卡住，等待玩家移动

		chase_mouth.global_position = new_pos

		# 碰撞检测：巨口碰到玩家
		if new_pos.distance_to(player.global_position) < 45.0:
			_chase_caught()
			return

		# 更新倒计时
		_update_chase_hud()

		# 20秒后触发7:00结局
		if chase_timer >= chase_duration:
			_chase_survive()

## 入场短对话：电梯开门众人感受压抑气氛，结束后NPC跟随玩家、怪物开始从走廊深处逼近。
func _entry_intro() -> void:
	# 入场短对话（电梯开门，感受气氛）
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "entry"))
	await DialogueManager.dialogue_ended
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	await get_tree().create_timer(0.3).timeout
	
	# 对话结束后玩家自由移动，NPC跟随
	if male_npc:
		male_npc.start_following(player, Vector2(20, -10))
	if cool_npc:
		cool_npc.start_following(player, Vector2(-30, 15))
	if cheerful_npc:
		cheerful_npc.start_following(player, Vector2(-25, -20))
	
	# 怪物开始从走廊深处缓缓向玩家移动
	monster_active = true
	_refresh_floor_3_npc_dialogues()
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()

## 发现怪物的剧情：众人瞥见走廊深处的人影，周锐当场崩溃逃跑，引出他的死亡事件。
func _entry_sequence() -> void:
	# 看到怪物时触发（从_physics_process调用）
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "entry2"))
	await DialogueManager.dialogue_ended
	
	# 男伴恐慌逃跑
	current_phase = Phase.MALE_DEATH
	_male_panic_event()

## 周锐死后的探索阶段：启用跑步致死检测、剩余NPC跟随玩家，并提示寻找电梯卡但绝不能跑。
func _after_male_death_explore() -> void:
	# 男伴死后进入探索阶段
	current_phase = Phase.EXPLORE
	player_run_death_active = true  # 启用跑步死亡检测
	
	# 确保玩家可以跑步（跑了会被大嘴吃掉）
	player.set_can_run(true)
	PlayerStats.set_stamina(PlayerStats.max_stamina)  # 重置体力防止遗留耗尽
	
	# 让其他NPC跟随玩家
	if cool_npc:
		cool_npc.start_following(player, Vector2(-30, 15))
	if cheerful_npc:
		cheerful_npc.start_following(player, Vector2(-25, -20))
	_enable_npc_phone_lights()
	_refresh_floor_3_npc_dialogues()
	
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	show_hint(LocaleManager.t("hint_f3_find_card_no_run"))

# === 玩家跑步 → 死亡 ===
## 玩家违反「禁止跑步」被深渊巨口吞噬的死亡演出：若规则已由周锐之死揭示则直接游戏结束，否则先播放黑屏旁白让规则浮现。
func _player_run_death() -> void:
	player_run_death_active = false
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 生成吞噬玩家的大嘴
	AudioManager.play_sfx(_rumble_sfx, -2.0)
	var death_mouth = _create_abyss_mouth_visual(player.global_position)
	AudioManager.play_sfx(_mouth_bite_sfx)
	ScreenEffects.abyss_impact()
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "player_run_death"))
	await DialogueManager.dialogue_ended
	
	# 玩家被吞
	var tw = create_tween()
	tw.tween_property(player, "scale", Vector2(0.05, 0.05), 0.3)
	tw.parallel().tween_property(player, "modulate:a", 0.0, 0.3)
	await tw.finished
	
	if death_mouth:
		var tw2 = create_tween()
		tw2.tween_property(death_mouth, "modulate:a", 0.0, 0.5)
		await tw2.finished
		death_mouth.queue_free()
	
	await get_tree().create_timer(0.8).timeout
	
	if _run_rule_revealed:
		# 规则已经在周瑞死时揭示过了：玩家明知故犯，直接游戏结束
		GameManager.go_to_game_over("abyss")
	else:
		# 规则尚未揭示：黑屏 + 规则浮现演出（玩家是第一个犯禁的人）
		var black_layer = CanvasLayer.new()
		black_layer.layer = 12
		add_child(black_layer)
		
		var black_bg = ColorRect.new()
		black_bg.color = Color(0.0, 0.0, 0.0, 1.0)
		black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		black_layer.add_child(black_bg)
		
		# 黑暗中的旁白文字（逐字浮现，白色）
		var narration = Label.new()
		narration.text = LocaleManager.t("floor3_dark_rule_narration")
		narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		narration.set_anchors_preset(Control.PRESET_CENTER)
		narration.offset_left = -300
		narration.offset_right = 300
		narration.offset_top = -50
		narration.offset_bottom = 50
		narration.add_theme_font_size_override("font_size", 28)
		narration.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		narration.visible_characters = 0
		black_layer.add_child(narration)
		
		# 逐字浮现动画
		var full_len = narration.text.length()
		var char_tw = create_tween()
		char_tw.tween_property(narration, "visible_characters", full_len, full_len * 0.08)
		await char_tw.finished
		
		# 添加"点击继续"提示
		var click_hint = Label.new()
		click_hint.text = LocaleManager.t("click_continue")
		click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		click_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		click_hint.offset_left = -100
		click_hint.offset_right = 100
		click_hint.offset_top = -60
		click_hint.offset_bottom = -30
		click_hint.add_theme_font_size_override("font_size", 20)
		click_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		black_layer.add_child(click_hint)
		
		# 等待玩家点击
		await _wait_for_click()
		
		# 移除旁白文字
		narration.queue_free()
		click_hint.queue_free()
		
		# 弹出规则纸 + 添加规则
		ScreenEffects.rule_appear()
		GameManager.add_rule(LocaleManager.t("rule_floor_3"))
		_run_rule_revealed = true
		await show_rule_paper_and_wait()
		
		# 规则纸关闭后 → 死亡界面
		await get_tree().create_timer(0.5).timeout
		black_layer.queue_free()
		GameManager.go_to_game_over("abyss")

# 等待玩家点击（鼠标或确认键）
## 轮询等待玩家点击鼠标或按下确认键以继续剧情。
func _wait_for_click() -> void:
	# 跳过当前帧残留输入
	await get_tree().process_frame
	await get_tree().process_frame
	# 轮询等待新输入
	while true:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			break
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
		await get_tree().process_frame

# === 生成吞噬用大嘴视觉（用于男伴死亡/玩家死亡）===
## 在指定位置生成深渊巨口的视觉表现（优先使用贴图，否则程序化绘制牙齿与咽喉，含红光脉动与弹出动画）。
## [param pos] 巨口出现的世界坐标。
## [return] 创建出的巨口节点。
func _create_abyss_mouth_visual(pos: Vector2) -> Node2D:
	var mouth = Node2D.new()
	mouth.position = pos + Vector2(0, 10)
	mouth.scale = Vector2(0.3, 0.3)
	add_child(mouth)

	var glow = PointLight2D.new()
	glow.color = Color(0.85, 0.08, 0.04)
	glow.energy = 2.8
	var glow_tex_path = "res://assets/sprites/effects/light_gradient.png"
	if ResourceLoader.exists(glow_tex_path):
		glow.texture = load(glow_tex_path)
	else:
		glow.texture = _create_light_texture()
	glow.texture_scale = 1.8
	glow.position = Vector2(0, -2)
	mouth.add_child(glow)
	var glow_tw = create_tween().set_loops()
	_loop_tweens.append(glow_tw)
	glow_tw.tween_property(glow, "energy", 1.9, 0.18)
	glow_tw.tween_property(glow, "energy", 3.2, 0.22)
	
	if ResourceLoader.exists(ABYSS_MOUTH_TEX_PATH):
		var mouth_sprite = Sprite2D.new()
		mouth_sprite.texture = load(ABYSS_MOUTH_TEX_PATH)
		mouth_sprite.centered = true
		var tex_size = mouth_sprite.texture.get_size()
		if tex_size.x > 0.0:
			mouth_sprite.scale = Vector2.ONE * (140.0 / tex_size.x)
		mouth.add_child(mouth_sprite)
	else:
		# 巨口主体
		var mouth_body = ColorRect.new()
		mouth_body.color = Color(0.02, 0.0, 0.02, 0.95)
		mouth_body.position = Vector2(-30, -35)
		mouth_body.size = Vector2(60, 70)
		mouth.add_child(mouth_body)
		# 牙齿上排
		for i in range(4):
			var tooth = ColorRect.new()
			tooth.color = Color(0.7, 0.7, 0.6, 0.8)
			tooth.position = Vector2(-25 + i * 14, -32)
			tooth.size = Vector2(5, 10)
			mouth.add_child(tooth)
		# 牙齿下排
		for i in range(4):
			var tooth = ColorRect.new()
			tooth.color = Color(0.7, 0.7, 0.6, 0.8)
			tooth.position = Vector2(-25 + i * 14, 24)
			tooth.size = Vector2(5, 10)
			mouth.add_child(tooth)
		# 深红色咽喉
		var throat = ColorRect.new()
		throat.color = Color(0.3, 0.0, 0.0, 0.7)
		throat.position = Vector2(-15, -18)
		throat.size = Vector2(30, 36)
		mouth.add_child(throat)
		var eye_left = ColorRect.new()
		eye_left.color = Color(0.95, 0.12, 0.08, 0.95)
		eye_left.position = Vector2(-16, -10)
		eye_left.size = Vector2(8, 6)
		mouth.add_child(eye_left)
		var eye_right = ColorRect.new()
		eye_right.color = Color(0.95, 0.12, 0.08, 0.95)
		eye_right.position = Vector2(8, -10)
		eye_right.size = Vector2(8, 6)
		mouth.add_child(eye_right)
		var eye_tw = create_tween().set_loops()
		_loop_tweens.append(eye_tw)
		eye_tw.tween_property(eye_left, "modulate:a", 0.45, 0.18)
		eye_tw.parallel().tween_property(eye_right, "modulate:a", 0.45, 0.18)
		eye_tw.tween_property(eye_left, "modulate:a", 1.0, 0.22)
		eye_tw.parallel().tween_property(eye_right, "modulate:a", 1.0, 0.22)
	
	# 弹出动画
	var tw = create_tween()
	tw.tween_property(mouth, "scale", Vector2(1.2, 1.2), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(mouth, "scale", Vector2(1.0, 1.0), 0.1)
	
	return mouth

## 预留的灯光布置接口（本层灯光已在场景中定义，无需额外处理）。
func _place_lights() -> void:
	pass

# === 探索阶段物品 ===
## 放置探索阶段的氛围物件：地板血迹及其触发区，玩家踏入即触发血迹剧情。
func _place_exploration_items() -> void:
	# --- 血迹 ---
	var blood = ColorRect.new()
	blood.color = Color(0.25, 0.02, 0.02, 0.6)
	blood.position = Vector2(180, -80)
	blood.size = Vector2(45, 18)
	add_child(blood)
	
	var blood_area = Area2D.new()
	blood_area.position = Vector2(200, -70)
	blood_area.collision_layer = 16
	add_child(blood_area)
	
	var blood_col = CollisionShape2D.new()
	var blood_shape = CircleShape2D.new()
	blood_shape.radius = 18.0
	blood_col.shape = blood_shape
	blood_area.add_child(blood_col)
	
	blood_area.body_entered.connect(func(body):
		if body.is_in_group("player") and current_phase == Phase.EXPLORE:
			blood_area.queue_free()
			_on_blood_found()
	)
	
	# 日记和电梯卡已改为房间内搜索获取。

## 搜出残破日记的剧情：暂停怪物行动，播放日记对话后恢复探索。
func _on_diary_found() -> void:
	player.freeze_player()
	var was_monster_active = monster_active
	monster_active = false
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	var d = StoryText.lines("floor_3", "diary")
	DialogueManager.start_dialogue(d)
	await DialogueManager.dialogue_ended
	monster_active = was_monster_active
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()

## 踩到血迹的剧情：暂停怪物行动，播放血迹对话后恢复探索。
func _on_blood_found() -> void:
	player.freeze_player()
	var was_monster_active = monster_active
	monster_active = false
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	var d = StoryText.lines("floor_3", "blood")
	DialogueManager.start_dialogue(d)
	await DialogueManager.dialogue_ended
	monster_active = was_monster_active
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()

# === 拿到卡后 ===
## 拿到电梯卡后的关键分支：背包里有绳子则想到借刀杀鬼的灵魂互换计划，否则只能徒步冲向电梯逃生。
func _card_found_monster_chase() -> void:
	player.freeze_player()
	player_run_death_active = false
	monster_active = false  # 对话期间怪物停止移动
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# NPC停止跟随
	if cool_npc:
		cool_npc.stop_following()
	if cheerful_npc:
		cheerful_npc.stop_following()
	
	if InventoryManager.has_item("rope"):
		# 有绳子 → 想到灵魂互换计划
		DialogueManager.start_dialogue(StoryText.lines("floor_3", "card_found"))
		await DialogueManager.dialogue_ended
		
		current_phase = Phase.MONSTER_CHASE
		player_run_death_active = false
		monster_active = false
		_trigger_soul_swap_cutscene()
	else:
		# 没有绳子 → 直接冲向电梯
		DialogueManager.start_dialogue(StoryText.lines("floor_3", "card_found_norope"))
		await DialogueManager.dialogue_ended
		
		current_phase = Phase.DONE
		monster_active = true  # 怪物继续追
		player_run_death_active = true  # 跑步仍致死
		
		# NPC跟随玩家一起逃
		if cool_npc:
			cool_npc.start_following(player, Vector2(15, 8))
		if cheerful_npc:
			cheerful_npc.start_following(player, Vector2(-15, 8))
		_refresh_floor_3_npc_dialogues()
		
		GameManager.set_state(GameManager.GameState.PLAYING)
		player.unfreeze_player()
		show_hint(LocaleManager.t("hint_f3_walk_to_elevator"), 8.0)

## 周锐恐慌逃跑被深渊巨口吞噬的剧情事件：他拔腿狂奔仍被破地而出的巨口吞食、掉落304钥匙，规则「禁止跑步」随他的死才正式揭示。
func _male_panic_event() -> void:
	if male_npc:
		male_npc.stop_following()
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "male_panic"))
	await DialogueManager.dialogue_ended
	
	# 男伴拔腿就跑（视觉表现：跑出一段距离再被吃）
	if male_npc:
		# 男伴恐慌往左跑，被地板巨口吐噬
		var run_target = male_npc.position + Vector2(-150, 0)
		var run_tw = create_tween()
		run_tw.tween_property(male_npc, "position", run_target, 1.2)
		
		# 先让玩家看到他在跑
		DialogueManager.start_dialogue(StoryText.lines("floor_3", "male_panic_run"))
		await DialogueManager.dialogue_ended
		
		# 跑了一段距离后大嘴冲出
		await get_tree().create_timer(0.5).timeout
		run_tw.kill()
		
		# 大嘴从地板冲出吞噬男伴
		AudioManager.play_sfx(_rumble_sfx, -2.0)
		var death_mouth = _create_abyss_mouth_visual(male_npc.global_position)
		AudioManager.play_sfx(_mouth_bite_sfx)
		ScreenEffects.abyss_impact()
		
		DialogueManager.start_dialogue(StoryText.lines("floor_3", "male_panic_death"))
		await DialogueManager.dialogue_ended
		
		GameManager.kill_character("male_npc")
		ScreenEffects.death_impact(12.0)
		var death_pos = male_npc.global_position
		var tw = create_tween()
		tw.tween_property(male_npc, "scale", Vector2(0.05, 0.05), 0.3)
		tw.parallel().tween_property(male_npc, "modulate:a", 0.0, 0.3)
		await tw.finished
		male_npc.queue_free()
		male_npc = null
		
		# 周锐死后掉落304房间钥匙
		_spawn_dropped_key(death_pos)
		
		# 大嘴缩回地板
		if death_mouth:
			await get_tree().create_timer(0.5).timeout
			var tw2 = create_tween()
			tw2.tween_property(death_mouth, "scale", Vector2(0.1, 0.1), 0.4)
			tw2.parallel().tween_property(death_mouth, "modulate:a", 0.0, 0.4)
			await tw2.finished
			death_mouth.queue_free()
	
	await get_tree().create_timer(1.0).timeout
	
	# 男伴死后规则才出现
	ScreenEffects.rule_appear()
	GameManager.add_rule(LocaleManager.t("rule_floor_3"))
	_run_rule_revealed = true  # 规则已通过周瑞之死揭示
	await show_rule_paper_and_wait()

	DialogueManager.start_dialogue(StoryText.lines("floor_3", "male_panic_aftermath"))
	await DialogueManager.dialogue_ended
	
	# 怪物开始缓步移动
	monster_active = true
	InputDevice.vibrate_rumble(1.0)
	
	# 进入探索阶段
	_after_male_death_explore()

## 触发灵魂互换过场：怪物追上玩家的瞬间冻结全场、切换换魂BGM，开始绑绳仪式。
func _trigger_soul_swap_cutscene() -> void:
	if current_phase != Phase.MONSTER_CHASE:
		return
	current_phase = Phase.SOUL_SWAP_CUTSCENE
	monster_active = false
	player_run_death_active = false
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 播放交换灵魂BGM
	var soul_bgm_path = "res://assets/audio/bgm/交换灵魂.mp3"
	if ResourceLoader.exists(soul_bgm_path):
		AudioManager.play_bgm(load(soul_bgm_path), 2.0)
	
	_soul_swap_with_rope()

## 绑绳换魂仪式：两名NPC贴近玩家身边模拟以绳相连，对话确认后消耗绳子并执行真正的换魂。
func _soul_swap_with_rope() -> void:
	# NPC贴近玩家身边模拟绑绳
	var tween_npc = create_tween()
	if cool_npc:
		tween_npc.parallel().tween_property(cool_npc, "position", player.position + Vector2(15, 5), 0.8)
	if cheerful_npc:
		tween_npc.parallel().tween_property(cheerful_npc, "position", player.position + Vector2(-15, 5), 0.8)
	await tween_npc.finished
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "soul_swap_rope"))
	await DialogueManager.dialogue_ended
	
	InventoryManager.remove_item("rope")
	
	await get_tree().create_timer(1.0).timeout
	_perform_soul_swap()

## 主角与怪物换魂的核心演出：镜头平移至怪物、闭眼黑屏完成灵魂互换，睁眼时玩家已在怪物体内，随即进入操控阶段。
func _perform_soul_swap() -> void:
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "perform_swap"))
	await DialogueManager.dialogue_ended
	
	# 灵魂互换时：相机平移到怪物位置
	if humanoid_monster and player.camera:
		var monster_offset = humanoid_monster.global_position - player.global_position
		var cam_tw = create_tween()
		cam_tw.tween_property(player.camera, "offset", monster_offset, 1.0).set_trans(Tween.TRANS_SINE)
		await cam_tw.finished
		await get_tree().create_timer(0.3).timeout
		# 让震动效果以怪物位置为基准，不要重置回原点
		ScreenEffects.set_base_offset(monster_offset)
	
	await ScreenEffects.soul_swap_eye_close()
	GameManager.trigger_soul_swap("humanoid_monster")
	_enter_monster_body()
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	await ScreenEffects.soul_swap_eye_open()
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "perform_swap2"))
	await DialogueManager.dialogue_ended
	
	current_phase = Phase.MONSTER_CONTROL
	_monster_run_sequence()


## 玩家附身怪物躯体：移除原怪物节点、玩家变身为怪物外观并站到其原位，同时解除体力、理智与黑暗的限制。
func _enter_monster_body() -> void:
	# 记录怪物当前位置，玩家附身后站在怪物原地
	var monster_pos = humanoid_monster.global_position if humanoid_monster else player.global_position
	
	# 把怪物身体移走（已被玩家"附身"）
	if humanoid_monster:
		humanoid_monster.queue_free()
		humanoid_monster = null
	
	# NPC就地停下（已在_soul_swap_with/without_rope里贴到玩家身边了）
	if cool_npc:
		cool_npc.stop_following()
	if cheerful_npc:
		cheerful_npc.stop_following()
	
	# 玩家就地变身为怪物，站在怪物原位置
	original_player_texture = player.sprite.texture
	var monster_texture = GameManager.load_char_texture("humanoid_monster", 18, 26)
	if player.has_method("set_texture_override"):
		player.set_texture_override(monster_texture)
	else:
		player.sprite.texture = monster_texture
	_apply_shadow_distortion(player.sprite)
	player.set_can_run(true)  # 怪物身体可以跑！
	player.walk_speed = 160.0
	player.run_speed = 240.0
	player.global_position = monster_pos  # 附身后站在怪物原来的位置
	
	# 玩家已移到怪物位置，相机归位（自然跟随新位置）
	if player.camera:
		player.camera.offset = Vector2.ZERO
		ScreenEffects.set_base_offset(Vector2.ZERO)
	
	# 进入怪物体后：关闭体力/理智消耗，关闭黑暗（怪物不受这些限制）
	PlayerStats.stamina_enabled = false
	PlayerStats.darkness_environment = false
	disable_darkness(0.5)  # 画面变亮，怪物什么都看得清
	
	# 怪物不需要手电筒
	if player_lighting:
		player_lighting.visible = false

## 附身后的操控阶段：创建倒计时HUD并交代计划，放开玩家操作，等其按下奔跑键即召唤巨口开始逃亡。
func _monster_run_sequence() -> void:
	# === 追逐战开始 ===
	
	# 倒计时HUD（先创建，对话结束前不显示计时）
	_create_chase_hud()
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "monster_run"))
	await DialogueManager.dialogue_ended
	
	var run_key = InputDevice.get_hint("run")
	show_hint(LocaleManager.t("hint_f3_run_now") % run_key, 5.0)
	
	# 先放开玩家，等玩家按下Shift开跑时才生成巨口
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	
	_waiting_for_shift = true

## 在走廊铺设地板突起与残骸障碍物，既是探索期的地形细节，也是追逐战中的阻挡点。
func _build_corridor_obstacles() -> void:
	# 走廊中的障碍物（地板突起/残骸），从一开始就存在
	# 混合竖向和横向障碍物
	var obstacle_data = [
		{"pos": Vector2(280, -100), "size": Vector2(18, 40)},
		{"pos": Vector2(140, -160), "size": Vector2(20, 35)},
		{"pos": Vector2(10, -80), "size": Vector2(22, 38)},
		{"pos": Vector2(-70, 150), "size": Vector2(48, 15)},
		{"pos": Vector2(-130, -130), "size": Vector2(18, 38)},
		{"pos": Vector2(-200, 60), "size": Vector2(42, 14)},
		{"pos": Vector2(-260, -50), "size": Vector2(20, 42)},
	]
	
	for data in obstacle_data:
		var obs = StaticBody2D.new()
		obs.position = data["pos"]
		obs.collision_layer = 4
		add_child(obs)
		
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = data["size"]
		col.shape = shape
		obs.add_child(col)
		
		# 障碍物视觉（像地板突起/裂缝的残骸）
		var vis = ColorRect.new()
		vis.color = Color(0.0, 0.0, 0.0, 0.95)
		vis.position = -data["size"] / 2
		vis.size = data["size"]
		obs.add_child(vis)
		
		# 警告标记
		var warn = ColorRect.new()
		warn.color = Color(0.08, 0.08, 0.08, 0.5)
		warn.position = -data["size"] / 2 - Vector2(3, 3)
		warn.size = data["size"] + Vector2(6, 6)
		warn.z_index = -1
		obs.add_child(warn)
		
		chase_obstacles.append(obs)

## 在玩家逃跑方向的身后生成追逐战巨口（含呼吸脉动与红光），它无视墙壁直线追击玩家。
func _spawn_chase_mouth() -> void:
	chase_mouth = CharacterBody2D.new()
	# 巨口固定在玩家逃跑方向的身后刷新
	var behind_dir = -player.facing_direction.normalized()
	if behind_dir == Vector2.ZERO:
		behind_dir = Vector2(0, -1)  # 默认在上方
	chase_mouth.position = player.global_position + behind_dir * 120.0
	chase_mouth.collision_layer = 16
	chase_mouth.collision_mask = 0  # 不碰撞墙壁，直接移动（避免被卡在房间里）
	add_child(chase_mouth)
	
	# 碰撞体（缩小）
	var mouth_col = CollisionShape2D.new()
	var mouth_shape = RectangleShape2D.new()
	mouth_shape.size = Vector2(30, 35)
	mouth_col.shape = mouth_shape
	chase_mouth.add_child(mouth_col)
	
	var mouth_pulse_node: Node2D = null
	if ResourceLoader.exists(ABYSS_MOUTH_TEX_PATH):
		var mouth_sprite = Sprite2D.new()
		mouth_sprite.texture = load(ABYSS_MOUTH_TEX_PATH)
		mouth_sprite.centered = true
		var tex_size = mouth_sprite.texture.get_size()
		if tex_size.x > 0.0:
			mouth_sprite.scale = Vector2.ONE * (95.0 / tex_size.x)
		chase_mouth.add_child(mouth_sprite)
		mouth_pulse_node = mouth_sprite
	else:
		# 巨口主体（缩小）
		var mouth_body = ColorRect.new()
		mouth_body.color = Color(0.02, 0.0, 0.02, 0.95)
		mouth_body.position = Vector2(-25, -30)
		mouth_body.size = Vector2(50, 60)
		chase_mouth.add_child(mouth_body)
		mouth_pulse_node = mouth_body
	var mouth_glow = PointLight2D.new()
	mouth_glow.color = Color(0.85, 0.08, 0.04)
	mouth_glow.energy = 2.6
	var glow_tex_path = "res://assets/sprites/effects/light_gradient.png"
	if ResourceLoader.exists(glow_tex_path):
		mouth_glow.texture = load(glow_tex_path)
	else:
		mouth_glow.texture = _create_light_texture()
	mouth_glow.texture_scale = 1.7
	mouth_glow.position = Vector2(0, -2)
	chase_mouth.add_child(mouth_glow)
	
	var eye_left: CanvasItem = null
	var eye_right: CanvasItem = null
	if not ResourceLoader.exists(ABYSS_MOUTH_TEX_PATH):
		# 牙齿上排
		for i in range(4):
			var tooth = ColorRect.new()
			tooth.color = Color(0.7, 0.7, 0.6, 0.8)
			tooth.position = Vector2(-20 + i * 12, -27)
			tooth.size = Vector2(5, 9)
			chase_mouth.add_child(tooth)
		# 牙齿下排
		for i in range(4):
			var tooth = ColorRect.new()
			tooth.color = Color(0.7, 0.7, 0.6, 0.8)
			tooth.position = Vector2(-20 + i * 12, 20)
			tooth.size = Vector2(5, 9)
			chase_mouth.add_child(tooth)
		# 深红色咽喉
		var throat = ColorRect.new()
		throat.color = Color(0.3, 0.0, 0.0, 0.7)
		throat.position = Vector2(-12, -15)
		throat.size = Vector2(24, 30)
		chase_mouth.add_child(throat)
		eye_left = ColorRect.new()
		eye_left.color = Color(0.95, 0.12, 0.08, 0.95)
		eye_left.position = Vector2(-14, -9)
		eye_left.size = Vector2(7, 5)
		chase_mouth.add_child(eye_left)
		eye_right = ColorRect.new()
		eye_right.color = Color(0.95, 0.12, 0.08, 0.95)
		eye_right.position = Vector2(7, -9)
		eye_right.size = Vector2(7, 5)
		chase_mouth.add_child(eye_right)
	
	# 呼吸脉动效果
	var tw = create_tween().set_loops()
	_loop_tweens.append(tw)
	if mouth_pulse_node:
		var base_scale := mouth_pulse_node.scale
		tw.tween_property(mouth_pulse_node, "scale", base_scale * Vector2(1.08, 1.04), 0.4)
		tw.tween_property(mouth_pulse_node, "scale", base_scale, 0.4)
	var glow_tw = create_tween().set_loops()
	_loop_tweens.append(glow_tw)
	glow_tw.tween_property(mouth_glow, "energy", 1.8, 0.2)
	if eye_left and eye_right:
		glow_tw.parallel().tween_property(eye_left, "modulate:a", 0.45, 0.2)
		glow_tw.parallel().tween_property(eye_right, "modulate:a", 0.45, 0.2)
	glow_tw.tween_property(mouth_glow, "energy", 3.0, 0.2)
	if eye_left and eye_right:
		glow_tw.parallel().tween_property(eye_left, "modulate:a", 1.0, 0.2)
		glow_tw.parallel().tween_property(eye_right, "modulate:a", 1.0, 0.2)

## 创建追逐战的倒计时HUD：顶部红色剩余秒数与底部坚持到天亮的提示文字。
func _create_chase_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	canvas.name = "ChaseHUD"
	add_child(canvas)
	
	chase_countdown_label = Label.new()
	chase_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chase_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chase_countdown_label.offset_left = -100
	chase_countdown_label.offset_right = 100
	chase_countdown_label.offset_top = 20
	chase_countdown_label.add_theme_font_size_override("font_size", 48)
	chase_countdown_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1))
	canvas.add_child(chase_countdown_label)
	
	# 底部提示
	var hint_label = Label.new()
	hint_label.text = LocaleManager.t("chase_survive_until_dawn")
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.offset_left = -80
	hint_label.offset_right = 80
	hint_label.offset_top = 55
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
	canvas.add_child(hint_label)

## 刷新追逐战倒计时显示，最后5秒开始闪烁制造紧张感。
func _update_chase_hud() -> void:
	if chase_countdown_label:
		var remaining = chase_duration - chase_timer
		var secs = ceili(remaining)
		chase_countdown_label.text = LocaleManager.t("countdown_seconds_left") % secs
		# 最后5秒闪烁
		if remaining <= 5.0:
			chase_countdown_label.modulate.a = 0.5 + 0.5 * sin(chase_timer * 8.0)

## 移除追逐战倒计时HUD并清空引用。
func _remove_chase_hud() -> void:
	if chase_countdown_label:
		var hud = get_node_or_null("ChaseHUD")
		if hud:
			hud.queue_free()
		chase_countdown_label = null

# === 追逐战：被巨口吞噬（失败）===
## 追逐战失败结局：玩家被巨口追上吞噬，画面冲击后进入游戏结束界面。
func _chase_caught() -> void:
	chase_active = false
	_remove_chase_hud()
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "chase_caught"))
	await DialogueManager.dialogue_ended
	ScreenEffects.abyss_impact()
	GameManager.go_to_game_over("chase_caught")

# === 追逐战：撑过20秒（成功）===
## 追逐战成功结局：撑过20秒后巨口冲至脚下，却只吞掉了玩家附身的怪物躯壳——07:00灵魂回归人体，进入胜利剧情。
func _chase_survive() -> void:
	chase_active = false
	_remove_chase_hud()
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	# 停止追逐战BGM
	AudioManager.stop_bgm(1.0)
	
	# 巨口以极快速度冲到玩家脚下（压迫感演出）
	if chase_mouth and is_instance_valid(chase_mouth):
		AudioManager.play_sfx(_mouth_bite_sfx)
		var dash_tw = create_tween()
		dash_tw.tween_property(chase_mouth, "global_position", player.global_position + Vector2(0, 10), 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		await dash_tw.finished
		# 短暂停顿让玩家感受到巨口已在脚下
		await get_tree().create_timer(0.35).timeout
	
	# 恢复玩家外观
	if player.has_method("clear_texture_override"):
		player.clear_texture_override()
	elif original_player_texture:
		player.sprite.texture = original_player_texture
	player.sprite.material = null
	player.walk_speed = 120.0
	player.run_speed = 200.0
	player.set_can_run(true)
	# player_run_death_active 延后到剧情结束才开启，防止切回瞬间按着shift被杀
	player.is_running = false
	
	# 灵魂回归人体：恢复体力/理智消耗和黑暗
	PlayerStats.stamina_enabled = true
	PlayerStats.darkness_environment = true
	enable_darkness(0.06, 1.0)
	
	# 恢复手电筒
	if player_lighting:
		player_lighting.visible = true
	
	# 巨口吞噬怪物身体的视觉（此时巨口已在玩家脚下，放大后消失）
	if chase_mouth and is_instance_valid(chase_mouth):
		var tw = create_tween()
		tw.tween_property(chase_mouth, "scale", Vector2(1.8, 1.8), 0.25)
		tw.tween_property(chase_mouth, "modulate:a", 0.0, 0.4)
		tw.tween_callback(chase_mouth.queue_free)
		chase_mouth = null
	
	# 清除追逐战障碍物
	for obs in chase_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	chase_obstacles.clear()
	
	# 玩家返回NPC旁（NPC当前就在小组位置，以它们目前中点为锤）
	var npc_center = player.global_position  # fallback
	if cool_npc and cheerful_npc:
		npc_center = (cool_npc.global_position + cheerful_npc.global_position) / 2.0
	elif cool_npc:
		npc_center = cool_npc.global_position
	elif cheerful_npc:
		npc_center = cheerful_npc.global_position
	player.global_position = npc_center + Vector2(0, -20)
	
	# === 07:00 灵魂弹回剧情 ===
	
	TransitionManager.flash_black(0.3)
	await get_tree().create_timer(0.5).timeout
	
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "chase_survive"))
	await DialogueManager.dialogue_ended
	
	GameManager.end_soul_swap()
	
	current_phase = Phase.DAWN_RETURN
	_victory_sequence()

## 胜利剧情：换魂归来后的对话收尾，恢复跑步致死规则并提示全员前往电梯离开第三层。
func _victory_sequence() -> void:
	DialogueManager.start_dialogue(StoryText.lines("floor_3", "victory"))
	await DialogueManager.dialogue_ended
	
	current_phase = Phase.DONE
	player_run_death_active = true  # 剧情结束后恢复跑步致死
	_refresh_floor_3_npc_dialogues()
	GameManager.set_state(GameManager.GameState.PLAYING)
	player.unfreeze_player()
	show_hint(LocaleManager.t("hint_f3_return_elevator"))

## 进入电梯剧情：招呼NPC跑向电梯汇合、插卡开门，记录怪物存活状态后切换到电梯内部场景。
func _enter_elevator() -> void:
	player.freeze_player()
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	var monster_still_alive = humanoid_monster != null and is_instance_valid(humanoid_monster)
	monster_active = false
	player_run_death_active = false
	
	# NPC停止跟随
	if cool_npc: cool_npc.stop_following()
	if cheerful_npc: cheerful_npc.stop_following()
	
	var elevator_pos = Vector2(-380, 220)
	var enter_elevator_lines = StoryText.lines("floor_3", "enter_elevator_scene")
	
	# 夏桐喊NPC过来
	DialogueManager.start_dialogue([enter_elevator_lines[0]])
	await DialogueManager.dialogue_ended
	
	# NPC快速跑向电梯
	if cool_npc and is_instance_valid(cool_npc):
		cool_npc.walk_to(elevator_pos + Vector2(10, -5))
	if cheerful_npc and is_instance_valid(cheerful_npc):
		cheerful_npc.walk_to(elevator_pos + Vector2(-10, -5))
	
	# 等NPC跑到（最多2秒）
	var wait_time = 0.0
	while wait_time < 2.0:
		var all_arrived = true
		if cool_npc and is_instance_valid(cool_npc) and cool_npc._is_walking_to:
			all_arrived = false
		if cheerful_npc and is_instance_valid(cheerful_npc) and cheerful_npc._is_walking_to:
			all_arrived = false
		if all_arrived:
			break
		await get_tree().process_frame
		wait_time += get_process_delta_time()
	
	# 插卡开门
	DialogueManager.start_dialogue(enter_elevator_lines.slice(1))
	await DialogueManager.dialogue_ended
	
	# 保存怪物存活状态给电梯场景
	GameManager.event_flags["floor3_monster_alive"] = monster_still_alive
	
	# 切换到电梯内部场景
	TransitionManager.transition_to_scene("res://scenes/levels/elevator_interior.tscn")

## 在指定位置放置可拾取的地面道具，附带名称标签与闪烁提示。
## [param pos] 道具世界坐标。
## [param item_id] 物品ID。
## [param item_name] 物品显示名。
## [param color] 道具视觉颜色。
func _place_room_item(pos: Vector2, item_id: String, item_name: String, color: Color) -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/simple_pickup.gd"))
	area.position = pos
	area.collision_layer = 16
	area.collision_mask = 1  # 检测玩家body
	area.item_id = item_id
	area.item_name = item_name
	area._level = self
	add_child(area)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	col.shape = shape
	area.add_child(col)
	var visual = ColorRect.new()
	visual.color = color
	visual.position = Vector2(-5, -5)
	visual.size = Vector2(10, 10)
	area.add_child(visual)
	var label = Label.new()
	var hint_text := "" if Engine.is_editor_hint() else InputDevice.hint("interact")
	label.text = "%s %s" % [item_name, hint_text]
	label.position = Vector2(-20, -22)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color.lightened(0.3))
	label.visible = false
	area.add_child(label)
	area._name_label = label
	var tw = create_tween().set_loops()
	_loop_tweens.append(tw)
	tw.tween_property(visual, "modulate:a", 0.4, 1.2)
	tw.tween_property(visual, "modulate:a", 1.0, 1.2)

## 创建可搜索的交互容器（运行时生成的交互物，如残破日记）。
## [param pos] 家具左上角。[param size] 尺寸。[param prop_name] 名称。
## [param color] 颜色。[param action_method] 搜索时触发的关卡方法名。
func _place_search_prop(pos: Vector2, size: Vector2, prop_name: String, color: Color, action_method: String) -> void:
	var visual = ColorRect.new()
	visual.position = pos
	visual.size = size
	visual.color = color
	add_child(visual)
	_place_container(pos, size, prop_name, color, "", "", action_method)

## 创建带脚本的容器交互区（供运行时生成搜索点使用；静态家具已由场景节点承担）。
func _place_container(furniture_pos: Vector2, furniture_size: Vector2,
		furniture_name: String, furniture_color: Color,
		item_id: String = "", item_name: String = "",
		search_action_method: String = "", post_take_action_method: String = "") -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/furniture_container.gd"))
	area.position = furniture_pos + furniture_size / 2.0
	area.collision_layer = 16
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	area.furniture_name = furniture_name
	area.contained_item_id = item_id
	area.contained_item_name = item_name
	area.search_action_method = search_action_method
	area.post_take_action_method = post_take_action_method
	area._level = self
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = furniture_size + Vector2(20, 20)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	var display_furniture_name := furniture_name if Engine.is_editor_hint() else LocaleManager.world_text(furniture_name)
	var hint_text := "" if Engine.is_editor_hint() else InputDevice.hint("interact")
	var name_label = create_world_label("%s %s" % [display_furniture_name, hint_text], furniture_pos + Vector2(-10, -22), 18, furniture_color.lightened(0.4))
	name_label.visible = false
	area._name_label = name_label
	area.tree_exiting.connect(func(): if is_instance_valid(name_label): name_label.queue_free())

## 程序化生成径向渐变的圆形光斑贴图，作为缺少光晕素材时的兜底光源纹理。
## [return] 生成的光斑纹理。
func _create_light_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for x in size:
		for y in size:
			var dist := Vector2(x, y).distance_to(center)
			var a := clampf(1.0 - dist / radius, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

## 在周锐死亡处掉落304房间钥匙拾取物（钥匙贴图、交互标签与闪烁提示），需按E拾取。
## [param pos] 钥匙掉落的世界坐标。
func _spawn_dropped_key(pos: Vector2) -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/items/simple_pickup.gd"))
	area.position = pos
	area.collision_layer = 16
	area.item_id = "room_304_key"
	area.item_name = "304房间钥匙"
	area._level = self
	# auto_collect = false（默认）：需要按E拾取
	add_child(area)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	area.add_child(col)
	
	# 钥匙贴图
	const KEY_TEX := "res://assets/sprites/_0001_钥匙.png"
	var key_vis: Node2D
	if ResourceLoader.exists(KEY_TEX):
		var key_sprite = Sprite2D.new()
		key_sprite.texture = load(KEY_TEX)
		key_sprite.position = Vector2(-4, -3)
		var tex_size = key_sprite.texture.get_size()
		key_sprite.scale = Vector2(8.0 / tex_size.x, 6.0 / tex_size.y)
		key_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		area.add_child(key_sprite)
		key_vis = key_sprite
	else:
		var vis = ColorRect.new()
		vis.color = Color(0.8, 0.7, 0.3, 0.8)
		vis.position = Vector2(-4, -3)
		vis.size = Vector2(8, 6)
		area.add_child(vis)
		key_vis = vis
	
	var label = create_world_label("304钥匙 %s" % InputDevice.hint("interact"), pos + Vector2(-20, -20), 18, Color(0.9, 0.8, 0.4))
	label.visible = false
	area._name_label = label
	area.tree_exiting.connect(func(): if is_instance_valid(label): label.queue_free())
	
	# 闪烁提示
	var tw = create_tween().set_loops()
	_loop_tweens.append(tw)
	tw.tween_property(key_vis, "modulate:a", 0.4, 1.0)
	tw.tween_property(key_vis, "modulate:a", 1.0, 1.0)

	
	# 过场动画中生成的道具：等玩家解冻后再做一次重叠检测
	# 避免"踩在道具上拾取不了"的问题
	_deferred_check_overlap(area)

## 判断人形怪物是否完整出现在玩家相机视野内（四周留20px边距确保全身可见）。
## [return] 怪物全身可见时为 true。
func _is_monster_on_screen() -> bool:
	if not humanoid_monster or not player or not player.camera:
		return false
	var cam_pos = player.camera.global_position
	var vp_size = get_viewport().get_visible_rect().size / player.camera.zoom
	var half = vp_size / 2.0
	var m_pos = humanoid_monster.global_position
	# 怪物全身都在屏幕内才算（留20px边距确保完整可见）
	var margin := 20.0
	return m_pos.x > cam_pos.x - half.x + margin and m_pos.x < cam_pos.x + half.x - margin and m_pos.y > cam_pos.y - half.y + margin and m_pos.y < cam_pos.y + half.y - margin

## 在过场动画结束/玩家解冻后，对特定道具补做一次重叠检测
## 解决"过场中生成的道具踩在上面拾取不了"的问题
func _deferred_check_overlap(pickup_area: Area2D) -> void:
	# 等待玩家解冻（game_state变为PLAYING）再检测
	var check := func():
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(pickup_area):
			return
		if not is_instance_valid(player):
			return
		# 如果玩家在范围内，强制加入交互列表
		if pickup_area.get_overlapping_bodies().has(player):
			if pickup_area._name_label:
				pickup_area._name_label.visible = true
		if player.interaction_area and player.interaction_area.get_overlapping_areas().has(pickup_area):
			if not player.nearby_interactables.has(pickup_area):
				player.nearby_interactables.append(pickup_area)
	GameManager.game_state_changed.connect(
		func(state):
			if state == GameManager.GameState.PLAYING:
				check.call(),
		CONNECT_ONE_SHOT
	)

## 为精灵应用阴影扭曲着色器，使怪物及附身状态的玩家呈现晃动扭曲的诡异质感。
## [param sprite] 要应用扭曲材质的精灵节点。
func _apply_shadow_distortion(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null:
		return
	var shader := Shader.new()
	shader.code = SHADOW_DISTORTION_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material

## 调试功能：清理现场、补齐绳子与电梯卡并处理各NPC状态，直接跳转到灵魂互换演出。
func debug_skip_to_soul_swap() -> void:
	if current_phase in [Phase.SOUL_SWAP_CUTSCENE, Phase.MONSTER_CONTROL, Phase.DAWN_RETURN]:
		return
	if player == null or humanoid_monster == null or not is_instance_valid(humanoid_monster):
		return
	if male_npc and is_instance_valid(male_npc):
		GameManager.kill_character("male_npc")
		male_npc.queue_free()
		male_npc = null
	if cool_npc and is_instance_valid(cool_npc):
		cool_npc.stop_following()
		cool_npc.global_position = player.global_position + Vector2(-20, 10)
	if cheerful_npc and is_instance_valid(cheerful_npc):
		cheerful_npc.stop_following()
		cheerful_npc.global_position = player.global_position + Vector2(20, 10)
	if not InventoryManager.has_item("rope"):
		InventoryManager.add_item("rope")
	if not InventoryManager.has_item("elevator_card"):
		InventoryManager.add_item("elevator_card")
	elevator_card_found = true
	_run_rule_revealed = true
	monster_active = false
	player_run_death_active = false
	chase_active = false
	_waiting_for_shift = false
	if chase_mouth and is_instance_valid(chase_mouth):
		chase_mouth.queue_free()
		chase_mouth = null
	_remove_chase_hud()
	for obs in chase_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	chase_obstacles.clear()
	show_hint("调试：已跳到换魂演出", 2.5)
	current_phase = Phase.MONSTER_CHASE
	_trigger_soul_swap_cutscene()

## 在家具位置创建可搜索容器
func _on_elevator_card_container_taken(_item_id: String = "") -> void:
	elevator_card_found = true
	AudioManager.stop_bgm(1.5)
	_card_found_monster_chase()

## 在走廊右侧搭建故障贩卖机：碰撞体、破损外观与可踢踹的交互区。
## [param _walls] 兼容基类签名的参数（未使用）。
func _build_vending_machine(_walls: Node2D) -> void:
	# 贩卖机视觉（走廊右侧）
	var vm_body = StaticBody2D.new()
	vm_body.name = "VendingMachineBody"
	vm_body.position = Vector2(420, 60)
	vm_body.collision_layer = 4
	add_child(vm_body)
	var vm_col = CollisionShape2D.new()
	var vm_shape = RectangleShape2D.new()
	vm_shape.size = Vector2(24, 40)
	vm_col.shape = vm_shape
	vm_body.add_child(vm_col)
	
	var vm_vis = ColorRect.new()
	vm_vis.color = Color(0.15, 0.18, 0.22)
	vm_vis.position = Vector2(-12, -20)
	vm_vis.size = Vector2(24, 40)
	vm_body.add_child(vm_vis)
	
	# 损坏标识
	create_world_label(LocaleManager.world_text("贩卖机"), Vector2(420, 60) + Vector2(-16, -35), 18, Color(0.4, 0.5, 0.6))
	create_world_label(LocaleManager.world_text("故障"), Vector2(420, 60) + Vector2(-10, -8), 14, Color(0.8, 0.2, 0.2))
	
	# 可踢踹交互区域
	var interact = Area2D.new()
	interact.set_script(load("res://scripts/items/vending_machine.gd"))
	interact.collision_layer = 16
	interact.add_to_group("interactable")
	interact._level = self
	add_child(interact)
	var ia_col = CollisionShape2D.new()
	var ia_shape = RectangleShape2D.new()
	ia_shape.size = Vector2(44, 60)
	ia_col.shape = ia_shape
	interact.add_child(ia_col)
	
	var hint_label = create_world_label(LocaleManager.vending_kick_prompt_text(), Vector2(420, 60) + Vector2(-22, -45), 16, Color(1.0, 1.0, 0.7))
	hint_label.visible = false
	
	interact.body_entered.connect(func(body):
		if body.is_in_group("player"):
			hint_label.text = LocaleManager.vending_kick_prompt_text()
			hint_label.visible = true
	)
	interact.body_exited.connect(func(body):
		if body.is_in_group("player"):
			hint_label.visible = false
	)
	
	# 用meta存储引用，供踢机逻辑使用
	interact.set_meta("vm_body", vm_body)
	interact.set_meta("hint_label", hint_label)
	interact.set_meta("interact_callback", Callable(self, "_kick_vending_machine").bind(vm_body))

## 踹贩卖机的交互逻辑：消耗体力、播放机体晃动，并按踢的次数递减的概率随机掉落补给。
## [param vm_body] 贩卖机的碰撞体节点。
func _kick_vending_machine(vm_body: Node2D) -> void:
	_vending_kicks += 1
	# 消耗体力
	PlayerStats.change_stamina(-PlayerStats.max_stamina / 3.0)
	
	# 贩卖机晃动效果
	var tw = create_tween()
	tw.tween_property(vm_body, "position:x", vm_body.position.x + 4, 0.05)
	tw.tween_property(vm_body, "position:x", vm_body.position.x - 4, 0.05)
	tw.tween_property(vm_body, "position:x", vm_body.position.x + 2, 0.05)
	tw.tween_property(vm_body, "position:x", vm_body.position.x, 0.05)
	
	# 随机掉落（前3次有东西，之后概率降低）
	var drop_chance = 0.8 if _vending_kicks <= 3 else 0.3
	if randf() < drop_chance:
		var drops = [
			["energy_drink", "能量饮料"],
			["coffee", "咖啡"],
			["sedative", "镇定剂"],
			["sweets", "糖果"],
			["energy_bar", "能量棒"],
			["bandage", "绷带"],
		]
		var drop = drops[randi() % drops.size()]
		InventoryManager.add_item(drop[0])
		var item_name = InventoryManager.get_item_data(drop[0]).get("name", drop[1])
		show_hint(LocaleManager.t("vending_drop_found") % item_name)
	else:
		show_hint(LocaleManager.t("vending_drop_empty"))
