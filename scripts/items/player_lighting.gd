extends Node2D
## 玩家照明系统 - 管理手机光/手电筒/火柴
## 挂载在玩家节点下，照明切换由玩家手动触发
## 用法:
##   var lighting = load("res://scripts/items/player_lighting.gd").new()
##   player.add_child(lighting)
##   （物品拾取时自动切换，无需手动调用）

class_name PlayerLighting

# 照明模式
enum LightMode { PHONE, FLASHLIGHT, MATCH }

const HELD_LIGHT_FORWARD_OFFSET: float = 6.5
const HELD_LIGHT_SIDE_OFFSET: float = 6.0
const HELD_LIGHT_TORSO_HEIGHT_RATIO: float = 0.44
const HELD_LIGHT_RAISED_HEIGHT_RATIO: float = 0.56

var current_mode: LightMode = LightMode.PHONE
var _cone_light: PointLight2D   # 锥形前方光（手机/手电筒）
var _circle_light: PointLight2D # 圆形光（火柴）
var _match_timer: float = 0.0
var _match_active: bool = false
var _mode_before_match: LightMode = LightMode.PHONE
var _player: CharacterBody2D
var _personal_light_enabled: bool = true
# 电池系统
var flashlight_battery: float = 100.0
var max_battery: float = 100.0
const BATTERY_DRAIN_RATE: float = 1.0  # 每秒消耗1%，满电可用100秒
var phone_has_power: bool = true  # 手机是否有电（第二层起设为false）
signal battery_changed(current: float, max_val: float)
# 手机参数（亮度高，范围最小）
const PHONE_ENERGY: float = 2.8
const PHONE_SCALE: float = 1.5
const PHONE_CONE_ANGLE: float = 50.0  # 度
const PHONE_RANGE: float = 60.0

# 手电筒参数（亮度最高，范围最大）
const FLASHLIGHT_ENERGY: float = 3.5
const FLASHLIGHT_SCALE: float = 3.9
const FLASHLIGHT_CONE_ANGLE: float = 50.0
const FLASHLIGHT_RANGE: float = 250.0

# 手电筒开启时玩家环形光的增强参数
const POINT_LIGHT_DEFAULT_ENERGY: float = 1.15
const POINT_LIGHT_FLASHLIGHT_ENERGY: float = 1.45
const POINT_LIGHT_DEFAULT_SCALE: float = 3.8
const POINT_LIGHT_FLASHLIGHT_SCALE: float = 4.3

# 火柴参数（全方位照明，范围中等）
const MATCH_ENERGY: float = 2.2
const MATCH_SCALE: float = 2.8
const MATCH_DURATION: float = 10.0

# 缓存纹理（避免重复创建导致atlas错误）
var _phone_texture: ImageTexture
var _flashlight_texture: ImageTexture
var _dust_particles: GPUParticles2D  # 手电筒光束灰尘

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	
	# 预生成纹理缓存
	_phone_texture = _make_cone_texture(128, PHONE_CONE_ANGLE, 0.0, 0.0, 0.0)
	_flashlight_texture = _make_cone_texture(128, FLASHLIGHT_CONE_ANGLE, 0.0, 0.0, 0.0)
	
	# 锥形光源（手机/手电筒共用，通过参数切换）
	_cone_light = PointLight2D.new()
	_cone_light.texture = _phone_texture
	_cone_light.shadow_enabled = true
	_cone_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	# 只照亮 light_mask=1 的物体（墙/地板/NPC），不照 light_mask=2 的玩家自身
	_cone_light.range_item_cull_mask = 1
	add_child(_cone_light)
	
	# 圆形光源（火柴）
	_circle_light = PointLight2D.new()
	_circle_light.texture = _make_circle_texture(128)
	_circle_light.energy = MATCH_ENERGY
	_circle_light.texture_scale = MATCH_SCALE
	_circle_light.color = Color(1.0, 0.75, 0.4)  # 暖黄火光
	_circle_light.shadow_enabled = true
	_circle_light.visible = false
	add_child(_circle_light)
	
	# 默认手机模式（首次设置纹理）
	_apply_phone_mode()
	
	# 手电筒光束灰尘粒子
	_dust_particles = _create_beam_dust()
	add_child(_dust_particles)
	_dust_particles.visible = false
	
	# 监听物品变化
	InventoryManager.item_added.connect(_on_item_changed)
	InventoryManager.item_removed.connect(_on_item_changed)

