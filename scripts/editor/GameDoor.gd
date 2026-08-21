@tool
extends Node2D
## 可在编辑器中拖拽放置的门节点
## 运行时自动创建门的碰撞、视觉和交互系统

class_name GameDoor

@export var door_size: Vector2 = Vector2(44, 8):
	set(value):
		door_size = value
		_rebuild()
@export var locked: bool = false:
	set(value):
		locked = value
		_rebuild()
@export var room_side_normal: Vector2 = Vector2.UP:
	set(value):
		room_side_normal = value
		_rebuild()

var _built_runtime: bool = false

## 节点就绪回调：仅在编辑器中重建预览，运行时由关卡脚本统一触发。
func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	# 运行时由 LevelBaseV2.discover_scene_nodes() 统一触发重建，
	# 避免场景装载期间父节点忙碌导致 add_child 失败

## 清空子节点后按环境重建：编辑器构建预览，运行时仅构建一次。
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	if Engine.is_editor_hint():
		_build_editor_preview()
	elif not _built_runtime:
		_built_runtime = true
		_build_runtime()

## 释放所有子节点。
func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

## 获取子节点应归属的 owner 节点。
## [return] 编辑器中返回当前编辑场景根节点，运行时返回自身。
func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

## 在编辑器中构建门框、门扇与上锁图标预览。
func _build_editor_preview() -> void:
	var owner_node = _get_owner()
	var is_vertical := door_size.x < door_size.y

	# Door frame
	var frame_color := Color(0.3, 0.22, 0.16)
	if is_vertical:
		var frame_left := ColorRect.new()
		frame_left.position = Vector2(-door_size.x / 2 - 1, -door_size.y / 2)
		frame_left.size = Vector2(2, door_size.y)
		frame_left.color = frame_color
		add_child(frame_left)
		frame_left.set_owner(owner_node)
		var frame_right := ColorRect.new()
		frame_right.position = Vector2(door_size.x / 2 - 1, -door_size.y / 2)
		frame_right.size = Vector2(2, door_size.y)
		frame_right.color = frame_color
		add_child(frame_right)
		frame_right.set_owner(owner_node)
	else:
		var frame_top := ColorRect.new()
		frame_top.position = Vector2(-door_size.x / 2, -door_size.y / 2 - 1)
		frame_top.size = Vector2(door_size.x, 2)
		frame_top.color = frame_color
		add_child(frame_top)
		frame_top.set_owner(owner_node)
		var frame_bottom := ColorRect.new()
		frame_bottom.position = Vector2(-door_size.x / 2, door_size.y / 2 - 1)
		frame_bottom.size = Vector2(door_size.x, 2)
		frame_bottom.color = frame_color
		add_child(frame_bottom)
		frame_bottom.set_owner(owner_node)

	# Door visual
	var door_rect := ColorRect.new()
	door_rect.position = -door_size / 2
	door_rect.size = door_size
	door_rect.color = Color(0.35, 0.2, 0.1) if locked else Color(0.2, 0.15, 0.08)
	door_rect.z_index = 11
	add_child(door_rect)
	door_rect.set_owner(owner_node)

	# Lock icon
	if locked:
		var lbl := Label.new()
		lbl.text = "LOCKED"
		lbl.position = Vector2(-20, -20)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		add_child(lbl)
		lbl.set_owner(owner_node)

## 运行时构建：委托关卡 add_door 创建门系统，无关卡时回退为简单门。
func _build_runtime() -> void:
	# Find the LevelBase parent to use its add_door method
	var level = _find_level()
	if level and level.has_method("add_door"):
		var walls_parent := _find_or_create_walls(level)
		level.add_door(walls_parent, position, door_size, locked, room_side_normal)
	else:
		# Fallback: build a simple door
		_build_simple_door()

## 回退方案：直接创建带碰撞和色块视觉的简易门。
func _build_simple_door() -> void:
	var door_body := StaticBody2D.new()
	door_body.collision_layer = 4
	add_child(door_body)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = door_size
	col.shape = rect
	door_body.add_child(col)
	var door_rect := ColorRect.new()
	door_rect.position = -door_size / 2
	door_rect.size = door_size
	door_rect.color = Color(0.2, 0.15, 0.08)
	door_rect.z_index = 11
	add_child(door_rect)

## 向上遍历祖先查找关卡节点。
## [return] 含 show_hint 方法的关卡节点，未找到返回 null。
func _find_level() -> Node:
	var p = get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null

## 查找关卡下的 Walls 节点，不存在则创建。
## [param level] 关卡节点。
## [return] Walls 容器节点。
func _find_or_create_walls(level: Node) -> Node2D:
	var walls := level.get_node_or_null("Walls")
	if walls:
		return walls
	walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 4
	level.add_child(walls)
	return walls
