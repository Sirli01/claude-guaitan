# 恐怖游戏 MCP 工具文档

本文档描述了为"失序者的生存守则"恐怖游戏专用的 MCP 工具。

## 概述

这些工具提供了对游戏核心系统的 MCP 访问，包括：
- Director 系统（恐怖张力控制）
- GameManager（游戏状态管理）
- 角色管理（生死状态、灵魂交换）
- 事件系统（事件标记、规则发现）
- 物品系统（背包管理）
- 对话系统
- 存档系统
- 音频系统
- 屏幕效果

## Director 系统工具

### get_director_state
获取 Director 系统的当前状态。

**参数**: 无

**返回**:
- `tension`: 当前张力值 (0.0-1.0)
- `phase`: 当前阶段 (CALM, BUILDUP, PEAK, RELIEF)
- `time_in_phase`: 在当前阶段的时间
- `total_peaks`: 总高峰次数
- `time_since_last_peak`: 距上次高峰的时间
- `is_paused`: 是否暂停

**示例**:
```json
{
  "tool": "get_director_state"
}
```

### set_director_tension
强制设置 Director 的张力级别。

**参数**:
- `tension` (必需): 张力值 (0.0-1.0)

**返回**:
- `status`: 操作状态
- `new_tension`: 新的张力值

**示例**:
```json
{
  "tool": "set_director_tension",
  "params": {
    "tension": 0.8
  }
}
```

### trigger_director_peak
强制触发高峰事件。

**参数**: 无

**返回**:
- `status`: 操作状态
- `total_peaks`: 总高峰次数

**示例**:
```json
{
  "tool": "trigger_director_peak"
}
```

### set_director_phase
设置 Director 到特定阶段。

**参数**:
- `phase` (必需): 阶段名称 (CALM, BUILDUP, PEAK, RELIEF)

**返回**:
- `status`: 操作状态
- `new_phase`: 新阶段名称

**示例**:
```json
{
  "tool": "set_director_phase",
  "params": {
    "phase": "PEAK"
  }
}
```

## GameManager 工具

### get_game_state
获取当前游戏状态。

**参数**: 无

**返回**:
- `current_state`: 游戏状态 (MENU, PLAYING, PAUSED, CUTSCENE, DIALOGUE, GAME_OVER)
- `current_floor`: 当前楼层
- `is_soul_swapped`: 是否灵魂交换
- `soul_swap_target`: 灵魂交换目标
- `death_cause`: 死亡原因
- `alive_characters`: 存活角色列表
- `discovered_rules_count`: 已发现规则数量
- `event_flags_count`: 事件标记数量

**示例**:
```json
{
  "tool": "get_game_state"
}
```

### set_game_state
设置游戏状态。

**参数**:
- `state` (必需): 游戏状态 (MENU, PLAYING, PAUSED, CUTSCENE, DIALOGUE, GAME_OVER)

**返回**:
- `status`: 操作状态
- `new_state`: 新状态名称

**示例**:
```json
{
  "tool": "set_game_state",
  "params": {
    "state": "PLAYING"
  }
}
```

### get_floor_info
获取当前楼层信息。

**参数**: 无

**返回**:
- `current_floor`: 当前楼层名称
- `floor_index`: 楼层索引
- `available_floors`: 可用楼层列表

**示例**:
```json
{
  "tool": "get_floor_info"
}
```

### change_floor
切换到不同的楼层。

**参数**:
- `floor` (必需): 楼层名称 (PROLOGUE, STREET, FLOOR_1, FLOOR_2, FLOOR_3, ENDING)

**返回**:
- `status`: 操作状态
- `new_floor`: 新楼层名称

**示例**:
```json
{
  "tool": "change_floor",
  "params": {
    "floor": "FLOOR_2"
  }
}
```

## 角色管理工具

### get_characters_status
获取所有角色的生死状态。

**参数**: 无

**返回**:
- `characters`: 角色状态字典
- `alive_count`: 存活角色数量
- `dead_count`: 死亡角色数量

**示例**:
```json
{
  "tool": "get_characters_status"
}
```

### set_character_alive
设置角色的生死状态。

**参数**:
- `character` (必需): 角色 ID (sister, cool_npc, cheerful_npc, male_npc, female_npc, timid_male)
- `alive` (必需): 是否存活 (true/false)

