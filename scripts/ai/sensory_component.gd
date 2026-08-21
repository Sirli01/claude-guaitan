extends Node2D
## 感知 AI 组件 — 挂载到任何 NPC/怪物上
## 提供视线锥检测和声音感知，实现潜行玩法
##
## 用法：作为 NPC 的子节点添加，在 Inspector 中配置参数
## NPC 需要有 facing_direction 属性表示朝向

class_name SensoryComponent

## 检测到玩家
signal player_detected(player: Node2D)
## 失去玩家踪迹
signal player_lost()
## 听到声音
signal sound_heard(position: Vector2, loudness: float)

## 视线范围（像素）
@export var vision_range: float = 200.0
## 视线角度（度，以朝向为中心）
@export var vision_angle: float = 90.0
## 听觉范围（像素）
@export var hearing_range: float = 300.0
## 确认检测所需时间（秒）—— 防止"秒发现"的不公平感
@export var detection_time: float = 1.5
## 失去踪迹后继续追踪的时间（秒）
@export var memory_time: float = 5.0

## 当前检测进度（0.0~1.0，达到 1.0 确认发现）
var detection_progress: float = 0.0
## 是否已确认发现玩家
var is_alert: bool = false
## 最后已知的玩家位置
var last_known_player_pos: Vector2
## 失去踪迹后的记忆倒计时
var _memory_countdown: float = 0.0

var _player_ref: Node2D = null

## 延迟缓存玩家引用，等待场景加载完成。
func _ready() -> void:
	# 延迟获取玩家引用（等场景完全加载）
	call_deferred("_cache_player")

## 从 player 分组查找并缓存玩家节点引用。
func _cache_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

## 每帧更新视线/听觉感知，推进或衰减检测进度并发送信号。
## [param delta] 帧间隔时间（秒）。
func _process(delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_cache_player()
		return

	var can_see := _check_vision(_player_ref)
	var can_hear := _check_hearing(_player_ref)

	if can_see or can_hear:
		# 正在感知到玩家
		detection_progress += delta / detection_time
		last_known_player_pos = _player_ref.global_position
		_memory_countdown = memory_time
		if detection_progress >= 1.0 and not is_alert:
			is_alert = true
			player_detected.emit(_player_ref)
	else:
		# 失去感知
		if is_alert:
			# 记忆倒计时
			_memory_countdown -= delta
			detection_progress = clampf(detection_progress - delta * 0.3, 0.0, 1.0)
			if _memory_countdown <= 0.0:
				is_alert = false
				detection_progress = 0.0
				player_lost.emit()
		else:
			detection_progress = maxf(detection_progress - delta * 0.5, 0.0)

## 检查视线（视锥 + 射线遮挡）
func _check_vision(player: Node2D) -> bool:
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	if dist > vision_range:
		return false

	# 角度检查
	var facing := Vector2.RIGHT
	var parent := get_parent()
	if "facing_direction" in parent:
		facing = parent.facing_direction
	elif "velocity" in parent and parent.velocity.length() > 0.1:
		facing = parent.velocity.normalized()

	var angle_to := rad_to_deg(facing.angle_to(to_player.normalized()))
	if absf(angle_to) > vision_angle / 2.0:
		return false

	# 射线检查（墙壁遮挡）
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player.global_position)
	# 只检测墙壁层（collision_layer 4 = walls）
	query.collision_mask = 4
	var result := space.intersect_ray(query)
	return result.is_empty()  # 没有墙壁遮挡 = 看到玩家

## 检查听觉（跑步 = 全范围，走路 = 半范围）
func _check_hearing(player: Node2D) -> bool:
	var dist := global_position.distance_to(player.global_position)
	if dist > hearing_range:
		return false

	# 跑步声音大，全范围可听到
	if "is_running" in player and player.is_running:
		return true
	# 走路声音小，半范围可听到
	if "is_moving" in player and player.is_moving:
		return dist < hearing_range * 0.5
	return false

## 外部调用：注册一次声音事件（门开、物品掉落等）
## pos: 声音位置, loudness: 音量（0.0~1.0，1.0 = 最大）
func register_sound(pos: Vector2, loudness: float) -> void:
	var dist := global_position.distance_to(pos)
	var effective_range := hearing_range * loudness
	if dist < effective_range:
		sound_heard.emit(pos, loudness)
		last_known_player_pos = pos
		if not is_alert:
			# 声音也能推进检测进度
			detection_progress = clampf(detection_progress + 0.3, 0.0, 1.0)

## 获取检测状态描述（调试用）
func get_status_text() -> String:
	if is_alert:
		return "ALERT"
	elif detection_progress > 0.5:
		return "SUSPICIOUS"
	elif detection_progress > 0.0:
		return "NOTICED"
	return "UNAWARE"

## 编辑器中绘制视锥范围
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# 绘制视锥
	var color := Color(1.0, 0.3, 0.3, 0.15)
	var line_color := Color(1.0, 0.3, 0.3, 0.4)
	var facing := Vector2.RIGHT
	var half_angle := deg_to_rad(vision_angle / 2.0)
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in 17:
		var angle := -half_angle + (half_angle * 2.0) * (float(i) / 16.0)
		points.append(facing.rotated(angle) * vision_range)
	draw_colored_polygon(points, color)
	# 绘制听觉范围
	draw_arc(Vector2.ZERO, hearing_range, 0, TAU, 32, Color(0.3, 0.5, 1.0, 0.15), 1.0)
