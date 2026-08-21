@tool
extends StaticBody2D
## 可在编辑器中拖拽放置的墙壁节点
## 在Inspector中调整 wall_size、wall_color 等属性，碰撞和视觉自动更新

class_name GameWall

@export var wall_size: Vector2 = Vector2(100, 8):
	set(value):
		wall_size = value
		_rebuild()
@export var wall_color: Color = Color(0.1, 0.08, 0.07):
	set(value):
		wall_color = value
		_rebuild()
@export var show_cap: bool = true:
	set(value):
		show_cap = value
		_rebuild()
@export var show_front_face: bool = true:
	set(value):
		show_front_face = value
		_rebuild()
@export var show_side_face: bool = true:
	set(value):
		show_side_face = value
		_rebuild()
@export var face_normal: Vector2 = Vector2.ZERO:
	set(value):
		face_normal = value
		_rebuild()
@export var cap_z_index: int = 4:
	set(value):
		cap_z_index = value
		_rebuild()

const WALL_FRONT_FACE_DEPTH: float = 22.0
const WALL_SIDE_FACE_DEPTH: float = 5.0

var _built: bool = false

func _ready() -> void:
	collision_layer = 4  # walls layer
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_built = false
	_build()
	_built = true

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

func _build() -> void:
	var size := wall_size
	if size.x <= 0 or size.y <= 0:
		return

	var owner_node = _get_owner()

	# Collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var col_center := Vector2.ZERO
	var col_size := size

	if size.x >= size.y and face_normal != Vector2.ZERO and absf(face_normal.y) > 0.5 and show_front_face:
		var dir_y := signf(face_normal.y)
		col_size.y += WALL_FRONT_FACE_DEPTH
		col_center.y -= dir_y * WALL_FRONT_FACE_DEPTH / 2.0
	elif size.y > size.x and face_normal != Vector2.ZERO and absf(face_normal.x) > 0.5 and show_side_face:
		var dir_x := signf(face_normal.x)
		col_size.x += WALL_SIDE_FACE_DEPTH
		col_center.x -= dir_x * WALL_SIDE_FACE_DEPTH / 2.0

	rect.size = col_size
	col.shape = rect
	col.position = col_center
	add_child(col)
	if Engine.is_editor_hint():
		col.set_owner(owner_node)

	# Visual cap (top-down view of the wall)
	if show_cap:
		var cap := ColorRect.new()
		cap.position = -size / 2
		cap.size = size
		cap.color = wall_color.lightened(0.05)
		cap.z_index = cap_z_index
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cap)
		if Engine.is_editor_hint():
			cap.set_owner(owner_node)

	# Front face (for horizontal walls)
	if size.x >= size.y:
		if face_normal != Vector2.ZERO and absf(face_normal.y) > 0.5 and show_front_face:
			_add_horizontal_face(size, signf(face_normal.y))
		elif show_front_face:
			_add_horizontal_face(size, 1.0)

	# Side face (for vertical walls)
	if size.y >= size.x:
		if face_normal != Vector2.ZERO and absf(face_normal.x) > 0.5 and show_side_face:
			_add_vertical_face(size, signf(face_normal.x))
		elif show_side_face:
			_add_vertical_face(size, 1.0)

	# Light occluder
	var occluder := LightOccluder2D.new()
	occluder.occluder_light_mask = 0
	var poly := OccluderPolygon2D.new()
	var half := size / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	occluder.occluder = poly
	add_child(occluder)
	if Engine.is_editor_hint():
		occluder.set_owner(owner_node)

	# Mark as nav obstacle
	add_to_group("nav_obstacle")

func _add_horizontal_face(size: Vector2, dir_sign: float) -> void:
	var face_h := 48.0
	var owner_node = _get_owner()
	var tex_path := "res://assets/sprites/_0002_水平墙正面.png"
	if ResourceLoader.exists(tex_path):
		var spr := Sprite2D.new()
		spr.texture = load(tex_path)
		spr.scale = Vector2(size.x / 880.0, face_h / 162.0)
		var center_y := dir_sign * (size.y * 0.5 - 16.0)
		spr.position = Vector2(0, center_y)
		spr.z_index = 0
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		if Engine.is_editor_hint():
			spr.set_owner(owner_node)
	else:
		var face := ColorRect.new()
		face.position = Vector2(-size.x / 2, 0)
		face.size = Vector2(size.x, face_h)
		face.color = wall_color.darkened(0.1)
		face.z_index = 0
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(face)
		if Engine.is_editor_hint():
			face.set_owner(owner_node)

func _add_vertical_face(size: Vector2, dir_sign: float) -> void:
	var face_w := WALL_SIDE_FACE_DEPTH
	var owner_node = _get_owner()
	var tex_path := "res://assets/sprites/_0004_竖向墙侧面.png"
	if ResourceLoader.exists(tex_path):
		var spr := Sprite2D.new()
		spr.texture = load(tex_path)
		spr.scale = Vector2(face_w / 55.0, size.y / 329.0)
		var center_x := (size.x * 0.5 + face_w * 0.5) * dir_sign
		spr.position = Vector2(center_x, 0)
		spr.z_index = 0
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		if Engine.is_editor_hint():
			spr.set_owner(owner_node)
	else:
		var face := ColorRect.new()
		face.position = Vector2(0, -size.y / 2)
		face.size = Vector2(face_w, size.y)
		face.color = wall_color.darkened(0.15)
		face.z_index = 0
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(face)
		if Engine.is_editor_hint():
			face.set_owner(owner_node)
