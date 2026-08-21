extends Node
## LocaleManager — 多语言管理器
## 支持语言：zh（中文）/ en（英语）/ ja（日语）
## 用法：LocaleManager.set_locale("en")
##       LocaleManager.t("pause_title")  → "Paused"
##       LocaleManager.item_locale("earplug")  → {name, description}

signal locale_changed(locale: String)

var current_locale: String = "zh"

const SUPPORTED_LOCALES := ["zh", "en", "ja"]

func _ready() -> void:
	_load_locale()

# ─── 持久化 ──────────────────────────────────────────────
func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		return
	current_locale = locale
	StoryText._locale = locale
	_save_locale()
	locale_changed.emit(locale)

func _save_locale() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings", "locale", current_locale)
	cfg.save("user://settings.cfg")

func _load_locale() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved = cfg.get_value("settings", "locale", "zh")
		if saved in SUPPORTED_LOCALES:
			current_locale = saved
			StoryText._locale = saved

# ─── 通用 UI 字符串 ───────────────────────────────────────
func t(key: String) -> String:
	var table = _UI.get(current_locale, _UI["zh"])
	return table.get(key, _UI["zh"].get(key, key))

# ─── 按键说明（整组返回）────────────────────────────────
func key_bindings() -> Array:
	return _KEY_BINDINGS.get(current_locale, _KEY_BINDINGS["zh"])

# ─── 游戏提示（整组返回）────────────────────────────────
func gameplay_tips() -> Array:
	return _GAMEPLAY_TIPS.get(current_locale, _GAMEPLAY_TIPS["zh"])

# ─── 道具名/描述覆写（zh 返回空字典，表示用原始数据）────
func item_locale(item_id: String) -> Dictionary:
	if current_locale == "zh":
		return {}
	return _ITEMS.get(current_locale, {}).get(item_id, {})

# ─── 死亡界面信息 ─────────────────────────────────────────
func death_info(cause: String) -> Dictionary:
	var table = _DEATH_INFO.get(current_locale, _DEATH_INFO["zh"])
	return table.get(cause, table.get("insanity", {}))

# ─── 手机聊天 locale 数据 ─────────────────────────────────
func phone_chat_locale(chat_id: String) -> Dictionary:
	if current_locale == "zh":
		return {}
	return _PHONE_CHAT.get(current_locale, {}).get(chat_id, {})

func world_text(text: String) -> String:
	var table = _WORLD_TEXT.get(current_locale, _WORLD_TEXT["zh"])
	return table.get(text, _WORLD_TEXT["zh"].get(text, text))

func searched_label(name: String) -> String:
	var display_name = world_text(name)
	match current_locale:
		"en":
			return "%s (searched)" % display_name
		"ja":
			return "%s（調査済み）" % display_name
		_:
			return "%s（已搜索）" % display_name

func container_empty_text(name: String) -> String:
	var display_name = world_text(name)
	match current_locale:
		"en":
			return "You searched the %s... nothing." % display_name
		"ja":
			return "%sを調べたが……何もなかった。" % display_name
		_:
			return "搜索了%s……什么都没有。" % display_name

func container_found_text(name: String, item_name: String) -> String:
	var display_name = world_text(name)
	match current_locale:
		"en":
			return "Found '%s' in the %s!" % [item_name, display_name]
		"ja":
			return "%sから「%s」を見つけた！" % [display_name, item_name]
		_:
			var suffix = display_name[-1]
			var connector = "" if suffix in ["底", "下", "中", "旁"] else "里"
			return "从%s%s找到了「%s」！" % [display_name, connector, item_name]

func door_unlocked_text(required_key: String, key_name: String) -> String:
	match current_locale:
		"en":
			if required_key == "master_key":
				return "Used %s to unlock the door... but the key is stuck inside." % key_name
			return "Unlocked the door with %s!" % key_name
		"ja":
			if required_key == "master_key":
				return "%sで扉を開けた……だが鍵は抜けなくなった。" % key_name
			return "%sで扉を開けた！" % key_name
		_:
			if required_key == "master_key":
				return "用%s打开了门……但钥匙拔不出来了。" % key_name
			return "用%s打开了门！" % key_name

func door_need_key_text() -> String:
	match current_locale:
		"en":
			return "The door is locked... you need a key."
		"ja":
			return "扉は鍵がかかっている……鍵が必要だ。"
		_:
			return "门锁住了……需要钥匙。"

func pickup_prompt_text() -> String:
	match current_locale:
		"en":
			return "Press %s to pick up" % InputDevice.get_hint("interact")
		"ja":
			return "%sで拾う" % InputDevice.get_hint("interact")
		_:
			return "按%s拾取" % InputDevice.get_hint("interact")

func bench_prompt_text() -> String:
	match current_locale:
		"en":
			return "Press %s to sit and rest" % InputDevice.hint("interact")
		"ja":
			return "ベンチ %s 座って休む" % InputDevice.hint("interact")
		_:
			return "长椅 %s 坐下休息" % InputDevice.hint("interact")

func bench_resting_text() -> String:
	match current_locale:
		"en":
			return "Resting... (move to cancel)"
		"ja":
			return "休憩中……（移動で中断）"
		_:
			return "休息中……（方向键中断）"

func bench_no_need_text() -> String:
	match current_locale:
		"en":
			return "You don't need to rest right now."
		"ja":
			return "今は休む必要はない。"
		_:
			return "已经不需要休息了。"

