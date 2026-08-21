# 《失序者的生存守则》Godot 项目优化执行方案

> **使用说明**：将本文件完整复制给 AI agent，按阶段顺序执行。每个阶段结束后必须在 Godot 编辑器中运行游戏验证功能不回退。
>
> **项目路径**：`c:\Users\25450\Desktop\claude guaitan`
> **引擎**：Godot 4.6 (GL Compatibility)
> **语言**：GDScript
> **主场景**：`res://scenes/main_menu.tscn`
> **Autoload列表**：见 `project.godot` 的 `[autoload]` 段（共16个全局单例：LocaleManager, GameManager, Director, TimeSystem, DialogueManager, AudioManager, InventoryManager, TransitionManager, SaveManager, PlayerStats, ScreenEffects, InputDevice, PauseMenu, TouchControls, DevConsole, UIScaleManager）

---

## 项目背景

这是一个2D俯视角恐怖生存游戏。玩家在不同楼层探索，遵守规则（如"禁止跑步"），与NPC互动，解谜。共3层楼+序章+结局。项目有70个GDScript文件，总代码量约10000行。

## 必须遵守的编码规范（来自 CLAUDE.md）

1. **禁止动态生成UI节点** — 所有UI节点必须在 `.tscn` 场景文件中搭建，脚本只用 `@onready` 引用。例外：`Node.instantiate()` 加载已有 `.tscn` 文件。
2. **禁止在脚本中编码UI属性** — 不写 `add_theme_font_size_override` / `add_theme_color_override` / `add_theme_stylebox_override`，所有样式通过 Theme 资源控制。
3. **禁止兜底代码** — 不写 `else: pass` 或 `match _: return "unknown"` 等掩盖错误的兜底分支。
4. **函数必须加注释** — 每个函数必须有 `##` 文档注释，说明做什么、参数、返回值。
5. **变量命名** — snake_case 函数/变量，PascalCase 类名，所有变量和函数加类型注解。

---

# 阶段一：完成 LevelBase v1→v2 迁移（P0，最重要）

## 1.1 问题说明

存在两套关卡基类：
- `scripts/levels/level_base.gd`（v1，1556行，`class_name LevelBase`，`@tool`，`extends Node2D`） — 所有楼层场景实际继承的类
- `scripts/levels/level_base_v2.gd`（v2，306行，`class_name LevelBaseV2`，`@tool`，`extends Node2D`） — 半成品，仅实现了部分方法

所有5个楼层脚本都继承 v1：
- `scripts/levels/floor_1_scene.gd` → `extends LevelBase`
- `scripts/levels/floor_2_scene.gd` → `extends LevelBase`
- `scripts/levels/floor_3_scene.gd` → `extends LevelBase`
- `scripts/levels/prologue_room_scene.gd` → `extends LevelBase`
- `scripts/levels/prologue_street_scene.gd` → `extends LevelBase`

## 1.2 v2 已有的方法（306行）

v2 当前实现了：`_ready()`, `_process()`, `_exit_tree()`, `setup_player()`, `setup_ui()`, `_auto_play_audio()`, `_apply_label_filter()`, `fix_label_filter()`(static), `_init_world_label_ui()`, `set_world_labels_visible()`, `_update_world_labels()`(空pass), `_on_locale_changed_status()`, `show_rule_paper_and_wait()`, `add_elevator_door_visual()`, `add_elevator_door_blocker()`, `_build_arrival_elevator()`, `create_world_label()`

v2 使用 `@onready` 引用场景节点：
- `@onready var game_world: Node2D = $GameWorld`
- `@onready var depth_sort_layer: Node2D = $GameWorld/DepthSortLayer`
- `@onready var y_sort_layer: Node2D = $GameWorld/YSortLayer`
- `@onready var world_label_container: Control = $UILayers/WorldLabelUI/WorldLabelContainer`
- `@onready var hud_layer: CanvasLayer = $UILayers/HUDLayer`
- `@onready var dialogue_layer: CanvasLayer = $UILayers/DialogueLayer`
- `@onready var inventory_layer: CanvasLayer = $UILayers/InventoryLayer`
- `@onready var rule_paper_layer: CanvasLayer = $UILayers/RulePaperLayer`
- `@onready var atmosphere_layer: CanvasLayer = $EffectsLayers/AtmosphereLayer`
- `@onready var darkness_layer: CanvasLayer = $EffectsLayers/DarknessLayer`
- `@onready var touch_controls_layer: CanvasLayer = $UILayers/TouchControlsLayer`

