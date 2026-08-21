@tool
extends Node2D
## 可在编辑器中拖拽放置的房间天花板遮罩
## 玩家进入房间时天花板淡出，离开时淡入

class_name GameCeiling

@export var room_id: String = "room_1":
	set(value):
		room_id = value
@export var ceiling_size: Vector2 = Vector2(180, 130):
	set(value):
		ceiling_size = value
		_rebuild()
## 可选：覆盖检测区域（留空则使用 ceiling_size）
@export var detection_rect: Rect2 = Rect2():
	set(value):
		detection_rect = value

var _ceiling_rect: ColorRect = null

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_build()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_ceiling_rect = null

func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

func _build() -> void:
	if ceiling_size.x <= 0 or ceiling_size.y <= 0:
		return

	var owner_node = _get_owner()

	_ceiling_rect = ColorRect.new()
	_ceiling_rect.position = -ceiling_size / 2
	_ceiling_rect.size = ceiling_size
	_ceiling_rect.color = Color(0.02, 0.015, 0.015, 1.0)
	_ceiling_rect.z_index = 10
	_ceiling_rect.light_mask = 0
	add_child(_ceiling_rect)
	if Engine.is_editor_hint():
		_ceiling_rect.set_owner(owner_node)

	# Detection area
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	if Engine.is_editor_hint():
		area.set_owner(owner_node)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var detect_size := detection_rect.size if detection_rect.size != Vector2.ZERO else ceiling_size
	shape.size = detect_size - Vector2(20, 20)
	col.shape = shape
	area.add_child(col)
	if Engine.is_editor_hint():
		col.set_owner(owner_node)

	if not Engine.is_editor_hint():
		var rid := room_id
		area.body_entered.connect(func(body):
			if body.is_in_group("player"):
				var level = _find_level()
				if level:
					level._enter_room(rid)
		)
		area.body_exited.connect(func(body):
			if body.is_in_group("player"):
				var level = _find_level()
				if level:
					level._exit_room(rid)
		)

	# Editor label
	if Engine.is_editor_hint():
		var lbl := Label.new()
		lbl.text = "Ceiling: %s" % room_id
		lbl.position = Vector2(-40, -ceiling_size.y / 2 - 16)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		add_child(lbl)
		lbl.set_owner(owner_node)

func _find_level() -> Node:
	var p = get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null

## 获取天花板 Rect2（供 LevelBase 使用）
func get_room_rect() -> Rect2:
	var detect := detection_rect if detection_rect.size != Vector2.ZERO else Rect2(-ceiling_size / 2, ceiling_size)
	return Rect2(position + detect.position, detect.size)
