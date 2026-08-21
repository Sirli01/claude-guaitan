# Floor_1 可视化迁移指南

## 概述

将 `floor_1_scene.gd` 中的动态代码创建改为 Godot 编辑器中拖拽放置 `@tool` 节点。

## 新增的 @tool 节点类型

| 节点脚本 | 类名 | 用途 |
|---------|------|------|
| `scripts/editor/GamePickup.gd` | GamePickup | 可拾取道具（电梯卡等） |
| `scripts/editor/GameContainer.gd` | GameContainer | 可搜索容器（急救箱等） |
| `scripts/editor/GameElevatorDoor.gd` | GameElevatorDoor | 电梯门（到达/目标） |
| `scripts/editor/GameDecorRect.gd` | GameDecorRect | 装饰矩形（镜子、大门等） |
| `scripts/editor/GameDoorLeak.gd` | GameDoorLeak | 门缝漏光效果 |

## 迁移对照表

### 1. 走廊急救箱

**原代码** (`_build_dynamic_elements`):
```gdscript
var aid_sprite = Sprite2D.new()
aid_sprite.texture = _TEX_MEDKIT
aid_sprite.position = Vector2(219, 49)
...
_place_container(Vector2(210, 42), Vector2(14, 14), "急救箱", Color(0.8, 0.2, 0.2), "bandage", "绷带")
```

**编辑器操作**:
1. 在 `Floor1` 场景中添加 `Node2D` 节点，挂载 `GameContainer.gd`
2. Inspector 设置:
   - `container_name`: "急救箱"
   - `container_size`: (14, 14)
   - `container_color`: (0.8, 0.2, 0.2)
   - `contained_item_id`: "bandage"
   - `contained_item_name`: "绷带"
   - `texture_path`: "res://assets/sprites/_0012_急救箱.png"
   - `texture_display_size`: (18, 14)
3. 拖到位置 (219, 49)

### 2. 大门装饰

**原代码**:
```gdscript
var gate_visual = ColorRect.new()
gate_visual.color = Color(0.2, 0.15, 0.12)
gate_visual.position = Vector2(-410, 345)
gate_visual.size = Vector2(40, 15)
add_child(gate_visual)
create_world_label(LocaleManager.world_text("大门"), Vector2(-402, 332), 18, Color(0.5, 0.4, 0.35))
# 大门交互区域...
```

**编辑器操作**:
1. 添加 `Node2D` → 挂载 `GameDecorRect.gd`
2. Inspector:
   - `decor_name`: "大门"
   - `decor_size`: (40, 15)
   - `decor_color`: (0.2, 0.15, 0.12)
   - `hint_text`: "hint_door_locked" (或直接写中文 "门锁住了")
   - `label_color`: (0.5, 0.4, 0.35)
3. 拖到位置 (-410, 345)

### 3. "门厅" 标签

**原代码**:
```gdscript
create_world_label(LocaleManager.world_text("门厅"), Vector2(-434, 330), 14, Color(0.72, 0.82, 0.88))
```

**编辑器操作**:
1. 添加 `Node2D` → 挂载 `GameDecorRect.gd`
2. Inspector:
   - `decor_name`: "门厅"
   - `decor_size`: (1, 1)  ← 极小，只显示标签
   - `decor_color`: (0, 0, 0, 0)  ← 透明
   - `show_label`: true
   - `label_color`: (0.72, 0.82, 0.88)
   - `label_font_size`: 14
3. 拖到位置 (-434, 330)

### 4. 电梯卡

**原代码** (`_place_elevator_card`):
```gdscript
var card_area = Area2D.new()
card_area.set_script(_SCRIPT_PICKUP)
card_area.position = Vector2(70, -250)
card_area.item_id = "elevator_card"
...
```

**编辑器操作**:
1. 添加 `Node2D` → 挂载 `GamePickup.gd`
2. Inspector:
   - `item_id`: "elevator_card"
   - `item_name`: "电梯卡"
   - `preview_color`: (0.5, 0.8, 1.0)
   - `texture_path`: "res://assets/sprites/_0000_电梯卡.png"
   - `texture_display_size`: (12, 8)
   - `pickup_radius`: 10.0
3. 拖到位置 (70, -250)

### 5. 镜子

