extends Node
## 全局游戏管理器 - 管理游戏状态、关卡流程、存档
## 负责控制游戏状态机、楼层切换、角色生死、事件标记等核心功能

enum GameState { MENU, PLAYING, PAUSED, CUTSCENE, DIALOGUE, GAME_OVER }
enum Floor { PROLOGUE, STREET, FLOOR_1, FLOOR_2, FLOOR_3, ENDING }

# ====== 角色名称（改名请只修改这里）======
const NAMES := {
	"": "",
	"sister": "夏桐",
	"younger_sister": "夏澈",
	"cool_npc": "林佳语",
	"cheerful_npc": "鹿可",
	"male_npc": "周锐",
	"female_npc": "沈薇",
	"timid_male": "余凡",
}

# ====== 角色颜色（有美术素材前的占位色块）======
const CHAR_COLORS := {
	"sister": Color(0.9, 0.7, 0.8),
	"cool_npc": Color(0.5, 0.6, 0.9),
	"cheerful_npc": Color(0.9, 0.8, 0.3),
	"male_npc": Color(0.4, 0.7, 0.5),
	"female_npc": Color(0.9, 0.4, 0.5),
	"timid_male": Color(0.6, 0.6, 0.4),
	"humanoid_monster": Color(0.2, 0.0, 0.1),
}

# ====== 美术素材路径（有素材时填入路径，自动替换色块）======
# 例: "sister": "res://art/characters/sister.png"
const SPRITE_PATHS := {
	"sister": "",
	"cool_npc": "",
	"cheerful_npc": "",
	"male_npc": "",
	"female_npc": "",
	"timid_male": "",
	"humanoid_monster": "res://assets/sprites/monsters/shadow_monster.png",
}

const PLAYER_VISUAL_HEIGHT: float = 72.0
const NPC_VISUAL_HEIGHT: float = 66.0
const MONSTER_VISUAL_HEIGHT: float = 108.0

const PLAYER_COLLISION_SIZE: Vector2 = Vector2(28, 20)
const PLAYER_COLLISION_OFFSET: Vector2 = Vector2(0, -10)
const NPC_COLLISION_SIZE: Vector2 = Vector2(28, 20)
const NPC_COLLISION_OFFSET: Vector2 = Vector2(0, -10)
const MONSTER_COLLISION_SIZE: Vector2 = Vector2(36, 28)
const MONSTER_COLLISION_OFFSET: Vector2 = Vector2(0, -14)

signal game_state_changed(new_state: GameState)
signal floor_changed(new_floor: Floor)
signal character_died(character_name: String)
signal soul_swapped(from: String, to: String)
signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String)

## 待丢失的物品列表
var pending_item_loss: Array[String] = []

## 当前游戏状态
var current_state: GameState = GameState.MENU
## 当前楼层
var current_floor: Floor = Floor.PROLOGUE
## 是否处于灵魂交换状态
var is_soul_swapped: bool = false
## 灵魂交换目标角色
var soul_swap_target: String = ""
## 死亡原因（insanity/abyss/chase_caught/monster）
var death_cause: String = "insanity"

## 存活角色追踪
var alive_characters: Dictionary = {
	"sister": true,       # 夏桐（玩家）
	"cool_npc": true,     # 林佳语
	"cheerful_npc": true, # 鹿可
	"male_npc": true,     # 周锐
	"female_npc": true,   # 沈薇
	"timid_male": true,   # 余凡
}

## 已发现的规则
var discovered_rules: Array[String] = []

## 事件标记
var event_flags: Dictionary = {}

## 楼层入口道具快照（用于死亡重开时回溯）
var _floor_entry_inventory: Array[String] = []
var _floor_entry_item_counts: Dictionary = {}

## 保存楼层入口时的背包快照。
func save_floor_entry_inventory() -> void:
	_floor_entry_inventory = InventoryManager.inventory.duplicate()
	_floor_entry_item_counts = InventoryManager.item_counts.duplicate()

## 恢复楼层入口时的背包快照。
func restore_floor_entry_inventory() -> void:
	InventoryManager.inventory = _floor_entry_inventory.duplicate()
	InventoryManager.item_counts = _floor_entry_item_counts.duplicate()
	InventoryManager.inventory_changed.emit()

## 初始化管理器：保证暂停状态下仍能处理游戏流程。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 设置游戏状态。
## [param new_state] 新的游戏状态。
func set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

## 切换楼层。
## [param new_floor] 新的楼层。
func change_floor(new_floor: Floor) -> void:
	current_floor = new_floor
	floor_changed.emit(new_floor)

