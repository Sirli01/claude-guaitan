extends CanvasModulate
## 黑暗与光源系统 - 全局视野遮罩
## 未被照亮的区域变暗。配合 PointLight2D / Light2D 使用。
## 用法:
##   var darkness = DarknessLayer.new()
##   level.add_child(darkness)
##   darkness.set_darkness(0.15)  # 设置环境基础亮度（0=全黑, 1=全亮）
##   darkness.fade_to_dark(0.1, 2.0)  # 渐变到很暗

class_name DarknessLayer

var _base_brightness: float = 0.15

func _ready() -> void:
	# 默认环境色：很暗的灰蓝色（模拟无光源环境）
	color = Color(_base_brightness, _base_brightness, _base_brightness * 1.1)

func set_darkness(brightness: float) -> void:
	## 设置基础环境亮度（0.0=纯黑, 1.0=全亮）
	_base_brightness = clampf(brightness, 0.0, 1.0)
	color = Color(_base_brightness, _base_brightness, _base_brightness * 1.1)

func fade_to_dark(target_brightness: float, duration: float = 2.0) -> void:
	## 渐变到目标亮度
	var target = clampf(target_brightness, 0.0, 1.0)
	var target_color = Color(target, target, target * 1.1)
	var tw = create_tween()
	tw.tween_property(self, "color", target_color, duration)

func fade_to_bright(duration: float = 1.0) -> void:
	## 恢复全亮
	fade_to_dark(1.0, duration)

func pulse_flicker(duration: float = 3.0, min_bright: float = 0.05, max_bright: float = 0.2) -> void:
	## 灯光闪烁效果（恐怖氛围）
	var tw = create_tween()
	var steps = int(duration / 0.15)
	for i in steps:
		var b = randf_range(min_bright, max_bright)
		tw.tween_property(self, "color", Color(b, b, b * 1.1), 0.08)
		tw.tween_interval(randf_range(0.02, 0.1))
	tw.tween_property(self, "color", Color(_base_brightness, _base_brightness, _base_brightness * 1.1), 0.3)