**返回**:
- `status`: 操作状态
- `character`: 角色 ID
- `alive`: 生死状态

**示例**:
```json
{
  "tool": "set_character_alive",
  "params": {
    "character": "cool_npc",
    "alive": false
  }
}
```

### get_soul_swap_status
获取灵魂交换状态。

**参数**: 无

**返回**:
- `is_soul_swapped`: 是否灵魂交换
- `soul_swap_target`: 灵魂交换目标

**示例**:
```json
{
  "tool": "get_soul_swap_status"
}
```

### trigger_soul_swap
触发灵魂交换。

**参数**:
- `target` (必需): 目标角色 ID

**返回**:
- `status`: 操作状态
- `from`: 来源角色
- `to`: 目标角色

**示例**:
```json
{
  "tool": "trigger_soul_swap",
  "params": {
    "target": "cool_npc"
  }
}
```

## 事件系统工具

### get_event_flags
获取所有事件标记。

**参数**: 无

**返回**:
- `event_flags`: 事件标记字典
- `count`: 标记数量

**示例**:
```json
{
  "tool": "get_event_flags"
}
```

### set_event_flag
设置事件标记。

**参数**:
- `flag_name` (必需): 标记名称
- `value` (必需): 标记值（可以是任意类型）

**返回**:
- `status`: 操作状态
- `flag_name`: 标记名称
- `value`: 标记值

**示例**:
```json
{
  "tool": "set_event_flag",
  "params": {
    "flag_name": "found_key",
    "value": true
  }
}
```

### get_discovered_rules
获取所有已发现的规则。

**参数**: 无

**返回**:
- `rules`: 规则列表
- `count`: 规则数量

**示例**:
```json
{
  "tool": "get_discovered_rules"
}
```

### discover_rule
发现一条新规则。

**参数**:
- `rule` (必需): 规则文本

**返回**:
- `status`: 操作状态
- `rule`: 规则文本
- `total_rules`: 总规则数量

**示例**:
```json
{
  "tool": "discover_rule",
  "params": {
    "rule": "不要在黑暗中停留超过30秒"
  }
}
```

## 物品系统工具

### get_inventory
获取玩家当前背包。

**参数**: 无

**返回**:
- `inventory`: 物品列表
- `item_counts`: 物品数量字典
- `total_items`: 总物品数量

**示例**:
```json
{
  "tool": "get_inventory"
}
```

### add_inventory_item
添加物品到背包。

**参数**:
- `item_id` (必需): 物品 ID

**返回**:
- `status`: 操作状态
- `item_id`: 物品 ID
- `new_count`: 新数量

**示例**:
```json
{
  "tool": "add_inventory_item",
  "params": {
    "item_id": "key_f1_01"
  }
}
```

### remove_inventory_item
从背包移除物品。

**参数**:
- `item_id` (必需): 物品 ID

**返回**:
- `status`: 操作状态
- `item_id`: 物品 ID
- `removed`: 是否成功移除

**示例**:
```json
{
  "tool": "remove_inventory_item",
  "params": {
    "item_id": "key_f1_01"
  }
}
```

## 对话系统工具

### start_dialogue
开始与 NPC 对话。

**参数**:
- `npc_id` (必需): NPC ID
- `dialogue_id` (可选): 对话 ID

**返回**:
- `status`: 操作状态
- `npc_id`: NPC ID
- `dialogue_id`: 对话 ID

**示例**:
```json
{
  "tool": "start_dialogue",
  "params": {
    "npc_id": "sister",
    "dialogue_id": "intro"
  }
}
```

### get_dialogue_state
获取当前对话状态。

**参数**: 无

**返回**:
- `is_dialogue_active`: 是否有对话进行中
- `current_npc`: 当前 NPC
- `current_dialogue_id`: 当前对话 ID

**示例**:
```json
{
  "tool": "get_dialogue_state"
}
```

## 存档系统工具

### save_game
保存当前游戏状态。

**参数**:
- `slot` (可选): 存档槽位 (0-9)，默认为 0

**返回**:
- `status`: 操作状态
- `slot`: 存档槽位
- `timestamp`: 保存时间戳

