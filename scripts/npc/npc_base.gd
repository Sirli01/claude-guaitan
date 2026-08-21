extends CharacterBody2D
## NPC基类 - 所有NPC共用

signal walk_completed  # walk_to 到达目标或超时时发射

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var walk_speed: float = 80.0
@export var follow_distance: float = 40.0

var sprite: Sprite2D
var collision: CollisionShape2D
var name_label: Label

var is_following: bool = false
var follow_target: Node2D = null
var dialogue_data: Array = []
var is_alive: bool = true
var phone_light: PointLight2D = null
var _phone_light_enabled: bool = false

# walk_to 相关
var _walk_target: Vector2 = Vector2.ZERO
var _is_walking_to: bool = false
var _walk_time: float = 0.0
const WALK_TIMEOUT: float = 12.0

# 跟随队列位置
var follow_offset: Vector2 = Vector2.ZERO

# 寻路代理
var _nav_agent: NavigationAgent2D = null

# 卡墙解除辅助
var _npc_stuck_timer: float = 0.0
var _npc_steer_dir: int = 0
var _npc_steer_timer: float = 0.0
var facing_direction: Vector2 = Vector2.DOWN

# 帧动画组件
var frame_animator: FrameAnimator

var _footstep_timer: float = 0.0
var _cached_player: Node2D = null  # 缓存 player 引用，避免每帧搜索
const NPC_STUCK_THRESHOLD: float = 0.8
const NPC_STEER_DURATION: float = 1.2
const NPC_FOOTSTEP_INTERVAL: float = 0.46

## 初始化 NPC：加入分组、创建帧动画组件、寻路代理与手机灯光。
func _ready() -> void:
	add_to_group("npc")
	add_to_group("interactable")
	if name_label:
		name_label.text = npc_name
	# 初始化帧动画组件
	frame_animator = FrameAnimator.new()
	add_child(frame_animator)
	if sprite and npc_id != "":
		frame_animator.setup(npc_id, sprite)
		frame_animator.walk_fps = 6.0
		frame_animator.idle_fps = 6.0
	# 寻路代理（需要场景中有 NavigationRegion2D）
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 8.0
	_nav_agent.target_desired_distance = 12.0
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)

	# NPC手机灯光（默认隐藏，由楼层场景在自由探索开始时启用）
	phone_light = PointLight2D.new()
	phone_light.color = Color(0.85, 0.85, 0.95)
	phone_light.energy = 1.8
	phone_light.texture_scale = 1.2
	phone_light.visible = false
	phone_light.shadow_enabled = false
	phone_light.texture = _make_npc_cone_texture(64, 60.0)
	add_child(phone_light)

## 每物理帧驱动 walk_to/跟随行为、动画、脚步声与卡墙绕行检测。
## [param delta] 距上一帧的时间间隔（秒）。
func _physics_process(delta: float) -> void:
	if not is_alive:
		_footstep_timer = 0.0
		_update_interaction_hint()
		return
	# 过场动画时：只允许 walk_to 移动（场景脚本主动调用的），其余冻结
	if GameManager.current_state == GameManager.GameState.CUTSCENE:
		if _is_walking_to:
			_walk_to_behavior(delta)
			if frame_animator:
				frame_animator.update(delta, velocity.length_squared() > 1.0, facing_direction)
			move_and_slide()
			_update_phone_light()
		else:
			velocity = Vector2.ZERO
			if frame_animator:
				frame_animator.update(0.0, false, facing_direction)
		_update_interaction_hint()
		return
	if _is_walking_to:
		_walk_to_behavior(delta)
	elif is_following and follow_target:
		_follow_behavior()
	else:
		velocity = Vector2.ZERO
	if frame_animator:
		frame_animator.update(delta, velocity.length_squared() > 1.0, facing_direction)
	move_and_slide()
	_update_phone_light()
	_update_footstep_audio(delta)
	_update_interaction_hint()
	# 跟随时卡墙检测：连续撞墙 0.8s 后随机绕行
	if is_following and follow_target and _npc_steer_dir == 0:
		var dist_to_target = global_position.distance_to(follow_target.global_position + follow_offset)
		if dist_to_target > follow_distance + 15.0 and get_slide_collision_count() > 0:
			_npc_stuck_timer += delta
			if _npc_stuck_timer >= NPC_STUCK_THRESHOLD:
				_npc_steer_dir = 1 if randf() > 0.5 else -1
				_npc_steer_timer = 0.0
				_npc_stuck_timer = 0.0
		else:
			_npc_stuck_timer = 0.0

