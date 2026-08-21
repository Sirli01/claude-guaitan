extends CanvasLayer
## HUD - 显示楼层、提示

@onready var floor_label: Label = $TopBar/FloorLabel
@onready var hint_label: Label = $HintLabel
@onready var rule_notification: PanelContainer = $RuleNotification
@onready var rule_notify_text: Label = $RuleNotification/Label

var _hint_tween: Tween = null

func _ready() -> void:
	GameManager.floor_changed.connect(_on_floor_changed)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	rule_notification.visible = false
	hint_label.visible = false
	# 隐藏时间标签（如果场景树中还存在的话）
	var time_label = get_node_or_null("TopBar/TimeLabel")
	if time_label:
		time_label.visible = false
	# 初始化楼层标签
	_on_floor_changed(GameManager.current_floor)

func _on_floor_changed(new_floor: GameManager.Floor) -> void:
	match new_floor:
		GameManager.Floor.PROLOGUE:
			floor_label.text = LocaleManager.t("floor_prologue")
		GameManager.Floor.STREET:
			floor_label.text = LocaleManager.t("floor_street")
		GameManager.Floor.FLOOR_1:
			floor_label.text = LocaleManager.t("floor_1")
		GameManager.Floor.FLOOR_2:
			floor_label.text = LocaleManager.t("floor_2")
		GameManager.Floor.FLOOR_3:
			floor_label.text = LocaleManager.t("floor_3")
		GameManager.Floor.ENDING:
			floor_label.text = "???"

func show_hint(text: String, duration: float = 3.0) -> void:
	hint_label.text = text
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	if _hint_tween and _hint_tween.is_running():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)
	_hint_tween.tween_callback(func(): hint_label.visible = false)

func _on_locale_changed(_locale: String) -> void:
	_on_floor_changed(GameManager.current_floor)

func show_rule_notification(rule_text: String) -> void:
	rule_notify_text.text = LocaleManager.t("rule_update") + rule_text
	rule_notification.visible = true
	rule_notification.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(rule_notification, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.0)
	tween.tween_property(rule_notification, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): rule_notification.visible = false)
