@tool
extends Node2D
## 可在编辑器中拖拽放置的道具拾取节点
## 编辑器中显示色块/贴图预览 + 名称标签
## 运行时自动创建 SimplePickup 交互区域

class_name GamePickup

## 物品ID（对应 InventoryManager 中的物品数据）
@export var item_id: String = "":
	set(value):
		item_id = value
		queue_redraw()
## 物品显示名（留空则从 InventoryManager 自动读取）
@export var item_name: String = "":
	set(value):
		item_name = value
		queue_redraw()
## 拾取区域半径
@export_range(5.0, 50.0, 1.0) var pickup_radius: float = 15.0:
	set(value):
		pickup_radius = value
		_rebuild()
## 编辑器预览色块大小
@export var preview_size: Vector2 = Vector2(10, 10):
	set(value):
		preview_size = value
		queue_redraw()
## 编辑器预览颜色
@export var preview_color: Color = Color(0.5, 0.8, 1.0):
	set(value):
		preview_color = value
		queue_redraw()
## 可选：贴图路径（留空则使用色块占位）
@export var texture_path: String = "":
	set(value):
		texture_path = value
		_rebuild()
## 贴图缩放后的目标大小
@export var texture_display_size: Vector2 = Vector2(12, 8):
	set(value):
		texture_display_size = value
		_rebuild()
## 贴图偏移（相对节点中心）
@export var texture_offset: Vector2 = Vector2.ZERO:
	set(value):
		texture_offset = value
		_rebuild()
## 是否走近自动拾取（无需按E）
@export var auto_collect: bool = false

var _pickup: Area2D = null  # 运行时创建的 SimplePickup

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		# 运行时延迟构建：可能向关卡添加世界标签，场景装载期间会失败
		call_deferred("_rebuild")

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_build()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_pickup = null

func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

func _build() -> void:
	var owner_node := _get_owner()

	# 编辑器：显示视觉预览
	if Engine.is_editor_hint():
		_build_editor_preview(owner_node)
	else:
		_build_runtime()

func _build_editor_preview(owner_node: Node) -> void:
	# 视觉预览
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_size := spr.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			spr.scale = Vector2(texture_display_size.x / tex_size.x, texture_display_size.y / tex_size.y)
		spr.position = texture_offset
		add_child(spr)
		spr.set_owner(owner_node)
	else:
		var rect := ColorRect.new()
		rect.position = -preview_size / 2
		rect.size = preview_size
		rect.color = preview_color
		add_child(rect)
		rect.set_owner(owner_node)

	# 拾取范围预览（圆形轮廓）
	var range_preview := Node2D.new()
	range_preview.name = "RangePreview"
	add_child(range_preview)
	range_preview.set_owner(owner_node)
	# 用 _draw 画圆圈

	# 名称标签
	var display := item_name if item_name != "" else item_id
	if display == "":
		display = "Pickup"
	var lbl := Label.new()
	lbl.text = "[%s]" % display
	lbl.position = Vector2(-30, -28)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", preview_color.lightened(0.3))
	add_child(lbl)
	lbl.set_owner(owner_node)

func _build_runtime() -> void:
	# 创建 SimplePickup 实例
	var SimplePickupScript = preload("res://scripts/items/simple_pickup.gd")
	_pickup = Area2D.new()
	_pickup.set_script(SimplePickupScript)
	_pickup.position = Vector2.ZERO
	_pickup.item_id = item_id
	_pickup.item_name = item_name
	_pickup.auto_collect = auto_collect

	# 碰撞
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	col.shape = shape
	_pickup.add_child(col)

	# 视觉
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_size := spr.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			spr.scale = Vector2(texture_display_size.x / tex_size.x, texture_display_size.y / tex_size.y)
		spr.position = texture_offset
		_pickup.add_child(spr)
	else:
		var rect := ColorRect.new()
		rect.position = -preview_size / 2
		rect.size = preview_size
		rect.color = preview_color
		_pickup.add_child(rect)

	add_child(_pickup)

	# 设置关卡引用
	var level := _find_level()
	if level:
		_pickup._level = level

	# 创建世界标签
	if level and level.has_method("create_world_label"):
		var display_name := item_name
		if display_name == "" and InventoryManager:
			display_name = InventoryManager.get_item_data(item_id).get("name", item_id)
		var hint_text := ""
		if InputDevice:
			hint_text = InputDevice.hint("interact")
		var lbl_text := "%s %s" % [display_name, hint_text] if hint_text != "" else display_name
		var lbl: Node = level.create_world_label(lbl_text, position + Vector2(-20, -22), 18, preview_color.lightened(0.3))
		lbl.visible = false
		_pickup._name_label = lbl

	# 转发 picked_up 信号
	if _pickup.has_signal("picked_up"):
		_pickup.picked_up.connect(func() -> void:
			# 如果有子节点想监听，可以在这里处理
			pass
		)

	# 微弱闪烁
	if _pickup.get_child_count() > 1:
		var visual_node = _pickup.get_child(1)  # 色块或精灵
		if visual_node is CanvasItem:
			var tw := create_tween().set_loops()
			tw.tween_property(visual_node, "modulate:a", 0.4, 1.5)
			tw.tween_property(visual_node, "modulate:a", 1.0, 1.5)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# 编辑器中画拾取范围圆圈
	draw_arc(Vector2.ZERO, pickup_radius, 0, TAU, 32, Color(0.4, 0.7, 1.0, 0.3), 1.0)

func _find_level() -> Node:
	var p := get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null

## 获取内部的 SimplePickup 引用（供关卡脚本访问）
func get_pickup() -> Area2D:
	return _pickup
