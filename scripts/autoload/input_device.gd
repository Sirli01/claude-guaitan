extends Node
## 输入设备检测 — 自动检测键鼠/手柄并提供对应的按键提示文本
## 当检测到手柄输入时切换到手柄模式，检测到键鼠输入时切换回来

signal input_device_changed(is_gamepad: bool)

var using_gamepad: bool = false

# 键鼠/手柄按键提示映射
const HINTS_KEYBOARD := {
	"interact": "Space",
	"dialogue_advance": "Space / 鼠标左键",
	"dialogue_skip": "Tab",
	"open_rules": "R",
	"open_inventory": "Tab",
	"run": "Shift",
	"pause": "ESC",
	"quick_save": "F5",
	"quick_load": "F9",
	"move": "W/A/S/D",
	"confirm": "Enter",
	"cancel": "ESC",
	"ui_close": "ESC",
}

const HINTS_GAMEPAD := {
	"interact": "X/□",
	"dialogue_advance": "A/×",
	"dialogue_skip": "RB/R1",
	"open_rules": "Y/△",
	"open_inventory": "RB/R1",
	"run": "LB/L1",
	"pause": "Start",
	"quick_save": "L3",
	"quick_load": "R3",
	"move": "左摇杆",
	"confirm": "A/×",
	"cancel": "B/○",
	"ui_close": "B/○",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var was_gamepad = using_gamepad
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return  # 忽略微小摇杆漂移
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		using_gamepad = false
	
	if was_gamepad != using_gamepad:
		input_device_changed.emit(using_gamepad)

## 获取指定动作的当前设备按键提示
func get_hint(action: String) -> String:
	if using_gamepad:
		return HINTS_GAMEPAD.get(action, action)
	return HINTS_KEYBOARD.get(action, action)

## 获取格式化的按键提示（带括号）
func hint(action: String) -> String:
	return "[%s]" % get_hint(action)

## ===== 手柄震动 =====
## 轻微震动（拾取物品、打开UI、交互）
func vibrate_light() -> void:
	if not using_gamepad: return
	Input.start_joy_vibration(0, 0.2, 0.0, 0.1)

## 中等震动（开手电筒、点火柴、使用道具）
func vibrate_medium() -> void:
	if not using_gamepad: return
	Input.start_joy_vibration(0, 0.35, 0.2, 0.15)

## 重度震动（怪物出现、惊吓事件）
func vibrate_heavy() -> void:
	if not using_gamepad: return
	Input.start_joy_vibration(0, 0.6, 0.8, 0.3)

## 持续低频震动（怪物脚步声、危险氛围）
func vibrate_rumble(duration: float = 0.5) -> void:
	if not using_gamepad: return
	Input.start_joy_vibration(0, 0.1, 0.35, duration)

## 自定义震动
func vibrate(weak: float, strong: float, duration: float) -> void:
	if not using_gamepad: return
	Input.start_joy_vibration(0, weak, strong, duration)

## 停止震动
func vibrate_stop() -> void:
	Input.stop_joy_vibration(0)