func bench_sit_text() -> String:
	match current_locale:
		"en":
			return "You sit on the bench and catch your breath..."
		"ja":
			return "ベンチに腰を下ろし、少しだけ息を整える……"
		_:
			return "坐在长椅上稍作休息……"

func bench_stood_up_text() -> String:
	match current_locale:
		"en":
			return "You stood up."
		"ja":
			return "立ち上がった。"
		_:
			return "站了起来。"

func bench_recovered_text() -> String:
	match current_locale:
		"en":
			return "Feeling better now."
		"ja":
			return "少し楽になった。"
		_:
			return "精神多了。"

func vending_kick_prompt_text() -> String:
	match current_locale:
		"en":
			return "Press %s to kick" % InputDevice.hint("interact")
		"ja":
			return "%sで蹴る" % InputDevice.hint("interact")
		_:
			return "踢一脚 %s" % InputDevice.hint("interact")

# ╔══════════════════════════════════════════════════════════╗
# ║                     UI 字符串数据                         ║
# ╚══════════════════════════════════════════════════════════╝
const _UI := {
	"zh": {
		"pause_title": "暂停菜单",
		"tab_settings": "设置",
		"tab_controls": "按键",
		"tab_items": "道具",
			"tab_tips": "提示",
		"vol_master": "主音量",
		"vol_bgm": "背景音乐",
		"vol_sfx": "音效",
		"vol_ambience": "环境音",
		"btn_restart": "重新开始本层",
		"btn_resume": "继续游戏",
		"close_hint": "按 ESC 关闭",
		"no_items": "还没有发现任何道具",
		"language_label": "语言",
		"lang_zh": "中文",
		"lang_en": "English",
		"lang_ja": "日本語",
		"tips_title": "— 游戏提示 —",
		"fullscreen": "全屏模式",
		"settings_title": "设置",
		"retry_floor": "从本层重新开始",
		"retry_all": "从头开始",
		"main_menu_btn": "返回主菜单",
		"game_title": "失 序 者 的 生 存 守 则",
		"start_btn": "开始游戏",
		"continue_btn": "继续游戏",
		"settings_btn": "设置",
		"quit_btn": "退出",
		"cat_key": "【关键道具】",
		"cat_food": "【食物】",
		"cat_medicine": "【药品】",
		"cat_special": "【特殊】",
		"effect_prefix": "  |  效果: ",
		"effect_stamina": "体力 +%d",
		"effect_sanity": "理智 +%d",
		"effect_match": "照亮周围10秒",
		"effect_battery": "手电筒电量 +50%%",
		"item_got": "获得了「%s」！",
		"saved": "已存档",
		"load_success": "读档成功",
		"no_save": "没有存档",
		"floor_prologue": "序章",
		"floor_street": "街道",
		"floor_1": "第一层",
		"floor_2": "第二层",
		"floor_3": "第三层",
		"rule_update": "规则更新: ",
		"hint_back_in_room": "回到了自己的房间",
		"hint_controls": "%s 移动    短按%s 闪避    长按%s 奔跑",
		"hint_explore_street": "在街道上探索，公寓入口在右侧",
		"hint_dead_end": "这边走不通……先去找妹妹吧。",
		"hint_wrong_way": "公寓入口不在这边……先去找妹妹吧。",
		"hint_door_locked": "大门被铁链从外面锁死了……出不去。",
		"hint_rule_paper": "口袋里多了一张纸条…按 %s 查看规则",
		"hint_need_card": "需要电梯卡才能使用电梯。",
		"elevator_label_no_card": "电梯（需要电梯卡）",
		"elevator_label_has_card": "电梯 %s（使用电梯卡）",
		"backpack_title": "背包",
		"backpack_empty": "背包是空的",
		"item_detail_hint": "选中道具查看详情",
		"item_use": "[使用]",
		"item_equip": "[切换]",
		"item_examine": "[查看]",
		"vol_title": "音量",
		"vol_music": "音乐",
		"vol_ambient": "环境音",
		"stat_stamina": "体力",
		"stat_sanity": "理智",
		"stat_battery": "电池",
		"floor_prologue_room": "序章 - 夏桐的房间",
		"floor_prologue_street": "序章 - 街道",
		"hint_f2_scream": "楼上传来了沈薇的求救声！快去找她！",
		"hint_f2_item_dropped": "沈薇身旁掉落了什么东西……",
		"hint_f2_cheerful_safe": "鹿可暂时安全了……去找找有什么能帮她的东西。",
		"hint_f2_go_elevator": "快去电梯！",
		"hint_f2_find_card": "紧靠在一起，找到电梯卡！",
		"hint_go_elevator": "快去电梯！",
		"phone_back": "< 返回",
		"phone_tap_next": "点击屏幕显示下一条消息",
		"rules_close_hint": "\n按 %s 关闭",
		"rules_title": "—— 规 则 ——",
		"prompt_pick_phone": "%s 拾取手机",
		"prompt_leave_room": "出门",
		"prompt_go_home": "%s 回家",
		"prompt_enter_apartment": "%s 进入公寓",
		"hint_open_phone_inventory": "按 %s 打开背包，点击手机查看聊天记录",
		"hint_check_phone_first": "先看看书桌上的手机吧...",
		"hint_find_sister": "出门寻找妹妹吧",
		"dialogue_history_title": "— 对话记录 —",
		"cutscene_advance_hint": "▼ 按空格继续",
		"hint_f3_find_card_no_run": "找到电梯卡。不要跑——绝对不要跑。",
		"hint_f3_walk_to_elevator": "快走！不能跑，走向电梯！",
		"hint_f3_run_now": "长按 %s 跑起来！往下冲！躲开障碍物！",
		"hint_f3_return_elevator": "去电梯……回去吧",
		"floor3_dark_rule_narration": "黑暗中，规则纸慢慢浮现出一行字……\n但夏桐永远看不到了。",
		"click_continue": "[ 点击继续 ]",
		"abyss_mouth_label": "深渊巨口",
		"chase_survive_until_dawn": "— 撑到天亮 —",
		"countdown_seconds_left": "剩余 %d 秒",
		"vending_drop_found": "踢出了「%s」！",
		"vending_drop_empty": "踢了一脚……什么都没掉出来。",
		"rule_floor_1": "23:00 - 07:00，禁止对视",
		"rule_floor_2": "禁止离群 — 第二层",
		"rule_floor_3": "禁止跑步 — 第三层",
		"rule_final_lie": "她在说谎",
	},
	"en": {
		"pause_title": "Paused",
		"tab_settings": "Settings",
		"tab_controls": "Controls",
		"tab_items": "Items",
		"tab_tips": "Tips",
		"vol_master": "Master",
		"vol_bgm": "Music",
		"vol_sfx": "SFX",
		"vol_ambience": "Ambience",
		"btn_restart": "Restart Floor",
		"btn_resume": "Resume",
		"close_hint": "Press ESC to close",
		"no_items": "No items discovered yet.",
		"language_label": "Language",
		"lang_zh": "中文",
		"lang_en": "English",
		"lang_ja": "日本語",
		"tips_title": "— Tips —",
		"fullscreen": "Fullscreen",
		"settings_title": "Settings",
		"retry_floor": "Retry This Floor",
		"retry_all": "Restart",
		"main_menu_btn": "Main Menu",
		"game_title": "SURVIVAL RULES\nOF THE DISORDERED",
		"start_btn": "New Game",
		"continue_btn": "Continue",
		"settings_btn": "Settings",
		"quit_btn": "Quit",
		"cat_key": "[Key Item]",
		"cat_food": "[Food]",
		"cat_medicine": "[Medicine]",
		"cat_special": "[Special]",
		"effect_prefix": "  |  Effect: ",
		"effect_stamina": "Stamina +%d",
		"effect_sanity": "Sanity +%d",
		"effect_match": "Illuminates area for 10 seconds",
		"effect_battery": "Flashlight +50%% charge",
		"item_got": "Picked up: %s",
		"saved": "Saved",
		"load_success": "Loaded",
		"no_save": "No save data",
		"floor_prologue": "Prologue",
		"floor_street": "Street",
		"floor_1": "Floor 1",
		"floor_2": "Floor 2",
		"floor_3": "Floor 3",
		"rule_update": "Rule update: ",
		"hint_back_in_room": "Back in your own room.",
		"hint_controls": "%s Move    Tap %s Dodge    Hold %s Sprint",
		"hint_explore_street": "Explore the street. The apartment entrance is to the right.",
		"hint_dead_end": "Dead end... Go find your sister first.",
		"hint_wrong_way": "That's not the way to the apartment... Go find your sister first.",
		"hint_door_locked": "The front door is chained shut from outside. No way out.",
		"hint_rule_paper": "A slip of paper appeared in your pocket. Press %s to view the rules.",
		"hint_need_card": "An elevator card is required.",
		"elevator_label_no_card": "Elevator (card required)",
		"elevator_label_has_card": "Elevator %s (use card)",
		"backpack_title": "Inventory",
		"backpack_empty": "Inventory is empty.",
		"item_detail_hint": "Select an item to view details.",
		"item_use": "[Use]",
		"item_equip": "[Toggle]",
		"item_examine": "[Examine]",
		"vol_title": "Volume",
		"vol_music": "Music",
		"vol_ambient": "Ambient",
		"stat_stamina": "Stamina",
		"stat_sanity": "Sanity",
		"stat_battery": "Battery",
		"floor_prologue_room": "Prologue - Xia Tong's Room",
		"floor_prologue_street": "Prologue - Street",
		"hint_f2_scream": "A desperate cry from upstairs — Shen Wei! Go help her!",
		"hint_f2_item_dropped": "Something fell near Shen Wei...",
		"hint_f2_cheerful_safe": "Lu Ke is safe for now... find something to help her.",
		"hint_f2_go_elevator": "Get to the elevator!",
		"hint_f2_find_card": "Stay together — find the elevator card!",
		"hint_go_elevator": "Get to the elevator!",
		"phone_back": "< Back",
		"phone_tap_next": "Tap the screen to show the next message",
		"rules_close_hint": "\nPress %s to close",
		"rules_title": "— RULES —",
		"prompt_pick_phone": "%s Pick up the phone",
		"prompt_leave_room": "Leave",
		"prompt_go_home": "%s Go home",
		"prompt_enter_apartment": "%s Enter the apartment",
		"hint_open_phone_inventory": "Press %s to open the inventory and select the phone to read the chat history.",
		"hint_check_phone_first": "Check the phone on the desk first...",
		"hint_find_sister": "Head out and look for your sister.",
		"dialogue_history_title": "— Dialogue Log —",
		"cutscene_advance_hint": "▼ Press Space to continue",
		"hint_f3_find_card_no_run": "You found the elevator card. Do not run. Absolutely do not run.",
		"hint_f3_walk_to_elevator": "Move! Don't run. Walk to the elevator!",
		"hint_f3_run_now": "Hold %s to run! Sprint downward! Dodge the obstacles!",
		"hint_f3_return_elevator": "To the elevator... let's go back.",
		"floor3_dark_rule_narration": "In the darkness, a line slowly surfaced on the rule sheet...\nBut Xia Tong would never get to read it.",
		"click_continue": "[ Click to continue ]",
		"abyss_mouth_label": "Abyss Maw",
		"chase_survive_until_dawn": "— Survive Until Dawn —",
		"countdown_seconds_left": "%d sec left",
		"vending_drop_found": "You kicked out \"%s\"!",
		"vending_drop_empty": "You kicked it... but nothing came out.",
		"rule_floor_1": "23:00 - 07:00 — Do not make eye contact",
		"rule_floor_2": "Do not separate from the group — Floor 2",
		"rule_floor_3": "No running — Floor 3",
		"rule_final_lie": "She is lying",
	},
	"ja": {
		"pause_title": "ポーズメニュー",
		"tab_settings": "設定",
		"tab_controls": "操作方法",
		"tab_items": "アイテム",
		"tab_tips": "ヒント",
		"vol_master": "マスター音量",
		"vol_bgm": "BGM",
		"vol_sfx": "効果音",
		"vol_ambience": "環境音",
		"btn_restart": "階層再起動",
		"btn_resume": "ゲームを続ける",
		"close_hint": "ESCで閉じる",
		"no_items": "まだアイテムを発見していません",
		"language_label": "言語",
		"lang_zh": "中文",
		"lang_en": "English",
		"lang_ja": "日本語",
		"tips_title": "— ヒント —",
		"fullscreen": "フルスクリーン",
		"settings_title": "設定",
		"retry_floor": "このフロアをやり直す",
		"retry_all": "最初からやり直す",
		"main_menu_btn": "メインメニューへ",
		"game_title": "失 序 者 の 生 存 規 則",
		"start_btn": "ゲーム開始",
		"continue_btn": "続きから",
		"settings_btn": "設定",
		"quit_btn": "終了",
		"cat_key": "【重要アイテム】",
		"cat_food": "【食料】",
		"cat_medicine": "【薬品】",
		"cat_special": "【特殊】",
		"effect_prefix": "  |  効果: ",
		"effect_stamina": "スタミナ +%d",
		"effect_sanity": "精神力 +%d",
		"effect_match": "周囲を10秒間照らす",
		"effect_battery": "懐中電灯 +50%% 充電",
		"item_got": "「%s」を手に入れた！",
		"saved": "セーブしました",
		"load_success": "ロード完了",
		"no_save": "セーブデータがありません",
		"floor_prologue": "序章",
		"floor_street": "通り",
		"floor_1": "1階",
		"floor_2": "2階",
		"floor_3": "3階",
		"rule_update": "ルール更新: ",
		"hint_back_in_room": "自分の部屋に戻った",
		"hint_controls": "%s 移動    %sタップ 回避    %sホールド ダッシュ",
		"hint_explore_street": "街を探索しよう。アパートの入口は右側にある。",
		"hint_dead_end": "行き止まり……まず妹を探しに行こう。",
		"hint_wrong_way": "アパートの入口はこちらではない……まず妹を探しに行こう。",
		"hint_door_locked": "正面玄関は外から鎖されている……出られない。",
		"hint_rule_paper": "ポケットにルール用紙が入っていた……%sで確認できる。",
		"hint_need_card": "エレベーターカードが必要です。",
		"elevator_label_no_card": "エレベーター（カード必要）",
		"elevator_label_has_card": "エレベーター %s（カード使用）",
		"backpack_title": "所持品",
		"backpack_empty": "アイテムがない。",
		"item_detail_hint": "アイテムを選択して詳細を表示",
		"item_use": "[使用]",
		"item_equip": "[切替]",
		"item_examine": "[確認]",
		"vol_title": "音量",
		"vol_music": "音楽",
		"vol_ambient": "環境音",
		"stat_stamina": "スタミナ",
		"stat_sanity": "精神力",
		"stat_battery": "電池",
		"floor_prologue_room": "序章 - 夏桐の部屋",
		"floor_prologue_street": "序章 - 通り",
		"hint_f2_scream": "上から沈薇の助けを求める声！急いで！",
		"hint_f2_item_dropped": "沈薇のそばに何か落ちている……",
		"hint_f2_cheerful_safe": "鹿可はとりあえず安全だ……彼女を助けるものを探そう。",
		"hint_f2_go_elevator": "エレベーターへ！",
		"hint_f2_find_card": "固まって離れないで。エレベーターカードを探して！",
		"hint_go_elevator": "エレベーターへ！",
		"phone_back": "< 戻る",
		"phone_tap_next": "画面をタップして次のメッセージを表示",
		"rules_close_hint": "\n%sで閉じる",
		"rules_title": "—— ルール ——",
		"prompt_pick_phone": "%sでスマホを拾う",
		"prompt_leave_room": "外に出る",
		"prompt_go_home": "%sで家に戻る",
		"prompt_enter_apartment": "%sでアパートに入る",
		"hint_open_phone_inventory": "%sで所持品を開き、スマホを選んでチャット履歴を確認して。",
		"hint_check_phone_first": "まず机の上のスマホを確認しよう……",
		"hint_find_sister": "外に出て妹を探そう",
		"dialogue_history_title": "—— 会話ログ ——",
		"cutscene_advance_hint": "▼ Spaceで続行",
		"hint_f3_find_card_no_run": "エレベーターカードを見つけた。走るな。絶対に走るな。",
		"hint_f3_walk_to_elevator": "急いで！ 走っちゃだめ、歩いてエレベーターへ！",
		"hint_f3_run_now": "%sを長押しして走れ！ 下へ駆けろ！ 障害物を避けて！",
		"hint_f3_return_elevator": "エレベーターへ……戻ろう。",
		"floor3_dark_rule_narration": "闇の中、ルール用紙に一行の文字がゆっくり浮かび上がる……\nだが夏桐がそれを見ることはもうない。",
		"click_continue": "[ クリックで続行 ]",
		"abyss_mouth_label": "深淵の大口",
		"chase_survive_until_dawn": "—— 夜明けまで耐えろ ——",
		"countdown_seconds_left": "残り %d 秒",
		"vending_drop_found": "「%s」が蹴り出された！",
		"vending_drop_empty": "蹴ってみたが……何も落ちなかった。",
		"rule_floor_1": "23:00 - 07:00、視線を合わせるな",
		"rule_floor_2": "群れを離れるな — 2階",
		"rule_floor_3": "走るな — 3階",
		"rule_final_lie": "彼女は嘘をついている",
	},
}