**示例**:
```json
{
  "tool": "save_game",
  "params": {
    "slot": 1
  }
}
```

### load_game
加载保存的游戏状态。

**参数**:
- `slot` (可选): 存档槽位 (0-9)，默认为 0

**返回**:
- `status`: 操作状态
- `slot`: 存档槽位
- `loaded`: 是否成功加载

**示例**:
```json
{
  "tool": "load_game",
  "params": {
    "slot": 1
  }
}
```

## 音频系统工具

### play_sound
播放音效或音乐。

**参数**:
- `sound_path` (必需): 声音文件路径
- `bus` (可选): 音频总线名称 (SFX, Music, Ambient)，默认为 SFX
- `volume_db` (可选): 音量（分贝），默认为 0

**返回**:
- `status`: 操作状态
- `sound_path`: 声音文件路径
- `playing`: 是否正在播放

**示例**:
```json
{
  "tool": "play_sound",
  "params": {
    "sound_path": "res://audio/sfx/horror_sting.wav",
    "bus": "SFX",
    "volume_db": -6.0
  }
}
```

### stop_sound
停止当前播放的声音。

**参数**:
- `sound_path` (必需): 要停止的声音路径

**返回**:
- `status`: 操作状态
- `sound_path`: 声音文件路径
- `stopped`: 是否成功停止

**示例**:
```json
{
  "tool": "stop_sound",
  "params": {
    "sound_path": "res://audio/sfx/horror_sting.wav"
  }
}
```

## 屏幕效果工具

### trigger_screen_effect
触发屏幕效果。

**参数**:
- `effect_type` (必需): 效果类型 (shake, flash, fade_in, fade_out, vignette, glitch)
- `intensity` (可选): 效果强度 (0.0-1.0)，默认为 0.5
- `duration` (可选): 效果持续时间（秒），默认为 1.0

**返回**:
- `status`: 操作状态
- `effect_type`: 效果类型
- `triggered`: 是否成功触发

**示例**:
```json
{
  "tool": "trigger_screen_effect",
  "params": {
    "effect_type": "shake",
    "intensity": 0.8,
    "duration": 2.0
  }
}
```

## 使用示例

### 场景 1: 调试恐怖张力
```json
// 获取当前张力状态
{"tool": "get_director_state"}

// 设置高张力
{"tool": "set_director_tension", "params": {"tension": 0.9}}

// 触发高峰事件
{"tool": "trigger_director_peak"}
```

### 场景 2: 测试角色死亡
```json
// 查看角色状态
{"tool": "get_characters_status"}

// 设置角色死亡
{"tool": "set_character_alive", "params": {"character": "cool_npc", "alive": false}}

// 查看游戏状态变化
{"tool": "get_game_state"}
```

### 场景 3: 测试物品系统
```json
// 添加物品
{"tool": "add_inventory_item", "params": {"item_id": "key_f1_01"}}

// 查看背包
{"tool": "get_inventory"}

// 移除物品
{"tool": "remove_inventory_item", "params": {"item_id": "key_f1_01"}}
```

### 场景 4: 触发恐怖效果
```json
// 播放恐怖音效
{"tool": "play_sound", "params": {"sound_path": "res://audio/sfx/horror_sting.wav"}}

// 触发屏幕震动
{"tool": "trigger_screen_effect", "params": {"effect_type": "shake", "intensity": 0.8}}

// 触发高峰事件
{"tool": "trigger_director_peak"}
```

## 注意事项

1. **运行时工具**: 这些工具主要在游戏运行时使用，需要游戏正在运行才能访问 autoload 单例。
2. **编辑器模式**: 某些工具在编辑器模式下可能无法正常工作，因为 autoload 单例可能未初始化。
3. **权限控制**: 某些工具可能需要在 MCP 服务器配置中启用相应的权限。
4. **错误处理**: 所有工具都包含错误处理，如果 autoload 单例不存在会返回错误信息。

## 扩展建议

可以考虑添加以下工具：
1. **怪物 AI 控制**: 控制怪物的行为和状态
2. **灯光控制**: 动态调整场景灯光
3. **天气系统**: 控制天气效果
4. **成就系统**: 管理游戏成就
5. **统计信息**: 游戏统计数据

## 技术支持

如有问题或建议，请联系开发团队。
