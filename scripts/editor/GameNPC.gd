@tool
extends Node2D
## 可在编辑器中拖拽放置的NPC生成点
## 运行时 LevelBase 在此位置生成实际NPC

class_name GameNPC

@export var npc_id: String = "cool_npc":
	set(value):
		npc_id = value
		queue_redraw()
@export var wander_points: Array[Vector2] = []

var _npc_body: CharacterBody2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Draw a colored circle preview
	var color := _get_npc_color()
	draw_circle(Vector2.ZERO, 12.0, color.darkened(0.3))
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 32, color, 2.0)
	# Name label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-20, -18), npc_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _get_npc_color() -> Color:
	if Engine.is_editor_hint():
		# Try to get from GameManager if available
		if Engine.has_singleton("GameManager"):
			return Color(0.5, 0.5, 0.5)
	# Use GameManager data at runtime
	return Color(0.5, 0.5, 0.5)

## 运行时由 LevelBase 调用，生成实际NPC
func spawn_npc(level: Node) -> CharacterBody2D:
	if Engine.is_editor_hint():
		return null
	if level.has_method("create_npc_visual"):
		_npc_body = level.create_npc_visual(position, npc_id)
		return _npc_body
	return null
