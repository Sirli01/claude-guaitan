extends Node2D
## 房间模板 v2 - 使用场景节点，可在编辑器中可视化编辑
## 用法：
##   1. 在编辑器中实例化 room_template.tscn
##   2. 通过 @export 变量配置房间属性
##   3. 在编辑器中直接调整地板、墙壁、家具等

class_name RoomTemplateV2

## 房间尺寸
@export var room_size: Vector2 = Vector2(300, 200):
	set(value):
		room_size = value
		_update_room_size()

## 地板颜色
@export var floor_color: Color = Color(0.08, 0.06, 0.05):
	set(value):
		floor_color = value
		_update_floor_color()

## 墙壁颜色
@export var wall_color: Color = Color(0.15, 0.12, 0.1):
	set(value):
		wall_color = value
		_update_wall_color()

## 墙壁厚度
@export var wall_thickness: float = 8.0:
	set(value):
		wall_thickness = value
		_update_room_size()

## 环境光明度 (0-1)
@export_range(0.0, 1.0) var ambient_light: float = 1.0:
	set(value):
		ambient_light = value
		_update_ambient_light()

## 环境光颜色
@export var ambient_color: Color = Color.WHITE:
	set(value):
		ambient_color = value
		_update_ambient_light()

## 背景音乐路径
@export_file("*.ogg", "*.wav", "*.mp3") var bgm_path: String = ""

## 环境音路径
@export_file("*.ogg", "*.wav", "*.mp3") var ambience_path: String = ""

## 是否显示墙壁
@export var show_walls: bool = true:
	set(value):
		show_walls = value
		_update_wall_visibility()

# 节点引用
@onready var floor_rect: ColorRect = $Floor
@onready var walls: StaticBody2D = $Walls
@onready var wall_visuals: Node2D = $WallVisuals
@onready var furniture_container: Node2D = $Furniture
@onready var pickup_container: Node2D = $Pickups
@onready var trigger_container: Node2D = $Triggers
@onready var door_container: Node2D = $Doors
@onready var decoration_container: Node2D = $Decorations
@onready var light_container: Node2D = $Lights
@onready var ambient_light_node: CanvasModulate = $AmbientLight

# 内部状态
var _initialized: bool = false


func _ready() -> void:
	_initialized = true
	_update_room_size()
	_update_floor_color()
	_update_wall_color()
	_update_ambient_light()
	_update_wall_visibility()
	_setup_audio()


## 更新房间尺寸
func _update_room_size() -> void:
	if not _initialized:
		return

	var half_size := room_size / 2

	# 更新地板
	if floor_rect:
		floor_rect.position = -half_size
		floor_rect.size = room_size

	# 更新墙壁碰撞体
	if walls:
		var top: CollisionShape2D = walls.get_node_or_null("WallTop")
		var bottom: CollisionShape2D = walls.get_node_or_null("WallBottom")
		var left: CollisionShape2D = walls.get_node_or_null("WallLeft")
		var right: CollisionShape2D = walls.get_node_or_null("WallRight")

		if top:
			top.position = Vector2(0, -half_size.y - wall_thickness / 2)
			if top.shape is RectangleShape2D:
				top.shape.size = Vector2(room_size.x + wall_thickness * 2, wall_thickness)

		if bottom:
			bottom.position = Vector2(0, half_size.y + wall_thickness / 2)
			if bottom.shape is RectangleShape2D:
				bottom.shape.size = Vector2(room_size.x + wall_thickness * 2, wall_thickness)

		if left:
			left.position = Vector2(-half_size.x - wall_thickness / 2, 0)
			if left.shape is RectangleShape2D:
				left.shape.size = Vector2(wall_thickness, room_size.y)

		if right:
			right.position = Vector2(half_size.x + wall_thickness / 2, 0)
			if right.shape is RectangleShape2D:
				right.shape.size = Vector2(wall_thickness, room_size.y)

	# 更新墙壁视觉
	if wall_visuals:
		var top_vis: ColorRect = wall_visuals.get_node_or_null("WallTopVis")
		var bottom_vis: ColorRect = wall_visuals.get_node_or_null("WallBottomVis")
		var left_vis: ColorRect = wall_visuals.get_node_or_null("WallLeftVis")
		var right_vis: ColorRect = wall_visuals.get_node_or_null("WallRightVis")

		if top_vis:
			top_vis.position = Vector2(-half_size.x - wall_thickness, -half_size.y - wall_thickness)
			top_vis.size = Vector2(room_size.x + wall_thickness * 2, wall_thickness)

		if bottom_vis:
			bottom_vis.position = Vector2(-half_size.x - wall_thickness, half_size.y)
			bottom_vis.size = Vector2(room_size.x + wall_thickness * 2, wall_thickness)

		if left_vis:
			left_vis.position = Vector2(-half_size.x - wall_thickness, -half_size.y - wall_thickness)
			left_vis.size = Vector2(wall_thickness, room_size.y + wall_thickness * 2)

		if right_vis:
			right_vis.position = Vector2(half_size.x, -half_size.y - wall_thickness)
			right_vis.size = Vector2(wall_thickness, room_size.y + wall_thickness * 2)


