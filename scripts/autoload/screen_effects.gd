extends CanvasLayer
## 全局屏幕特效系统 - 震动、闪屏、暗角、低理智泛红
## 用法：ScreenEffects.shake(8.0, 0.3) / ScreenEffects.flash_white(0.2) / ScreenEffects.flash_red(0.3)

# === 震动 ===
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _original_offset: Vector2 = Vector2.ZERO

# === 闪屏 ===
var _flash_rect: ColorRect
var _flash_tween: Tween
var _eyelid_rect: ColorRect
var _eyelid_shader: ShaderMaterial
var _eyelid_tween: Tween
var _eyelid_open_amount: float = 1.0

# === 暗角（低理智泛红） ===
var _vignette: ColorRect
var _vignette_shader: ShaderMaterial
# === 心跳声（低理智时） ===
var _heartbeat_player: AudioStreamPlayer
var _heartbeat_active: bool = false
var _heartbeat_timer: float = 0.0
var _heartbeat_interval: float = 0.8  # 心跳间隔（秒）
var _heartbeat_stream: AudioStream
# === 画面干扰（理智极低时画面扭曲，待实现） ===

## 初始化特效层：创建闪屏矩形、眼睑遮罩、暗角泛红层与心跳播放器，并连接理智信号。
func _ready() -> void:
	layer = 100  # 在最上层
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 闪屏层
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_flash_rect)

	# 眼睑遮罩（灵魂互换时的闭眼/睁眼）
	_eyelid_rect = ColorRect.new()
	_eyelid_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyelid_rect.anchors_preset = Control.PRESET_FULL_RECT
	_eyelid_rect.visible = false
	_eyelid_rect.color = Color(1, 1, 1, 1)
	_eyelid_rect.z_index = 20
	var eyelid_shader_code := """
shader_type canvas_item;
uniform float open_amount : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness : hint_range(0.001, 0.1) = 0.025;
uniform float edge_min_open : hint_range(0.0, 0.4) = 0.14;
void fragment() {
	float x = abs(UV.x - 0.5) / 0.5;
	float curve = 1.0 - pow(clamp(x, 0.0, 1.0), 1.8);
	float opening = open_amount * mix(edge_min_open, 1.0, curve);
	float top_y = 0.5 - opening * 0.5;
	float bottom_y = 0.5 + opening * 0.5;
	float top_mask = 1.0 - smoothstep(top_y, top_y + edge_softness, UV.y);
	float bottom_mask = smoothstep(bottom_y - edge_softness, bottom_y, UV.y);
	float alpha = max(top_mask, bottom_mask);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	var eyelid_shader = Shader.new()
	eyelid_shader.code = eyelid_shader_code
	_eyelid_shader = ShaderMaterial.new()
	_eyelid_shader.shader = eyelid_shader
	_eyelid_rect.material = _eyelid_shader
	add_child(_eyelid_rect)
	_set_eyelid_open_amount(1.0)
	
	# 暗角泛红层（用 GDScript 画的径向渐变）
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.anchors_preset = Control.PRESET_FULL_RECT
	_vignette.color = Color(0, 0, 0, 0)  # 初始透明
	
	var shader_code := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(0.3, 1.2, dist);
	COLOR = vec4(tint_color.rgb, vignette * intensity * 0.7);
}
"""
	var shader = Shader.new()
	shader.code = shader_code
	_vignette_shader = ShaderMaterial.new()
	_vignette_shader.shader = shader
	_vignette.material = _vignette_shader
	add_child(_vignette)
	
	# 心跳音效播放器
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.bus = "SFX"
	_heartbeat_player.volume_db = -6.0
	add_child(_heartbeat_player)
	_heartbeat_stream = _generate_heartbeat_sound()
	
	# 连接理智变化信号
	if PlayerStats:
		PlayerStats.sanity_changed.connect(_on_sanity_changed)

## 每帧更新震屏衰减与低理智心跳节奏。
## [param delta] 帧间隔时间（秒）。
func _process(delta: float) -> void:
	_process_shake(delta)
	_process_heartbeat(delta)

# ============================================
# 屏幕震动
# ============================================

## 触发屏幕震动
## intensity: 震动强度（像素），duration: 持续时间（秒）
func shake(intensity: float = 6.0, duration: float = 0.3) -> void:
	# 取最大值，不覆盖正在进行的更强震动
	# 视口放大后自动缩放震动幅度
	var scaled_intensity = intensity * 2.0
	if scaled_intensity > _shake_intensity:
		_shake_intensity = scaled_intensity
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = 0.0

