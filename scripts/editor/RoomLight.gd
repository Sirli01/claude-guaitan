@tool
extends PointLight2D
## 可在编辑器中拖拽放置的灯光节点
## light_type: room(暖色)/corridor(冷白)/flickering(闪烁)/broken(损坏)/dust(灰尘粒子)

class_name RoomLight

@export var light_type: String = "room":
	set(value):
		light_type = value
		_apply_type()
@export_range(0.0, 5.0, 0.1) var base_energy: float = 1.8:
	set(value):
		base_energy = value
		_apply_type()
@export_range(0.1, 10.0, 0.1) var light_scale_val: float = 2.5:
	set(value):
		light_scale_val = value
		_apply_type()
@export var create_detection_area: bool = true

var _detection_area: Area2D = null

## 节点就绪回调：应用灯光类型，运行时延迟创建检测区域或灰尘粒子。
func _ready() -> void:
	_apply_type()
	# 检测区域/灰尘粒子需要 add_child 到父节点，延迟到场景装载完成后再创建
	if not Engine.is_editor_hint():
		if create_detection_area:
			call_deferred("_setup_detection")
		if light_type == "dust":
			call_deferred("_spawn_dust")

## 按 light_type 配置纹理、颜色与能量，并启动对应效果（闪烁/损坏/灰尘）。
func _apply_type() -> void:
	# tscn 加载时 setter 会先于入树触发，等 _ready 再应用
	if not is_inside_tree():
		return
	texture = _make_circle_texture(64)
	texture_scale = light_scale_val
	shadow_enabled = true
	range_item_cull_mask = 3  # light_mask 1+2

	match light_type:
		"room":
			energy = base_energy
			color = Color(1.0, 0.9, 0.7)
		"corridor":
			energy = base_energy
			color = Color(0.85, 0.9, 1.0)
		"flickering":
			energy = base_energy
			color = Color(0.85, 0.9, 1.0)
			if not Engine.is_editor_hint():
				_start_flicker()
		"broken":
			energy = 0.0
			color = Color(0.85, 0.9, 1.0)
			if not Engine.is_editor_hint():
				_start_broken()
		"dust":
			energy = 0.0
			color = Color.WHITE

## 创建玩家进出检测区域，维护关卡的玩家在灯下计数。
func _setup_detection() -> void:
	if _detection_area and is_instance_valid(_detection_area):
		_detection_area.queue_free()
	_detection_area = Area2D.new()
	_detection_area.position = position
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = light_scale_val * 32.0
	col.shape = shape
	_detection_area.add_child(col)
	get_parent().add_child(_detection_area)

	_detection_area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			var level = _find_level()
			if level:
				level._player_in_light_count += 1
	)
	_detection_area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			var level = _find_level()
			if level:
				level._player_in_light_count = maxi(level._player_in_light_count - 1, 0)
	)

## 向上遍历祖先查找关卡节点。
## [return] 含 show_hint 方法的关卡节点，未找到返回 null。
func _find_level() -> Node:
	var p = get_parent()
	while p:
		if p.has_method("show_hint"):
			return p
		p = p.get_parent()
	return null

## 启动闪烁灯光的循环动画。
func _start_flicker() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "energy", base_energy * 0.3, randf_range(0.05, 0.1))
	tw.tween_property(self, "energy", base_energy, randf_range(0.05, 0.15))
	tw.tween_interval(randf_range(1.0, 3.0))
	tw.tween_property(self, "energy", base_energy * 0.1, 0.03)
	tw.tween_property(self, "energy", base_energy * 0.8, 0.05)
	tw.tween_property(self, "energy", base_energy * 0.15, 0.04)
	tw.tween_property(self, "energy", base_energy, 0.08)
	tw.tween_interval(randf_range(2.0, 5.0))

## 启动损坏灯光的偶发闪动循环动画。
func _start_broken() -> void:
	var tw := create_tween().set_loops()
	tw.tween_interval(randf_range(4.0, 8.0))
	tw.tween_property(self, "energy", 0.4, 0.03)
	tw.tween_property(self, "energy", 0.0, 0.05)
	tw.tween_interval(0.1)
	tw.tween_property(self, "energy", 0.2, 0.02)
	tw.tween_property(self, "energy", 0.0, 0.08)

## 在父节点下创建漂浮灰尘粒子效果。
func _spawn_dust() -> void:
	var particles := GPUParticles2D.new()
	particles.position = position
	particles.amount = 8
	particles.lifetime = 4.0
	particles.speed_scale = 0.3
	particles.z_index = 2

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -0.5, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 1, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(30, 20, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.6
	mat.color = Color(0.8, 0.75, 0.65, 0.25)

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	particles.process_material = mat
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for px in 4:
		for py in 4:
			var dist := Vector2(px - 2, py - 2).length() / 2.0
			var a := clampf(1.0 - dist, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	particles.texture = ImageTexture.create_from_image(img)
	get_parent().add_child(particles)

## 生成径向渐隐的圆形光斑纹理。
## [param size] 纹理边长（像素）。
## [return] 生成的圆形 ImageTexture。
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
