@tool
extends Node2D
## 可在编辑器中拖拽放置的电梯门节点
## 编辑器中显示门框预览，运行时自动创建门视觉 + 碰撞 + 触发区域
## 支持"到达门"（已开启）和"目标门"（需刷卡/事件后开启）

class_name GameElevatorDoor

## 门的尺寸
@export var door_size: Vector2 = Vector2(72, 60):
	set(value):
		door_size = value
		_rebuild()
## 是否为到达电梯（玩家从此出来，门默认开启）
@export var is_arrival: bool = false:
	set(value):
		is_arrival = value
		_rebuild()
## 电梯标签文本
@export var elevator_label: String = "电梯":
	set(value):
		elevator_label = value
		queue_redraw()
## 是否需要电梯卡
@export var requires_card: bool = false
## 需要触发的事件标签（留空则不需要事件）
@export var required_event: String = ""
## 进入电梯后加载的场景路径
@export var target_scene: String = ""

const ELEVATOR_DOOR_TEX_PATH := "res://assets/sprites/_0013_电梯门.png"
const ELEVATOR_DOOR_OPEN_TEX_PATH := "res://assets/sprites/打开的电梯门.png"

var _door_visual: Node = null

## 节点就绪回调：编辑器中立即重建预览，运行时延迟构建。
func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		# 运行时延迟构建：可能向关卡添加世界标签，场景装载期间会失败
		call_deferred("_rebuild")

## 清空并重建门的全部子节点（视觉/碰撞/触发区域）。
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_build()

## 释放所有子节点并重置门视觉引用。
func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_door_visual = null

## 获取子节点应归属的 owner 节点。
## [return] 编辑器中返回当前编辑场景根节点，运行时返回自身。
func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

## 构建门内容：编辑器走预览分支，运行时走完整构建分支。
func _build() -> void:
	var owner_node := _get_owner()

	if Engine.is_editor_hint():
		_build_editor_preview(owner_node)
	else:
		_build_runtime()

## 在编辑器中构建门框、门扇、标签与需求提示预览。
## [param owner_node] 子节点归属的 owner 场景根节点。
func _build_editor_preview(owner_node: Node) -> void:
	# 门框
	var frame := ColorRect.new()
	frame.position = -door_size / 2
	frame.size = door_size
	frame.color = Color(0.18, 0.18, 0.2)
	add_child(frame)
	frame.set_owner(owner_node)

	# 门扇
	if is_arrival:
		# 开着的门
		var door_left := ColorRect.new()
		door_left.position = -door_size / 2 + Vector2(0, 2)
		door_left.size = Vector2(4, door_size.y - 2)
		door_left.color = Color(0.25, 0.25, 0.28)
		add_child(door_left)
		door_left.set_owner(owner_node)
		var door_right := ColorRect.new()
		door_right.position = Vector2(door_size.x / 2 - 4, -door_size.y / 2 + 2)
		door_right.size = Vector2(4, door_size.y - 2)
		door_right.color = Color(0.25, 0.25, 0.28)
		add_child(door_right)
		door_right.set_owner(owner_node)
	else:
		# 关着的门
		var door := ColorRect.new()
		door.position = -door_size / 2 + Vector2(4, 2)
		door.size = door_size - Vector2(8, 2)
		door.color = Color(0.22, 0.22, 0.25)
		door.z_index = 1
		add_child(door)
		door.set_owner(owner_node)

	# 标签
	var lbl := Label.new()
	lbl.text = elevator_label
	lbl.position = Vector2(-20, -door_size.y / 2 - 18)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	add_child(lbl)
	lbl.set_owner(owner_node)

	# 需求提示
	if requires_card:
		var req_lbl := Label.new()
		req_lbl.text = "[需要电梯卡]"
		req_lbl.position = Vector2(-30, door_size.y / 2 + 4)
		req_lbl.add_theme_font_size_override("font_size", 9)
		req_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		add_child(req_lbl)
		req_lbl.set_owner(owner_node)