## 杀死角色。
## [param char_name] 角色ID。
func kill_character(char_name: String) -> void:
	if alive_characters.has(char_name):
		alive_characters[char_name] = false
		character_died.emit(char_name)

## 检查角色是否存活。
## [param char_name] 角色ID。
## [return] 是否存活。
func is_character_alive(char_name: String) -> bool:
	return alive_characters.get(char_name, false)

## 添加规则。
## [param rule_text] 规则文本。
func add_rule(rule_text: String) -> void:
	if rule_text not in discovered_rules:
		discovered_rules.append(rule_text)

## 设置事件标记。
## [param flag_name] 标记名称。
## [param value] 标记值。
func set_flag(flag_name: String, value: Variant = true) -> void:
	event_flags[flag_name] = value

## 获取事件标记。
## [param flag_name] 标记名称。
## [param default] 默认值。
## [return] 标记值。
func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return event_flags.get(flag_name, default)

## 开始新游戏。
func start_new_game() -> void:
	_reset_all_state()
	game_state_changed.emit(GameState.PLAYING)
	get_tree().change_scene_to_file("res://scenes/levels/prologue_room.tscn")

## 重置所有状态。
func _reset_all_state() -> void:
	current_state = GameState.PLAYING
	current_floor = Floor.PROLOGUE
	is_soul_swapped = false
	soul_swap_target = ""
	alive_characters = {
		"sister": true,
		"cool_npc": true,
		"cheerful_npc": true,
		"male_npc": true,
		"female_npc": true,
		"timid_male": true,
	}
	discovered_rules.clear()
	event_flags.clear()
	pending_item_loss.clear()
	InventoryManager.clear()
	PlayerStats.reset()
	TimeSystem.reset()

## 触发灵魂交换。
## [param target] 目标角色ID。
func trigger_soul_swap(target: String) -> void:
	is_soul_swapped = true
	soul_swap_target = target
	soul_swapped.emit("sister", target)

## 结束灵魂交换。
func end_soul_swap() -> void:
	var old_target = soul_swap_target
	is_soul_swapped = false
	soul_swap_target = ""
	soul_swapped.emit(old_target, "sister")

## 获取存活角色数量。
## [return] 存活角色数量。
func get_alive_count() -> int:
	var count := 0
	for alive in alive_characters.values():
		if alive:
			count += 1
	return count

## 进入游戏结束界面。
## [param cause] 死亡原因。
func go_to_game_over(cause: String = "insanity") -> void:
	set_state(GameState.GAME_OVER)
	death_cause = cause
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

## 重新开始当前楼层（Game Over后使用）。
func restart_current_floor() -> void:
	var scene_path := _get_floor_scene_path(current_floor)
	if scene_path == "":
		start_new_game()
		return

	# 根据楼层重置角色存活状态
	_reset_state_for_floor(current_floor)
	set_state(GameState.PLAYING)
	get_tree().change_scene_to_file(scene_path)

## 获取楼层对应的场景路径。
## [param floor_id] 楼层ID。
## [return] 场景路径。
func _get_floor_scene_path(floor_id: Floor) -> String:
	match floor_id:
		Floor.PROLOGUE: return "res://scenes/levels/prologue_room.tscn"
		Floor.STREET: return "res://scenes/levels/prologue_street.tscn"
		Floor.FLOOR_1: return "res://scenes/levels/floor_1.tscn"
		Floor.FLOOR_2: return "res://scenes/levels/floor_2.tscn"
		Floor.FLOOR_3: return "res://scenes/levels/floor_3.tscn"
		_: return ""

## 重置楼层状态。
## [param floor_id] 楼层ID。
func _reset_state_for_floor(floor_id: Floor) -> void:
	# 清理当前状态
	is_soul_swapped = false
	soul_swap_target = ""
	pending_item_loss.clear()
	PlayerStats.reset()
	AudioManager.stop_all()
	
	# 根据楼层设置正确的角色存活状态
	match floor_id:
		Floor.FLOOR_1:
			alive_characters = {
				"sister": true, "cool_npc": true, "cheerful_npc": true,
				"male_npc": true, "female_npc": true, "timid_male": true,
			}
		Floor.FLOOR_2:
			alive_characters = {
				"sister": true, "cool_npc": true, "cheerful_npc": true,
				"male_npc": true, "female_npc": true, "timid_male": true,
			}
		Floor.FLOOR_3:
			GameManager.restore_floor_entry_inventory()
			alive_characters = {
				"sister": true, "cool_npc": true, "cheerful_npc": true,
				"male_npc": true, "female_npc": false, "timid_male": false,
			}

