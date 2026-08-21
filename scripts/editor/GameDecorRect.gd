@tool
extends Node2D
## 可在编辑器中拖拽放置的装饰矩形节点
## 用于镜子、大门、装饰色块等静态视觉元素
## 可选交互：玩家靠近时显示提示文字

class_name GameDecorRect

## 装饰名称
@export var decor_name: String = "":
	set(value):
		decor_name = value
		queue_redraw()
## 矩形大小
@export var decor_size: Vector2 = Vector2(30, 8):
	set(value):
		decor_size = value
		_rebuild()
## 矩形颜色
@export var decor_color: Color = Color(0.15, 0.15, 0.2):
	set(value):
		decor_color = value
		_rebuild()
## Z 轴层级
@export var decor_z_index: int = 0:
	set(value):
		decor_z_index = value
		if is_inside_tree():
			for child in get_children():
				if child is ColorRect:
					child.z_index = value
## 靠近时显示的提示文字（留空 = 无交互）
@export var hint_text: String = ""
## 提示文字持续时间
@export var hint_duration: float = 4.0
## 标签颜色（留空 = 不显示标签）
@export var label_color: Color = Color(0.5, 0.4, 0.35):
	set(value):
		label_color = value
		queue_redraw()
## 是否显示世界标签
@export var show_label: bool = true:
	set(value):
		show_label = value
		queue_redraw()
## 世界标签字号
@export var label_font_size: int = 18

## 节点就绪回调：编辑器中立即重建预览，运行时延迟构建。
func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()
	else:
		# 运行时延迟构建：可能向关卡添加世界标签，场景装载期间会失败
		call_deferred("_rebuild")

## 清空并重建装饰矩形的全部子节点。
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	_build()

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

## 构建装饰色块；编辑器额外显示名称标签，运行时转交 _build_runtime。
func _build() -> void:
	var owner_node := _get_owner()

	# 装饰色块
	var rect := ColorRect.new()
	rect.position = -decor_size / 2
	rect.size = decor_size
	rect.color = decor_color
	rect.z_index = decor_z_index
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	if Engine.is_editor_hint():
		rect.set_owner(owner_node)

	# 编辑器标签
	if Engine.is_editor_hint():
		var display_name := decor_name if decor_name != "" else "Decor"
		var lbl := Label.new()
		lbl.text = display_name
		lbl.position = Vector2(-20, -decor_size.y / 2 - 16)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", label_color.lightened(0.3))
		add_child(lbl)
		lbl.set_owner(owner_node)
	else:
		_build_runtime()

## 运行时构建：创建世界标签与靠近触发的提示区域。
func _build_runtime() -> void:
	var level := _find_level()

	# 世界标签
	if show_label and decor_name != "" and level and level.has_method("create_world_label"):
		var display_name := LocaleManager.world_text(decor_name) if LocaleManager else decor_name
		level.create_world_label(display_name, position + Vector2(0, -decor_size.y / 2 - 10), label_font_size, label_color)

	# 交互提示（靠近时触发）
	if hint_text != "" and level:
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		add_child(area)
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = decor_size + Vector2(20, 20)
		col.shape = shape
		area.add_child(col)

		var captured_hint := hint_text
		var captured_duration := hint_duration
		area.body_entered.connect(func(body: Node2D) -> void:
			if body.is_in_group("player") and level.has_method("show_hint"):
				level.show_hint(captured_hint, captured_duration)
		)

## 编辑器中绘制交互范围虚框（仅有提示文字时）。
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# 编辑器中画交互范围（如果有提示）
	if hint_text != "":
		draw_rect(
			Rect2(-decor_size / 2 - Vector2(10, 10), decor_size + Vector2(20, 20)),
			Color(0.8, 0.6, 0.2, 0.15), false, 1.0)

## 向上遍历祖先查找关卡节点。
## [return] 含 show_hint 方法的关卡节点，未找到返回 null。
func _find_level() -> Node:
	var p := get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null
