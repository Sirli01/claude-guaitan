extends Node2D
## 房间模板 - 数据驱动的房间构建器
## 用法:
##   var room = RoomTemplate.new()
##   room.room_config = {
##       "size": Vector2(300, 200),
##       "bg_color": Color(0.08, 0.06, 0.05),
##       "walls": true,
##       "wall_color": Color(0.15, 0.12, 0.1),
##       "ambient_light": 0.3,           # 环境光明度 (0~1)
##       "ambient_color": Color.WHITE,    # 环境光色温
##       "bgm": "res://assets/audio/bgm/xxx.ogg",
##       "ambience": "res://assets/audio/ambience/xxx.ogg",
##       "furniture": [                    # 家具列表（阻挡+视觉）
##           {"pos": Vector2(50,30), "size": Vector2(40,30), "color": Color(0.3,0.2,0.15), "name": "桌子"},
##       ],
##       "pickups": [                      # 可拾取物品
##           {"pos": Vector2(100,80), "item_id": "bread"},
##       ],
##       "triggers": [                     # 触发区域
##           {"pos": Vector2(0,90), "size": Vector2(50,20), "event_id": "room_enter_scare"},
##       ],
##       "doors": [                        # 门（连接其他房间/走廊）
##           {"pos": Vector2(150,0), "size": Vector2(30,10), "target_scene": "", "target_pos": Vector2.ZERO},
##       ],
##       "decorations": [                  # 纯视觉装饰（无碰撞）
##           {"pos": Vector2(20,60), "size": Vector2(10,10), "color": Color(0.2,0.2,0.2)},
##       ],
##   }
##   add_child(room)
##   room.build()

class_name RoomTemplate

var room_config: Dictionary = {}
var walls_body: StaticBody2D
var furniture_nodes: Array[Node2D] = []
var pickup_nodes: Array[Node2D] = []
var trigger_nodes: Array[Area2D] = []
var door_nodes: Array[Area2D] = []

signal door_entered(door_data: Dictionary)
signal trigger_activated(event_id: String, trigger_data: Dictionary)

## 根据 room_config 构建整个房间（地板、墙、家具、物品、触发器、门、装饰、音频与环境光）。
func build() -> void:
	var size: Vector2 = room_config.get("size", Vector2(300, 200))
	var bg_color: Color = room_config.get("bg_color", Color(0.08, 0.06, 0.05))
	
	# 地板
	var floor_rect = ColorRect.new()
	floor_rect.position = -size / 2
	floor_rect.size = size
	floor_rect.color = bg_color
	floor_rect.z_index = -10
	add_child(floor_rect)
	
	# 墙壁
	if room_config.get("walls", true):
		_build_walls(size, room_config.get("wall_color", Color(0.15, 0.12, 0.1)))
	
	# 家具
	for f in room_config.get("furniture", []):
		_build_furniture(f)
	
	# 可拾取物品
	for p in room_config.get("pickups", []):
		_build_pickup(p)
	
	# 触发区域
	for t in room_config.get("triggers", []):
		_build_trigger(t)
	
	# 门
	for d in room_config.get("doors", []):
		_build_door(d)
	
	# 纯装饰
	for dec in room_config.get("decorations", []):
		_build_decoration(dec)
	
	# 音频
	_setup_audio()
	
	# 环境光
	_setup_ambient_light()

## 构建四面墙壁（碰撞体+视觉色块）。
## [param size] 房间尺寸。
## [param color] 墙壁颜色。
func _build_walls(size: Vector2, color: Color) -> void:
	walls_body = StaticBody2D.new()
	walls_body.collision_layer = 4
	add_child(walls_body)
	
	var thickness = 8.0
	var half = size / 2
	# 上下左右四面墙
	var wall_data = [
		{"pos": Vector2(0, -half.y - thickness/2), "size": Vector2(size.x + thickness*2, thickness)},
		{"pos": Vector2(0, half.y + thickness/2), "size": Vector2(size.x + thickness*2, thickness)},
		{"pos": Vector2(-half.x - thickness/2, 0), "size": Vector2(thickness, size.y)},
		{"pos": Vector2(half.x + thickness/2, 0), "size": Vector2(thickness, size.y)},
	]
	for w in wall_data:
		var col = CollisionShape2D.new()
		col.position = w["pos"]
		var rect = RectangleShape2D.new()
		rect.size = w["size"]
		col.shape = rect
		walls_body.add_child(col)
		# 视觉
		var vis = ColorRect.new()
		vis.position = w["pos"] - w["size"] / 2
		vis.size = w["size"]
		vis.color = color
		add_child(vis)

