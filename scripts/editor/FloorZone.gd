@tool
extends Node2D
## 可在编辑器中拖拽放置的地板区域
## 设置 floor_type 为 "corridor" 或 "room" 自动使用对应纹理，否则使用纯色

class_name FloorZone

@export var floor_size: Vector2 = Vector2(200, 100):
	set(value):
		floor_size = value
		_rebuild()
@export var floor_color: Color = Color(0.24, 0.26, 0.31):
	set(value):
		floor_color = value
		_rebuild()
@export var floor_type: String = "corridor":
	set(value):
		floor_type = value
		_rebuild()

var _visual: Node = null

## 置于底层并构建地板视觉。
func _ready() -> void:
	z_index = -10
	_rebuild()

## 清除并重建地板视觉（属性变更时调用）。
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_visual()
	_build_visual()

## 移除当前地板视觉节点。
func _clear_visual() -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null

## 根据地板类型构建平铺纹理或纯色地板，编辑器中设置 owner。
func _build_visual() -> void:
	if floor_size.x <= 0 or floor_size.y <= 0:
		return

	var tex_path := ""
	if floor_type == "corridor":
		tex_path = "res://assets/sprites/_0000_走廊地板.png"
	elif floor_type == "room":
		tex_path = "res://assets/sprites/_0001_房间木地板.png"

	if tex_path != "" and ResourceLoader.exists(tex_path):
		var zone := TextureRect.new()
		zone.position = -floor_size / 2
		zone.size = floor_size
		zone.texture = load(tex_path)
		zone.stretch_mode = TextureRect.STRETCH_TILE
		zone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		zone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		zone.modulate = Color(0.24, 0.21, 0.18)
		add_child(zone)
		_visual = zone
	else:
		var zone := ColorRect.new()
		zone.position = -floor_size / 2
		zone.size = floor_size
		zone.color = floor_color
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(zone)
		_visual = zone

	if Engine.is_editor_hint() and _visual:
		var tree = get_tree()
		if tree and tree.edited_scene_root:
			_visual.set_owner(tree.edited_scene_root)
