extends CharacterBody2D
## 玩家角色 - 姐姐

@export var walk_speed: float = 120.0
@export var run_speed: float = 200.0

var sprite: Sprite2D
var collision: CollisionShape2D
var interaction_area: Area2D
var camera: Camera2D
var point_light: PointLight2D

var can_move: bool = true
var can_run: bool = true  # 第三层禁止跑步
var facing_direction: Vector2 = Vector2.DOWN
var is_running: bool = false
var nearby_interactables: Array = []
var _signals_connected: bool = false

# 闪避系统
const DODGE_HOLD_THRESHOLD: float = 0.15  # 按住超过此时间算跑步
const DODGE_SPEED_MULT: float = 1.8  # 闪避速度倍率（相对walk_speed）
const DODGE_DURATION: float = 0.2  # 闪避持续时间
const DODGE_STAMINA_COST: float = 4.0  # 闪避消耗体力（比跑步到同距离更贵）
var _run_hold_time: float = 0.0
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO

# 帧动画组件
var frame_animator: FrameAnimator

var _footstep_timer: float = 0.0
const WALK_FOOTSTEP_INTERVAL: float = 0.42
const RUN_FOOTSTEP_INTERVAL: float = 0.28

## 初始化玩家：加入分组、连接全局信号并创建帧动画组件。
func _ready() -> void:
	add_to_group("player")
	GameManager.game_state_changed.connect(_on_game_state_changed)
	PlayerStats.exhaustion_started.connect(_on_exhaustion_started)
	PlayerStats.exhaustion_ended.connect(_on_exhaustion_ended)
	PlayerStats.game_over_insanity.connect(_on_insanity_death)
	PlayerStats.panic_mode_changed.connect(_on_panic_mode_changed)
	# 初始化帧动画组件
	frame_animator = FrameAnimator.new()
	add_child(frame_animator)
	if sprite:
		frame_animator.setup("sister", sprite)
		frame_animator.walk_fps = 7.0
		frame_animator.idle_fps = 7.0
	call_deferred("_connect_interaction_signals")

## 确保帧动画组件完成初始化。
## tscn 直接实例化本节点时，关卡脚本对 sprite 的赋值晚于 _ready()，
## 帧目录未加载会导致角色永远静止朝下，需在赋值后调用此方法补建。
func ensure_frame_animator() -> void:
	if frame_animator == null or sprite == null:
		return
	if frame_animator.is_using_preview_frames():
		return
	frame_animator.setup("sister", sprite)
	frame_animator.walk_fps = 7.0
	frame_animator.idle_fps = 7.0

## 连接交互区域进出信号（幂等，仅连接一次）。
func _connect_interaction_signals() -> void:
	if _signals_connected:
		return
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)
		interaction_area.area_entered.connect(_on_interaction_area_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_area_exited)
		_signals_connected = true

## 每物理帧处理移动输入、跑步/闪避判定、速度计算与脚步声更新。
## [param delta] 距上一帧的时间间隔（秒）。
func _physics_process(delta: float) -> void:
	if not can_move or PlayerStats.is_exhausted:
		velocity = Vector2.ZERO
		_is_dodging = false
		_run_hold_time = 0.0
		_footstep_timer = 0.0
		PlayerStats.update_movement_state(false, false)
		if frame_animator:
			frame_animator.update(0.0, false, facing_direction)
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		velocity = Vector2.ZERO
		_is_dodging = false
		_run_hold_time = 0.0
		_footstep_timer = 0.0
		PlayerStats.update_movement_state(false, false)
		if frame_animator:
			frame_animator.update(0.0, false, facing_direction)
		return
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var run_pressed := Input.is_action_pressed("run") and can_run and not PlayerStats.is_exhausted
	var run_just_pressed := Input.is_action_just_pressed("run") and can_run and not PlayerStats.is_exhausted
	
	# 闪避计时
	if _is_dodging:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_is_dodging = false
	elif run_just_pressed and input_dir != Vector2.ZERO and PlayerStats.stamina > 0:
		_start_dodge(input_dir)
	
	# 跑步按键状态追踪
	if run_pressed:
		_run_hold_time += delta
	else:
		_run_hold_time = 0.0
	
	# 只有长按才算真正跑步
	is_running = run_pressed and _run_hold_time >= DODGE_HOLD_THRESHOLD and input_dir != Vector2.ZERO
	
	# 体力不足时强制切换为走路
	if is_running and PlayerStats.stamina <= 0:
		is_running = false
	
	# 计算速度
	var speed: float
	if _is_dodging:
		speed = walk_speed * DODGE_SPEED_MULT
		velocity = _dodge_direction * speed
	elif is_running:
		speed = run_speed
		velocity = input_dir * speed
	else:
		speed = walk_speed
		velocity = input_dir * speed
	
	if input_dir != Vector2.ZERO:
		facing_direction = input_dir.normalized()
		PlayerStats.update_movement_state(true, is_running)
	elif _is_dodging:
		PlayerStats.update_movement_state(true, false)
	else:
		PlayerStats.update_movement_state(false, false)

	if frame_animator:
		frame_animator.update(delta, input_dir != Vector2.ZERO or _is_dodging, facing_direction, is_running)
	
	move_and_slide()
	_update_footstep_audio(delta, velocity.length_squared() > 1.0)