const _WORLD_TEXT := {
	"zh": {
		"第一层": "第一层",
		"第二层": "第二层",
		"第三层": "第三层",
		"序章 - 夏桐的房间": "序章 - 夏桐的房间",
		"序章 - 街道": "序章 - 街道",
		"大门": "大门",
		"出门": "出门",
		"镜子": "镜子",
		"电梯": "电梯",
		"小卖部": "小卖部",
		"夏桐的家": "夏桐的家",
		"归栖公寓": "归栖公寓",
		"邮箱": "邮箱",
		"草丛": "草丛",
		"垃圾桶": "垃圾桶",
		"报刊架": "报刊架",
		"消防栓": "消防栓",
		"床": "床",
		"桌子": "桌子",
		"书桌": "书桌",
		"衣柜": "衣柜",
		"货架": "货架",
		"柜台": "柜台",
		"沙发": "沙发",
		"椅子": "椅子",
		"柜子": "柜子",
		"箱子": "箱子",
		"药箱": "药箱",
		"储藏室": "储藏室",
		"破床": "破床",
		"碎桌": "碎桌",
		"破椅子": "破椅子",
		"碎玻璃": "碎玻璃",
		"双人床": "双人床",
		"床头柜": "床头柜",
		"背包": "背包",
		"相框": "相框",
		"急救包": "急救包",
		"折叠桌": "折叠桌",
		"折叠椅": "折叠椅",
		"废柜": "废柜",
		"杂物": "杂物",
		"破沙发": "破沙发",
		"破瓶子": "破瓶子",
		"贩卖机": "贩卖机",
		"故障": "故障",
		"长椅": "长椅",
	},
	"en": {
		"第一层": "Floor 1",
		"第二层": "Floor 2",
		"第三层": "Floor 3",
		"序章 - 夏桐的房间": "Prologue - Xia Tong's Room",
		"序章 - 街道": "Prologue - Street",
		"大门": "Front Door",
		"出门": "Leave",
		"镜子": "Mirror",
		"电梯": "Elevator",
		"小卖部": "Convenience Store",
		"夏桐的家": "Xia Tong's Home",
		"归栖公寓": "Guiqi Apartments",
		"邮箱": "Mailbox",
		"草丛": "Bush",
		"垃圾桶": "Trash Can",
		"报刊架": "News Rack",
		"消防栓": "Fire Hydrant",
		"床": "Bed",
		"桌子": "Table",
		"书桌": "Desk",
		"衣柜": "Wardrobe",
		"货架": "Shelf",
		"柜台": "Counter",
		"沙发": "Sofa",
		"椅子": "Chair",
		"柜子": "Cabinet",
		"箱子": "Box",
		"药箱": "Medicine Cabinet",
		"储藏室": "Storage Room",
		"破床": "Broken Bed",
		"碎桌": "Broken Table",
		"破椅子": "Broken Chair",
		"碎玻璃": "Broken Glass",
		"双人床": "Double Bed",
		"床头柜": "Nightstand",
		"背包": "Backpack",
		"相框": "Photo Frame",
		"急救包": "First Aid Kit",
		"折叠桌": "Folding Table",
		"折叠椅": "Folding Chair",
		"废柜": "Ruined Cabinet",
		"杂物": "Junk",
		"破沙发": "Broken Sofa",
		"破瓶子": "Broken Bottle",
		"贩卖机": "Vending Machine",
		"故障": "Out of Order",
		"长椅": "Bench",
	},
	"ja": {
		"第一层": "1階",
		"第二层": "2階",
		"第三层": "3階",
		"序章 - 夏桐的房间": "序章 - 夏桐の部屋",
		"序章 - 街道": "序章 - 通り",
		"大门": "正面玄関",
		"出门": "外に出る",
		"镜子": "鏡",
		"电梯": "エレベーター",
		"小卖部": "売店",
		"夏桐的家": "夏桐の家",
		"归栖公寓": "帰栖アパート",
		"邮箱": "郵便受け",
		"草丛": "茂み",
		"垃圾桶": "ゴミ箱",
		"报刊架": "新聞ラック",
		"消防栓": "消火栓",
		"床": "ベッド",
		"桌子": "テーブル",
		"书桌": "机",
		"衣柜": "洋服ダンス",
		"货架": "棚",
		"柜台": "カウンター",
		"沙发": "ソファ",
		"椅子": "椅子",
		"柜子": "戸棚",
		"箱子": "箱",
		"药箱": "救急箱",
		"储藏室": "物置",
		"破床": "壊れたベッド",
		"碎桌": "壊れた机",
		"破椅子": "壊れた椅子",
		"碎玻璃": "割れたガラス",
		"双人床": "ダブルベッド",
		"床头柜": "サイドテーブル",
		"背包": "リュック",
		"相框": "写真立て",
		"急救包": "救急キット",
		"折叠桌": "折りたたみ机",
		"折叠椅": "折りたたみ椅子",
		"废柜": "壊れた棚",
		"杂物": "ガラクタ",
		"破沙发": "壊れたソファ",
		"破瓶子": "割れた瓶",
		"贩卖机": "自動販売機",
		"故障": "故障中",
		"长椅": "ベンチ",
	},
}