## 根据朝向更新手机灯光的位置与旋转。
func _update_phone_light() -> void:
	if not _phone_light_enabled or not phone_light or not phone_light.visible:
		return
	var dir = facing_direction if facing_direction != Vector2.ZERO else Vector2.DOWN
	phone_light.rotation = dir.angle() + PI / 2.0
	phone_light.position = dir * 10.0 + Vector2(0, -15)

## 跟随行为：超出跟随距离时沿导航路径追近，卡墙时侧向绕行。
func _follow_behavior() -> void:
	var target_pos = follow_target.global_position + follow_offset
	var dist = global_position.distance_to(target_pos)
	if dist > follow_distance:
		var desired_dir = (target_pos - global_position).normalized()
		var move_dir: Vector2
		
		# 优先使用导航路径
		_nav_agent.target_position = target_pos
		var next_pos = _nav_agent.get_next_path_position()
		if next_pos.distance_squared_to(global_position) > 4.0:
			move_dir = (next_pos - global_position).normalized()
		else:
			move_dir = desired_dir
		
		# 正在绕行：叠加侧向分量
		if _npc_steer_dir != 0:
			var perp = Vector2(-desired_dir.y, desired_dir.x) * _npc_steer_dir
			move_dir = (desired_dir + perp * 1.5).normalized()
			_npc_steer_timer += get_physics_process_delta_time()
			if _npc_steer_timer >= NPC_STEER_DURATION:
				_npc_steer_dir = 0
				_npc_steer_timer = 0.0
		
		velocity = move_dir * walk_speed
		_update_facing_from_vector(move_dir)
	else:
		velocity = Vector2.ZERO

## 按固定间隔在 NPC 所在位置播放脚步声。
## [param delta] 距上一帧的时间间隔（秒）。
func _update_footstep_audio(delta: float) -> void:
	if velocity.length_squared() <= 1.0:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	AudioManager.play_footstep_at_position(global_position, -15.0)
	_footstep_timer = NPC_FOOTSTEP_INTERVAL

## 与 NPC 交互：有对话数据时开始对话。
func interact() -> void:
	if not dialogue_data.is_empty():
		DialogueManager.start_dialogue(dialogue_data)

## 更新名字标签：玩家靠近且有对话时显示交互按键提示，否则隐藏。
func _update_interaction_hint() -> void:
	if not name_label:
		return
	if dialogue_data.is_empty() or not is_alive or GameManager.current_state != GameManager.GameState.PLAYING:
		name_label.visible = false
		return
	# 使用缓存的 player 引用，无效时重新获取
	if not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	var player = _cached_player
	if player == null:
		name_label.visible = false
		return
	var show_prompt := false
	if player.nearby_interactables.has(self):
		show_prompt = true
	elif player.interaction_area:
		show_prompt = player.interaction_area.get_overlapping_bodies().has(self)
	name_label.text = "%s %s" % [npc_name, InputDevice.hint("interact")]
	name_label.visible = show_prompt

