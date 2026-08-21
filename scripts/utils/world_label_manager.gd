extends Node
## 世界坐标标签管理器 - 在 UI 层渲染文字，避免相机缩放导致像素化
## 任何场景都可以使用：var wlm = WorldLabelManager.new(self, camera_zoom)

var _layer: CanvasLayer
var _container: Control
var _tracked: Array = []
var _zoom: float = 3.0
var _cam_node: Camera2D = null

func _init() -> void:
	pass

## 初始化（场景 ready 后调用）
func setup(parent: Node, zoom: float = 3.0) -> void:
	_zoom = zoom
	_layer = CanvasLayer.new()
	_layer.layer = 4
	_layer.name = "WorldLabelUI"
	parent.add_child(_layer)
	_container = Control.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_container)

## 设置相机引用（用于每帧更新位置）
func set_camera(cam: Camera2D) -> void:
	_cam_node = cam

## 创建 UI 标签并跟踪世界坐标
func create_label(text: String, world_pos: Vector2, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(font_size * _zoom))
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(lbl)
	_tracked.append({"label": lbl, "world_pos": world_pos})
	return lbl

## 每帧调用更新标签位置
func update_positions() -> void:
	if not _cam_node or _tracked.is_empty():
		return
	var vp_size = _cam_node.get_viewport().get_visible_rect().size
	var zoom = _cam_node.zoom
	var cam_center = _cam_node.get_screen_center_position()
	var i := 0
	while i < _tracked.size():
		var entry = _tracked[i]
		var label = entry["label"]
		if not is_instance_valid(label):
			_tracked.remove_at(i)
			continue
		var sp = (entry["world_pos"] - cam_center) * zoom + vp_size / 2.0
		label.position = sp
		i += 1
