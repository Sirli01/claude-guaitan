class_name GameConfig
## ========================================
## 《失序者的生存守则》资源配置中心
## ========================================
## 所有美术素材路径、音频路径都在这里配置！
## 贴素材时只需要在这个文件里改路径即可。
##
## 路径格式: "res://assets/..."
## 留空 "" 表示暂无素材（使用占位色块/静音）

# ╔══════════════════════════════════════════╗
# ║           角 色 美 术                     ║
# ╚══════════════════════════════════════════╝
# 角色立绘/小人素材路径
# 有素材时填入路径，没有就留空（自动用色块代替）
# 这些值会覆盖 GameManager.SPRITE_PATHS
const CHARACTER_SPRITES := {
	"sister": "res://assets/sprites/player/sister/idle/idle_down.png",          # 夏桐（玩家/姐姐）
	"cool_npc": "res://assets/sprites/npc/cool_npc/idle/idle_down.png",        # 林佳语
	"cheerful_npc": "res://assets/sprites/npc/cheerful_npc/idle/idle_down.png",    # 鹿可
	"male_npc": "res://assets/sprites/npc/male_npc/idle/idle_down.png",        # 周锐
	"female_npc": "res://assets/sprites/npc/female_npc/idle/idle_down.png",      # 沈薇
	"timid_male": "res://assets/sprites/npc/timid_male/idle/idle_down.png",      # 余凡
	"humanoid_monster": "", # 人形怪物
}

# ╔══════════════════════════════════════════╗
# ║           场 景 美 术                     ║
# ╚══════════════════════════════════════════╝
# 地板/墙壁/家具等环境纹理
const ENVIRONMENT_SPRITES := {
	# 地板纹理（替换色块地板）
	"floor_tile_dark": "",     # 阴暗地砖
	"floor_tile_wood": "",     # 木地板
	"floor_tile_blood": "",    # 血迹地板
	"floor_carpet": "",        # 地毯
	# 墙壁纹理
	"wall_concrete": "",       # 水泥墙
	"wall_wallpaper": "",      # 壁纸墙
	"wall_cracked": "",        # 裂缝墙
	# 家具
	"furniture_bed": "",       # 床
	"furniture_desk": "",      # 书桌
	"furniture_wardrobe": "",  # 衣柜
	"furniture_mirror": "",    # 镜子
	"furniture_bookshelf": "", # 书架
	# 其他
	"elevator_door": "",       # 电梯门
	"streetlamp": "",          # 路灯
	"apartment_door": "",      # 公寓入口
}

# 物品图标（对应 InventoryManager.ITEM_DATA 中的 icon 字段）
const ITEM_SPRITES := {
	"earplug": "",          # 耳塞
	"rope": "",             # 绳子
	"elevator_card": "",    # 电梯卡
	"phone": "",            # 手机
	"rule_paper": "",       # 规则纸条
	"bread": "",            # 面包
	"canned_food": "",      # 罐头
	"suspicious_candy": "", # 可疑糖果
	"energy_drink": "",     # 能量饮料
	"antidote": "",         # 解毒药
	"bandage": "",          # 绷带
	"talisman": "",         # 护身符
	"silent_shoes": "",     # 软底鞋
}

# ╔══════════════════════════════════════════╗
# ║           怪 物 美 术                     ║
# ╚══════════════════════════════════════════╝
const MONSTER_SPRITES := {
	"humanoid_monster": "",  # 人形怪物
	"abyss_mouth": "",      # 深渊巨口
	"high_heel": "",        # 高跟鞋怪
	"chase_mouth": "",      # 追逐战巨口
}

# ╔══════════════════════════════════════════╗
# ║           背 景 音 乐 (BGM)              ║
# ╚══════════════════════════════════════════╝
# 每个场景的BGM，填入 .ogg 文件路径
const BGM := {
	"main_menu": "",        # 主菜单
	"prologue_room": "",    # 序章房间（温馨）
	"prologue_street": "",  # 序章街道（夜晚氛围）
	"floor_1": "",          # 第一层（诡异初现）
	"floor_2": "",          # 第二层（压迫恐惧）
	"floor_3": "",          # 第三层（绝境追逐）
	"floor_3_chase": "",    # 第三层追逐战（紧张）
	"ending": "",           # 结局（空灵/反转）
	"game_over": "",        # 游戏结束
}

# ╔══════════════════════════════════════════╗
# ║           环 境 音 (Ambience)             ║
# ╚══════════════════════════════════════════╝
# 持续循环的环境底噪
const AMBIENCE := {
	"prologue_room": "",    # 夜晚房间（空调嗡鸣、钟表）
	"prologue_street": "",  # 夜晚街道（虫鸣、远处车声）
	"floor_1": "",          # 第一层（电灯闪烁、远处滴水）
	"floor_2": "",          # 第二层（风声、金属吱嘎）
	"floor_3": "",          # 第三层（深沉低频嗡鸣、心跳）
	"floor_3_chase": "",    # 第三层追逐（急促呼吸）
	"ending": "",           # 结局（死寂→嗡鸣）
}

# ╔══════════════════════════════════════════╗
# ║           音 效 (SFX)                     ║
# ╚══════════════════════════════════════════╝
# 一次性触发的音效
const SFX := {
	# 通用
	"item_pickup": "",       # 拾取物品
	"door_open": "",         # 开门
	"door_close": "",        # 关门
	"footstep_walk": "",     # 走路脚步
	"footstep_run": "",      # 跑步脚步
	"elevator_ding": "",     # 电梯到达
	"elevator_move": "",     # 电梯运行
	"paper_rustle": "",      # 纸张翻动（查看规则）
	# 恐怖音效
	"scare_sting": "",       # 惊吓刺针音
	"scare_low": "",         # 低频恐怖音
	"heartbeat": "",         # 心跳
	"whisper": "",           # 耳语
	"scream": "",            # 尖叫
	"silence_cut": "",       # 音效突然中断（反向恐惧）
	# 第一层
	"mirror_crack": "",      # 镜子裂纹
	"clock_chime": "",       # 23:00钟声
	# 第二层
	"high_heel_step": "",    # 高跟鞋脚步
	"high_heel_stomp": "",   # 高跟鞋践踏（击杀）
	"body_crush": "",        # 身体被碾碎
	# 第三层
	"monster_growl": "",     # 怪物低吼
	"floor_crack": "",       # 地板裂开
	"abyss_mouth_open": "",  # 巨口张开
	"abyss_mouth_chomp": "", # 巨口咬合
	"soul_swap_whoosh": "",  # 灵魂互换音效
	"dawn_chime": "",        # 7:00黎明钟声
	# 结局
	"paper_new_text": "",    # 纸条出现新字
}

# ╔══════════════════════════════════════════╗
# ║           工 具 方 法                     ║
# ╚══════════════════════════════════════════╝

static func load_audio(path: String) -> AudioStream:
	## 安全加载音频（路径为空或不存在则返回null）
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

static func load_texture(path: String) -> Texture2D:
	## 安全加载纹理（路径为空或不存在则返回null）
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

static func get_bgm(scene_id: String) -> AudioStream:
	return load_audio(BGM.get(scene_id, ""))

static func get_ambience(scene_id: String) -> AudioStream:
	return load_audio(AMBIENCE.get(scene_id, ""))

static func get_sfx(sfx_id: String) -> AudioStream:
	return load_audio(SFX.get(sfx_id, ""))
