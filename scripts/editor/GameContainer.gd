@tool
extends Node2D
## 可在编辑器中拖拽放置的可搜索容器节点
## 用于急救箱、宝箱等独立搜索点（非家具）
## 编辑器中显示容器色块 + 名称标签
## 运行时自动创建 FurnitureContainer 交互区域

class_name GameContainer

## 容器显示名（如"急救箱"、"宝箱"）
@export var container_name: String = "柜子":
	set(value):
		container_name = value
		queue_redraw()
## 容器尺寸
@export var container_size: Vector2 = Vector2(14, 14):
	set(value):
		container_size = value
		_rebuild()
## 容器颜色
@export var container_color: Color = Color(0.8, 0.2, 0.2):
	set(value):
		container_color = value
		queue_redraw()
## 内含物品ID（留空 = 空容器）
@export var contained_item_id: String = ""
## 内含物品显示名
@export var contained_item_name: String = ""
## 可选：容器贴图路径
@export var texture_path: String = "":
	set(value):
		texture_path = value
		_rebuild()
## 贴图显示大小
@export var texture_display_size: Vector2 = Vector2(18, 14):
	set(value):
		texture_display_size = value
		_rebuild()
## 无物品时触发的场景回调方法名
@export var search_action_method: String = ""
## 拿到物品后触发的场景回调方法名
@export var post_take_action_method: String = ""

var _container: Area2D = null  # 运行时创建的 FurnitureContainer

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
	_container = null

func _get_owner() -> Node:
	if Engine.is_editor_hint():
		var tree = get_tree()
		if tree:
			return tree.edited_scene_root
	return self

func _build() -> void:
	var owner_node := _get_owner()

	# 贴图或色块视觉
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_size := spr.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			spr.scale = Vector2(texture_display_size.x / tex_size.x, texture_display_size.y / tex_size.y)
		spr.centered = false
		spr.position = -texture_display_size / 2
		add_child(spr)
		if Engine.is_editor_hint():
			spr.set_owner(owner_node)
	else:
		var rect := ColorRect.new()
		rect.position = -container_size / 2
		rect.size = container_size
		rect.color = container_color
		add_child(rect)
		if Engine.is_editor_hint():
			rect.set_owner(owner_node)

	# 编辑器标签
	if Engine.is_editor_hint():
		var item_hint := ""
		if contained_item_id != "":
			item_hint = " → %s" % contained_item_id
		var lbl := Label.new()
		lbl.text = "[%s%s]" % [container_name, item_hint]
		lbl.position = Vector2(-30, -container_size.y / 2 - 18)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", container_color.lightened(0.4))
		add_child(lbl)
		lbl.set_owner(owner_node)
	else:
		_build_runtime()

func _build_runtime() -> void:
	# 创建 FurnitureContainer
	var ContainerScript = preload("res://scripts/items/furniture_container.gd")
	_container = Area2D.new()
	_container.set_script(ContainerScript)
	_container.position = container_size / 2  # FurnitureContainer 使用左上角原点
	_container.furniture_name = container_name
	_container.contained_item_id = contained_item_id
	_container.contained_item_name = contained_item_name
	_container.search_action_method = search_action_method
	_container.post_take_action_method = post_take_action_method

	# 碰撞（比容器稍大，方便交互）
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = container_size + Vector2(10, 10)
	col.shape = shape
	_container.add_child(col)

	add_child(_container)

	# 设置关卡引用
	var level := _find_level()
	if level:
		_container._level = level

	# 创建世界标签
	if level and level.has_method("create_world_label"):
		var display_name := LocaleManager.world_text(container_name) if LocaleManager else container_name
		var hint_text := ""
		if InputDevice:
			hint_text = InputDevice.hint("interact")
		var lbl_text := "%s %s" % [display_name, hint_text] if hint_text != "" else display_name
		var lbl: Node = level.create_world_label(
			lbl_text,
			position + Vector2(-10, -22),
			18,
			container_color.lightened(0.4))
		lbl.visible = false
		_container._name_label = lbl

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# 编辑器中画交互范围轮廓
	draw_rect(
		Rect2(-container_size / 2 - Vector2(5, 5), container_size + Vector2(10, 10)),
		Color(0.8, 0.6, 0.2, 0.2), false, 1.0)

func _find_level() -> Node:
	var p := get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null

## 获取内部的 FurnitureContainer 引用
func get_container() -> Area2D:
	return _container