# ╔══════════════════════════════════════════════════════════╗
# ║                   按键说明数据                            ║
# ╚══════════════════════════════════════════════════════════╝
const _KEY_BINDINGS := {
	"zh": [
		{"action": "W/A/S/D  |  左摇杆", "desc": "移动"},
		{"action": "Shift  |  LB/L1", "desc": "短按闪避 / 长按奔跑（均消耗体力）"},
		{"action": "E  |  X/□", "desc": "互动 / 搜索"},
		{"action": "鼠标/Space  |  A/×", "desc": "推进对话"},
		{"action": "Tab  |  RB/R1", "desc": "打开背包"},
		{"action": "R  |  Y/△", "desc": "查看规则纸条"},
		{"action": "ESC  |  Start/Options", "desc": "暂停菜单"},
		{"action": "B/○", "desc": "关闭当前界面（手柄）"},
		{"action": "F5  |  L3（左摇杆按下）", "desc": "快速存档"},
		{"action": "F9  |  R3（右摇杆按下）", "desc": "快速读档"},
	],
	"en": [
		{"action": "W/A/S/D  |  Left Stick", "desc": "Move"},
		{"action": "Shift  |  LB/L1", "desc": "Tap: Dodge / Hold: Sprint (both drain stamina)"},
		{"action": "E  |  X/□", "desc": "Interact / Search"},
		{"action": "Mouse/Space  |  A/×", "desc": "Advance Dialogue"},
		{"action": "Tab  |  RB/R1", "desc": "Open Inventory"},
		{"action": "R  |  Y/△", "desc": "View Rules"},
		{"action": "ESC  |  Start/Options", "desc": "Pause Menu"},
		{"action": "B/○", "desc": "Close UI (Gamepad)"},
		{"action": "F5  |  L3 (push)", "desc": "Quick Save"},
		{"action": "F9  |  R3 (push)", "desc": "Quick Load"},
	],
	"ja": [
		{"action": "W/A/S/D  |  左スティック", "desc": "移動"},
		{"action": "Shift  |  LB/L1", "desc": "タップ：回避 / ホールド：ダッシュ（スタミナ消費）"},
		{"action": "E  |  X/□", "desc": "調べる"},
		{"action": "マウス/Space  |  A/×", "desc": "会話を進める"},
		{"action": "Tab  |  RB/R1", "desc": "所持品を開く"},
		{"action": "R  |  Y/△", "desc": "ルール用紙を確認"},
		{"action": "ESC  |  Start/Options", "desc": "ポーズメニュー"},
		{"action": "B/○", "desc": "UIを閉じる（ゲームパッド）"},
		{"action": "F5  |  L3（左スティック押し込み）", "desc": "クイックセーブ"},
		{"action": "F9  |  R3（右スティック押し込み）", "desc": "クイックロード"},
	],
}

