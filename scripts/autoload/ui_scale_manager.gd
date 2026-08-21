extends Node
## UI缩放管理器 — 根据分辨率自动调整UI大小
## 解决4K视口下UI过小的问题

## 基准分辨率（设计时使用的分辨率）
const BASE_WIDTH: float = 1920.0
const BASE_HEIGHT: float = 1080.0

## 当前缩放因子
var scale_factor: float = 1.0

## 信号：缩放因子变化
signal scale_changed(new_scale: float)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 连接窗口大小变化信号
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	# 初始计算
	_update_scale_factor()


## 视口大小变化回调
func _on_viewport_size_changed() -> void:
	_update_scale_factor()


## 更新缩放因子
func _update_scale_factor() -> void:
	var viewport_size = get_viewport().get_visible_rect().size

	# 计算缩放因子（基于宽度比例）
	var new_scale = viewport_size.x / BASE_WIDTH

	# 限制最小和最大缩放
	new_scale = clampf(new_scale, 0.5, 3.0)

	if not is_equal_approx(new_scale, scale_factor):
		scale_factor = new_scale
		scale_changed.emit(scale_factor)
		print("[UI Scale] 缩放因子更新: %.2f (视口: %s)" % [scale_factor, viewport_size])


## 获取缩放后的字体大小
## [param base_size] 基准字体大小
## [return] 缩放后的字体大小
func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * scale_factor)


## 获取缩放后的向量
## [param base_vector] 基准向量
## [return] 缩放后的向量
func get_scaled_vector(base_vector: Vector2) -> Vector2:
	return base_vector * scale_factor


## 应用缩放到 Control 节点
## [param control] 要缩放的 Control 节点
## [param scale_override] 可选的缩放覆盖
func apply_scale_to_control(control: Control, scale_override: float = -1.0) -> void:
	var s = scale_override if scale_override > 0 else scale_factor
	control.scale = Vector2(s, s)


## 应用缩放到字体大小
## [param label] Label 节点
## [param base_size] 基准字体大小
func apply_scaled_font_size(label: Label, base_size: int) -> void:
	label.add_theme_font_size_override("font_size", get_scaled_font_size(base_size))


## 应用缩放到按钮字体大小
## [param button] Button 节点
## [param base_size] 基准字体大小
func apply_scaled_button_font_size(button: Button, base_size: int) -> void:
	button.add_theme_font_size_override("font_size", get_scaled_font_size(base_size))


## 批量应用缩放到场景中的所有 Label
## [param node] 根节点
## [param base_size] 基准字体大小
func apply_scaled_font_size_to_all_labels(node: Node, base_size: int) -> void:
	for child in node.get_children():
		if child is Label:
			apply_scaled_font_size(child, base_size)
		elif child is Button:
			apply_scaled_button_font_size(child, base_size)
		if child.get_child_count() > 0:
			apply_scaled_font_size_to_all_labels(child, base_size)
