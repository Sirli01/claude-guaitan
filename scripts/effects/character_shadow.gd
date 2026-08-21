extends Node2D
## 角色脚下动态投影 - 半透明、限制在脚下，并随最近光源轻微偏移

class_name CharacterShadow

const SHADOW_TEXTURE_SIZE := Vector2i(64, 32)
const SHADOW_ALPHA: float = 0.3

var _host: CharacterBody2D = null
var _char_id: String = "sister"
var _shadow_sprite: Sprite2D = null
var _lights: Array[PointLight2D] = []
var _scan_timer: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## 设置投影所属的角色ID（决定碰撞尺寸来源）。
## [param char_id] 角色ID。
func setup(char_id: String) -> void:
	_char_id = char_id

## 初始化：创建阴影精灵、按宿主碰撞体计算基准缩放并刷新光源列表。
func _ready() -> void:
	_host = get_parent() as CharacterBody2D
	_shadow_sprite = Sprite2D.new()
	_shadow_sprite.texture = _make_shadow_texture()
	_shadow_sprite.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_shadow_sprite.z_index = -1
	add_child(_shadow_sprite)
	
	var collision_size = _get_collision_size()
	var base_width = maxf(collision_size.x * 0.95, 12.0)
	var base_height = maxf(collision_size.y * 0.28, 4.0)
	_base_scale = Vector2(
		(base_width * 2.0) / float(SHADOW_TEXTURE_SIZE.x),
		(base_height * 2.0) / float(SHADOW_TEXTURE_SIZE.y)
	)
	_refresh_lights()
	_update_shadow_visual()

## 每帧更新阴影视觉，并定期重新扫描场景中的点光源。
## [param delta] 帧间隔（秒）。
func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.25
		_refresh_lights()
	_update_shadow_visual()

## 重新收集当前场景中所有可见且有效的 PointLight2D。
func _refresh_lights() -> void:
	_lights.clear()
	var scene = get_tree().current_scene
	if scene:
		_collect_lights(scene)

## 递归收集节点树中的点光源。
## [param node] 遍历起点节点。
func _collect_lights(node: Node) -> void:
	if node is PointLight2D and node.visible and node.energy > 0.01:
		_lights.append(node)
	for child in node.get_children():
		_collect_lights(child)

## 根据最近光源计算阴影的位置、旋转、拉伸与透明度。
func _update_shadow_visual() -> void:
	var best_strength = 0.0
	var best_dir = Vector2.ZERO
	for light in _lights:
		if not is_instance_valid(light) or not light.visible or light.energy <= 0.01:
			continue
		var to_host = _host.global_position - light.global_position
		var distance = to_host.length()
		if distance <= 0.001:
			continue
		var light_range = maxf(96.0, light.texture_scale * 90.0)
		if distance > light_range:
			continue
		var strength = light.energy * (1.0 - distance / light_range)
		if strength > best_strength:
			best_strength = strength
			best_dir = to_host.normalized()
	
	var stretch = 0.0
	var offset = Vector2(0.0, 2.0)
	var rotation = 0.0
	if best_strength > 0.0 and best_dir != Vector2.ZERO:
		var t = clampf(best_strength / 3.5, 0.0, 1.0)
		stretch = lerpf(0.05, 0.2, t)
		offset += Vector2(best_dir.x * lerpf(1.5, 4.0, t), clampf(best_dir.y * 1.2, -1.0, 1.8))
		rotation = best_dir.angle()
	_shadow_sprite.position = offset
	_shadow_sprite.rotation = rotation
	_shadow_sprite.scale = _base_scale * Vector2(1.0 + stretch, 1.0 - stretch * 0.3)
	_shadow_sprite.modulate.a = SHADOW_ALPHA

## 按角色ID返回对应的碰撞尺寸。
## [return] 碰撞尺寸。
func _get_collision_size() -> Vector2:
	match _char_id:
		"sister":
			return GameManager.PLAYER_COLLISION_SIZE
		"humanoid_monster":
			return GameManager.MONSTER_COLLISION_SIZE
		_:
			return GameManager.NPC_COLLISION_SIZE

## 程序化生成椭圆形柔和阴影贴图。
## [return] 生成的阴影纹理。
func _make_shadow_texture() -> ImageTexture:
	var img = Image.create(SHADOW_TEXTURE_SIZE.x, SHADOW_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	var center = Vector2(SHADOW_TEXTURE_SIZE.x * 0.5, SHADOW_TEXTURE_SIZE.y * 0.5)
	for x in SHADOW_TEXTURE_SIZE.x:
		for y in SHADOW_TEXTURE_SIZE.y:
			var dx = (x - center.x) / center.x
			var dy = (y - center.y) / center.y
			var dist = dx * dx + dy * dy
			var alpha = clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
