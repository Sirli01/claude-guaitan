class_name RbGameState
## rebuild 全局运行状态（只读查询接口 + 显式写入方法）
##
## 设计约束：
## - 不注册为 autoload，避免改动 project.godot 影响旧系统。
## - 使用静态变量在场景切换之间保留状态。
## - 其他系统只通过下面的方法读写，禁止直接赋值内部变量。

enum State {
	MENU,      ## 主菜单，不接受游戏内输入
	PLAYING,   ## 可自由移动 / 可交互
	DIALOGUE,  ## 对话中，移动与交互被冻结
	PAUSED,    ## 预留：暂停
}

## 当前状态。外部请用 get_state() / set_state() 访问。
static var _current_state: State = State.MENU

## 下一个关卡应使用的出生点名称；用完即清空。
static var _pending_spawn_id: String = ""

## 剧情标记（最小流程只需要这两个，后续可扩展）。
static var _flags: Dictionary = {}


static func get_state() -> State:
	return _current_state


static func set_state(next_state: State) -> State:
	var previous: State = _current_state
	_current_state = next_state
	return previous


## 玩家是否可以移动 / 触发交互。
static func is_gameplay_active() -> bool:
	return _current_state == State.PLAYING


static func consume_pending_spawn_id() -> String:
	var spawn_id: String = _pending_spawn_id
	_pending_spawn_id = ""
	return spawn_id


static func set_pending_spawn_id(spawn_id: String) -> void:
	_pending_spawn_id = spawn_id


static func set_flag(key: String, value: bool = true) -> void:
	_flags[key] = value


static func has_flag(key: String) -> bool:
	return bool(_flags.get(key, false))


## 开始新游戏时重置全部运行时状态。
static func reset_for_new_game() -> void:
	_current_state = State.PLAYING
	_pending_spawn_id = ""
	_flags.clear()
