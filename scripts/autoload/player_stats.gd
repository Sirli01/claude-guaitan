extends Node
## 玩家状态系统 - 体力值（Stamina）+ 理智值（Sanity）+ 黑暗理智流失
## 用法:
##   PlayerStats.change_stamina(-20)       # 减体力
##   PlayerStats.reduce_sanity(30)         # 扣理智（怪物攻击/惊吓事件调用）

signal stamina_changed(current: float, max_val: float)
signal sanity_changed(current: float, max_val: float)
signal exhaustion_started  # 体力归零 → 脱力
signal exhaustion_ended    # 体力恢复到30% → 脱力解除
signal panic_mode_changed(is_panic: bool)  # 理智<50% 恐慌模式切换
signal game_over_insanity  # 理智归零 → 精神崩溃死亡

# ====== 体力值（Stamina）======
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_enabled: bool = false  # 默认关闭，关卡脚本里开启

# 体力消耗/恢复速率
const STAMINA_WALK_DRAIN: float = 0.5    # 走路每秒消耗
const STAMINA_RUN_DRAIN: float = 5.0     # 跑步每秒消耗
const STAMINA_IDLE_RECOVER: float = 2.0  # 基础站立每秒恢复
const STAMINA_RECOVER_BOOST: float = 3.0 # 低体力时额外加速恢复（体力越低恢复越快）
const EXHAUSTION_THRESHOLD: float = 0.5  # 脱力恢复阈值（50%）

var is_exhausted: bool = false  # 脱力状态
var saved_flashlight_battery: float = 100.0  # 跨场景持久化电池电量
var _player_moving: bool = false
var _player_running: bool = false

# ====== 理智值（Sanity）======
var sanity: float = 100.0
var max_sanity: float = 100.0
var is_panic: bool = false  # 恐慌状态（理智<50%）
const PANIC_THRESHOLD: float = 0.5       # 恐慌阈值（50%）
const PANIC_STAMINA_MULTIPLIER: float = 1.5  # 恐慌时体力消耗倍率

# ====== 黑暗理智流失 ======
var darkness_environment: bool = false  # 是否处于黑暗环境（由关卡脚本设置）
var has_strong_light: bool = false       # 是否持有强光源（由 PlayerLighting 更新）
var in_light_area: bool = false          # 是否处于灯光区域（由 LevelBase 更新）
const DARKNESS_SANITY_DRAIN: float = 1.5  # 黑暗中仅手机光时每秒理智流失
const LIGHT_SANITY_RECOVER: float = 0.8  # 有强光源或处于灯光区域时每秒理智恢复

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# 对话/过场/非游戏状态时不消耗
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if stamina_enabled:
		_process_stamina(delta)
	# 黑暗环境中无强光照明且不在灯光区域时持续流失理智
	if darkness_environment and not has_strong_light and not in_light_area:
		reduce_sanity(DARKNESS_SANITY_DRAIN * delta)
	# 有强光源或处于灯光区域时缓慢恢复理智
	elif (has_strong_light or in_light_area) and sanity < max_sanity:
		restore_sanity(LIGHT_SANITY_RECOVER * delta)

# ====== 体力值（Stamina）======

func _process_stamina(delta: float) -> void:
	var drain := 0.0
	var panic_mult := PANIC_STAMINA_MULTIPLIER if is_panic else 1.0

	if _player_running:
		drain = STAMINA_RUN_DRAIN * panic_mult
	elif _player_moving:
		drain = STAMINA_WALK_DRAIN * panic_mult
	else:
		# 站立恢复（低体力时恢复更快，避免脱力后节奏断裂）
		var pct = stamina / max_stamina if max_stamina > 0 else 1.0
		var boost = STAMINA_RECOVER_BOOST * (1.0 - pct)  # 体力越低boost越大
		change_stamina((STAMINA_IDLE_RECOVER + boost) * delta)
		return

	change_stamina(-drain * delta)

func change_stamina(amount: float) -> void:
	var old = stamina
	stamina = clampf(stamina + amount, 0.0, max_stamina)
	if stamina != old:
		stamina_changed.emit(stamina, max_stamina)
	# 脱力判定
	if stamina <= 0 and not is_exhausted:
		is_exhausted = true
		exhaustion_started.emit()
	elif is_exhausted and stamina >= max_stamina * EXHAUSTION_THRESHOLD:
		is_exhausted = false
		exhaustion_ended.emit()

func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	stamina_changed.emit(stamina, max_stamina)
	# 设置体力后同步清除脱力状态
	if is_exhausted and stamina >= max_stamina * EXHAUSTION_THRESHOLD:
		is_exhausted = false
		exhaustion_ended.emit()

func get_stamina_percent() -> float:
	return stamina / max_stamina if max_stamina > 0 else 0.0

## 由 Player.gd 每帧调用，更新移动状态
func update_movement_state(moving: bool, running: bool) -> void:
	_player_moving = moving
	_player_running = running

# ====== 理智值（Sanity）======

func reduce_sanity(amount: float) -> void:
	## 扣除理智（供怪物攻击、惊吓事件调用）
	var old = sanity
	sanity = clampf(sanity - amount, 0.0, max_sanity)
	if sanity != old:
		sanity_changed.emit(sanity, max_sanity)
	_check_panic_state()
	if sanity <= 0 and old > 0:
		game_over_insanity.emit()

func restore_sanity(amount: float) -> void:
	## 恢复理智（安全道具、特定事件）
	var old = sanity
	sanity = clampf(sanity + amount, 0.0, max_sanity)
	if sanity != old:
		sanity_changed.emit(sanity, max_sanity)
	_check_panic_state()

func set_sanity(value: float) -> void:
	sanity = clampf(value, 0.0, max_sanity)
	sanity_changed.emit(sanity, max_sanity)
	_check_panic_state()

func get_sanity_percent() -> float:
	return sanity / max_sanity if max_sanity > 0 else 0.0

func _check_panic_state() -> void:
	var should_panic = get_sanity_percent() < PANIC_THRESHOLD
	if should_panic != is_panic:
		is_panic = should_panic
		panic_mode_changed.emit(is_panic)



# ====== 物品效果处理（由 InventoryManager 调用）======

func apply_item_effects(effects: Array) -> void:
	## 处理物品的效果列表
	## 效果格式: {"type": "stamina|sanity", "value": 数值}
	for effect in effects:
		var type: String = effect.get("type", "")
		var value: float = effect.get("value", 0.0)
		match type:
			"stamina":
				change_stamina(value)
			"sanity":
				if value > 0:
					restore_sanity(value)
				else:
					reduce_sanity(-value)

# ====== 重置 ======

func reset() -> void:
	stamina = max_stamina
	sanity = max_sanity
	stamina_enabled = false
	is_exhausted = false
	is_panic = false
	_player_moving = false
	_player_running = false
	darkness_environment = false
	has_strong_light = false
	in_light_area = false
	saved_flashlight_battery = 100.0
	stamina_changed.emit(stamina, max_stamina)
	sanity_changed.emit(sanity, max_sanity)
