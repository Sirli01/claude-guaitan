class_name RbPlayerController
extends CharacterBody2D
## rebuild 玩家控制器 —— 只负责移动与朝向。
##
## 不创建任何节点：Sprite2D / CollisionShape2D / InteractionSensor / Camera2D
## 全部在 rb_player.tscn 中搭好。贴图也由场景通过 @export 注入，脚本里不写资源路径。

## 四方向待机贴图，在 rb_player.tscn 中赋值。
@export var texture_idle_down: Texture2D
@export var texture_idle_up: Texture2D
@export var texture_idle_left: Texture2D
@export var texture_idle_right: Texture2D

@export_group("移动")
@export var move_speed: float = 130.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_sensor: RbInteractionSensor = $InteractionSensor
@onready var camera: Camera2D = $Camera2D

## 当前朝向，用于选择待机贴图。
var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	_apply_facing_texture()


func get_facing() -> Vector2:
	return _facing


## 冻结移动（例如对话时），由关卡根节点调用。
func set_movement_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	if not enabled:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Vector2.ZERO
	if RbGameState.is_gameplay_active():
		input_direction = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)

	if input_direction == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
		_update_facing(input_direction)

	move_and_slide()


func _update_facing(direction: Vector2) -> void:
	var next_facing: Vector2 = _facing
	if absf(direction.x) > absf(direction.y):
		next_facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	else:
		next_facing = Vector2.DOWN if direction.y > 0.0 else Vector2.UP

	if next_facing == _facing:
		return
	_facing = next_facing
	_apply_facing_texture()


func _apply_facing_texture() -> void:
	if sprite == null:
		return
	var next_texture: Texture2D = texture_idle_down
	if _facing == Vector2.UP:
		next_texture = texture_idle_up
	elif _facing == Vector2.LEFT:
		next_texture = texture_idle_left
	elif _facing == Vector2.RIGHT:
		next_texture = texture_idle_right

	if next_texture != null:
		sprite.texture = next_texture
