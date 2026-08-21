extends Area2D
## 通用房门：普通门自动开关，锁门解锁后自动开关
## 视觉与碰撞都按铰链门旋转，靠近哪一侧就向对应方向开门

const OPEN_DURATION: float = 0.16
const CLOSE_DURATION: float = 0.14
const GAP_ALPHA: float = 0.55

var _door_pivot: Node2D
var _door_body: StaticBody2D
var _door_collision: CollisionShape2D
var _door_visual: CanvasItem
var _door_gap: ColorRect
var _lock_label: Label
var _hint_label: Label
var _level: Node
var _required_key: String = "master_key"
var _locked: bool = false
var _is_open: bool = false
var _door_vertical: bool = true
var _room_side_normal: Vector2 = Vector2.UP
var _body_inside_count: int = 0
var _player_inside_count: int = 0
var _anim_tween: Tween = null
var _open_angle: float = 0.0

var _open_progress: float = 0.0:
	set(value):
		_open_progress = clampf(value, 0.0, 1.0)
		_apply_open_progress()

## 初始化门：读取元数据配置、设置碰撞掩码并连接身体进出信号。
func _ready() -> void:
	_door_pivot = get_meta("door_pivot") if has_meta("door_pivot") else null
	_door_body = get_meta("door_body") if has_meta("door_body") else null
	_door_collision = get_meta("door_collision") if has_meta("door_collision") else null
	_door_visual = get_meta("door_visual") if has_meta("door_visual") else null
	_door_gap = get_meta("door_gap") if has_meta("door_gap") else null
	_lock_label = get_meta("lock_label") if has_meta("lock_label") else null
	_hint_label = get_meta("hint_label") if has_meta("hint_label") else null
	_level = get_meta("level") if has_meta("level") else null
	_refresh_meta_state()
	_door_vertical = get_meta("door_vertical", true)
	_room_side_normal = (get_meta("room_side_normal", Vector2.UP) as Vector2).normalized()
	# 同时检测玩家和NPC以便门在关闭时不会把NPC困住，但仅允许玩家触发开门逻辑
	collision_mask = 3  # 检测 layer 1(player) + layer 2(npc)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_open_progress()
	_sync_interaction_state()

## 从元数据刷新所需钥匙与锁定状态（支持运行时动态修改）。
func _refresh_meta_state() -> void:
	_required_key = get_meta("required_key") if has_meta("required_key") else _required_key
	_locked = get_meta("locked") if has_meta("locked") else _locked

## 玩家交互：未锁直接开门；已锁且有钥匙则解锁开门，否则提示需要钥匙。
func interact() -> void:
	_refresh_meta_state()
	if not _locked:
		_open_door(_get_player_actor())
		return
	if InventoryManager.has_item(_required_key):
		_unlock_door(_get_player_actor())
	else:
		_show_level_hint(LocaleManager.door_need_key_text())

## 实体进入门区时计数；若为玩家且门未锁则自动开门。
## [param body] 进入门区的物理体（玩家或 NPC）。
func _on_body_entered(body: Node) -> void:
	# 统计进入门区的可移动实体（玩家或NPC），但仅玩家触发开门
	if not (body.is_in_group("player") or body.is_in_group("npc")):
		return
	_body_inside_count += 1
	if body.is_in_group("player"):
		_player_inside_count += 1
		_sync_interaction_state()
		if not _locked:
			_open_door(body)

## 实体离开门区时更新计数，无人停留且未锁时自动关门。
## [param body] 离开门区的物理体（玩家或 NPC）。
func _on_body_exited(body: Node) -> void:
	# 统计离开门区的玩家/NPC，保证门在有任何实体停留时不关闭
	if not (body.is_in_group("player") or body.is_in_group("npc")):
		return
	_body_inside_count = maxi(_body_inside_count - 1, 0)
	if body.is_in_group("player"):
		_player_inside_count = maxi(_player_inside_count - 1, 0)
		_sync_interaction_state()
	if not _locked and _body_inside_count == 0:
		_close_door()

