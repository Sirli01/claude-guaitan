extends CanvasLayer
## 氛围效果管理器 - 屏幕后处理效果
## 用法:
##   var atmo = AtmosphereLayer.new()
##   add_child(atmo)
##   atmo.set_vignette(0.6)                   # 暗角
##   atmo.set_fog(Color(0.1, 0.05, 0.05), 0.3) # 迷雾
##   atmo.pulse_heartbeat(3.0)                  # 心跳效果
##   atmo.flash_scare(Color.RED, 0.3)          # 恐怖闪屏
##   atmo.set_color_grade(Color(0.8, 0.9, 1.0)) # 色调偏移

class_name AtmosphereLayer

var _vignette_rect: ColorRect
var _fog_rect: ColorRect
var _flash_rect: ColorRect
var _grain_rect: ColorRect
var _sanity_vignette_rect: ColorRect
var _heartbeat_tween: Tween
var _sanity_pulse_tween: Tween
var _distortion_rect: ColorRect  # 低理智扭曲
var _interference_rect: ColorRect  # 怪物信号干扰

func _ready() -> void:
	layer = 90  # 在大多数UI之上
	add_to_group("atmosphere_layer")
	
	# 暗角层
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.visible = false
	add_child(_vignette_rect)
	
	# 迷雾层
	_fog_rect = ColorRect.new()
	_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.visible = false
	add_child(_fog_rect)
	
	# 闪屏层
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.modulate.a = 0
	_flash_rect.color = Color.WHITE
	add_child(_flash_rect)
	
	# 噪点层
	_grain_rect = ColorRect.new()
	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_rect.visible = false
	add_child(_grain_rect)
	
	# 理智暗角（恐慌状态脉冲遮罩）
	_sanity_vignette_rect = ColorRect.new()
	_sanity_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sanity_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sanity_vignette_rect.visible = false
	_sanity_vignette_rect.material = _make_sanity_vignette_material()
	add_child(_sanity_vignette_rect)
	
	# 低理智画面扭曲层
	_distortion_rect = ColorRect.new()
	_distortion_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_distortion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distortion_rect.visible = false
	add_child(_distortion_rect)
	
	# 怪物信号干扰层
	_interference_rect = ColorRect.new()
	_interference_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_interference_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interference_rect.visible = false
	add_child(_interference_rect)

# ====== 暗角 ======

func set_vignette(intensity: float = 0.5, color: Color = Color.BLACK, fade_time: float = 1.0) -> void:
	## intensity: 0=无暗角, 1=全黑
	if intensity <= 0:
		if _vignette_rect.visible:
			var tw = create_tween()
			tw.tween_property(_vignette_rect, "modulate:a", 0.0, fade_time)
			tw.tween_callback(func(): _vignette_rect.visible = false)
		return
	_vignette_rect.visible = true
	_vignette_rect.color = Color(color.r, color.g, color.b, intensity)
	# 用shader做径向渐变效果，这里用简化版：四周暗角
	_vignette_rect.material = _make_vignette_material(intensity)
	_vignette_rect.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(_vignette_rect, "modulate:a", 1.0, fade_time)

func _make_vignette_material(intensity: float) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(0.3, 1.2, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", intensity)
	return mat

# ====== 迷雾 ======

func set_fog(color: Color = Color(0.1, 0.08, 0.06), density: float = 0.2, fade_time: float = 2.0) -> void:
	if density <= 0:
		if _fog_rect.visible:
			var tw = create_tween()
			tw.tween_property(_fog_rect, "modulate:a", 0.0, fade_time)
			tw.tween_callback(func(): _fog_rect.visible = false)
		return
	_fog_rect.visible = true
	_fog_rect.color = Color(color.r, color.g, color.b, density)
	_fog_rect.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(_fog_rect, "modulate:a", 1.0, fade_time)

# ====== 恐怖闪屏 ======

func flash_scare(color: Color = Color.RED, duration: float = 0.15, intensity: float = 0.8) -> void:
	_flash_rect.color = color
	_flash_rect.modulate.a = intensity
	var tw = create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)

func flash_white(duration: float = 0.3) -> void:
	flash_scare(Color.WHITE, duration, 1.0)

func flash_black(duration: float = 0.5) -> void:
	_flash_rect.color = Color.BLACK
	_flash_rect.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(duration * 0.6)
	tw.tween_property(_flash_rect, "modulate:a", 0.0, duration * 0.4)