## 更新地板颜色
func _update_floor_color() -> void:
	if floor_rect:
		floor_rect.color = floor_color


## 更新墙壁颜色
func _update_wall_color() -> void:
	if wall_visuals:
		for child in wall_visuals.get_children():
			if child is ColorRect:
				child.color = wall_color


## 更新环境光
func _update_ambient_light() -> void:
	if ambient_light_node:
		ambient_light_node.color = ambient_color * ambient_light


## 更新墙壁可见性
func _update_wall_visibility() -> void:
	if walls:
		walls.visible = show_walls
	if wall_visuals:
		wall_visuals.visible = show_walls


## 设置音频
func _setup_audio() -> void:
	if bgm_path != "" and ResourceLoader.exists(bgm_path):
		AudioManager.play_bgm(load(bgm_path))
	if ambience_path != "" and ResourceLoader.exists(ambience_path):
		AudioManager.play_ambience(load(ambience_path))


## 添加家具（在编辑器中调用或代码中调用）
## [param pos] 家具位置
## [param size] 家具尺寸
## [param color] 家具颜色
## [param sprite_path] 可选的贴图路径
## [return] 创建的家具节点
func add_furniture(pos: Vector2, size: Vector2, color: Color, sprite_path: String = "") -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)

	var vis = ColorRect.new()
	vis.position = -size / 2
	vis.size = size
	vis.color = color
	body.add_child(vis)

	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var spr = Sprite2D.new()
		spr.texture = load(sprite_path)
		spr.z_index = 1
		body.add_child(spr)
		vis.visible = false

	furniture_container.add_child(body)
	return body


## 添加可拾取物品
## [param pos] 物品位置
## [param item_id] 物品ID
## [param sprite_path] 可选的贴图路径
## [return] 创建的物品节点
func add_pickup(pos: Vector2, item_id: String, sprite_path: String = "") -> Area2D:
	var item_data = InventoryManager.get_item_data(item_id)

	var pickup = Area2D.new()
	pickup.position = pos
	pickup.collision_layer = 16
	pickup.collision_mask = 1
	pickup.set_script(load("res://scripts/items/pickup_item.gd"))

	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		spr.texture = load(sprite_path)
	else:
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.9, 0.8, 0.3))
		spr.texture = ImageTexture.create_from_image(img)
	pickup.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	col.shape = shape
	pickup.add_child(col)

	pickup_container.add_child(pickup)
	pickup.item_id = item_id
	pickup.item_display_name = item_data.get("name", item_id)

	return pickup


## 添加触发区域
## [param pos] 触发器位置
## [param size] 触发器尺寸
## [param event_id] 事件ID
## [param one_shot] 是否只触发一次
## [return] 创建的触发器节点
func add_trigger(pos: Vector2, size: Vector2, event_id: String, one_shot: bool = true) -> Area2D:
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 1

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	area.add_child(col)

	trigger_container.add_child(area)
	return area


## 添加门
## [param pos] 门位置
## [param size] 门尺寸
## [param target_scene] 目标场景路径
## [param target_pos] 目标位置
## [return] 创建的门节点
func add_door(pos: Vector2, size: Vector2, target_scene: String = "", target_pos: Vector2 = Vector2.ZERO) -> Area2D:
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 1

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	area.add_child(col)

	var vis = ColorRect.new()
	vis.position = -size / 2
	vis.size = size
	vis.color = Color(0.3, 0.22, 0.15)
	area.add_child(vis)

	door_container.add_child(area)
	return area


## 添加装饰
## [param pos] 装饰位置
## [param size] 装饰尺寸
## [param color] 装饰颜色
## [param sprite_path] 可选的贴图路径
func add_decoration(pos: Vector2, size: Vector2, color: Color, sprite_path: String = "") -> void:
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var spr = Sprite2D.new()
		spr.position = pos
		spr.texture = load(sprite_path)
		decoration_container.add_child(spr)
	else:
		var vis = ColorRect.new()
		vis.position = pos - size / 2
		vis.size = size
		vis.color = color
		decoration_container.add_child(vis)


## 添加灯光
## [param pos] 灯光位置
## [param energy] 灯光强度
## [param color] 灯光颜色
## [param radius] 灯光半径
## [return] 创建的灯光节点
func add_light(pos: Vector2, energy: float = 1.0, color: Color = Color.WHITE, radius: float = 100.0) -> PointLight2D:
	var light = PointLight2D.new()
	light.position = pos
	light.energy = energy
	light.color = color

	# 创建圆形纹理
	var img = Image.create(int(radius * 2), int(radius * 2), false, Image.FORMAT_RGBA8)
	for x in range(int(radius * 2)):
		for y in range(int(radius * 2)):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				img.set_pixel(x, y, Color.TRANSPARENT)
	light.texture = ImageTexture.create_from_image(img)

	light_container.add_child(light)
	return light