## 触发一次闪避冲刺，沿输入方向位移并扣除体力。
## [param input_dir] 闪避方向（取自玩家当前输入方向）。
func _start_dodge(input_dir: Vector2) -> void:
	_is_dodging = true
	_dodge_timer = DODGE_DURATION
	_dodge_direction = input_dir.normalized()
	PlayerStats.change_stamina(-DODGE_STAMINA_COST)

## 按走路/跑步节奏定时播放脚步声。
## [param delta] 距上一帧的时间间隔（秒）。
## [param moving] 玩家本帧是否在移动。
func _update_footstep_audio(delta: float, moving: bool) -> void:
	if not moving:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	AudioManager.play_footstep(-10.0 if is_running or _is_dodging else -12.0)
	_footstep_timer = RUN_FOOTSTEP_INTERVAL if is_running or _is_dodging else WALK_FOOTSTEP_INTERVAL

## 处理原始按键输入：F12 触发全地图截图。
## [param event] 输入事件。
func _input(event: InputEvent) -> void:
	# F12 = 全地图截图（调试用，放在 _input 确保不被 UI 拦截）
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_capture_full_map()

## 处理未被 UI 消费的输入：推进对话、交互、开关规则书与物品栏。
## [param event] 未被消费的输入事件。
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state == GameManager.GameState.DIALOGUE:
		# 对话历史面板打开时不推进对话
		if DialogueManager.dialogue_ui and DialogueManager.dialogue_ui._history_visible:
			return
		if event.is_action_pressed("dialogue_skip"):
			DialogueManager.skip_current_dialogue()
			return
		if event.is_action_pressed("dialogue_advance") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			DialogueManager.advance()
		return
	
	if event.is_action_pressed("interact") and GameManager.current_state == GameManager.GameState.PLAYING:
		_try_interact()
	
	if event.is_action_pressed("open_rules"):
		_toggle_rules()
	
	if event.is_action_pressed("open_inventory"):
		_toggle_inventory()

## 设置纹理覆盖（委托给 FrameAnimator）
func set_texture_override(texture: Texture2D) -> void:
	if frame_animator:
		frame_animator.set_texture_override(texture)

## 清除纹理覆盖（委托给 FrameAnimator）
func clear_texture_override() -> void:
	if frame_animator:
		frame_animator.clear_texture_override()

## 全地图截图（委托给 MapCaptureTool）
func _capture_full_map() -> void:
	MapCaptureTool.capture_full_map(self)

## 尝试与附近可交互物互动，优先选择距离最近的目标。
func _try_interact() -> void:
	var candidates: Array = []
	# 收集缓存中的有效候选
	for obj in nearby_interactables:
		if is_instance_valid(obj) and obj.is_in_group("interactable") and obj.has_method("interact"):
			candidates.append(obj)
	# 实时扫描补充（处理刚生成/初始重叠的道具）
	if interaction_area:
		for area in interaction_area.get_overlapping_areas():
			if area.is_in_group("interactable") and area.has_method("interact") and not candidates.has(area):
				candidates.append(area)
		for body in interaction_area.get_overlapping_bodies():
			if body.is_in_group("interactable") and body.has_method("interact") and not candidates.has(body):
				candidates.append(body)
	if candidates.is_empty():
		return
	# 按距离排序，优先选最近的（避免跟随NPC拦截地面道具的E键）
	candidates.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	candidates[0].interact()

