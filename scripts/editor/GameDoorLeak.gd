@tool
extends Node2D
## 可在编辑器中拖拽放置的门缝漏光效果节点
## 在门的边缘创建微弱的光线泄漏效果，暗示门后有光源
## 编辑器中显示一条光线预览

class_name GameDoorLeak

## 漏光宽度（光线长度）
@export var leak_width: float = 24.0:
	set(value):
		leak_width = value
		queue_redraw()
## 漏光方向："bottom"（门底）、"left"（门左侧）、"right"（门右侧）
@export_enum("bottom", "left", "right") var leak_direction: String = "bottom":
	set(value):
		leak_direction = value
		queue_redraw()
## 光线能量
@export_range(0.1, 3.0, 0.1) var light_energy: float = 1.0:
	set(value):
		light_energy = value
		# 运行时更新
		if _light and is_instance_valid(_light):
			_light.energy = value
## 光线颜色
@export var light_color: Color = Color(1.0, 0.9, 0.7, 0.6):
	set(value):
		light_color = value
		if _light and is_instance_valid(_light):
			_light.color = value
		queue_redraw()
## 光线缩放
@export_range(0.5, 5.0, 0.1) var light_scale: float = 1.5:
	set(value):
		light_scale = value

var _light: PointLight2D = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		# 延迟构建：可能向关卡添加节点，场景装载期间会失败
		call_deferred("_build_runtime")
	else:
		queue_redraw()

func _build_runtime() -> void:
	# 创建门缝漏光（与 LevelBase.add_door_light_leak 逻辑一致）
	_light = PointLight2D.new()
	_light.texture = _make_circle_texture(32)
	_light.energy = light_energy
	_light.texture_scale = light_scale
	_light.color = light_color
	_light.shadow_enabled = false  # 漏光不需要阴影

	# 根据方向调整灯光形状
	match leak_direction:
		"bottom":
			_light.position = Vector2(0, 4)
			# 水平拉伸成窄条
			var light_size := Vector2(leak_width, 8)
			# 使用 PointLight2D 无法直接拉伸，用能量补偿
		"left":
			_light.position = Vector2(-4, 0)
		"right":
			_light.position = Vector2(4, 0)

	add_child(_light)

	# 添加微弱的呼吸效果
	var tw := create_tween().set_loops()
	var base_e := light_energy
	tw.tween_property(_light, "energy", base_e * 0.6, randf_range(1.5, 3.0))
	tw.tween_property(_light, "energy", base_e, randf_range(1.5, 3.0))

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# 编辑器中画一条光线预览
	var col := light_color
	col.a = 0.4
	match leak_direction:
		"bottom":
			draw_line(Vector2(-leak_width / 2, 0), Vector2(leak_width / 2, 0), col, 3.0)
			draw_rect(Rect2(-leak_width / 2, -4, leak_width, 8), Color(col.r, col.g, col.b, 0.1))
		"left":
			draw_line(Vector2(0, -leak_width / 2), Vector2(0, leak_width / 2), col, 3.0)
			draw_rect(Rect2(-4, -leak_width / 2, 8, leak_width), Color(col.r, col.g, col.b, 0.1))
		"right":
			draw_line(Vector2(0, -leak_width / 2), Vector2(0, leak_width / 2), col, 3.0)
			draw_rect(Rect2(-4, -leak_width / 2, 8, leak_width), Color(col.r, col.g, col.b, 0.1))

	# 标签
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-20, -12), "LightLeak", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.5, 0.5))

static func _make_circle_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for x in size:
		for y in size:
			var dist := Vector2(x - half, y - half).length() / half
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