# ====== 心跳效果（屏幕边缘脉冲红光）======

func pulse_heartbeat(duration: float = 5.0, bpm: float = 80.0) -> void:
	if _heartbeat_tween and _heartbeat_tween.is_valid():
		_heartbeat_tween.kill()
	_vignette_rect.visible = true
	_vignette_rect.material = _make_vignette_material(0.6)
	_vignette_rect.color = Color(0.4, 0, 0, 0.5)
	
	var beat_interval = 60.0 / bpm
	var beats = int(duration / beat_interval)
	
	_heartbeat_tween = create_tween()
	for i in beats:
		_heartbeat_tween.tween_property(_vignette_rect, "modulate:a", 0.9, beat_interval * 0.15)
		_heartbeat_tween.tween_property(_vignette_rect, "modulate:a", 0.3, beat_interval * 0.25)
		_heartbeat_tween.tween_property(_vignette_rect, "modulate:a", 0.7, beat_interval * 0.15)
		_heartbeat_tween.tween_property(_vignette_rect, "modulate:a", 0.2, beat_interval * 0.45)
	_heartbeat_tween.tween_property(_vignette_rect, "modulate:a", 0.0, 0.5)
	_heartbeat_tween.tween_callback(func(): _vignette_rect.visible = false)

func stop_heartbeat() -> void:
	if _heartbeat_tween and _heartbeat_tween.is_valid():
		_heartbeat_tween.kill()
	_vignette_rect.modulate.a = 0
	_vignette_rect.visible = false

# ====== 噪点/静电 ======

func set_grain(intensity: float = 0.15, fade_time: float = 0.5) -> void:
	if intensity <= 0:
		if _grain_rect.visible:
			var tw = create_tween()
			tw.tween_property(_grain_rect, "modulate:a", 0.0, fade_time)
			tw.tween_callback(func(): _grain_rect.visible = false)
		return
	_grain_rect.visible = true
	_grain_rect.material = _make_grain_material(intensity)
	_grain_rect.modulate.a = 0
	var tw = create_tween()
	tw.tween_property(_grain_rect, "modulate:a", 1.0, fade_time)

func _make_grain_material(intensity: float) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.15;
void fragment() {
	float noise = fract(sin(dot(UV + vec2(TIME * 0.1), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(noise), intensity * 0.5);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", intensity)
	return mat

# ====== 色调偏移 ======

func set_color_grade(tint: Color = Color(0.9, 0.85, 1.0), fade_time: float = 1.0) -> void:
	## 整体画面色调偏移（冷色=蓝调恐怖，暖色=压抑感）
	if tint == Color.WHITE:
		set_fog(Color.TRANSPARENT, 0, fade_time)
		return
	set_fog(tint, 0.08, fade_time)

# ====== 屏幕震动 ======

func screen_shake(intensity: float = 5.0, duration: float = 0.5) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var original = camera.offset
	var tw = create_tween()
	var steps = int(duration / 0.05)
	for i in steps:
		var strength = intensity * (1.0 - float(i) / steps)
		tw.tween_property(camera, "offset", original + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		), 0.05)
	tw.tween_property(camera, "offset", original, 0.05)

# ====== 一键清除所有效果 ======

func clear_all(fade_time: float = 1.0) -> void:
	stop_heartbeat()
	set_sanity_vignette(false)
	set_vignette(0, Color.BLACK, fade_time)
	set_fog(Color.BLACK, 0, fade_time)
	set_grain(0, fade_time)
	set_distortion(0, fade_time)
	stop_interference(fade_time)
	_flash_rect.modulate.a = 0

# ====== 理智暗角（Sanity Vignette）======

func set_sanity_vignette(enabled: bool) -> void:
	## 恐慌模式：屏幕边缘暗红/黑色脉冲遮罩
	if enabled:
		_sanity_vignette_rect.visible = true
		_sanity_vignette_rect.modulate.a = 0.0
		if _sanity_pulse_tween and _sanity_pulse_tween.is_valid():
			_sanity_pulse_tween.kill()
		_sanity_pulse_tween = create_tween().set_loops()
		_sanity_pulse_tween.tween_property(_sanity_vignette_rect, "modulate:a", 0.7, 1.2).set_ease(Tween.EASE_IN_OUT)
		_sanity_pulse_tween.tween_property(_sanity_vignette_rect, "modulate:a", 0.3, 1.2).set_ease(Tween.EASE_IN_OUT)
	else:
		if _sanity_pulse_tween and _sanity_pulse_tween.is_valid():
			_sanity_pulse_tween.kill()
		if _sanity_vignette_rect.visible:
			var tw = create_tween()
			tw.tween_property(_sanity_vignette_rect, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): _sanity_vignette_rect.visible = false)

func _make_sanity_vignette_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float ring = smoothstep(0.35, 1.0, dist);
	// 暗红到黑色渐变
	vec3 col = mix(vec3(0.15, 0.0, 0.02), vec3(0.0), smoothstep(0.5, 1.0, dist));
	COLOR = vec4(col, ring * 0.8);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	return mat

# ====== 低理智画面扭曲 ======

func set_distortion(intensity: float = 0.3, fade_time: float = 1.0) -> void:
	## 理智低时画面波纹扭曲（intensity 0~1）
	if intensity <= 0:
		if _distortion_rect.visible:
			var tw = create_tween()
			tw.tween_property(_distortion_rect, "modulate:a", 0.0, fade_time)
			tw.tween_callback(func(): _distortion_rect.visible = false)
		return
	_distortion_rect.visible = true
	_distortion_rect.material = _make_distortion_material(intensity)
	_distortion_rect.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_distortion_rect, "modulate:a", 1.0, fade_time)