## 切换规则书界面的显示/隐藏。
func _toggle_rules() -> void:
	var rules_ui = get_tree().get_first_node_in_group("rules_ui")
	if rules_ui:
		rules_ui.toggle()

## 切换物品栏界面的显示/隐藏。
func _toggle_inventory() -> void:
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui:
		inv_ui.toggle()

## 可交互物体进入交互区域时缓存它。
## [param body] 进入区域的节点。
func _on_interaction_area_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		nearby_interactables.append(body)

## 可交互物体离开交互区域时移除缓存。
## [param body] 离开区域的节点。
func _on_interaction_area_exited(body: Node2D) -> void:
	nearby_interactables.erase(body)

## 可交互 Area 进入交互区域时缓存它。
## [param area] 进入区域的 Area2D。
func _on_interaction_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable"):
		nearby_interactables.append(area)

## 可交互 Area 离开交互区域时移除缓存。
## [param area] 离开区域的 Area2D。
func _on_interaction_area_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)

## 游戏状态变化时同步玩家能否移动。
## [param new_state] 新的游戏状态。
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	can_move = (new_state == GameManager.GameState.PLAYING)

## 脱力开始回调：强制停止移动、播放喘息声并提示玩家休息。
func _on_exhaustion_started() -> void:
	## 脱力状态：强制停止移动，播放喘息声，提示玩家
	velocity = Vector2.ZERO
	AudioManager.play_sfx(GameConfig.get_sfx("heartbeat"))
	var level = get_tree().current_scene
	if level and level.has_method("show_hint"):
		level.show_hint("没体力了……站着休息一下吧。", 4.0)

## 脱力解除回调（当前无需额外处理）。
func _on_exhaustion_ended() -> void:
	## 脱力解除
	pass

## 理智归零回调：冻结玩家并延迟进入游戏结束流程。
func _on_insanity_death() -> void:
	## 理智归零 → 精神崩溃死亡
	freeze_player()
	# 短暂延迟后进入 game over
	var tw = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func(): GameManager.go_to_game_over())

## 恐慌模式切换时通知氛围层显示/隐藏理智脉冲遮罩。
## [param is_panic] 是否处于恐慌模式。
func _on_panic_mode_changed(is_panic: bool) -> void:
	## 恐慌模式：通知氛围层显示/隐藏脉冲遮罩
	var atmo = get_tree().get_first_node_in_group("atmosphere_layer")
	if atmo and atmo.has_method("set_sanity_vignette"):
		atmo.set_sanity_vignette(is_panic)

## 怪物触碰玩家时调用
func on_monster_hit(knockback_dir: Vector2 = Vector2.ZERO, sanity_damage: float = 30.0) -> void:
	PlayerStats.reduce_sanity(sanity_damage)
	# 屏幕震动
	var atmo = get_tree().get_first_node_in_group("atmosphere_layer")
	if atmo and atmo.has_method("screen_shake"):
		atmo.screen_shake(8.0, 0.4)
	# 玩家被击退（逐帧碰撞检测，不会穿墙）
	if knockback_dir != Vector2.ZERO:
		_do_knockback(knockback_dir.normalized())

## 执行击退位移：逐帧碰撞检测移动，撞墙即停。
## [param dir] 击退方向（单位向量）。
func _do_knockback(dir: Vector2) -> void:
	var distance := 80.0
	var step := 5.0
	var traveled := 0.0
	while traveled < distance:
		var move = min(step, distance - traveled)
		var collision = move_and_collide(dir * move)
		traveled += move
		if collision:
			break
		await get_tree().process_frame

## 设置玩家是否允许跑步。
## [param value] true 允许跑步，false 禁止。
func set_can_run(value: bool) -> void:
	can_run = value

## 冻结玩家：禁止移动并将速度归零。
func freeze_player() -> void:
	can_move = false
	velocity = Vector2.ZERO

## 解除冻结，恢复玩家移动。
func unfreeze_player() -> void:
	can_move = true