func _process(delta: float) -> void:
	# 更新锥形光方向
	if _player and _cone_light.visible:
		var dir = _player.facing_direction if _player.facing_direction != Vector2.ZERO else Vector2.DOWN
		var hand_anchor = _get_light_anchor(dir)
		_cone_light.rotation = dir.angle() + PI / 2.0
		_cone_light.position = hand_anchor + dir * HELD_LIGHT_FORWARD_OFFSET
		_circle_light.position = hand_anchor
		# 灰尘粒子跟随光束方向
		if _dust_particles and _dust_particles.visible:
			_dust_particles.rotation = _cone_light.rotation
			_dust_particles.position = hand_anchor + dir * 40.0
	elif _player and _circle_light.visible:
		var dir = _player.facing_direction if _player.facing_direction != Vector2.ZERO else Vector2.DOWN
		_circle_light.position = _get_light_anchor(dir)
	
	# 非游戏状态时不消耗电池
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# 手电筒电池消耗
	if current_mode == LightMode.FLASHLIGHT:
		flashlight_battery -= BATTERY_DRAIN_RATE * delta
		battery_changed.emit(flashlight_battery, max_battery)
		# 低电量闪烁（15% 以下随机闪烁，电量越低越频繁）
		if flashlight_battery < 15.0 and flashlight_battery > 0.0:
			var flicker_chance := (15.0 - flashlight_battery) / 15.0  # 0→1
			if randf() < flicker_chance * delta * 3.0:
				_cone_light.energy = FLASHLIGHT_ENERGY * randf_range(0.1, 0.6)
				get_tree().create_timer(randf_range(0.05, 0.15)).timeout.connect(
					func() -> void:
						if current_mode == LightMode.FLASHLIGHT and flashlight_battery > 0:
							_cone_light.energy = FLASHLIGHT_ENERGY
				)
		if flashlight_battery <= 0:
			flashlight_battery = 0.0
			_apply_phone_mode()
	
	# 火柴倒计时
	if _match_active:
		_match_timer -= delta
		if _match_timer < 2.0:
			_circle_light.energy = MATCH_ENERGY * (0.5 + 0.5 * sin(_match_timer * 8.0))
		if _match_timer <= 0:
			_extinguish_match()
	
	# 更新强光源状态给 PlayerStats（用于黑暗理智流失判定）
	PlayerStats.has_strong_light = (current_mode == LightMode.FLASHLIGHT or _match_active or (current_mode == LightMode.PHONE and phone_has_power))

func _get_light_anchor(dir: Vector2) -> Vector2:
	var char_height = GameManager.get_character_visual_height("sister")
	if absf(dir.x) > absf(dir.y):
		return Vector2(signf(dir.x) * HELD_LIGHT_SIDE_OFFSET, -char_height * HELD_LIGHT_TORSO_HEIGHT_RATIO)
	if dir.y < 0.0:
		return Vector2(HELD_LIGHT_SIDE_OFFSET * 0.5, -char_height * HELD_LIGHT_RAISED_HEIGHT_RATIO)
	return Vector2(HELD_LIGHT_SIDE_OFFSET * 0.6, -char_height * 0.44)

func _on_item_changed(item_id: String) -> void:
	if item_id != "flashlight":
		return
	if current_mode == LightMode.FLASHLIGHT and not InventoryManager.has_item("flashlight"):
		_apply_phone_mode()

func toggle_flashlight() -> bool:
	if _match_active:
		return false
	if not InventoryManager.has_item("flashlight"):
		return false
	if current_mode == LightMode.FLASHLIGHT:
		_apply_phone_mode()
		return true
	if flashlight_battery <= 0:
		return false
	_apply_flashlight_mode()
	return true

func set_personal_light_enabled(enabled: bool) -> void:
	_personal_light_enabled = enabled
	if _player and _player.point_light:
		_player.point_light.visible = enabled
	if not enabled:
		_cone_light.visible = false
		_circle_light.visible = false
		if _dust_particles:
			_dust_particles.visible = false
		return
	if _match_active:
		_circle_light.visible = true
		return
	if current_mode == LightMode.FLASHLIGHT:
		_apply_flashlight_mode()
	else:
		_apply_phone_mode()

## 使用火柴（由物品栏UI或快捷键调用）
func use_match() -> void:
	if _match_active:
		return
	_mode_before_match = current_mode
	_match_active = true
	_match_timer = MATCH_DURATION
	InputDevice.vibrate_medium()
	current_mode = LightMode.MATCH
	_cone_light.visible = false
	_circle_light.visible = true
	_circle_light.energy = MATCH_ENERGY
	if _dust_particles:
		_dust_particles.visible = false

func _extinguish_match() -> void:
	_match_active = false
	_match_timer = 0.0
	_circle_light.visible = false
	# 恢复火柴点燃前的模式
	if _mode_before_match == LightMode.FLASHLIGHT and InventoryManager.has_item("flashlight") and flashlight_battery > 0:
		_apply_flashlight_mode()
	else:
		_apply_phone_mode()
	_mode_before_match = current_mode