# ====== 对话快捷方法（自动通过ID查找显示名称）======
## 构造一条对话台词数据。
## [param who] 说话人角色ID（自动映射为显示名称）。
## [param text] 台词内容。
## [param emotion] 情绪标记（可选）。
## [return] 包含 speaker/text/emotion 的台词字典。
func say(who: String, text: String, emotion: String = "") -> Dictionary:
	return {"speaker": NAMES.get(who, who), "text": text, "emotion": emotion}

# ====== 美术素材加载（有素材用素材，没素材用色块）======
## 获取角色贴图路径：优先 GameConfig 配置，其次本文件 SPRITE_PATHS。
## [param char_id] 角色ID。
## [return] 贴图资源路径，未配置时为空字符串。
static func get_character_sprite_path(char_id: String) -> String:
	var config_path = GameConfig.CHARACTER_SPRITES.get(char_id, "")
	if config_path != "":
		return config_path
	return SPRITE_PATHS.get(char_id, "")

## 获取角色帧序列目录（manifest.json 所在目录）。
## [param char_id] 角色ID。
## [return] 帧目录路径，未配置时为空字符串。
static func get_character_frames_root(char_id: String) -> String:
	var sprite_path = get_character_sprite_path(char_id)
	if sprite_path == "":
		return ""
	var sprite_dir = sprite_path.get_base_dir()
	if sprite_dir.get_file() == "idle":
		return sprite_dir.get_base_dir()
	return sprite_dir

## 获取角色帧序列目录的绝对路径。
## [param char_id] 角色ID。
## [return] 绝对路径，未配置时为空字符串。
static func get_character_frames_root_absolute(char_id: String) -> String:
	var frames_root = get_character_frames_root(char_id)
	if frames_root == "":
		return ""
	return ProjectSettings.globalize_path(frames_root)

# 纹理缓存（避免重复加载同一角色纹理）
static var _texture_cache: Dictionary = {}

## 加载角色纹理（带缓存）：有素材用素材，否则生成占位色块。
## [param char_id] 角色ID。
## [param width] 占位色块宽度（像素）。
## [param height] 占位色块高度（像素）。
## [return] 角色纹理。
static func load_char_texture(char_id: String, width: int, height: int) -> Texture2D:
	# 检查缓存
	if _texture_cache.has(char_id):
		return _texture_cache[char_id]
	var path = get_character_sprite_path(char_id)
	var texture: Texture2D
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	else:
		var color = CHAR_COLORS.get(char_id, Color(0.5, 0.5, 0.5))
		var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
		img.fill(color)
		texture = ImageTexture.create_from_image(img)
	_texture_cache[char_id] = texture
	return texture

## 获取角色的视觉高度。
## [param char_id] 角色ID。
## [return] 视觉高度（像素）。
static func get_character_visual_height(char_id: String) -> float:
	match char_id:
		"sister":
			return PLAYER_VISUAL_HEIGHT
		"humanoid_monster":
			return MONSTER_VISUAL_HEIGHT
		_:
			return NPC_VISUAL_HEIGHT

## 将角色 Sprite 缩放并定位到该角色的标准视觉高度。
## [param sprite] 目标 Sprite2D。
## [param char_id] 角色ID。
static func fit_character_sprite(sprite: Sprite2D, char_id: String) -> void:
	if sprite == null or sprite.texture == null:
		return
	var texture_size = sprite.texture.get_size()
	if texture_size.y <= 0.0:
		return
	var target_height = get_character_visual_height(char_id)
	var scale_factor = target_height / texture_size.y
	sprite.centered = true
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0.0, -target_height * 0.5)

## 按角色类型设置碰撞形状的尺寸与偏移。
## [param collision] 目标 CollisionShape2D（矩形）。
## [param char_id] 角色ID。
static func fit_character_collision(collision: CollisionShape2D, char_id: String) -> void:
	if collision == null:
		return
	var rect = collision.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		collision.shape = rect
	match char_id:
		"sister":
			rect.size = PLAYER_COLLISION_SIZE
			collision.position = PLAYER_COLLISION_OFFSET
		"humanoid_monster":
			rect.size = MONSTER_COLLISION_SIZE
			collision.position = MONSTER_COLLISION_OFFSET
		_:
			rect.size = NPC_COLLISION_SIZE
			collision.position = NPC_COLLISION_OFFSET

## 创建角色脚下动态投影节点并完成初始化。
## [param char_id] 角色ID。
## [return] 投影节点实例。
static func create_character_shadow_occluder(char_id: String) -> Node2D:
	var shadow = load("res://scripts/effects/character_shadow.gd").new()
	if shadow.has_method("setup"):
		shadow.setup(char_id)
	return shadow
