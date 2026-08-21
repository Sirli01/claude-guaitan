extends Area2D
## 可休息的长椅 — 按E坐下冻结玩家，2秒恢复全部体力
## 按任意方向键可中途打断

var _level: Node
var _name_label: Label
var _is_resting: bool = false
var _sit_offset := Vector2(0, -4)  # 玩家坐下时相对长椅的位置偏移

func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _name_label:
		_name_label.text = LocaleManager.bench_prompt_text()
		_name_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _name_label:
		_name_label.visible = false

func interact() -> void:
	if _is_resting:
		return
	if PlayerStats.stamina >= PlayerStats.max_stamina:
		if _level and _level.has_method("show_hint"):
			_level.show_hint(LocaleManager.bench_no_need_text())
		return

	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		return

	_is_resting = true

	# 保存玩家原位置，然后吸附到椅子位置并冻结
	var saved_position: Vector2 = player_node.global_position
	player_node.global_position = global_position + _sit_offset
	player_node.freeze_player()

	if _name_label:
		_name_label.text = LocaleManager.bench_resting_text()
	if _level and _level.has_method("show_hint"):
		_level.show_hint(LocaleManager.bench_sit_text(), 3.0)

	# 2秒内恢复全部体力
	var start_val := PlayerStats.stamina
	var tw = (_level.create_tween() if _level else create_tween())
	tw.tween_method(func(v: float): PlayerStats.set_stamina(v), start_val, PlayerStats.max_stamina, 2.0)

	# 每帧检测方向键，按下则中断
	var interrupted := false
	while tw.is_running():
		await get_tree().process_frame
		if Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
		   or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			tw.kill()
			interrupted = true
			break

	# 恢复原位并解冻玩家
	player_node.global_position = saved_position
	player_node.unfreeze_player()
	_is_resting = false

	if _name_label:
		_name_label.text = LocaleManager.bench_prompt_text()
	if _level and _level.has_method("show_hint"):
		if interrupted:
			_level.show_hint(LocaleManager.bench_stood_up_text(), 1.5)
		else:
			_level.show_hint(LocaleManager.bench_recovered_text(), 2.0)