## 按时间线性衰减震屏强度，结束后复位相机偏移。
## [param delta] 帧间隔时间（秒）。
func _process_shake(delta: float) -> void:
	if _shake_duration <= 0:
		return
	_shake_timer += delta
	if _shake_timer >= _shake_duration:
		_shake_duration = 0.0
		_shake_intensity = 0.0
		_apply_camera_offset(Vector2.ZERO)
		return
	
	# 衰减震动
	var progress = _shake_timer / _shake_duration
	var current_intensity = _shake_intensity * (1.0 - progress)
	var shake_offset = Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)
	_apply_camera_offset(shake_offset)

## 在基准偏移之上叠加震动偏移并写入当前相机。
## [param cam_offset] 本帧的震动偏移量。
func _apply_camera_offset(cam_offset: Vector2) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.offset = _original_offset + cam_offset

## 设置震动的"基准偏移"（灵魂互换等需要改camera.offset时先调这个）
func set_base_offset(base_offset: Vector2) -> void:
	_original_offset = base_offset

# ============================================
# 闪屏效果
# ============================================

## 白色闪屏（灵魂互换、规则出现）
func flash_white(duration: float = 0.15) -> void:
	_do_flash(Color(1, 1, 1, 0.8), duration)

## 红色闪屏（NPC死亡、受伤）
func flash_red(duration: float = 0.2) -> void:
	_do_flash(Color(0.8, 0, 0, 0.6), duration)

## 黑色闪屏（意识模糊）
func flash_black(duration: float = 0.3) -> void:
	_do_flash(Color(0, 0, 0, 0.9), duration)

## 自定义颜色闪屏
func flash_color(color: Color, duration: float = 0.2) -> void:
	_do_flash(color, duration)

## 用补间将全屏矩形从指定颜色淡出到透明，实现闪屏。
## [param color] 闪屏颜色（含透明度）。
## [param duration] 淡出时长（秒）。
func _do_flash(color: Color, duration: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, duration)

## 设置眼睑遮罩的张开程度并同步到着色器参数。
## [param value] 张开程度，0 为完全闭合，1 为完全睁开。
func _set_eyelid_open_amount(value: float) -> void:
	_eyelid_open_amount = clampf(value, 0.0, 1.0)
	if _eyelid_shader:
		_eyelid_shader.set_shader_parameter("open_amount", _eyelid_open_amount)

## 显示眼睑遮罩并立即设为指定张开程度。
## [param open_amount] 初始张开程度（0~1）。
func _show_eyelid(open_amount: float) -> void:
	if _eyelid_tween and _eyelid_tween.is_valid():
		_eyelid_tween.kill()
	_eyelid_rect.visible = true
	_set_eyelid_open_amount(open_amount)