# ╔══════════════════════════════════════════════════════════╗
# ║                   游戏提示数据                            ║
# ╚══════════════════════════════════════════════════════════╝
const _GAMEPLAY_TIPS := {
	"zh": [
		"走路和跑步都会消耗体力，原地不动可以缓慢恢复。",
		"在黑暗环境中没有光源时，理智会持续下降。",
		"点亮火柴或打开手电筒可以恢复理智。",
		"站在灯光区域下也可以恢复理智。",
		"理智降到 0 会导致精神崩溃死亡。",
		"注意阅读规则纸条，违反规则可能导致死亡。",
	],
	"en": [
		"Walking and running both drain stamina. Standing still restores it slowly.",
		"In darkness without a light source, your sanity will steadily drain.",
		"Lighting a match or turning on a flashlight restores sanity.",
		"Standing beneath a light source also restores sanity.",
		"When sanity reaches 0, you suffer a mental breakdown and die.",
		"Read the rules carefully. Breaking them may be fatal.",
	],
	"ja": [
		"歩行と走りはどちらもスタミナを消費する。静止すると少しずつ回復する。",
		"光源のない暗所では、精神力が徐々に低下する。",
		"マッチを灯したり懐中電灯をつけると精神力が回復する。",
		"灯りの下に立つだけでも精神力が回復する。",
		"精神力が0になると精神崩壊を引き起こし、死亡する。",
		"ルール用紙をよく読むこと。ルールを破ると死に至る可能性がある。",
	],
}

