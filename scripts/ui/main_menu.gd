extends Control
## 主菜单 — 开始/继续/设置/退出

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var settings_btn: Button = $VBoxContainer/SettingsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

## 设置面板
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var header_label: Label = $SettingsPanel/VBox/HeaderLabel
@onready var zh_btn: Button = $SettingsPanel/VBox/LangHBox/ZhButton
@onready var en_btn: Button = $SettingsPanel/VBox/LangHBox/EnButton
@onready var ja_btn: Button = $SettingsPanel/VBox/LangHBox/JaButton
@onready var master_label: Label = $SettingsPanel/VBox/MasterHBox/MasterLabel
@onready var master_slider: HSlider = $SettingsPanel/VBox/MasterHBox/MasterSlider
@onready var bgm_label: Label = $SettingsPanel/VBox/BgmHBox/BgmLabel
@onready var bgm_slider: HSlider = $SettingsPanel/VBox/BgmHBox/BgmSlider
@onready var sfx_label: Label = $SettingsPanel/VBox/SfxHBox/SfxLabel
@onready var sfx_slider: HSlider = $SettingsPanel/VBox/SfxHBox/SfxSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBox/FullscreenCheck


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	AudioManager.wire_button_clicks(self)

	_apply_locale()
	LocaleManager.locale_changed.connect(func(_l): _apply_locale())

	# 没有存档时灰掉继续按钮
	continue_btn.disabled = not SaveManager.has_save()
	if continue_btn.disabled:
		continue_btn.modulate.a = 0.4

	_animate_title()

	# 手柄支持：首个按钮获取焦点，确保D-pad/摇杆可导航
	start_btn.grab_focus()

	# 主菜单BGM（直接全音量播放，无渐入）
	var bgm_path = "res://assets/audio/bgm/title_bgm.mp3"
	if ResourceLoader.exists(bgm_path):
		AudioManager.bgm_player.stream = load(bgm_path)
		AudioManager.bgm_player.volume_db = -5.0
		AudioManager.bgm_player.play()

	# 初始化设置面板
	_setup_settings()


## 应用多语言文本。
func _apply_locale() -> void:
	title_label.text = LocaleManager.t("game_title")
	start_btn.text = LocaleManager.t("start_btn")
	continue_btn.text = LocaleManager.t("continue_btn")
	settings_btn.text = LocaleManager.t("settings_btn")
	quit_btn.text = LocaleManager.t("quit_btn")

	# 设置面板
	header_label.text = LocaleManager.t("settings_title")
	zh_btn.text = LocaleManager.t("lang_zh")
	en_btn.text = LocaleManager.t("lang_en")
	ja_btn.text = LocaleManager.t("lang_ja")
	master_label.text = LocaleManager.t("vol_master")
	bgm_label.text = LocaleManager.t("vol_bgm")
	sfx_label.text = LocaleManager.t("vol_sfx")
	fullscreen_check.text = LocaleManager.t("fullscreen")


## 标题淡入动画。
func _animate_title() -> void:
	title_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)


## 开始新游戏。
func _on_start() -> void:
	AudioManager.bgm_player.stop()
	GameManager.start_new_game()


## 继续存档。
func _on_continue() -> void:
	AudioManager.bgm_player.stop()
	SaveManager.load_game()


## 退出游戏。
func _on_quit() -> void:
	get_tree().quit()


## 切换设置面板显示/隐藏。
func _on_settings() -> void:
	settings_panel.visible = not settings_panel.visible


## 初始化设置面板：连接信号、设置初始值。
func _setup_settings() -> void:
	# 语言按钮
	zh_btn.pressed.connect(func(): LocaleManager.set_locale("zh"))
	en_btn.pressed.connect(func(): LocaleManager.set_locale("en"))
	ja_btn.pressed.connect(func(): LocaleManager.set_locale("ja"))

	# 音量滑块
	_init_volume_slider(master_slider, "Master")
	_init_volume_slider(bgm_slider, "BGM")
	_init_volume_slider(sfx_slider, "SFX")

	# 全屏切换
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# 更新语言按钮高亮
	_update_lang_highlight()

	AudioManager.wire_button_clicks(settings_panel)


## 初始化音量滑块，绑定到对应的音频总线。
## [param slider] HSlider 节点。
## [param bus_name] 音频总线名称。
func _init_volume_slider(slider: HSlider, bus_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	else:
		slider.value = 0.8
	slider.value_changed.connect(func(val: float) -> void:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(val))
	)


## 全屏切换回调。
## [param on] 是否全屏。
func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## 更新语言按钮高亮，当前语言按钮显示为强调色。
func _update_lang_highlight() -> void:
	zh_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "zh" else Color(0.6, 0.6, 0.65, 1)
	en_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "en" else Color(0.6, 0.6, 0.65, 1)
	ja_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "ja" else Color(0.6, 0.6, 0.65, 1)