**原代码** (`_place_mirror`):
```gdscript
var mirror_rect = ColorRect.new()
mirror_rect.color = Color(0.15, 0.15, 0.2)
mirror_rect.position = Vector2(145, -178)
mirror_rect.size = Vector2(30, 8)
```

**编辑器操作**:
1. 添加 `Node2D` → 挂载 `GameDecorRect.gd`
2. Inspector:
   - `decor_name`: "镜子"
   - `decor_size`: (30, 8)
   - `decor_color`: (0.15, 0.15, 0.2)
   - `label_color`: (0.4, 0.4, 0.5)
3. 拖到位置 (145, -178)

### 6. 电梯门

**原代码** (`_build_elevator`):
```gdscript
elev_door_vis = add_elevator_door_visual(Vector2(340, -130), Vector2(40, 36))
add_elevator_door_blocker(Vector2(340, -130), Vector2(36, 10))
create_world_label(LocaleManager.world_text("电梯"), Vector2(325, -165), 20, Color(0.5, 0.5, 0.5))
# 触发区域 + 电梯卡检查...
```

**编辑器操作**:
1. 添加 `Node2D` → 挂载 `GameElevatorDoor.gd`
2. Inspector:
   - `door_size`: (40, 36)
   - `is_arrival`: false
   - `elevator_label`: "电梯"
   - `requires_card`: true
3. 拖到位置 (340, -130)

### 7. 门缝漏光

**原代码** (`_place_dynamic_lights`):
```gdscript
_door_leak_lights.append(add_door_light_leak(Vector2(-250, -105), 24.0, "left"))
_door_leak_lights.append(add_door_light_leak(Vector2(-165, -170), 25.0))
...
```

**编辑器操作** (每个漏光):
1. 添加 `Node2D` → 挂载 `GameDoorLeak.gd`
2. Inspector 设置 `leak_width`、`leak_direction`、`light_energy`
3. 拖到对应门的位置

### 8. 闪烁灯

**原代码**:
```gdscript
_corridor_lights.append(add_flickering_light(Vector2(320, -130), 1.5, 2.4))
```

**编辑器操作**:
1. 添加 `PointLight2D` → 挂载 `RoomLight.gd` (已有)
2. Inspector:
   - `light_type`: "flickering"
   - `base_energy`: 1.5
   - `light_scale_val`: 2.4
3. 拖到位置 (320, -130)

### 9. 环境灰尘

**原代码**:
```gdscript
add_dust_ambient(Vector2(-360, 220), Vector2(40, 28))
```

**编辑器操作**:
1. 添加 `PointLight2D` → 挂载 `RoomLight.gd`
2. Inspector:
   - `light_type`: "dust"
3. 拖到对应位置

## 迁移后的 floor_1_scene.gd

迁移后 `_ready()` 简化为:

```gdscript
func _ready() -> void:
    GameManager.set_state(GameManager.GameState.PLAYING)
    GameManager.change_floor(GameManager.Floor.FLOOR_1)
    AudioManager.exit_silence_mode()

    # 所有静态几何 + 交互元素都从 .tscn 加载
    discover_scene_nodes()

    # 收集走廊灯光引用（停电事件需要控制）
    for child in get_children():
        if child is PointLight2D and child.name.begins_with("Corridor"):
            _corridor_lights.append(child)

    # 收集电梯门引用（电梯卡事件需要控制）
    for child in get_children():
        if child is GameElevatorDoor and not child.is_arrival:
            _elevator_door = child

    setup_player(Vector2(-780, 620), 6.0)
    _spawn_npcs()  # NPC 仍由 GameNPC 节点 + 代码混合处理

    # 读档恢复
    if GameManager.event_flags.get("floor1_23_triggered", false):
        _event_23_triggered = true
    if InventoryManager.has_item("elevator_card"):
        elevator_card_found = true

    setup_ui("第一层")
    # ... 后续开场逻辑不变
```

`_build_dynamic_elements()` 和 `_place_dynamic_lights()` 可以完全删除。

## 步骤

1. 在 Godot 编辑器中打开 `scenes/levels/floor_1.tscn`
2. 按上面的对照表逐个添加节点
3. 在 Inspector 中设置属性
4. 拖到正确位置
5. 修改 `floor_1_scene.gd` 移除对应代码
6. 运行测试

**建议渐进式迁移**：一次迁移一个元素，测试通过后再迁移下一个。