# ╔══════════════════════════════════════════════════════════╗
# ║               道具名称/描述（EN & JA）                    ║
# ╚══════════════════════════════════════════════════════════╝
const _ITEMS := {
	"en": {
		"earplug":      {"name": "Earplugs",      "description": "Earplugs that block out sound."},
		"rope":         {"name": "Rope",           "description": "A sturdy length of rope."},
		"elevator_card":{"name": "Elevator Card",  "description": "A magnetic card for summoning the elevator."},
		"phone":        {"name": "Phone",          "description": "Xia Tong's phone. Her chat history with her sister is still there."},
		"rule_paper":   {"name": "Rule Sheet",     "description": "A strange rule sheet. New lines of text appear on their own."},
		"master_key":   {"name": "Master Key",     "description": "A rust-eaten skeleton key — it opens any locked room in the building."},
		"room_304_key": {"name": "Room 304 Key",   "description": "Zhou Rui's room key, engraved with '304'."},
		"flashlight":   {"name": "Flashlight",     "description": "An old flashlight. Illuminates a wide area ahead."},
		"match":        {"name": "Match",          "description": "One match. Burns for ten seconds, casting a small circle of light."},
		"battery":      {"name": "Battery",        "description": "A flashlight battery. Restores 50% charge."},
		"energy_drink": {"name": "Energy Drink",   "description": "Restores a fair amount of stamina."},
		"sedative":     {"name": "Sedative",       "description": "Eases panic. Restores sanity."},
		"sweets":       {"name": "Candy",          "description": "Something sweet to steady the nerves, just a little."},
		"energy_bar":   {"name": "Energy Bar",     "description": "A convenience-store energy bar. Restores some stamina."},
		"coffee":       {"name": "Coffee",         "description": "A canned coffee, faintly bitter. Restores a touch of stamina and sanity."},
		"bandage":      {"name": "Bandage",        "description": "First-aid bandages. Wrapping them brings a small measure of calm."},
	},
	"ja": {
		"earplug":      {"name": "耳栓",              "description": "音を遮断する耳栓。"},
		"rope":         {"name": "ロープ",             "description": "しっかりとした一本のロープ。"},
		"elevator_card":{"name": "エレベーターカード",  "description": "エレベーターを呼ぶための磁気カード。"},
		"phone":        {"name": "スマートフォン",      "description": "夏桐の携帯。妹とのチャット履歴がまだ残っている。"},
		"rule_paper":   {"name": "ルール用紙",         "description": "奇妙なルール用紙。放っておいても文字が増えていく。"},
		"master_key":   {"name": "マスターキー",        "description": "錆びついた万能鍵。このアパートの鍵のかかった部屋をすべて開けられる。"},
		"room_304_key": {"name": "304号室の鍵",        "description": "周锐の部屋の鍵。「304」と刻まれている。"},
		"flashlight":   {"name": "懐中電灯",           "description": "古びた懐中電灯。広い範囲を照らせる。"},
		"match":        {"name": "マッチ",             "description": "一本のマッチ。火をつけると10秒間、小さな光の輪を作る。"},
		"battery":      {"name": "電池",               "description": "懐中電灯用の電池。電池残量を50%回復できる。"},
		"energy_drink": {"name": "エナジードリンク",    "description": "スタミナをかなり回復できる。"},
		"sedative":     {"name": "鎮静剤",             "description": "パニックを和らげ、精神力を回復する。"},
		"sweets":       {"name": "キャンディ",          "description": "甘いキャンディ。精神を少しだけ落ち着かせてくれる。"},
		"energy_bar":   {"name": "エナジーバー",        "description": "コンビニのエナジーバー。スタミナを回復できる。"},
		"coffee":       {"name": "コーヒー",            "description": "缶コーヒー、少し苦め。スタミナと精神力を少し回復できる。"},
		"bandage":      {"name": "包帯",               "description": "救急箱の包帯。巻くと、少し気持ちが落ち着く。"},
	},
}

