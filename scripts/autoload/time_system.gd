extends Node
## 时间系统 - 纯事件驱动（不再自动流逝）
## 剧情到哪一步就 set_time() 设定当前时间，仅用于内部状态判断

var game_hour: int = 20
var game_minute: int = 0
var is_forbidden_time: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 设置当前剧情时间点（不会自动流逝，纯标记）
func set_time(hour: int, minute: int = 0) -> void:
	game_hour = hour
	game_minute = minute
	is_forbidden_time = (game_hour >= 23 or game_hour < 7)

func is_in_forbidden_period() -> bool:
	return game_hour >= 23 or game_hour < 7

func reset() -> void:
	game_hour = 20
	game_minute = 0
	is_forbidden_time = false
