extends SceneTree
## rebuild 最小流程自动化冒烟测试（headless）。
##
## 运行方式：
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . \
##       --script res://rebuild/tools/rb_flow_test.gd
##
## 它不依赖真实按键输入，而是直接驱动公开信号与公开方法，
## 用来验证"场景结构 + 信号接线 + 状态机"这条链路没断。

var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if condition:
		print("  [PASS] %s" % label)
		return true
	_failures.append(label)
	print("  [FAIL] %s" % label)
	return false


func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_physics(count: int) -> void:
	for i in count:
		await physics_frame


## 模拟玩家按下并松开“交互”键（Space），走完整的
## “按键 → 传感器 _unhandled_input → interact_requested”真实输入链路。
## 冒烟测试原本直接 emit 信号，会绕过这条路径，这里单独覆盖。
func _interact_via_input() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = 32  # KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await _wait_frames(3)
	var release := InputEventKey.new()
	release.physical_keycode = 32
	release.pressed = false
	Input.parse_input_event(release)
	await _wait_frames(3)


func _run() -> void:
	print("=========== rebuild 最小流程测试 ===========")
	RbGameState.reset_for_new_game()

	# ---------------------------------------------------------- 序章街道
	print("[1] 加载序章街道")
	change_scene_to_file(RbSceneRegistry.resolve_path(RbSceneRegistry.PROLOGUE_STREET))
	await _wait_frames(3)

	var street := current_scene as RbLevelRoot
	if not _check(street != null, "街道根节点是 RbLevelRoot"):
		return _finish()

	_check(street.player != null, "玩家实例存在（来自 rb_level_base.tscn）")
	_check(street.game_ui != null, "GameUi 实例存在（来自 rb_level_base.tscn）")
	_check(street.dialogue_runner != null, "DialogueRunner 存在")
	_check(street.props.get_child_count() > 0, "World/Props 有内容")
	_check(street.spawn_points.get_node_or_null("default") != null, "街道有 default 出生点")

	var street_spawn := street.spawn_points.get_node("default") as Marker2D
	_check(street.player.global_position.is_equal_approx(street_spawn.global_position),
		"玩家被放到 default 出生点 %s" % str(street_spawn.global_position))

	# ---------------------------------------------------------- 开场对话
	print("[2] 开场对话")
	_check(street.dialogue_runner.is_active(), "进入关卡自动播放 street_intro")
	_check(street.dialogue_runner.get_active_id() == RbDialogueDb.STREET_INTRO, "对话 id 正确")
	_check(RbGameState.get_state() == RbGameState.State.DIALOGUE, "状态切到 DIALOGUE")
	_check(street.game_ui.dialogue_box.visible, "对话框已显示")
	_check(not RbGameState.is_gameplay_active(), "对话中玩家移动被冻结")

	var street_line_count: int = RbDialogueDb.get_lines(RbDialogueDb.STREET_INTRO).size()
	for i in street_line_count:
		street.dialogue_runner.advance()
	_check(not street.dialogue_runner.is_active(), "推进 %d 行后对话结束" % street_line_count)
	_check(not street.game_ui.dialogue_box.visible, "对话框已隐藏")
	_check(RbGameState.get_state() == RbGameState.State.PLAYING, "状态恢复 PLAYING")

	# ---------------------------------------------------------- 交互探测
	print("[3] 走到公寓门前")
	var apartment_door := street.props.get_node_or_null("ApartmentDoor") as RbDoor
	if not _check(apartment_door != null, "街道存在 ApartmentDoor"):
		return _finish()

	street.player.global_position = apartment_door.global_position + Vector2(0, 40)
	await _wait_physics(4)
	await _wait_frames(1)

	var sensor: RbInteractionSensor = street.player.interaction_sensor
	_check(sensor.get_current_target() == apartment_door, "交互探测器锁定了门")
	_check(street.game_ui.interact_prompt.visible, "交互提示条已显示")

	# ---------------------------------------------------------- 切换到房间
	print("[4] 开门进入房间（真实按键）")
	await _interact_via_input()
	await _wait_frames(2)

	var room := current_scene as RbLevelRoot
	if not _check(room != null and room.level_id == "prologue_room", "已切换到 prologue_room"):
		return _finish()

	var room_spawn := room.spawn_points.get_node_or_null("from_street") as Marker2D
	if _check(room_spawn != null, "房间有 from_street 出生点"):
		_check(room.player.global_position.is_equal_approx(room_spawn.global_position),
			"玩家出现在 from_street 出生点 %s" % str(room_spawn.global_position))

	_check(room.dialogue_runner.get_active_id() == RbDialogueDb.ROOM_INTRO, "房间开场对话播放")
	var room_line_count: int = RbDialogueDb.get_lines(RbDialogueDb.ROOM_INTRO).size()
	for i in room_line_count:
		room.dialogue_runner.advance()
	_check(RbGameState.is_gameplay_active(), "房间开场对话结束后可自由移动")

	# ---------------------------------------------------------- 可交互物品
	print("[5] 查看手机")
	var phone := room.props.get_node_or_null("Phone") as RbExaminable
	if not _check(phone != null, "房间存在 Phone 可交互物"):
		return _finish()

	room.player.global_position = phone.global_position + Vector2(0, 30)
	await _wait_physics(4)
	await _wait_frames(1)

	var room_sensor: RbInteractionSensor = room.player.interaction_sensor
	_check(room_sensor.get_current_target() == phone, "交互探测器锁定了手机")

	await _interact_via_input()
	await _wait_frames(1)
	_check(room.dialogue_runner.get_active_id() == RbDialogueDb.ROOM_PHONE_FIRST, "播放首次查看对话")
	_check(phone.has_been_examined(), "手机被标记为已查看")
	_check(RbGameState.has_flag("read_sister_message"), "剧情标记 read_sister_message 已写入")

	var phone_line_count: int = RbDialogueDb.get_lines(RbDialogueDb.ROOM_PHONE_FIRST).size()
	for i in phone_line_count:
		room.dialogue_runner.advance()
	_check(not room.dialogue_runner.is_active(), "手机对话结束")

	print("[6] 再次查看手机（重复文本分支，真实按键）")
	await _interact_via_input()
	await _wait_frames(1)
	_check(room.dialogue_runner.get_active_id() == RbDialogueDb.ROOM_PHONE_REPEAT, "播放重复查看对话")
	room.dialogue_runner.stop()
	await _wait_frames(1)

	# ---------------------------------------------------------- 返回街道
	print("[7] 返回街道")
	var back_door := room.props.get_node_or_null("DoorToStreet") as RbDoor
	if not _check(back_door != null, "房间存在 DoorToStreet"):
		return _finish()

	room.player.global_position = back_door.global_position + Vector2(0, 40)
	await _wait_physics(4)
	await _wait_frames(1)
	_check(room.player.interaction_sensor.get_current_target() == back_door, "锁定返回门")

	await _interact_via_input()
	await _wait_frames(2)

	var street_again := current_scene as RbLevelRoot
	if _check(street_again != null and street_again.level_id == "prologue_street", "已切回 prologue_street"):
		var from_room_spawn := street_again.spawn_points.get_node_or_null("from_room") as Marker2D
		if _check(from_room_spawn != null, "街道有 from_room 出生点"):
			_check(street_again.player.global_position.is_equal_approx(from_room_spawn.global_position),
				"玩家出现在 from_room 出生点 %s" % str(from_room_spawn.global_position))
		# 第二次进入街道仍会重播开场对话，这里推完以便观察状态恢复
		while street_again.dialogue_runner.is_active():
			street_again.dialogue_runner.advance()
		_check(RbGameState.is_gameplay_active(), "回到街道后可自由移动")

	# ---------------------------------------------------------- 主菜单场景
	print("[8] 主菜单场景可独立加载")
	change_scene_to_file(RbSceneRegistry.resolve_path(RbSceneRegistry.MAIN_MENU))
	await _wait_frames(3)
	var menu := current_scene as RbMainMenuUi
	_check(menu != null, "主菜单根节点是 RbMainMenuUi")
	_check(RbGameState.get_state() == RbGameState.State.MENU, "主菜单把状态切回 MENU")

	_finish()


func _finish() -> void:
	print("===========================================")
	if _failures.is_empty():
		print("全部通过：%d / %d" % [_checks, _checks])
		quit(0)
		return
	print("失败 %d / %d：" % [_failures.size(), _checks])
	for failure: String in _failures:
		print("  - %s" % failure)
	quit(1)