# ╔══════════════════════════════════════════════════════════╗
# ║                 死亡界面信息                              ║
# ╚══════════════════════════════════════════════════════════╝
const _DEATH_INFO := {
	"zh": {
		"insanity":     {"title": "精神崩溃",  "subtitle": "你的理智已经完全崩塌……",             "color": Color(0.6, 0.1, 0.2)},
		"abyss":        {"title": "深渊吞噬",  "subtitle": "地板下的巨口将你拖入了永恒的黑暗……",   "color": Color(0.3, 0.05, 0.15)},
		"chase_caught": {"title": "未能逃脱",  "subtitle": "巨口追上了你……再也没有下一次机会。",    "color": Color(0.4, 0.0, 0.1)},
		"monster":      {"title": "被它抓住了", "subtitle": "那个东西的红眼睛是你最后看到的东西……", "color": Color(0.5, 0.0, 0.0)},
	},
	"en": {
		"insanity":     {"title": "Mental Breakdown",       "subtitle": "Your sanity has crumbled to nothing...",                             "color": Color(0.6, 0.1, 0.2)},
		"abyss":        {"title": "Swallowed by the Abyss", "subtitle": "The maw beneath the floor dragged you into eternal darkness...",      "color": Color(0.3, 0.05, 0.15)},
		"chase_caught": {"title": "No Escape",              "subtitle": "The Abyss caught up with you. There are no more chances.",           "color": Color(0.4, 0.0, 0.1)},
		"monster":      {"title": "Caught",                 "subtitle": "The red eyes of that thing were the last thing you ever saw...",     "color": Color(0.5, 0.0, 0.0)},
	},
	"ja": {
		"insanity":     {"title": "精神崩壊",       "subtitle": "あなたの精神は完全に崩れ落ちた……",           "color": Color(0.6, 0.1, 0.2)},
		"abyss":        {"title": "深淵に飲まれた",  "subtitle": "床下の巨大な口があなたを永遠の闇へ引きずり込んだ……", "color": Color(0.3, 0.05, 0.15)},
		"chase_caught": {"title": "逃げられなかった", "subtitle": "巨口はあなたに追いついた……もう次の機会はない。",  "color": Color(0.4, 0.0, 0.1)},
		"monster":      {"title": "捕まった",        "subtitle": "あの赤い目が、最後に見たものだった……",          "color": Color(0.5, 0.0, 0.0)},
	},
}