## 开始跟随指定目标。
## [param target] 要跟随的目标节点。
## [param offset] 相对目标的跟随偏移（用于队列站位）。
func start_following(target: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	is_following = true
	follow_target = target
	follow_offset = offset

## 停止跟随并原地站定。
func stop_following() -> void:
	is_following = false
	follow_target = null
	velocity = Vector2.ZERO

## 物理移动到目标位置（尊重墙壁碰撞，到达后发射 walk_completed）
func walk_to(target: Vector2) -> void:
	_walk_target = target
	_is_walking_to = true
	_walk_time = 0.0

## 停止 walk_to 移动
func stop_walking() -> void:
	_is_walking_to = false
	velocity = Vector2.ZERO
	walk_completed.emit()

## walk_to 的每帧行为：直线走向目标，超时或抵达后停止。
## [param delta] 距上一帧的时间间隔（秒）。
func _walk_to_behavior(delta: float) -> void:
	_walk_time += delta
	if _walk_time > WALK_TIMEOUT:
		stop_walking()
		return
	if global_position.distance_to(_walk_target) < 8.0:
		stop_walking()
		return
	var dir = (_walk_target - global_position).normalized()
	velocity = dir * walk_speed
	_update_facing_from_vector(dir)

## 根据移动方向更新朝向。
## [param direction] 移动方向，零向量时保持不变。
func _update_facing_from_vector(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	facing_direction = direction.normalized()

## 启用 NPC 手机灯光。
func enable_phone_light() -> void:
	_phone_light_enabled = true
	if phone_light:
		phone_light.visible = true

## 关闭 NPC 手机灯光。
func disable_phone_light() -> void:
	_phone_light_enabled = false
	if phone_light:
		phone_light.visible = false

## NPC 死亡处理：标记死亡、通知 GameManager、掉落手机灯光并播放死亡动画。
## [param death_type] 死亡类型，决定播放的死亡动画。
func die(death_type: String = "generic") -> void:
	is_alive = false
	GameManager.kill_character(npc_id)
	velocity = Vector2.ZERO
	# 掉落手机灯光在地面
	if _phone_light_enabled and phone_light:
		_spawn_ground_light()
		phone_light.visible = false
	# 播放死亡动画
	_play_death(death_type)

## 在死亡位置留下一个持续发光、60 秒后渐隐消失的手机灯光。
func _spawn_ground_light() -> void:
	# 在NPC死亡位置留下一个持续发光的手机灯光
	var parent = get_parent()
	if not parent:
		return
	var ground = Node2D.new()
	ground.name = "DroppedPhoneLight"
	ground.position = global_position
	ground.z_index = -1
	parent.add_child(ground)

	var light = PointLight2D.new()
	light.color = Color(0.85, 0.85, 0.95)
	light.energy = 0.5
	light.texture_scale = 1.2
	light.texture = _make_circle_light_tex(32)
	light.shadow_enabled = false
	ground.add_child(light)

	# 60秒后渐隐消失
	var tween = ground.create_tween()
	tween.tween_interval(60.0)
	tween.tween_property(ground, "modulate:a", 0.0, 3.0)
	tween.tween_callback(ground.queue_free)

## 按死亡类型播放对应死亡动画，结束后销毁节点。
## [param death_type] 死亡类型（如 high_heel、abyss_mouth）。
func _play_death(death_type: String) -> void:
	match death_type:
		"high_heel":
			# 被高跟鞋穿胸
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0.5, 0, 0, 1), 0.3)
			tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
			await tween.finished
			queue_free()
		"abyss_mouth":
			# 被巨口吞噬
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
			tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
			await tween.finished
			queue_free()
		_:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
			await tween.finished
			queue_free()

## 设置 NPC 的对话数据。
## [param data] 对话数据数组。
func set_dialogue(data: Array) -> void:
	dialogue_data = data

## 朝目标位置设置移动速度，接近目标时停下。
## [param target_pos] 目标位置。
## [param speed_override] 速度覆盖值，小于等于 0 时使用默认 walk_speed。
func move_to_position(target_pos: Vector2, speed_override: float = -1.0) -> void:
	var spd = speed_override if speed_override > 0 else walk_speed
	var dir = (target_pos - global_position).normalized()
	velocity = dir * spd
	# 到达目标后停止
	if global_position.distance_to(target_pos) < 5.0:
		velocity = Vector2.ZERO


## 生成 NPC 手机锥形光纹理（委托 TextureUtils）。
## [param size] 纹理边长（像素）。
## [param angle_deg] 锥形张角（度）。
## [return] 生成的锥形光纹理。
func _make_npc_cone_texture(size: int, angle_deg: float) -> ImageTexture:
	return TextureUtils.make_cone_texture(size, angle_deg)

## 生成圆形光纹理（委托 TextureUtils）。
## [param size] 纹理边长（像素）。
## [return] 生成的圆形光纹理。
func _make_circle_light_tex(size: int) -> ImageTexture:
	return TextureUtils.make_circle_texture(size)
