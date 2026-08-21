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

## 标准家具贴图配置：kind → [纹理路径, 纹理尺寸, 显示高度, 纹理偏移Y]
const KIND_TEXTURES := {
	"bed": ["res://assets/sprites/_0005_单人床.png", Vector2(140, 228), 55.0, -114.0],
	"desk": ["res://assets/sprites/_0006_桌子1.png", Vector2(179, 118), 30.0, -59.0],
	"writing_desk": ["res://assets/sprites/_0009_桌子2.png", Vector2(137, 111), 34.0, -55.5],
	"counter": ["res://assets/sprites/_0009_桌子2.png", Vector2(137, 111), 36.0, -55.5],
	"sofa": ["res://assets/sprites/_0007_沙发.png", Vector2(251, 140), 40.0, -70.0],
	"cabinet": ["res://assets/sprites/_0008_柜子.png", Vector2(182, 151), 45.0, -75.5],
	"chair": ["res://assets/sprites/_0011_椅子.png", Vector2(82, 108), 32.0, -54.0],
	"shelf": ["res://assets/sprites/_0010_长储物柜.png", Vector2(380, 87), 24.0, -43.5],
}

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
	elif _build_kind_texture():
		_visual_node = get_child(get_child_count() - 1)
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

## 按家具种类绘制标准贴图（与 LevelBaseV2.add_standard_furniture 的显示参数一致）。
## [return] 是否成功按种类绘制了贴图。
func _build_kind_texture() -> bool:
	var kind := furniture_kind
	if kind == "":
		kind = _resolve_kind(furniture_name)
	if not KIND_TEXTURES.has(kind):
		return false
	var cfg: Array = KIND_TEXTURES[kind]
	var tex_path: String = cfg[0]
	if not ResourceLoader.exists(tex_path):
		return false
	var tex_size: Vector2 = cfg[1]
	var display_h: float = cfg[2]
	var offset_y: float = cfg[3]
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.position = Vector2(furniture_size.x / 2.0, furniture_size.y)
	spr.offset = Vector2(0.0, offset_y)
	spr.scale = Vector2(furniture_size.x, display_h) / tex_size
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return true

## 根据家具名称推断标准种类。
## [param label_text] 家具名称。[return] KIND_TEXTURES 中的种类键（可能为空）。
func _resolve_kind(label_text: String) -> String:
	if label_text == "书桌":
		return "writing_desk"
	if label_text == "柜台":
		return "counter"
	if label_text == "货架":
		return "shelf"
	if label_text == "床头柜" or label_text == "衣柜" or label_text.contains("柜"):
		return "cabinet"
	if label_text.contains("沙发"):
		return "sofa"
	if label_text.contains("椅"):
		return "chair"
	if label_text.contains("桌"):
		return "desk"
	if label_text.contains("床"):
		return "bed"
	return ""