## 用缓动补间把眼睑张开程度过渡到目标值。
## [param target] 目标张开程度（0~1）。
## [param duration] 过渡时长（秒）。
## [return] 正在执行的补间动画。
func _animate_eyelid_to(target: float, duration: float) -> Tween:
	if _eyelid_tween and _eyelid_tween.is_valid():
		_eyelid_tween.kill()
	_eyelid_tween = create_tween()
	_eyelid_tween.tween_method(_set_eyelid_open_amount, _eyelid_open_amount, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _eyelid_tween

## 灵魂互换闭眼演出：显示眼睑并伴随震屏与重度震动渐闭至全黑。
## [param duration] 闭眼时长（秒）。
## [param start_open] 起始张开程度（0~1）。
func soul_swap_eye_close(duration: float = 0.28, start_open: float = 0.92) -> void:
	_show_eyelid(start_open)
	shake(4.0, duration + 0.06)
	InputDevice.vibrate_heavy()
	var tw = _animate_eyelid_to(0.0, duration)
	await tw.finished

## 灵魂互换睁眼演出：从全黑渐睁至目标程度，完成后隐藏眼睑遮罩。
## [param duration] 睁眼时长（秒）。
## [param end_open] 结束张开程度（0~1）。
func soul_swap_eye_open(duration: float = 0.36, end_open: float = 1.0) -> void:
	_show_eyelid(0.0)
	shake(2.5, duration)
	InputDevice.vibrate_medium()
	var tw = _animate_eyelid_to(end_open, duration)
	await tw.finished
	_eyelid_rect.visible = false
	_set_eyelid_open_amount(1.0)

# ============================================
# 低理智视觉效果
# ============================================

## 理智变化回调：低于阈值时增强边缘泛红、加速心跳并叠加音频失真与画面扭曲。
## [param current] 当前理智值。
## [param max_val] 理智上限值。
func _on_sanity_changed(current: float, max_val: float) -> void:
	var ratio = current / max_val if max_val > 0 else 1.0
	
	if ratio < 0.5:
		# 理智低于50%：屏幕边缘泛红，越低越强
		var intensity = (0.5 - ratio) / 0.5  # 0→1
		_vignette_shader.set_shader_parameter("intensity", intensity)
		# 启动心跳
		if not _heartbeat_active:
			_heartbeat_active = true
			_heartbeat_timer = 0.0
		# 理智越低，心跳越快（指数加速）
		_heartbeat_interval = lerpf(0.8, 0.25, intensity * intensity)
		# 音频失真：理智低于 50% 时开始低通滤波
		AudioManager.set_audio_muffle(intensity * 0.4, 0.5)
		# 理智低于30%：画面扭曲
		if ratio < 0.3:
			var distort_str = (0.3 - ratio) / 0.3  # 0→1
			var atmo = _get_atmosphere_layer()
			if atmo:
				atmo.set_distortion(distort_str * 0.5, 0.5)
		else:
			var atmo = _get_atmosphere_layer()
			if atmo:
				atmo.set_distortion(0, 0.5)
	else:
		_vignette_shader.set_shader_parameter("intensity", 0.0)
		_heartbeat_active = false
		# 理智恢复：清除音频失真
		AudioManager.set_audio_muffle(0.0, 1.0)
		var atmo = _get_atmosphere_layer()
		if atmo:
			atmo.set_distortion(0, 0.5)

## 从 atmosphere_layer 分组中获取氛围层节点。
## [return] 氛围层节点，不存在时返回 null。
func _get_atmosphere_layer() -> Node:
	var nodes = get_tree().get_nodes_in_group("atmosphere_layer")
	return nodes[0] if nodes.size() > 0 else null

## 低理智激活状态下按当前间隔循环播放心跳音效。
## [param delta] 帧间隔时间（秒）。
func _process_heartbeat(delta: float) -> void:
	if not _heartbeat_active:
		return
	_heartbeat_timer += delta
	if _heartbeat_timer >= _heartbeat_interval:
		_heartbeat_timer -= _heartbeat_interval
		if _heartbeat_stream and not _heartbeat_player.playing:
			_heartbeat_player.stream = _heartbeat_stream
			_heartbeat_player.play()

## 程序化生成心跳声（双脉冲 thump-thump）
func _generate_heartbeat_sound() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.35  # 一次心跳的时长
	var total_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples * 2)  # 16-bit
	
	for i in total_samples:
		var t := float(i) / sample_rate
		var sample := 0.0
		
		# 第一下 (thump) — 0.00-0.10s
		if t < 0.10:
			var env := (1.0 - t / 0.10) * (1.0 - t / 0.10)
			sample = sin(t * TAU * 50.0) * env * 0.7
		# 第二下 (thump) — 0.15-0.25s（较轻）
		elif t >= 0.15 and t < 0.25:
			var t2 := t - 0.15
			var env := (1.0 - t2 / 0.10) * (1.0 - t2 / 0.10)
			sample = sin(t2 * TAU * 45.0) * env * 0.5
		
		var int_sample := clampi(int(sample * 32000), -32768, 32767)
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

# ============================================
# 组合特效（常用场景一键调用）
# ============================================

## NPC死亡：红闪 + 强震 + 重度震动
func death_impact(intensity: float = 10.0) -> void:
	flash_red(0.3)
	shake(intensity, 0.4)
	InputDevice.vibrate_heavy()

## 规则出现：白闪 + 轻震 + 中度震动
func rule_appear() -> void:
	flash_white(0.2)
	shake(4.0, 0.2)
	InputDevice.vibrate_medium()
	# 诡异音效：低频嗡鸣 + 金属刮擦
	var sfx = preload("res://scripts/utils/procedural_sfx.gd")
	AudioManager.play_sfx(sfx.ground_rumble(), -8.0)
	get_tree().create_timer(0.3).timeout.connect(func():
		AudioManager.play_sfx(sfx.metal_clang(), -12.0)
	)

## 巨口出现：黑闪 + 强震 + 重度震动
func abyss_impact() -> void:
	flash_black(0.2)
	shake(12.0, 0.5)
	InputDevice.vibrate_heavy()

## 灵魂互换：白闪 + 中震 + 重度震动
func soul_swap_flash() -> void:
	flash_white(0.3)
	shake(6.0, 0.8)
	InputDevice.vibrate_heavy()

## 受伤/碰到怪物：红闪 + 轻震 + 中度震动
func hit_impact() -> void:
	flash_red(0.15)
	shake(5.0, 0.2)
	InputDevice.vibrate_medium()
