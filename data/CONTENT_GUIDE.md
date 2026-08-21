# 公寓怪谈 - 内容扩展指南
> 只需改数据、贴素材，不用碰代码逻辑

---

## 一、添加新物品

打开 `scripts/autoload/inventory_manager.gd`，在 `ITEM_DATA` 字典里加一行：

```gdscript
"my_new_food": {
    "name": "神秘饭团",
    "description": "散发着奇怪的香气",
    "icon": "rice_ball",           # 对应 assets/sprites/items/rice_ball.png
    "category": "food",            # key=剧情道具, food=食物, medicine=药品, special=特殊
    "consumable": true,            # true=使用后消失
    "effects": [
        {"type": "satiety", "value": 35},              # 恢复35饱食度
        {"type": "speed_up", "value": 20, "duration": 10},  # 加速10秒
    ],
},
```

### 可用效果类型
| type | 说明 | 参数 |
|------|------|------|
| `satiety` | 改变饱食度 | value: 正数恢复，负数扣除 |
| `heal` | 同satiety | value |
| `poison` | 中毒（持续扣饱食度）| duration |
| `bleed` | 流血 | duration |
| `cold` | 失温 | duration |
| `frightened` | 惊吓 | duration |
| `weak` | 虚弱 | duration |
| `speed_up` | 加速 | value, duration |
| `speed_down` | 减速 | value, duration |
| `silent_step` | 静步 | value, duration |
| `sharp_eye` | 锐眼 | value, duration |
| `tough` | 坚韧（防御）| value, duration |
| `cure` | 解除异常 | cure_target: 状态id（留空=全部清除）|

---

## 二、在关卡中放置物品

```gdscript
# 方法1：用 RoomTemplate
var room = RoomTemplate.new()
room.room_config = {
    "pickups": [
        {"pos": Vector2(100, 50), "item_id": "bread"},
        {"pos": Vector2(-50, 80), "item_id": "suspicious_candy", "color": Color.PURPLE},
    ],
}
room.build()

# 方法2：直接代码
var pickup = preload("res://scripts/items/pickup_item.gd").new()
# ... 或用 level_base 已有的手动方式
```

---

## 三、开启饱食度系统

在关卡脚本的 `_ready()` 中：
```gdscript
PlayerStats.satiety_enabled = true
PlayerStats.satiety_drain_rate = 1.5  # 每秒消耗1.5（越大越紧迫）
PlayerStats.set_satiety(80)           # 初始值
```

---

## 四、创建房间（RoomTemplate）

```gdscript
var room = RoomTemplate.new()
room.position = Vector2(0, 0)
room.room_config = {
    "size": Vector2(300, 200),
    "bg_color": Color(0.08, 0.06, 0.05),
    "walls": true,
    "wall_color": Color(0.15, 0.12, 0.1),
    "ambient_light": 0.3,
    "bgm": "res://assets/audio/bgm/floor3_tense.ogg",
    "ambience": "res://assets/audio/ambience/dripping.ogg",
    "furniture": [
        {"pos": Vector2(50, 30), "size": Vector2(40, 30), "color": Color(0.3, 0.2, 0.15)},
        {"pos": Vector2(-80, -20), "size": Vector2(20, 50), "sprite": "res://assets/sprites/environment/bookshelf.png"},
    ],
    "pickups": [
        {"pos": Vector2(100, 80), "item_id": "bread"},
    ],
    "doors": [
        {"pos": Vector2(150, 0), "size": Vector2(30, 10), "target_scene": "res://scenes/levels/hallway.tscn"},
    ],
    "decorations": [
        {"pos": Vector2(-30, 60), "size": Vector2(8, 8), "color": Color(0.5, 0.1, 0.1)},  # 血迹
    ],
}
add_child(room)
room.build()

# 监听门和触发器
room.door_entered.connect(func(data): print("进门:", data))
room.trigger_activated.connect(func(id, data): print("触发:", id))
```

---

## 五、创建事件（EventTemplate）

```gdscript
var evt = EventTemplate.new()
evt.event_config = {
    "id": "bathroom_scare",
    "one_shot": true,
    "conditions": {"flag": "entered_bathroom"},
    "actions": [
        {"type": "freeze_player"},
        {"type": "sfx", "path": "res://assets/audio/sfx/scare_sting.ogg"},
        {"type": "screen_shake", "intensity": 8, "duration": 0.6},
        {"type": "dialogue", "lines": [
            {"speaker": "???", "text": "你不该来这里的..."},
        ]},
        {"type": "apply_effect", "effects": [{"type": "frightened", "duration": 5}]},
        {"type": "set_flag", "flag": "bathroom_scared"},
        {"type": "unfreeze_player"},
    ],
}
add_child(evt)

# 在触发区域里调用
trigger.body_entered.connect(func(_b): evt.try_trigger())

# 自定义动作（如生怪）
evt.custom_action.connect(func(type, data):
    if type == "spawn_monster":
        _spawn_my_monster(data)
)
```

---

## 六、氛围效果（AtmosphereLayer）

`setup_ui()` 之后自动创建 `atmosphere` 变量：

```gdscript
# 暗角（恐怖基础氛围）
atmosphere.set_vignette(0.5)

# 迷雾
atmosphere.set_fog(Color(0.1, 0.05, 0.05), 0.25)

# 恐怖闪屏
atmosphere.flash_scare(Color.RED, 0.2)
atmosphere.flash_black(0.5)

# 心跳效果
atmosphere.pulse_heartbeat(5.0, 90)  # 5秒, 90bpm

# 噪点/静电
atmosphere.set_grain(0.2)

# 色调偏移（冷色调）
atmosphere.set_color_grade(Color(0.8, 0.85, 1.0))

# 屏幕震动
atmosphere.screen_shake(6.0, 0.4)

# 清除所有
atmosphere.clear_all()
```

---

## 七、音频素材放置

```
assets/audio/bgm/        → 背景音乐 (.ogg)
assets/audio/ambience/    → 环境音 (.ogg)  
assets/audio/sfx/         → 音效 (.ogg/.wav)
```

在关卡中播放：
```gdscript
AudioManager.play_bgm(load("res://assets/audio/bgm/my_track.ogg"))
AudioManager.play_ambience(load("res://assets/audio/ambience/rain.ogg"))
AudioManager.play_sfx(load("res://assets/audio/sfx/door_creak.ogg"))
```

---

## 八、美术素材放置

```
assets/sprites/items/       → 物品图标
assets/sprites/environment/ → 家具、墙壁、地板纹理
assets/sprites/monsters/    → 怪物
assets/sprites/npc/         → NPC立绘/小人
assets/sprites/player/      → 玩家角色
assets/sprites/ui/          → UI元素
```

替换角色素材：在 `game_manager.gd` 的 `SPRITE_PATHS` 填入路径即可，留空则用色块。

---

## 九、运行时注册物品（不改文件）

```gdscript
# 在关卡脚本中动态注册
InventoryManager.register_item("secret_key", {
    "name": "密室钥匙",
    "description": "一把生锈的钥匙",
    "icon": "key",
    "category": "key",
})
```