## 1.3 v2 缺失的方法清单（必须从 v1 复制）

以下按 v1 (`level_base.gd`) 中的行号列出，共26组方法：

### 第1组：世界标签系统（v1 L295-350）
- `_world_label_scale_multiplier()` (L295-296)
- `create_tracked_world_label()` (L312-322) — 创建跟随节点移动的标签
- `_update_world_labels()` (L325-350) — v2 中是空 `pass`，需替换为完整实现

### 第2组：提示和音效（v1 L362-408）
- `play_sfx()` (L362-366)
- `show_hint()` (L368-395) — 显示浮动提示文字
- `_remove_hint()` (L397-408)

### 第3组：黑暗和灯光系统（v1 L410-602）
- `enable_darkness()` / `disable_darkness()` (L410-420)
- `add_room_light()` (L422-435) — 暖色房间灯
- `add_corridor_light()` (L437-450) — 冷白走廊灯
- `add_flickering_light()` (L452-467) — 闪烁灯
- `add_broken_light()` (L469-488) — 损坏灯
- `_add_light_detection_area()` (L490-508) — 灯光区域检测
- `_make_circle_light_texture()` (L510-520) — 圆形灯光纹理缓存

### 第4组：体力系统（v1 L522-526）
- `enable_stamina()` — 快捷启用体力系统

### 第5组：环境效果（v1 L528-602）
- `add_dust_ambient()` (L528-567) — 环境灰尘粒子
- `add_door_light_leak()` (L569-602) — 门缝漏光

### 第6组：地板和墙壁系统（v1 L604-893）
- `add_floor_zone()` (L604-625)
- `add_wall()` (L627-634)
- `add_visible_wall()` (L636-683) — 复杂的带正面/侧面的墙壁
- `_make_wall_rect()` (L685-692)
- `_ensure_depth_sort_layer()` (L694-702) — v2中改为直接返回 `depth_sort_layer`
- `_resolve_standard_furniture_kind()` (L704-715)
- `_add_textured_furniture_visual()` (L717-725)
- `_add_textured_furniture_body()` (L727-739)
- `add_standard_furniture()` (L741-798) — 标准家具（床/桌/沙发/柜/椅）
- `_add_furniture()` (L800-810)
- `create_elevator_card_pickup()` (L812-859)
- `_add_horizontal_wall_face()` (L861-862)
- `_add_horizontal_wall_face_dir()` (L864-875)
- `_add_vertical_wall_face()` (L877-878)
- `_add_vertical_wall_face_dir()` (L880-889)

### 第7组：NPC和交互（v1 L891-1092）
- `create_npc_visual()` (L891-932) — 创建NPC视觉
- `set_npc_story_dialogue()` (L934-936)
- `create_trigger_area()` (L938-951)
- `add_door()` (L957-1092) — 完整门系统（碰撞、视觉、交互、锁）

### 第8组：房间天花板系统（v1 L1098-1212）
- `add_room_ceiling()` (L1098-1130)
- `_ensure_masks_ready()` (L1132-1155)
- `_enter_room()` (L1157-1168)
- `_exit_room()` (L1170-1179)
- `_show_outside_mask()` (L1181-1204)
- `_hide_outside_mask()` (L1206-1212)

### 第9组：其他（v1 L1214-1556）
- `_make_light_texture()` (L1214-1215)
- `_setup_status_hud()` (L1219-1380) — 体力条/理智条/电池条HUD（注意：大量动态创建UI，暂保留功能）
- `_on_locale_changed_status()` (L1382-1390) — v2已有简单版，需扩展
- `_refresh_status_icons()` (L1392-1396)
- `setup_navigation()` (L1400-1422) — 导航网格烘焙
- `has_scene_visual_nodes()` (L1427-1437)
- `discover_scene_nodes()` (L1441-1487) — 发现编辑器放置的节点
- `_setup_furniture_interaction()` (L1489-1518)
- `_register_ceiling()` (L1521-1555)

## 1.4 迁移时的适配规则

将 v1 方法复制到 v2 时，做以下适配：

