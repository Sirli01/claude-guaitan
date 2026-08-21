# 失序者的生存守则 — AI 开发指南

## Godot Skills（自动加载）

> **规则：实现任何 Godot 系统前，必须先加载对应的 skill。**

### 总入口（必读）
@./.godot_prompter/skills/godot-master/SKILL.md

### 恐怖游戏专项（氛围/张力/AI）
@./.godot_prompter/skills/godot-genre-horror/SKILL.md

### 系统架构
@./.godot_prompter/skills/godot-composition/SKILL.md
@./.godot_prompter/skills/godot-autoload-architecture/SKILL.md
@./.godot_prompter/skills/godot-signal-architecture/SKILL.md

### 具体系统
@./.godot_prompter/skills/godot-scene-management/SKILL.md
@./.godot_prompter/skills/godot-state-machine-advanced/SKILL.md
@./.godot_prompter/skills/godot-dialogue-system/SKILL.md
@./.godot_prompter/skills/godot-inventory-system/SKILL.md
@./.godot_prompter/skills/godot-save-load-systems/SKILL.md

## GodotPrompter Skills

@./.godot_prompter/skills/using-godot-prompter/SKILL.md

## 项目信息

- **引擎**: Godot 4.6 (GL Compatibility)
- **项目名**: 失序者的生存守则
- **语言**: GDScript
- **分辨率**: 1920x1080, canvas_items stretch mode

## Autoload 列表

| 名称 | 路径 |
|------|------|
| LocaleManager | scripts/autoload/locale_manager.gd |
| GameManager | scripts/autoload/game_manager.gd |
| TimeSystem | scripts/autoload/time_system.gd |
| DialogueManager | scripts/autoload/dialogue_manager.gd |
| AudioManager | scripts/autoload/audio_manager.gd |
| InventoryManager | scripts/autoload/inventory_manager.gd |
| TransitionManager | scripts/autoload/transition_manager.gd |
| SaveManager | scripts/autoload/save_manager.gd |
| PlayerStats | scripts/autoload/player_stats.gd |
| ScreenEffects | scripts/autoload/screen_effects.gd |
| Director | scripts/autoload/director.gd |
| InputDevice | scripts/autoload/input_device.gd |
| PauseMenu | scripts/ui/pause_menu.gd |
| TouchControls | scripts/ui/touch_controls.gd |
| DevConsole | scripts/ui/dev_console.gd |

## 目录结构

- `scenes/` — 场景文件
- `scripts/` — 脚本（autoload, gameplay, ui 等）
- `assets/` — 字体、图片等资源
- `data/` — 数据文件
- `tools/` — 工具脚本
- `docs/` — 文档
- `website/` — 网站相关

## 代码规范

- 遵循 Godot GDScript 风格指南：snake_case 函数/变量，PascalCase 类名
- 所有变量和函数加类型注解
- 使用信号解耦系统间通信
- 优先使用组合而非继承（Component 模式）

## ⛔ 禁止事项（严格遵守）

### 1. 禁止动态生成节点

**不要用代码创建 UI 节点或场景节点。** 所有节点必须在 Godot 编辑器的场景树中搭建。

```gdscript
# ❌ 禁止
var button = Button.new()
button.text = "开始游戏"
button.position = Vector2(100, 200)
add_child(button)

# ✅ 正确：在编辑器中拖入 Button 节点，脚本只处理逻辑
@onready var start_button: Button = %StartButton

func _on_start_button_pressed() -> void:
    pass
```

唯一例外：`Node.instantiate()` 用于加载已有的 `.tscn` 场景文件（如弹出窗口、粒子效果），且实例化后必须 `add_child` 到编辑器中预设好的父节点上。

### 2. 禁止在脚本中编码 UI 属性

**不要在 GDScript 里硬编码 UI 外观属性。** 所有 UI 样式必须通过 Theme 资源控制。

```gdscript
# ❌ 禁止
label.add_theme_font_size_override("font_size", 24)
label.add_theme_color_override("font_color", Color.WHITE)
button.add_theme_stylebox_override("normal", style_box)
panel.position = Vector2(50, 100)
panel.size = Vector2(400, 300)

# ✅ 正确：在编辑器中设置 Theme 和布局，脚本只绑定数据
@onready var label: Label = %ItemName
label.text = item.display_name
```

### 3. 禁止兜底代码

**不要写防御性的 `else`/`match` 兜底分支来处理"不应该发生"的情况。** 如果逻辑走到不该走的分支，说明设计有问题，应该暴露错误而非静默吞掉。

```gdscript
# ❌ 禁止
func get_state_name(state: int) -> String:
    match state:
        State.IDLE: return "idle"
        State.RUN: return "run"
        State.JUMP: return "jump"
        _: return "unknown"  # 兜底——掩盖了遗漏的 case

# ✅ 正确：没有兜底，遗漏会立即暴露问题
func get_state_name(state: int) -> String:
    match state:
        State.IDLE: return "idle"
        State.RUN: return "run"
        State.JUMP: return "jump"
    push_error("Unhandled state: %d" % state)
    return ""

# ❌ 禁止
if resource != null:
    process(resource)
else:
    pass  # 什么都不做——隐藏了空引用 bug

# ✅ 正确：断言或报错
assert(resource != null, "Resource must not be null")
process(resource)
```

### 4. 函数必须加注释

**每个函数（包括 lambda）必须有文档注释。** 注释说明：做什么、参数含义、返回值。

```gdscript
# ❌ 禁止
func calc(a: int, b: int, c: bool) -> float:
    if c:
        return float(a * b)
    return float(a + b)

# ✅ 正确
## 根据模式计算伤害值。
## [param damage] 基础伤害。
## [param multiplier] 放大系数。
## [param is_critical] 是否暴击，暴击时使用乘法而非加法。
## [return] 最终伤害值。
func calculate_damage(damage: int, multiplier: float, is_critical: bool) -> float:
    if is_critical:
        return float(damage * multiplier)
    return float(damage + multiplier)
```

短函数（1-3 行、意图明显）可用单行 `##` 注释。复杂逻辑必须逐段注释。

## 实现新功能时

1. 先读取相关 skill（如 `player-controller`, `state-machine`, `inventory-system` 等）
2. 按 skill 中的模式和检查清单实现
3. 实现后用 `godot-code-review` skill 检查代码质量