## 解锁房门：消耗对应钥匙、清除锁标识并随即自动开门。
## [param opener] 触发解锁的节点，用于决定开门方向。
func _unlock_door(opener: Node = null) -> void:
	_refresh_meta_state()
	_locked = false
	set_meta("locked", false)
	InputDevice.vibrate_light()
	if is_instance_valid(_lock_label):
		_lock_label.queue_free()
	_sync_interaction_state()
	var key_data = InventoryManager.get_item_data(_required_key)
	var key_name = key_data.get("name", "钥匙") if key_data else "钥匙"
	if _level and _level.has_method("show_hint"):
		_level.show_hint(LocaleManager.door_unlocked_text(_required_key, key_name), 6.0)
	InventoryManager.remove_item(_required_key)
	_open_door(opener)

## 打开房门：播放开门音效并按开启者方位决定开门方向。
## [param opener] 触发开门的节点，用于决定开门方向。
func _open_door(opener: Node = null) -> void:
	if _locked or _is_open:
		return
	_open_angle = _resolve_open_angle(opener)
	_is_open = true
	AudioManager.play_door_open()
	_sync_interaction_state()
	_animate_to(1.0, OPEN_DURATION)

## 关闭房门：播放关门音效并将门动画收回关闭状态。
func _close_door() -> void:
	if _locked or not _is_open or _body_inside_count > 0:
		return
	_is_open = false
	AudioManager.play_door_close()
	_sync_interaction_state()
	_animate_to(0.0, CLOSE_DURATION)

## 用补间动画将门的开启进度平滑过渡到目标值。
## [param target] 目标进度（0=关，1=开）。
## [param duration] 动画时长（秒）。
func _animate_to(target: float, duration: float) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "_open_progress", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 按开启进度应用门的表现：门板淡出成残影、门缝透光并关闭碰撞。
func _apply_open_progress() -> void:
	var is_sprite_door := is_instance_valid(_door_visual) and _door_visual is Sprite2D
	# 统一改成“门板淡出 + 碰撞关闭”，不再让任何门发生扇叶旋转推人。
	if is_instance_valid(_door_collision):
		_door_collision.disabled = (_open_progress > 0.01)
	if is_instance_valid(_door_pivot):
		_door_pivot.rotation = 0.0
	if is_instance_valid(_door_visual):
		# 贴图门和色块门都只保留一层残影，避免出现会挡人的翻转门板。
		var target_alpha := 0.28 if is_sprite_door else 0.22
		_door_visual.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, target_alpha, _open_progress))
	if is_instance_valid(_door_gap):
		var gap_alpha := 1.0 if is_sprite_door else GAP_ALPHA
		_door_gap.modulate = Color(1.0, 1.0, 1.0, lerpf(0.0, gap_alpha, _open_progress))

## 更新交互提示标签：玩家在附近且门需要操作时显示按键提示。
func _sync_hint() -> void:
	if not is_instance_valid(_hint_label):
		return
	if _player_inside_count > 0 and (_locked or not _is_open):
		_hint_label.text = "%s %s" % [LocaleManager.world_text("门"), InputDevice.hint("interact")]
		_hint_label.visible = true
	else:
		_hint_label.visible = false

## 同步可交互状态：玩家在附近且门待操作时加入 interactable 组。
func _sync_interaction_state() -> void:
	if _player_inside_count > 0 and (_locked or not _is_open):
		add_to_group("interactable")
	else:
		remove_from_group("interactable")
	_sync_hint()

## 通过关卡场景显示提示文本。
## [param text] 提示内容。
func _show_level_hint(text: String) -> void:
	if _level and _level.has_method("show_hint"):
		_level.show_hint(text)

## 计算门板开启角度：向远离开启者的一侧摆动。
## [param opener] 触发开门的节点，用于判断其位于门的哪一侧。
## [return] 门板相对关闭状态的旋转角（弧度）。
func _resolve_open_angle(opener: Node = null) -> float:
	var actor = opener if opener is Node2D else _get_player_actor()
	var desired_swing_side = _room_side_normal
	if actor and actor is Node2D:
		var actor_offset = (actor as Node2D).global_position - global_position
		if actor_offset.dot(_room_side_normal) > 0.0:
			desired_swing_side = -_room_side_normal
	var closed_direction = Vector2.DOWN if _door_vertical else Vector2.RIGHT
	return wrapf(desired_swing_side.angle() - closed_direction.angle(), -PI, PI)

## 获取场景中的玩家节点。
## [return] 玩家 Node2D，不存在时返回 null。
func _get_player_actor() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

## 判断节点是否为可操作门的玩家。
## [param body] 待判断的节点。
## [return] 是玩家时返回 true。
func _is_door_user(body: Node) -> bool:
	return body.is_in_group("player")