1. **`add_child(node)` 的目标**：
   - 游戏世界对象（墙、地板、家具、灯光、粒子、电梯门）→ `game_world.add_child(node)`
   - 深度排序对象（玩家、NPC、怪物）→ `depth_sort_layer.add_child(node)`
   - HUD元素 → `hud_layer.add_child(node)`

2. **`_ensure_depth_sort_layer()`** → v2 中已有 `@onready var depth_sort_layer`，方法改为直接返回它：
   ```gdscript
   func _ensure_depth_sort_layer() -> Node2D:
       return depth_sort_layer
   ```

3. **`_depth_sort_layer` 变量** → 全部替换为 `depth_sort_layer`（去掉下划线前缀，因为v2用@onready）

4. **`_world_label_container` 变量** → v2 中叫 `world_label_container`（@onready）

5. **v2 已有的 `_update_world_labels()` 空实现** → 替换为 v1 L325-350 的完整实现

6. **v2 已有的 `create_world_label()`** → 补充 v1 中的 `_world_label_scale_multiplier()` 调用

## 1.5 执行步骤

### 步骤 1：补全 level_base_v2.gd
将 1.3 节列出的所有方法从 v1 复制到 v2，按 1.4 节的适配规则修改。

### 步骤 2：修改5个楼层脚本的继承
将 `extends LevelBase` 改为 `extends LevelBaseV2`：
- `scripts/levels/floor_1_scene.gd` 第2行
- `scripts/levels/floor_2_scene.gd` 第2行
- `scripts/levels/floor_3_scene.gd` 第2行
- `scripts/levels/prologue_room_scene.gd` 的 extends 行
- `scripts/levels/prologue_street_scene.gd` 的 extends 行

### 步骤 3：删除 v1
删除 `scripts/levels/level_base.gd` 和 `scripts/levels/level_base.gd.uid`。

### 步骤 4：验证
运行游戏，依次进入每个楼层，验证：
- 玩家移动、灯光、NPC、门系统、房间天花板遮罩、导航网格、HUD、对话系统全部正常

---

# 阶段二：拆分 floor_3_scene.gd（P0）

## 2.1 问题说明

`scripts/levels/floor_3_scene.gd`（1785行）混合了6大职责：关卡布局、怪物AI、追逐战、灵魂交换、事件流程、视觉效果生成。

## 2.2 拆分方案

### 2.2.1 创建 `shaders/shadow_distortion.gdshader`

将 floor_3_scene.gd 第57-78行的内联shader字符串提取为独立文件：

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform float sway_strength = 0.028;
uniform float ripple_strength = 0.014;
uniform float vertical_wobble = 0.010;

