extends Control
## 游戏结束界面 — 根据死因显示不同画面

## 死因 → {标题, 副标题, 颜色}
const DEATH_INFO := {
	"insanity": {
		"title": "精神崩溃",
		"subtitle": "你的理智已经完全崩塔……",
		"color": Color(0.6, 0.1, 0.2),
	},
	"abyss": {
		"title": "深渊吞噬",
		"subtitle": "地板下的巨口将你拖入了永恒的黑暗……",
		"color": Color(0.3, 0.05, 0.15),
	},
	"chase_caught": {
		"title": "未能逃脱",
		"subtitle": "巨口追上了你……再也没有下一次机会。",
		"color": Color(0.4, 0.0, 0.1),
	},
	"monster": {
		"title": "被它抓住了",
		"subtitle": "那个东西的红眼睛是你最后看到的东西……",
		"color": Color(0.5, 0.0, 0.0),
	},
}

@onready var title_label: Label = $CenterBox/TitleLabel
@onready var subtitle_label: Label = $CenterBox/SubtitleLabel
@onready var retry_floor_btn: Button = $CenterBox/RetryFloorButton
@onready var retry_all_btn: Button = $CenterBox/RetryAllButton
@onready var menu_btn: Button = $CenterBox/MenuButton

var _title_tween: Tween


func _ready() -> void:
	var info := _get_death_info()

	# 设置文字和颜色
	title_label.text = info.get("title", "??")
	title_label.add_theme_color_override("font_color", info.get("color", Color(0.6, 0.1, 0.2)))
	subtitle_label.text = info.get("subtitle", "")

	# 设置按钮文本
	retry_floor_btn.text = LocaleManager.t("retry_floor")
	retry_all_btn.text = LocaleManager.t("retry_all")
	menu_btn.text = LocaleManager.t("main_menu_btn")

	# 连接信号
	retry_floor_btn.pressed.connect(func(): GameManager.restart_current_floor())
	retry_all_btn.pressed.connect(func(): GameManager.start_new_game())
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

	AudioManager.wire_button_clicks(self)

	# 标题闪烁动画
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "modulate:a", 0.4, 1.5)
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 1.5)

	# 手柄支持
	retry_floor_btn.grab_focus()


func _exit_tree() -> void:
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()


## 获取当前死因对应的信息字典。
## [return] 包含 title、subtitle、color 的字典。
func _get_death_info() -> Dictionary:
	var cause := GameManager.death_cause
	if DEATH_INFO.has(cause):
		return DEATH_INFO[cause]
	# 尝试从 LocaleManager 获取
	var localized := LocaleManager.death_info(cause)
	if localized.has("title"):
		return localized
	return {"title": "??", "subtitle": "", "color": Color(0.6, 0.1, 0.2)}
