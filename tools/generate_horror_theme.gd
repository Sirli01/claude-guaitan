@tool
extends EditorScript
## 生成恐怖风格 Theme 资源文件。
## 在 Godot 编辑器中：工具 → 执行脚本 运行此文件。
## 生成结果保存到 res://assets/ui/horror_theme.tres

const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"
const OUTPUT_PATH := "res://assets/ui/horror_theme.tres"

# ── 配色方案（暗紫哥特风）──
const BG_DARK       := Color(0.051, 0.039, 0.059)    # #0D0A0F 深紫黑
const PANEL_BG      := Color(0.102, 0.082, 0.125)    # #1A1520 暗紫灰
const PANEL_HOVER   := Color(0.137, 0.114, 0.169)    # #231D2B 悬停微亮
const BORDER        := Color(0.239, 0.165, 0.290)    # #3D2A4A 紫灰边框
const BORDER_HOVER  := Color(0.353, 0.239, 0.420)    # #5A3D6B 悬停边框
const ACCENT        := Color(0.769, 0.118, 0.227)    # #C41E3A 血红强调
const ACCENT_PRESSED:= Color(0.545, 0.059, 0.122)    # #8B0F1F 按下更深
const TEXT_PRIMARY   := Color(0.910, 0.875, 0.890)    # #E8DFE3 灰白
const TEXT_SECONDARY := Color(0.620, 0.557, 0.588)    # #9E8E96 灰紫
const DANGER        := Color(0.545, 0.102, 0.102)    # #8B1A1A 暗红
const FOCUS_RING    := Color(0.420, 0.129, 0.659)    # #6B21A8 紫色光晕
const SLIDER_TROUGH := Color(0.080, 0.060, 0.100)    # 滑块轨道
const SLIDER_FILL   := Color(0.600, 0.100, 0.180)    # 滑块填充


func _run() -> void:
	var theme := Theme.new()
	var font := load(FONT_PATH) as FontFile
	if font:
		theme.default_font = font
	theme.default_font_size = 28

	# ── PanelContainer / Panel ──
	theme.set_stylebox("panel", "PanelContainer", _make_panel(PANEL_BG, BORDER))
	theme.set_stylebox("panel", "Panel", _make_panel(PANEL_BG, BORDER))

	# ── Button ──
	theme.set_stylebox("normal", "Button", _make_panel(PANEL_BG, BORDER, 8, 12, 16, 12))
	theme.set_stylebox("hover", "Button", _make_panel(PANEL_HOVER, BORDER_HOVER, 8, 12, 16, 12))
	theme.set_stylebox("pressed", "Button", _make_panel(ACCENT_PRESSED, ACCENT, 8, 12, 16, 12))
	theme.set_stylebox("disabled", "Button", _make_panel(Color(0.06, 0.05, 0.07), Color(0.15, 0.12, 0.18), 8, 12, 16, 12))
	theme.set_stylebox("focus", "Button", _make_focus_ring(FOCUS_RING))
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.97))
	theme.set_color("font_pressed_color", "Button", Color(1, 0.85, 0.88))
	theme.set_color("font_disabled_color", "Button", TEXT_SECONDARY)
	theme.set_font_size("font_size", "Button", 32)

	# ── Label ──
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)

	# ── RichTextLabel ──
	theme.set_color("default_color", "RichTextLabel", TEXT_PRIMARY)
	theme.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.5))

	# ── HSlider ──
	theme.set_stylebox("slider", "HSlider", _make_slider_panel())
	theme.set_stylebox("grabber_area", "HSlider", _make_slider_grabber())
	theme.set_stylebox("grabber_area_highlight", "HSlider", _make_slider_grabber_hover())
	theme.set_stylebox("tick", "HSlider", _make_panel(ACCENT, ACCENT, 0, 0, 0, 0))

	# ── CheckButton ──
	theme.set_color("font_color", "CheckButton", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "CheckButton", Color(1, 0.95, 0.97))
	theme.set_font_size("font_size", "CheckButton", 26)

	# ── ScrollBar ──
	theme.set_stylebox("scroll", "ScrollBar", _make_panel(Color(0.04, 0.03, 0.05), Color.TRANSPARENT, 4, 4, 4, 4))
	theme.set_stylebox("grabber", "ScrollBar", _make_panel(Color(0.25, 0.18, 0.30), BORDER, 6, 6, 6, 6))
	theme.set_stylebox("grabber_highlight", "ScrollBar", _make_panel(Color(0.35, 0.25, 0.42), BORDER_HOVER, 6, 6, 6, 6))

	# ── TabContainer / TabBar ──
	theme.set_stylebox("tab_selected", "TabContainer", _make_panel(PANEL_BG, BORDER_HOVER, 6, 8, 12, 8))
	theme.set_stylebox("tab_unselected", "TabContainer", _make_panel(Color(0.06, 0.05, 0.07), BORDER, 6, 8, 12, 8))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_SECONDARY)

	# ── TooltipPanel ──
	theme.set_stylebox("panel", "TooltipPanel", _make_panel(Color(0.08, 0.06, 0.10), ACCENT, 6, 12, 16, 12))

	# ── 保存 ──
	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err == OK:
		print("✅ Horror theme saved to: ", OUTPUT_PATH)
	else:
		push_error("❌ Failed to save theme: ", err)


## 创建面板样式
func _make_panel(bg: Color, border: Color, radius: int = 6, ml: int = 16, mt: int = 16, mr: int = 16, mb: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = ml
	s.content_margin_top = mt
	s.content_margin_right = mr
	s.content_margin_bottom = mb
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	return s


## 创建焦点环样式
func _make_focus_ring(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_top = 10
	s.content_margin_right = 10
	s.content_margin_bottom = 10
	s.draw_center = false
	return s


## 创建滑块轨道样式
func _make_slider_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SLIDER_TROUGH
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.content_margin_left = 4
	s.content_margin_right = 4
	return s


## 创建滑块手柄样式
func _make_slider_grabber() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT
	s.border_color = BORDER_HOVER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## 创建滑块手柄悬停样式
func _make_slider_grabber_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.85, 0.15, 0.28)
	s.border_color = Color(0.5, 0.3, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
