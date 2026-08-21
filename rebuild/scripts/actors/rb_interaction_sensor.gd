class_name RbInteractionSensor
extends Area2D
## rebuild 交互探测器 —— 挂在玩家身上，负责"当前离谁最近"和"按键了没"。
##
## 它不执行交互，只把结果通过信号交给关卡根节点，保持单向数据流。

## 当前锁定目标发生变化（可能为 null）。
signal target_changed(target: RbInteractable)
## 玩家按下交互键，且有合法目标。
signal interact_requested(target: RbInteractable)

var _candidates: Array[RbInteractable] = []
var _current_target: RbInteractable = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func get_current_target() -> RbInteractable:
	return _current_target


## 外部（例如对话结束后）要求重新计算并重新广播当前目标。
func force_refresh() -> void:
	_recalculate_target()
	target_changed.emit(_current_target)


func _physics_process(_delta: float) -> void:
	_recalculate_target()


func _unhandled_input(event: InputEvent) -> void:
	if not RbGameState.is_gameplay_active():
		return
	if not event.is_action_pressed(&"interact"):
		return
	if _current_target == null:
		return
	interact_requested.emit(_current_target)
	# 消费掉本次输入，避免同一次按键又被对话推进器接走。
	get_viewport().set_input_as_handled()


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as RbInteractable
	if interactable == null:
		return
	if not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as RbInteractable
	if interactable == null:
		return
	_candidates.erase(interactable)


func _recalculate_target() -> void:
	var nearest: RbInteractable = null
	var nearest_distance: float = INF
	var origin: Vector2 = global_position

	var index: int = _candidates.size() - 1
	while index >= 0:
		var candidate: RbInteractable = _candidates[index]
		if not is_instance_valid(candidate):
			_candidates.remove_at(index)
		elif candidate.can_interact():
			var distance: float = origin.distance_squared_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
		index -= 1

	if nearest == _current_target:
		return
	_current_target = nearest
	target_changed.emit(_current_target)
