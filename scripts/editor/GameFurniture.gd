@tool
extends StaticBody2D
## 可在编辑器中拖拽放置的家具节点
## 内含物品时设置 contained_item_id，玩家靠近可搜索

class_name GameFurniture

@export var furniture_name: String = "柜子":
	set(value):
		furniture_name = value
		_rebuild()
@export var furniture_size: Vector2 = Vector2(30, 18):
	set(value):
		furniture_size = value
		_rebuild()
@export var furniture_color: Color = Color(0.16, 0.1, 0.08):
	set(value):
		furniture_color = value
		_rebuild()
@export var contained_item_id: String = "":
	set(value):
		contained_item_id = value
@export var contained_item_name: String = "":
	set(value):
		contained_item_name = value
@export var furniture_kind: String = "":
	set(value):
		furniture_kind = value
		_rebuild()

## 可选：关联的 Sprite2D 纹理路径
@export var texture_path: String = "":
	set(value):
		texture_path = value
		_rebuild()

var _visual_node: Node = null

func _ready() -> void:
	collision_layer = 4  # walls layer
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_build()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_visual_node = null

func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

func _build() -> void:
	if furniture_size.x <= 0 or furniture_size.y <= 0:
		return

	var owner_node = _get_owner()

	# Collision
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = furniture_size
	col.shape = rect
	col.position = furniture_size / 2.0
	add_child(col)
	if Engine.is_editor_hint():
		col.set_owner(owner_node)

	# Visual
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.position = furniture_size / 2.0
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		_visual_node = spr
	else:
		var rect_vis := ColorRect.new()
		rect_vis.position = Vector2.ZERO
		rect_vis.size = furniture_size
		rect_vis.color = furniture_color
		rect_vis.z_index = 3
		add_child(rect_vis)
		_visual_node = rect_vis

	if Engine.is_editor_hint() and _visual_node:
		_visual_node.set_owner(owner_node)

	# Name label in editor
	if Engine.is_editor_hint():
		var lbl := Label.new()
		lbl.text = furniture_name
		lbl.position = Vector2(0, -18)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		lbl.set_owner(owner_node)