## 运行时构建：按到达/目标类型生成开门视觉、碰撞阻挡与交互触发区域，并添加电梯标签。
func _build_runtime() -> void:
	var level := _find_level()
	var door_center := position
	var center_2d := door_center + Vector2(0, -20) if not is_arrival else door_center

	if is_arrival:
		# 到达电梯：显示打开的门
		_build_open_door(center_2d)
		_build_blocker(center_2d)
	else:
		# 目标电梯：显示关闭的门
		_build_closed_door(center_2d)
		_build_blocker(center_2d)
		_build_trigger()

	# 电梯标签
	if level and level.has_method("create_world_label"):
		var label_text := LocaleManager.world_text(elevator_label) if LocaleManager else elevator_label
		level.create_world_label(label_text, position + Vector2(-14, -door_size.y / 2 - 20), 14, Color(0.4, 0.4, 0.45))

## 构建打开状态的电梯门视觉（贴图或色块回退）。
## [param center] 门视觉的中心位置。
func _build_open_door(center: Vector2) -> void:
	if ResourceLoader.exists(ELEVATOR_DOOR_OPEN_TEX_PATH):
		var door := Sprite2D.new()
		door.texture = load(ELEVATOR_DOOR_OPEN_TEX_PATH)
		door.centered = true
		door.position = center
		var tex_size := door.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			door.scale = Vector2(door_size.x / tex_size.x, door_size.y / tex_size.y)
		add_child(door)
		_door_visual = door
	else:
		# 回退：色块门
		var left := ColorRect.new()
		left.position = center - door_size / 2 + Vector2(0, 2)
		left.size = Vector2(4, door_size.y - 2)
		left.color = Color(0.18, 0.18, 0.2)
		add_child(left)
		var right := ColorRect.new()
		right.position = center + Vector2(door_size.x / 2 - 4, -door_size.y / 2 + 2)
		right.size = Vector2(4, door_size.y - 2)
		right.color = Color(0.18, 0.18, 0.2)
		add_child(right)
		var top := ColorRect.new()
		top.position = center - door_size / 2
		top.size = Vector2(door_size.x, 4)
		top.color = Color(0.18, 0.18, 0.2)
		add_child(top)

## 构建关闭状态的电梯门视觉（贴图缺失时回退为开门样式）。
## [param center] 门视觉的中心位置。
func _build_closed_door(center: Vector2) -> void:
	if ResourceLoader.exists(ELEVATOR_DOOR_TEX_PATH):
		var door := Sprite2D.new()
		door.texture = load(ELEVATOR_DOOR_TEX_PATH)
		door.centered = true
		door.position = center
		var tex_size := door.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			door.scale = Vector2(door_size.x / tex_size.x, door_size.y / tex_size.y)
		add_child(door)
		_door_visual = door
	else:
		_build_open_door(center)  # 回退

## 在指定位置创建矩形静态碰撞体，阻挡玩家通行。
## [param center] 碰撞体中心位置。
func _build_blocker(center: Vector2) -> void:
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 4
	blocker.position = center
	add_child(blocker)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = door_size
	col.shape = shape
	blocker.add_child(col)

## 创建玩家进入检测区域：校验电梯卡与事件条件后加载目标场景。
func _build_trigger() -> void:
	var level := _find_level()
	if not level:
		return
	var area := Area2D.new()
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = door_size + Vector2(20, 20)
	col.shape = shape
	area.add_child(col)

	area.body_entered.connect(func(body: Node2D) -> void:
		if not body.is_in_group("player"):
			return
		# 检查电梯卡需求
		if requires_card and InventoryManager:
			if not InventoryManager.has_item("elevator_card"):
				return
		# 检查事件需求
		if required_event != "" and GameManager:
			if not GameManager.event_flags.get(required_event, false):
				return
		# 进入电梯
		if target_scene != "" and GameManager:
			GameManager.load_scene(target_scene)
	)

## 打开电梯门（由关卡脚本调用）
func open_door() -> void:
	if _door_visual and is_instance_valid(_door_visual):
		_door_visual.queue_free()
	_door_visual = null
	# 切换为打开状态
	is_arrival = true
	# 移除碰撞阻挡
	for child in get_children():
		if child is StaticBody2D:
			child.queue_free()

## 向上遍历祖先查找关卡节点。
## [return] 含 show_hint 方法的关卡节点，未找到返回 null。
func _find_level() -> Node:
	var p := get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null