void fragment() {
    vec2 uv = UV;
    float t = TIME * 2.7;
    uv.x += sin(uv.y * 11.0 + t * 2.4) * sway_strength;
    uv.x += sin(uv.y * 25.0 - t * 3.2) * ripple_strength;
    uv.y += sin(uv.x * 17.0 + t * 1.8) * vertical_wobble;
    vec4 col = texture(TEXTURE, uv) * COLOR;
    if (col.a < 0.02) {
        discard;
    }
    col.a *= 0.92 + 0.08 * sin(t * 1.4 + uv.y * 22.0);
    COLOR = col;
}
```

floor_3_scene.gd 中改为：
```gdscript
const SHADOW_DISTORTION_SHADER := preload("res://shaders/shadow_distortion.gdshader")
```

`_apply_shadow_distortion()` 方法改为使用预加载的shader而非 `Shader.new()` + 字符串。

### 2.2.2 创建 `scripts/monsters/humanoid_monster_ai.gd`

```gdscript
extends Node
class_name HumanoidMonsterAI
```

提取的变量（从 floor_3_scene.gd）：
- `monster_speed`, `monster_active`, `_monster_nav_agent`
- `_monster_stuck_timer`, `_monster_steer_dir`, `_monster_steer_timer`
- `_monster_step_sfx`, `_monster_step_timer`
- `_monster_wander_target`, `_monster_wander_timer`
- 常量 `MONSTER_STUCK_THRESHOLD`, `MONSTER_STEER_DURATION`

提取的方法：
- `_build_monster()` (L278-340) — 改名为 `build_monster(parent: Node2D, depth_sort_layer: Node2D)`
- 怪物AI更新逻辑 — 从 `_physics_process()` L429-528 提取为 `update(delta: float, player: CharacterBody2D, current_room_id: String, atmosphere: AtmosphereLayer)`

暴露的信号：
- `signal monster_hit_player(knockback: Vector2, sanity_damage: float)`
- `signal monster_seen()` — 用于触发发现剧情

### 2.2.3 创建 `scripts/monsters/abyss_mouth.gd`

```gdscript
extends Node
class_name AbyssMouthSystem
```

提取的变量：
- `chase_mouth`, `chase_mouth_speed`, `chase_timer`, `chase_duration`, `chase_active`
- `chase_obstacles`, `_waiting_for_shift`, `chase_countdown_label`
- `_mouth_bite_sfx`, `_mouth_move_sfx`, `_mouth_move_timer`
- 常量 `MOUTH_MOVE_INTERVAL`, `ABYSS_MOUTH_TEX_PATH`

提取的方法：
- `_spawn_chase_mouth()` (L1178-1276)
- `_create_chase_hud()` (L1278-1304)
- `_update_chase_hud()` (L1306-1313)
- `_remove_chase_hud()` (L1315-1320)
- `_create_abyss_mouth_visual()` (L752-831)
- `_create_light_texture()` (L1511-1521)
- 追逐逻辑 — 从 `_physics_process()` L531-582 提取为 `update(delta: float, player: CharacterBody2D)`

### 2.2.4 创建 `scripts/levels/soul_swap_system.gd`

```gdscript
extends Node
class_name SoulSwapSystem
```

提取的方法：
- `_trigger_soul_swap_cutscene()` (L1015-1029)
- `_soul_swap_with_rope()` (L1031-1046)
- `_perform_soul_swap()` (L1048-1073)
- `_enter_monster_body()` (L1076-1116)
- `_monster_run_sequence()` (L1118-1134)
- `_chase_survive()` (L1335-1409) — 灵魂回归
- `_chase_caught()` (L1323-1332) — 追逐失败

### 2.2.5 floor_3_scene.gd 重构后结构

重构后约400-500行，仅保留：
- `Phase` 枚举和状态变量
- `_ready()` — 初始化各子系统组件
- `_build_floor()` — 关卡布局（L164-243）
- `_place_lights()` — 灯光放置（L833-848）
- `_build_corridor_obstacles()` — 走廊障碍（L1136-1176）
- `_spawn_npcs()` — NPC生成（L245-253）
- `_build_elevator()` — 电梯构建（L347-399）
- `_place_exploration_items()` — 探索物品（L851-876）
- 事件流程方法 — 调用子系统组件
- 物品放置辅助方法（`_place_container`, `_place_search_prop`, `_place_room_item`, `_spawn_dropped_key`）
- `_physics_process()` — 简化为调用各子系统的 `update()` 方法

## 2.3 验证

运行第三层完整流程：
- 电梯入场 → NPC跟随 → 看到怪物 → 男伴恐慌被吃 → 规则出现
- 探索 → 拿到电梯卡（有绳子走换魂路线，无绳子走逃跑路线）
- 换魂路线：灵魂交换 → 控制怪物跑步 → 追逐战20秒 → 07:00回归 → 胜利
- 逃跑路线：走到电梯 → 进入电梯
- 跑步死亡：禁止跑步阶段跑步 → 被深渊巨口吞噬
- 读档功能正常

---

# 阶段三：本地化系统重构（P1）

## 3.1 问题说明

`scripts/autoload/locale_manager.gd`（873行）将所有翻译文本硬编码在 GDScript `const` 字典中。主要数据结构：
- `const _UI` — UI字符串字典
- `const _KEY_BINDINGS` — 按键说明数组
- `const _GAMEPLAY_TIPS` — 游戏提示数组
- `const _ITEMS` — 道具名/描述
- `const _DEATH_INFO` (L790-814) — 死亡界面信息
- `const _PHONE_CHAT` (L819-872) — 手机聊天内容
- `const _WORLD_TEXT` — 世界文本

公共API方法（必须保持接口不变）：
- `t(key: String) -> String` — 通用UI字符串
- `key_bindings() -> Array` — 按键说明
- `gameplay_tips() -> Array` — 游戏提示
- `item_locale(item_id: String) -> Dictionary` — 道具本地化
- `death_info(cause: String) -> Dictionary` — 死亡信息
- `phone_chat_locale(chat_id: String) -> Dictionary` — 手机聊天
- `world_text(text: String) -> String` — 世界文本
- `searched_label(name: String) -> String` — 搜索标签
- `container_empty_text(name: String) -> String` — 容器空文本
- `container_found_text(name: String, item_name: String) -> String` — 找到物品文本
- `door_unlocked_text(required_key: String, key_name: String) -> String`
- `door_need_key_text() -> String`
- `pickup_prompt_text() -> String`
- `bench_*_text()` 系列
- `vending_kick_prompt_text()` 等

## 3.2 执行步骤

### 步骤 1：创建 `data/locale/` 目录

### 步骤 2：提取字典为 JSON 文件

创建以下JSON文件（每个包含 zh/en/ja 三种语言）：
- `data/locale/ui_strings.json`
- `data/locale/key_bindings.json`
- `data/locale/gameplay_tips.json`
- `data/locale/items_locale.json`
- `data/locale/death_info.json`
- `data/locale/phone_chat.json`
- `data/locale/world_text.json`

JSON 格式示例：
```json
{
    "zh": { "pause_title": "暂停", "resume": "继续游戏", ... },
    "en": { "pause_title": "Paused", "resume": "Resume", ... },
    "ja": { "pause_title": "一時停止", "resume": "続行", ... }
}
```

### 步骤 3：重写 locale_manager.gd

```gdscript
extends Node
## LocaleManager — 多语言管理器（数据外部化版本）