## 构建单件家具（阻挡碰撞体+视觉，可选贴图替换色块）。
## [param data] 家具配置（pos/size/color/sprite/name）。
func _build_furniture(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(30, 20))
	var color: Color = data.get("color", Color(0.25, 0.18, 0.12))
	
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 4
	add_child(body)
	
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
	
	# ART: 如果有sprite路径
	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var spr = Sprite2D.new()
		spr.texture = load(sprite_path)
		spr.z_index = 1
		body.add_child(spr)
		vis.visible = false  # 有素材时隐藏色块
	
	furniture_nodes.append(body)

## 构建单个可拾取物品（Area2D+图标+提示标签）。
## [param data] 物品配置（pos/item_id/sprite/hint）。
func _build_pickup(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var item_id: String = data.get("item_id", "")
	var item_data = InventoryManager.get_item_data(item_id)
	
	var pickup = Area2D.new()
	pickup.position = pos
	pickup.collision_layer = 16
	pickup.collision_mask = 1
	pickup.set_script(load("res://scripts/items/pickup_item.gd"))
	
	# 视觉
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	var icon_path = data.get("sprite", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		spr.texture = load(icon_path)
	else:
		# 色块占位
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(data.get("color", Color(0.9, 0.8, 0.3)))
		spr.texture = ImageTexture.create_from_image(img)
	pickup.add_child(spr)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	col.shape = shape
	pickup.add_child(col)
	
	var hint = Label.new()
	hint.name = "HintLabel"
	hint.text = data.get("hint", "按%s拾取" % InputDevice.get_hint("interact"))
	hint.position = Vector2(-25, -25)
	hint.add_theme_font_size_override("font_size", 20)
	hint.visible = false
	pickup.add_child(hint)
	
	add_child(pickup)
	pickup.item_id = item_id
	pickup.item_display_name = item_data.get("name", item_id)
	
	pickup_nodes.append(pickup)

## 构建单个触发区域，玩家进入时发出 trigger_activated 信号。
## [param data] 触发器配置（pos/size/event_id/one_shot）。
func _build_trigger(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(40, 40))
	var event_id: String = data.get("event_id", "")
	var one_shot: bool = data.get("one_shot", true)
	
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 1
	add_child(area)
	
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	area.add_child(col)
	
	var triggered = false
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if one_shot and triggered:
				return
			triggered = true
			trigger_activated.emit(event_id, data)
	)
	
	trigger_nodes.append(area)

## 构建单扇门区域，玩家进入时发出 door_entered 信号。
## [param data] 门配置（pos/size/color/target_scene/target_pos）。
func _build_door(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(30, 10))
	
	var area = Area2D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 1
	add_child(area)
	
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	area.add_child(col)
	
	# 门的视觉标记
	var vis = ColorRect.new()
	vis.position = -size / 2
	vis.size = size
	vis.color = data.get("color", Color(0.3, 0.22, 0.15))
	area.add_child(vis)
	
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			door_entered.emit(data)
	)
	
	door_nodes.append(area)

## 构建纯视觉装饰（优先使用贴图，否则用色块，无碰撞）。
## [param data] 装饰配置（pos/size/color/sprite/z_index）。
func _build_decoration(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(10, 10))
	var color: Color = data.get("color", Color(0.2, 0.2, 0.2))
	
	var sprite_path = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var spr = Sprite2D.new()
		spr.position = pos
		spr.texture = load(sprite_path)
		spr.z_index = data.get("z_index", 0)
		add_child(spr)
	else:
		var vis = ColorRect.new()
		vis.position = pos - size / 2
		vis.size = size
		vis.color = color
		vis.z_index = data.get("z_index", 0)
		add_child(vis)

## 按 room_config 播放房间 BGM 与环境音。
func _setup_audio() -> void:
	var bgm_path = room_config.get("bgm", "")
	if bgm_path != "" and ResourceLoader.exists(bgm_path):
		AudioManager.play_bgm(load(bgm_path))
	var amb_path = room_config.get("ambience", "")
	if amb_path != "" and ResourceLoader.exists(amb_path):
		AudioManager.play_ambience(load(amb_path))

## 用 CanvasModulate 设置房间整体环境光亮度与色温。
func _setup_ambient_light() -> void:
	var light_energy: float = room_config.get("ambient_light", -1.0)
	if light_energy < 0:
		return
	# 用CanvasModulate控制整体亮度
	var modulate = CanvasModulate.new()
	var ambient_color: Color = room_config.get("ambient_color", Color.WHITE)
	modulate.color = ambient_color * light_energy
	add_child(modulate)
