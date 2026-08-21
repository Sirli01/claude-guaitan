extends Node
## 恐怖导演系统 — 控制游戏张力节奏
## 使用锯齿波模型：平静 → 积累 → 高峰 → 释放 → 平静
## 监控玩家状态，动态调整威胁出现时机，防止玩家疲劳

signal tension_changed(tension: float)
signal peak_reached()
signal relief_started()
signal calm_started()

## 张力阶段
enum Phase { CALM, BUILDUP, PEAK, RELIEF }

## 当前张力值（0.0 = 平静，1.0 = 最高峰）
var tension: float = 0.0
## 当前阶段
var phase: Phase = Phase.CALM
## 在当前阶段中已过的时间（秒）
var time_in_phase: float = 0.0

# ===== 锯齿波参数 =====
## 积累阶段持续时间范围（秒）
@export var buildup_duration_min: float = 45.0
@export var buildup_duration_max: float = 90.0
## 高峰阶段持续时间（秒）
@export var peak_duration: float = 8.0
## 释放阶段持续时间（秒）
@export var relief_duration: float = 20.0
## 平静阶段持续时间（秒）
@export var calm_duration: float = 15.0

# ===== 运行时状态 =====
var _current_buildup_duration: float = 60.0
## 总高峰次数（用于调试和成就系统）
var total_peaks: int = 0
## 上次高峰后经过的时间
var time_since_last_peak: float = 0.0
## 是否被暂停（由 GameManager 控制）
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_roll_buildup_duration()

func _process(delta: float) -> void:
	if _paused:
		return
	# 只在游戏进行中运作
	if GameManager and GameManager.current_state != GameManager.GameState.PLAYING:
		return

	time_in_phase += delta
	time_since_last_peak += delta

	match phase:
		Phase.CALM:
			tension = 0.0
			if time_in_phase >= calm_duration:
				_enter_phase(Phase.BUILDUP)

		Phase.BUILDUP:
			# 线性积累（也可换成指数曲线让前期更慢、后期更快）
			tension = clampf(time_in_phase / _current_buildup_duration, 0.0, 1.0)
			tension_changed.emit(tension)
			if tension >= 1.0:
				_enter_phase(Phase.PEAK)

		Phase.PEAK:
			tension = 1.0
			tension_changed.emit(tension)
			if time_in_phase >= peak_duration:
				_enter_phase(Phase.RELIEF)

		Phase.RELIEF:
			tension = clampf(1.0 - (time_in_phase / relief_duration), 0.0, 1.0)
			tension_changed.emit(tension)
			if tension <= 0.0:
				_enter_phase(Phase.CALM)

## 进入新阶段
func _enter_phase(new_phase: Phase) -> void:
	phase = new_phase
	time_in_phase = 0.0
	match new_phase:
		Phase.PEAK:
			total_peaks += 1
			time_since_last_peak = 0.0
			peak_reached.emit()
		Phase.RELIEF:
			relief_started.emit()
		Phase.CALM:
			calm_started.emit()
		Phase.BUILDUP:
			_roll_buildup_duration()

## 随机选择积累时长
func _roll_buildup_duration() -> void:
	_current_buildup_duration = randf_range(buildup_duration_min, buildup_duration_max)

## 强制触发高峰（供关卡脚本调用，如 23:00 停电事件）
func force_peak() -> void:
	tension = 1.0
	_enter_phase(Phase.PEAK)

## 强制进入释放阶段
func force_relief() -> void:
	_enter_phase(Phase.RELIEF)

## 强制进入平静阶段
func force_calm() -> void:
	_enter_phase(Phase.CALM)

## 暂停/恢复 Director
func set_paused(paused: bool) -> void:
	_paused = paused

## 获取怪物生成激进程度（供关卡脚本使用）
## 返回 0.0~1.0，越高越激进
func get_monster_aggressiveness() -> float:
	return tension

## 获取当前阶段名称（调试用）
func get_phase_name() -> String:
	match phase:
		Phase.CALM: return "CALM"
		Phase.BUILDUP: return "BUILDUP"
		Phase.PEAK: return "PEAK"
		Phase.RELIEF: return "RELIEF"
	return "UNKNOWN"