# ╔══════════════════════════════════════════════════════════╗
# ║                 手机聊天 locale 数据                      ║
# ╚══════════════════════════════════════════════════════════╝
const _PHONE_CHAT := {
	"en": {
		"prologue_chat": {
			"contact_name": "Xia Che",
			"messages": [
				{"sender": "Xia Che", "text": "Sis! I found an insanely cheap apartment!", "time": "Last Fri 09:30"},
				{"sender": "self", "text": "Where? Be careful with cheap places.", "time": "Last Fri 09:32"},
				{"sender": "Xia Che", "text": "It's called Guiqi Apartments — only RMB 800 a month! And it's super close to school", "time": "Last Fri 09:33"},
				{"sender": "Xia Che", "text": "It's a bit old... but the room is actually pretty big", "time": "Last Fri 09:34"},
				{"sender": "self", "text": "Send me some photos first", "time": "Last Fri 09:35"},
				{"sender": "Xia Che", "text": "Sure! I'll send some tonight after I'm done moving~", "time": "Last Fri 09:36"},
				{"sender": "self", "text": "Moved in? Where are the photos?", "time": "Last Fri 20:14"},
				{"sender": "Xia Che", "text": "All moved in! Battery's almost dead, I'll send photos tomorrow.", "time": "Last Fri 21:02"},
				{"sender": "Xia Che", "text": "Sis, the neighbors here are all so quiet. The whole floor is completely silent.", "time": "Last Fri 23:15"},
				{"sender": "self", "text": "Don't wander around at night. Go to sleep.", "time": "Last Fri 23:17"},
				{"sender": "Xia Che", "text": "I know, goodnight!", "time": "Last Fri 23:18"},
				{"sender": "self", "text": "Xia Che? Photos?", "time": "Sat 12:30"},
				{"sender": "self", "text": "Sleeping in again?", "time": "Sat 15:20"},
				{"sender": "self", "text": "Did your phone die again?", "time": "Sun 10:00"},
				{"sender": "self", "text": "Why aren't you replying", "time": "Sun 18:45"},
				{"sender": "self", "text": "Xia Che??", "time": "Mon 09:12"},
				{"sender": "self", "text": "Where are you? You're not picking up my calls either", "time": "Mon 14:30"},
				{"sender": "self", "text": "Xia Che, where are you...", "time": "Mon 22:00"},
				{"sender": "self", "text": "...I'm coming to find you.", "time": "Tue 08:00"},
			],
		},
	},
	"ja": {
		"prologue_chat": {
			"contact_name": "夏澈",
			"messages": [
				{"sender": "夏澈", "text": "お姉ちゃん！すごく安いアパートを見つけたよ！", "time": "先週金曜 09:30"},
				{"sender": "self", "text": "どこ？安い所は気をつけないと。", "time": "先週金曜 09:32"},
				{"sender": "夏澈", "text": "帰栖アパートっていうの。家賃たった800元で、学校にもすごく近いよ", "time": "先週金曜 09:33"},
				{"sender": "夏澈", "text": "ちょっと古いだけで……部屋は広いんだよ", "time": "先週金曜 09:34"},
				{"sender": "self", "text": "写真送ってよ", "time": "先週金曜 09:35"},
				{"sender": "夏澈", "text": "わかった！夜引っ越し終わったら送るね〜", "time": "先週金曜 09:36"},
				{"sender": "self", "text": "引っ越し終わった？写真は？", "time": "先週金曜 20:14"},
				{"sender": "夏澈", "text": "終わったよ！電池切れそうだから明日送る。", "time": "先週金曜 21:02"},
				{"sender": "夏澈", "text": "お姉ちゃん、ここの住人みんなすごく静かだよ。フロア全体、ほとんど物音がしないの", "time": "先週金曜 23:15"},
				{"sender": "self", "text": "夜中に出歩かないで、早く寝てね", "time": "先週金曜 23:17"},
				{"sender": "夏澈", "text": "わかってるって、おやすみ！", "time": "先週金曜 23:18"},
				{"sender": "self", "text": "夏澈？写真は？", "time": "土曜 12:30"},
				{"sender": "self", "text": "また寝坊してるの？", "time": "土曜 15:20"},
				{"sender": "self", "text": "またスマホの充電切れ？", "time": "日曜 10:00"},
				{"sender": "self", "text": "なんで返事しないの", "time": "日曜 18:45"},
				{"sender": "self", "text": "夏澈？？", "time": "月曜 09:12"},
				{"sender": "self", "text": "どこにいるの？電話も出ないし", "time": "月曜 14:30"},
				{"sender": "self", "text": "夏澈、どこにいるの……", "time": "月曜 22:00"},
				{"sender": "self", "text": "……私が探しに行く。", "time": "火曜 08:00"},
			],
		},
	},
}