func _apply_phone_mode() -> void:
	current_mode = LightMode.PHONE
	if _dust_particles:
		_dust_particles.visible = false
	_restore_point_light()
	if _player and _player.point_light:
		_player.point_light.visible = _personal_light_enabled
	if not _personal_light_enabled:
		_cone_light.visible = false
		_circle_light.visible = false
		return
	if phone_has_power:
		_cone_light.visible = true
		_cone_light.texture = _phone_texture
		_cone_light.energy = PHONE_ENERGY
		_cone_light.texture_scale = PHONE_SCALE
		_cone_light.color = Color(0.85, 0.85, 0.95)
	else:
		# 手机没电，无光源
		_cone_light.visible = false

func _apply_flashlight_mode() -> void:
	current_mode = LightMode.FLASHLIGHT
	InputDevice.vibrate_medium()
	if _player and _player.point_light:
		_player.point_light.visible = _personal_light_enabled
	if not _personal_light_enabled:
		_cone_light.visible = false
		if _dust_particles:
			_dust_particles.visible = false
		return
	_cone_light.visible = true
	_cone_light.texture = _flashlight_texture
	_cone_light.energy = FLASHLIGHT_ENERGY
	_cone_light.texture_scale = FLASHLIGHT_SCALE
	_cone_light.color = Color(0.95, 0.92, 0.8)  # 手电筒暖白光
	_boost_point_light()
	if _dust_particles:
		_dust_particles.visible = true

## 生成锥形光纹理（从中心向上扩散的锥形）
func _make_cone_texture(size: int, angle_deg: float, center_glow_max: float, near_fade_start: float, near_fade_end: float) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half = size / 2.0
	var angle_rad = deg_to_rad(angle_deg / 2.0)
	for x in size:
		for y in size:
			var dx = x - half
			var dy = y - half
			var dist = Vector2(dx, dy).length() / half
			# 锥形：以向上（-Y）为中心
			var pixel_angle = atan2(abs(dx), -dy)
			var in_cone = pixel_angle < angle_rad and dy < 0
			var falloff = clampf(1.0 - dist, 0.0, 1.0)
			var cone_falloff = clampf(1.0 - pixel_angle / angle_rad, 0.0, 1.0) if in_cone else 0.0
			var near_fade = 1.0
			if near_fade_end > near_fade_start and dist < near_fade_end:
				near_fade = clampf((dist - near_fade_start) / (near_fade_end - near_fade_start), 0.0, 1.0)
			var alpha = falloff * cone_falloff * 0.9 * near_fade
			# 中心微光用于保留贴身的基础可见度
			var center_glow = clampf(1.0 - dist * 3.0, 0.0, center_glow_max)
			alpha = maxf(alpha, center_glow)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

## 生成圆形光纹理
func _make_circle_texture(size: int) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half = size / 2.0
	for x in size:
		for y in size:
			var dist = Vector2(x - half, y - half).length() / half
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha  # 二次衰减
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

## 补充电池（由 InventoryManager 调用）
func add_battery(amount: float) -> void:
	flashlight_battery = clampf(flashlight_battery + amount, 0.0, max_battery)
	battery_changed.emit(flashlight_battery, max_battery)
	# 如果当前是手机模式且有手电筒，自动切换
	if current_mode == LightMode.PHONE and InventoryManager.has_item("flashlight") and flashlight_battery > 0 and not _match_active:
		_apply_flashlight_mode()

func get_battery_percent() -> float:
	return flashlight_battery / max_battery if max_battery > 0 else 0.0

## 手电筒模式增强玩家环形光（让周围也更亮）
func _boost_point_light() -> void:
	if _player and _player.point_light:
		_player.point_light.energy = POINT_LIGHT_FLASHLIGHT_ENERGY
		_player.point_light.texture_scale = POINT_LIGHT_FLASHLIGHT_SCALE

## 恢复玩家环形光到默认
func _restore_point_light() -> void:
	if _player and _player.point_light:
		_player.point_light.energy = POINT_LIGHT_DEFAULT_ENERGY
		_player.point_light.texture_scale = POINT_LIGHT_DEFAULT_SCALE

## 设置手机是否有电（第二层起调用 disable_phone_power()）
func disable_phone_power() -> void:
	phone_has_power = false
	if current_mode == LightMode.PHONE:
		_cone_light.visible = false

func _create_beam_dust() -> GPUParticles2D:
	## 手电筒光束中飘浮的灰尘粒子
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 3.0
	particles.speed_scale = 0.6
	particles.z_index = 1
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1.0, 0)  # 沿光束方向（向上=本地坐标的前方）
	mat.spread = 25.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0.5, 0.5, 0)  # 轻微漂移
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(15, 50, 0)  # 沿光束长条分布
	mat.scale_min = 0.3
	mat.scale_max = 1.0
	mat.color = Color(0.95, 0.9, 0.75, 0.35)
	
	# 淡入淡出
	var alpha_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve
	
	particles.process_material = mat
	
	# 小圆点贴图
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for px in 6:
		for py in 6:
			var dist = Vector2(px - 3, py - 3).length() / 3.0
			var a = clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	particles.texture = ImageTexture.create_from_image(img)
	
	return particles