func _make_distortion_material(intensity: float) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
void fragment() {
	vec2 uv = SCREEN_UV;
	// 水波扭曲
	float wave = sin(uv.y * 20.0 + TIME * 2.0) * intensity * 0.008;
	float wave2 = cos(uv.x * 15.0 + TIME * 1.5) * intensity * 0.005;
	// 边缘更强
	vec2 center = uv - vec2(0.5);
	float edge = length(center) * 2.0;
	float edge_mult = smoothstep(0.2, 0.8, edge);
	vec2 distorted_uv = uv + vec2(wave, wave2) * edge_mult;
	vec4 col = textureLod(SCREEN_TEXTURE, distorted_uv, 0.0);
	// 轻微色差
	float chromatic = intensity * 0.003 * edge_mult;
	col.r = textureLod(SCREEN_TEXTURE, distorted_uv + vec2(chromatic, 0.0), 0.0).r;
	col.b = textureLod(SCREEN_TEXTURE, distorted_uv - vec2(chromatic, 0.0), 0.0).b;
	COLOR = col;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", intensity)
	return mat

# ====== 怪物信号干扰 ======

func set_interference(intensity: float = 0.5, fade_time: float = 0.3) -> void:
	## 怪物靠近时的TV信号干扰效果（噪点+扫描线+色偏）
	if intensity <= 0:
		if _interference_rect.visible:
			var tw = create_tween()
			tw.tween_property(_interference_rect, "modulate:a", 0.0, fade_time)
			tw.tween_callback(func(): _interference_rect.visible = false)
		return
	_interference_rect.visible = true
	_interference_rect.material = _make_interference_material(intensity)
	_interference_rect.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_interference_rect, "modulate:a", 1.0, fade_time)

func stop_interference(fade_time: float = 0.5) -> void:
	set_interference(0, fade_time)

func _make_interference_material(intensity: float) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 col = textureLod(SCREEN_TEXTURE, uv, 0.0);
	
	// 扫描线
	float scanline = sin(uv.y * 800.0 + TIME * 5.0) * 0.5 + 0.5;
	col.rgb -= scanline * intensity * 0.1;
	
	// 随机噪点
	float noise = fract(sin(dot(uv + vec2(TIME * 0.3), vec2(12.9898, 78.233))) * 43758.5453);
	col.rgb = mix(col.rgb, vec3(noise), intensity * 0.15);
	
	// 水平位移（glitch）
	float glitch = step(0.97, fract(sin(TIME * 3.0 + uv.y * 5.0) * 100.0));
	vec2 glitch_uv = uv + vec2(glitch * intensity * 0.02, 0.0);
	col.rgb = mix(col.rgb, textureLod(SCREEN_TEXTURE, glitch_uv, 0.0).rgb, glitch);
	
	// 色彩偏移
	float shift = intensity * 0.004;
	col.r = textureLod(SCREEN_TEXTURE, uv + vec2(shift, 0.0), 0.0).r;
	col.b = textureLod(SCREEN_TEXTURE, uv - vec2(shift, 0.0), 0.0).b;
	
	COLOR = col;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", intensity)
	return mat