signal locale_changed(locale: String)
var current_locale: String = "zh"
const SUPPORTED_LOCALES := ["zh", "en", "ja"]

var _ui: Dictionary = {}
var _key_bindings: Dictionary = {}
var _gameplay_tips: Dictionary = {}
var _items: Dictionary = {}
var _death_info: Dictionary = {}
var _phone_chat: Dictionary = {}
var _world_text: Dictionary = {}

func _ready() -> void:
    _load_all_locale_data()
    _load_locale()

func _load_all_locale_data() -> void:
    _ui = _load_json("res://data/locale/ui_strings.json")
    _key_bindings = _load_json("res://data/locale/key_bindings.json")
    # ... 其余同理

func _load_json(path: String) -> Dictionary:
    if not ResourceLoader.exists(path):
        push_error("Locale data not found: " + path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("Cannot open: " + path)
        return {}
    var text := file.get_as_text()
    file.close()
    var result = JSON.parse_string(text)
    return result if result is Dictionary else {}

# 以下方法保持接口不变，只是从内存字典查找而非const字典
func t(key: String) -> String: ...
func key_bindings() -> Array: ...
# ... 其余方法同理
```

### 步骤 4：验证
切换语言（zh/en/ja），验证所有文本正确显示。

---

# 阶段四：违反编码规范修复（P1）

## 4.1 修复动态创建UI节点

### 4.1.1 phone_ui.gd（248行）

当前在 `_add_message_bubble()` 方法（约L204-249）动态创建：`HBoxContainer`, `PanelContainer`, `StyleBoxFlat`, `Label`, `Control`（spacer）。

**修复**：
1. 检查 `scenes/ui/phone_ui.tscn` 是否已有消息气泡模板，如无则创建
2. 创建一个 `scenes/ui/message_bubble.tscn` 预设模板
3. `phone_ui.gd` 改为 `var bubble := preload("res://scenes/ui/message_bubble.tscn").instantiate()` 并设置文本

### 4.1.2 pause_menu.gd（323行）

当前动态创建：`HBoxContainer`(L220), `Label`(L223, L230), `HSeparator`(L250), `VBoxContainer`(L291), `Label`(L295, L308, L318)。

**修复**：
1. 在 `scenes/ui/pause_menu.tscn` 中预设操作说明列表项模板和道具列表项模板
2. 脚本改为实例化模板并填充数据

### 4.1.3 level_base 的 _setup_status_hud()（v1 L1219-1380）

此方法在阶段一迁移到v2后仍在使用。动态创建 `VBoxContainer`, `Label`(3个), `ProgressBar`(3个), `HBoxContainer`, `StyleBoxFlat`(6个)。

**修复**：
1. 在 `scenes/levels/level_base.tscn` 的 `HUDLayer/HUD` 下预设状态条节点
2. v2 脚本改为 `@onready` 引用
3. 信号连接逻辑保留，只去掉节点创建

## 4.2 修复硬编码UI属性

### 迁移到 Theme 资源

**文件**：`assets/ui/horror_theme.tres`（已存在的Theme资源）

需要迁移的 `add_theme_*_override` 调用：
- `phone_ui.gd` — 13处（L77-79, L205-253）
- `pause_menu.gd` — 11处（L211-304）
- `level_base` 的 `show_hint()`, `_setup_status_hud()`, `_add_room_label()`, `create_world_label()` 等

在 Theme 中定义：
- `Label` 的 font_size 变体（通过 `@export_group` 或命名约定）
- `Label` 的 font_color 变体
- `ProgressBar` 的 `background`/`fill` StyleBox（体力绿/理智紫/电池橙，含低值变色）

### 保留例外
`create_world_label(text, world_pos, font_size, color)` 等参数化方法保留运行时设置，添加注释 `## 例外：世界标签需要参数化字体大小和颜色`。

---

# 阶段五：性能优化（P1）

## 5.1 将运行时 load() 改为 preload() 或 const

**具体文件和行号**：

| 文件 | 行号 | 当前代码 | 改为 |
|------|------|---------|------|
| floor_3_scene.gd | L102 | `load("res://assets/audio/sfx/巨嘴吼声.mp3")` | 顶部 `const _SFX_MOUTH_BITE := preload(...)` |
| floor_3_scene.gd | L103 | `load("res://assets/audio/sfx/巨嘴移动.wav")` | 顶部 `const _SFX_MOUTH_MOVE := preload(...)` |
| floor_3_scene.gd | L320 | `load("res://assets/sprites/effects/light_gradient.png")` | 顶部 `const _LIGHT_TEX := preload(...)` |
| floor_3_scene.gd | L1026 | `load("res://assets/audio/bgm/交换灵魂.mp3")` | 顶部 `const _BGM_SOUL_SWAP := preload(...)` |
| elevator_interior_scene.gd | L106 | `load("res://assets/audio/sfx/电梯运行声.wav")` | `preload` |
| elevator_f2_interior_scene.gd | L100, L108 | 同上 | `preload` |
| elevator_f1_interior_scene.gd | L107, L115 | 同上 | `preload` |
| level_base/v2 | L119 | `load("res://scripts/items/player_lighting.gd")` | `preload` 或直接引用类名 |
| level_base/v2 | L80(规则纸条) | `load("res://scenes/ui/rule_paper_ui.tscn")` | `preload` |
| level_base/v2 | L231(背包) | `load("res://scenes/ui/inventory_ui.tscn")` | `preload` |
| level_base/v2 | L235(对话) | `load("res://scenes/ui/dialogue_ui.tscn")` | `preload` |
| level_base/v2 | L250(触屏) | `load("res://scripts/ui/touch_controls.gd")` | `preload` |

## 5.2 _process 优化

### 5.2.1 确保 _update_world_labels() 有空列表提前返回
v1 L326 已有检查 `if _tracked_labels.is_empty(): return`，确保 v2 也有。

### 5.2.2 floor_3 怪物AI导航节流
怪物AI提取到独立组件后，导航路径更新改为 0.1-0.2 秒间隔（使用 Timer），而非每帧调用 `_monster_nav_agent.get_next_path_position()`。

---

# 阶段六：存档系统重构（P2）

## 6.1 问题说明

`scripts/autoload/save_manager.gd`（254行）的 `save_game()` (L56) 和 `load_game()` 直接访问 GameManager/InventoryManager/PlayerStats 的内部变量。

## 6.2 执行步骤

### 步骤 1：为各 Autoload 添加存档接口

在 `game_manager.gd` 添加：
```gdscript
func to_save_data() -> Dictionary:
    return {
        "current_floor": current_floor,
        "is_soul_swapped": is_soul_swapped,
        "soul_swap_target": soul_swap_target,
        "alive_characters": alive_characters.duplicate(),
        "discovered_rules": discovered_rules.duplicate(),
        "event_flags": event_flags.duplicate(),
    }

func from_save_data(data: Dictionary) -> void:
    current_floor = data.get("current_floor", current_floor)
    is_soul_swapped = data.get("is_soul_swapped", false)
    # ... 其余同理
```

在 `inventory_manager.gd` 添加类似方法（序列化 `inventory`, `item_counts`）。

在 `player_stats.gd` 添加类似方法（序列化 `stamina`, `sanity`, `saved_flashlight_battery`, `stamina_enabled`）。

### 步骤 2：重写 save_manager.gd 的 save_game() 和 load_game()

```gdscript
func save_game() -> void:
    var data := {
        "version": 3,
        "scene_path": _get_scene_path(),
        "player_pos_x": _get_player_pos().x,
        "player_pos_y": _get_player_pos().y,
        "GameManager": GameManager.to_save_data(),
        "InventoryManager": InventoryManager.to_save_data(),
        "PlayerStats": PlayerStats.to_save_data(),
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(data)
    file.close()
    game_saved.emit()

func load_game() -> bool:
    if not has_save():
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data := file.get_var()
    file.close()
    data = _migrate_save_data(data)
    is_loading_save = true
    _saved_player_pos = Vector2(data.player_pos_x, data.player_pos_y)
    GameManager.from_save_data(data.GameManager)
    InventoryManager.from_save_data(data.InventoryManager)
    PlayerStats.from_save_data(data.PlayerStats)
    # 切换场景
    get_tree().change_scene_to_file(data.scene_path)
    return true

func _migrate_save_data(data: Dictionary) -> Dictionary:
    var version: int = data.get("version", 1)
    if version < 3:
        data = _migrate_v2_to_v3(data)
    return data
```

### 步骤 3：验证
每层楼存档/读档，验证玩家位置、物品栏、角色存活状态、事件标记全部正确。

---

# 阶段七：其他改进（P3）

## 7.1 音频路径集中管理

在 `data/game_config.gd` 中添加：
```gdscript
const SFX_PATHS := {
    "elevator_running": "res://assets/audio/sfx/电梯运行声.wav",
    "elevator_arrival": "res://assets/audio/sfx/电梯到达声.mp3",
    "mouth_bite": "res://assets/audio/sfx/巨嘴吼声.mp3",
    "mouth_move": "res://assets/audio/sfx/巨嘴移动.wav",
    "blackout": "res://assets/audio/sfx/断电.mp3",
}
const BGM_PATHS := {
    "floor_3_a": "res://assets/audio/bgm/第三层bgm.mp3",
    "floor_3_b": "res://assets/audio/bgm/第三层bgm2.mp3",
    "soul_swap": "res://assets/audio/bgm/交换灵魂.mp3",
}
```

各脚本中硬编码路径改为引用 GameConfig 常量。

## 7.2 备份文件清理

删除 `scripts/editor/script_tools_native_backup.gd` 和 `.uid`（确认无用后）。检查其他 `_backup`/`_old` 文件。

## 7.3 floor_2_scene.gd 拆分（916行）

参考 floor_3 拆分模式，将NPC行为逻辑和谜题事件提取到独立脚本。需先阅读该文件确定拆分点。

## 7.4 prologue_street_scene.gd 拆分（825行）

将街道布局生成和事件逻辑分离。

---

# 执行顺序总结

| 顺序 | 阶段 | 优先级 | 预计工作量 | 依赖 |
|------|------|--------|-----------|------|
| 1 | LevelBase v1→v2 迁移 | P0 | 大 | 无 |
| 2 | floor_3_scene.gd 拆分 | P0 | 大 | 阶段1完成 |
| 3 | 本地化系统重构 | P1 | 中 | 无 |
| 4 | 违反编码规范修复 | P1 | 中 | 阶段1完成（部分） |
| 5 | 性能优化 | P1 | 小 | 阶段1-2完成 |
| 6 | 存档系统重构 | P2 | 中 | 无 |
| 7 | 其他改进 | P3 | 小 | 无 |

## 关键原则

1. 每个阶段完成后必须在 Godot 中运行游戏验证功能不回退
2. 不改变游戏玩法和内容
3. 遵守 CLAUDE.md 编码规范（禁止动态创建UI、禁止硬编码UI属性、禁止兜底代码、函数必须加注释、类型注解）
4. 如果某阶段风险过高可先跳过
5. 每次只做一个阶段，验证通过后再做下一个
6. 所有新文件必须创建对应的 `.uid` 文件（Godot 会自动生成）
7. 删除文件时同时删除对应的 `.uid` 文件