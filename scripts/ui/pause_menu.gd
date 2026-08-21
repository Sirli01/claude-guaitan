extends CanvasLayer
## 暂停菜单 — ESC打开，包含音量设置、按键说明、道具说明、提示

var is_open: bool = false
var _current_tab: int = 0  # 0=设置, 1=按键, 2=道具, 3=提示

# ── 场景节点引用 ──
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MainVBox/TitleLabel

## 标签页按钮
@onready var tab_buttons: Array[Button] = [
	$Panel/MainVBox/TabButtons/Tab0,
	$Panel/MainVBox/TabButtons/Tab1,
	$Panel/MainVBox/TabButtons/Tab2,
	$Panel/MainVBox/TabButtons/Tab3,
]

## 标签页内容容器
@onready var tab_pages: Array[ScrollContainer] = [
	$Panel/MainVBox/ContentArea/SettingsPage,
	$Panel/MainVBox/ContentArea/KeysPage,
	$Panel/MainVBox/ContentArea/ItemsPage,
	$Panel/MainVBox/ContentArea/TipsPage,
]

# ── 设置页节点 ──
@onready var lang_label: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/LangHBox/LangLabel
@onready var zh_btn: Button = $Panel/MainVBox/ContentArea/SettingsPage/VBox/LangHBox/ZhBtn
@onready var en_btn: Button = $Panel/MainVBox/ContentArea/SettingsPage/VBox/LangHBox/EnBtn
@onready var ja_btn: Button = $Panel/MainVBox/ContentArea/SettingsPage/VBox/LangHBox/JaBtn
@onready var master_label: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/MasterHBox/MasterLabel
@onready var master_slider: HSlider = $Panel/MainVBox/ContentArea/SettingsPage/VBox/MasterHBox/MasterSlider
@onready var master_val: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/MasterHBox/MasterVal
@onready var bgm_label: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/BgmHBox/BgmLabel
@onready var bgm_slider: HSlider = $Panel/MainVBox/ContentArea/SettingsPage/VBox/BgmHBox/BgmSlider
@onready var bgm_val: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/BgmHBox/BgmVal
@onready var sfx_label: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/SfxHBox/SfxLabel
@onready var sfx_slider: HSlider = $Panel/MainVBox/ContentArea/SettingsPage/VBox/SfxHBox/SfxSlider
@onready var sfx_val: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/SfxHBox/SfxVal
@onready var amb_label: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/AmbHBox/AmbLabel
@onready var amb_slider: HSlider = $Panel/MainVBox/ContentArea/SettingsPage/VBox/AmbHBox/AmbSlider
@onready var amb_val: Label = $Panel/MainVBox/ContentArea/SettingsPage/VBox/AmbHBox/AmbVal
@onready var fullscreen_check: CheckButton = $Panel/MainVBox/ContentArea/SettingsPage/VBox/FullscreenCheck

# ── 动态内容容器 ──
@onready var keys_vbox: VBoxContainer = $Panel/MainVBox/ContentArea/KeysPage/KeysVBox
@onready var items_vbox: VBoxContainer = $Panel/MainVBox/ContentArea/ItemsPage/ItemsVBox
@onready var tips_vbox: VBoxContainer = $Panel/MainVBox/ContentArea/TipsPage/TipsVBox

# ── 底部按钮 ──
@onready var restart_btn: Button = $Panel/MainVBox/BottomButtons/RestartButton
@onready var quit_btn: Button = $Panel/MainVBox/BottomButtons/QuitButton
@onready var resume_btn: Button = $Panel/MainVBox/BottomButtons/ResumeButton
@onready var close_hint: Label = $Panel/MainVBox/CloseHint


## 暂停菜单初始化：构建标签页并应用多语言文本
func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# 连接标签页按钮
	for i in tab_buttons.size():
		var idx := i
		tab_buttons[i].pressed.connect(func(): _switch_tab(idx))

	# 连接底部按钮
	restart_btn.pressed.connect(_on_restart_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	resume_btn.pressed.connect(close)

	# 初始化设置页
	_setup_settings_page()

	# 应用多语言
	_apply_locale()
	LocaleManager.locale_changed.connect(func(_l): _apply_locale())

	AudioManager.wire_button_clicks(self)


## 输入处理 — ESC 打开/关闭。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (is_open and event.is_action_pressed("ui_close")):
		if _is_other_ui_open():
			return
		if is_open:
			close()
		elif event.is_action_pressed("ui_cancel") and GameManager.current_state in [GameManager.GameState.PLAYING, GameManager.GameState.PAUSED]:
			open()
		get_viewport().set_input_as_handled()


## 检查是否有其他 UI 打开（背包、手机等）。
## [return] 如果有其他 UI 打开则返回 true。
func _is_other_ui_open() -> bool:
	return get_tree().paused and not is_open


## 打开暂停菜单。
func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	GameManager.set_state(GameManager.GameState.PAUSED)
	AudioManager.play_system_open()
	_switch_tab(0)
	_refresh_items_tab()


## 关闭暂停菜单。
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)


## 应用多语言文本到所有静态节点。
func _apply_locale() -> void:
	title_label.text = LocaleManager.t("pause_title")

	# 标签页按钮
	var tab_names: Array[String] = [
		LocaleManager.t("tab_settings"),
		LocaleManager.t("tab_controls"),
		LocaleManager.t("tab_items"),
		LocaleManager.t("tab_tips"),
	]
	for i in tab_buttons.size():
		tab_buttons[i].text = tab_names[i]

	# 设置页
	lang_label.text = LocaleManager.t("language_label")
	zh_btn.text = LocaleManager.t("lang_zh")
	en_btn.text = LocaleManager.t("lang_en")
	ja_btn.text = LocaleManager.t("lang_ja")
	master_label.text = LocaleManager.t("vol_master")
	bgm_label.text = LocaleManager.t("vol_bgm")
	sfx_label.text = LocaleManager.t("vol_sfx")
	amb_label.text = LocaleManager.t("vol_ambience")
	fullscreen_check.text = LocaleManager.t("fullscreen")

	# 底部按钮
	restart_btn.text = LocaleManager.t("btn_restart")
	quit_btn.text = LocaleManager.t("quit_btn")
	resume_btn.text = LocaleManager.t("btn_resume")
	close_hint.text = LocaleManager.t("close_hint")

	# 刷新动态内容
	_refresh_keys_tab()
	_refresh_tips_tab()
	_refresh_items_tab()

	# 更新语言按钮高亮
	_update_lang_highlight()


## 初始化设置页：连接滑块信号、读取当前音量。
func _setup_settings_page() -> void:
	# 语言按钮
	zh_btn.pressed.connect(func(): LocaleManager.set_locale("zh"))
	en_btn.pressed.connect(func(): LocaleManager.set_locale("en"))
	ja_btn.pressed.connect(func(): LocaleManager.set_locale("ja"))

	# 音量滑块
	_init_slider(master_slider, master_val, "Master")
	_init_slider(bgm_slider, bgm_val, "BGM")
	_init_slider(sfx_slider, sfx_val, "SFX")
	_init_slider(amb_slider, amb_val, "Ambience")

	# 全屏切换
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(func(on: bool) -> void:
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)


## 初始化音量滑块，绑定到音频总线并更新百分比显示。
## [param slider] HSlider 节点。
## [param val_label] 显示百分比的 Label。
## [param bus_name] 音频总线名称。
func _init_slider(slider: HSlider, val_label: Label, bus_name: String) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	else:
		slider.value = 1.0
	val_label.text = "%d%%" % int(slider.value * 100)

	slider.value_changed.connect(func(val: float) -> void:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(val))
		val_label.text = "%d%%" % int(val * 100)
	)


## 切换标签页显示。
## [param idx] 标签页索引（0-3）。
func _switch_tab(idx: int) -> void:
	_current_tab = idx
	for i in tab_pages.size():
		tab_pages[i].visible = (i == idx)
	for i in tab_buttons.size():
		if i == idx:
			tab_buttons[i].add_theme_color_override("font_color", Color(1, 0.9, 0.7))
		else:
			tab_buttons[i].remove_theme_color_override("font_color")


## 刷新按键说明标签页内容。
func _refresh_keys_tab() -> void:
	_clear_children(keys_vbox)
	for binding in LocaleManager.key_bindings():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var key_lbl := Label.new()
		key_lbl.text = binding.action
		key_lbl.custom_minimum_size = Vector2(400, 0)
		key_lbl.add_theme_font_size_override("font_size", 36)
		key_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
		hbox.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = binding.desc
		desc_lbl.add_theme_font_size_override("font_size", 36)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.7))
		hbox.add_child(desc_lbl)

		keys_vbox.add_child(hbox)


## 刷新提示标签页内容。
func _refresh_tips_tab() -> void:
	_clear_children(tips_vbox)

	var tips_title := Label.new()
	tips_title.text = LocaleManager.t("tips_title")
	tips_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips_title.add_theme_font_size_override("font_size", 40)
	tips_title.add_theme_color_override("font_color", Color(0.8, 0.65, 0.5))
	tips_vbox.add_child(tips_title)

	var sep := HSeparator.new()
	tips_vbox.add_child(sep)

	for tip in LocaleManager.gameplay_tips():
		var tip_lbl := Label.new()
		tip_lbl.text = "· " + tip
		tip_lbl.add_theme_font_size_override("font_size", 32)
		tip_lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.65))
		tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tips_vbox.add_child(tip_lbl)


## 刷新道具标签页内容。
func _refresh_items_tab() -> void:
	_clear_children(items_vbox)

	var discovered := InventoryManager.discovered_items
	var has_any := false

	for item_id in discovered:
		var data := InventoryManager.get_item_data(item_id)
		if data.is_empty():
			continue

		# 构建效果描述
		var effect_text := ""
		if data.has("effects"):
			var parts: Array[String] = []
			for eff in data.effects:
				match eff.type:
					"stamina":
						parts.append(LocaleManager.t("effect_stamina") % eff.value)
					"sanity":
						parts.append(LocaleManager.t("effect_sanity") % eff.value)
			effect_text = LocaleManager.t("effect_prefix") + ", ".join(parts)
		elif data.has("consumable") and data.consumable:
			if item_id == "match":
				effect_text = LocaleManager.t("effect_prefix") + LocaleManager.t("effect_match")
			elif item_id == "battery":
				effect_text = LocaleManager.t("effect_prefix") + LocaleManager.t("effect_battery")

		var item_box := VBoxContainer.new()
		item_box.add_theme_constant_override("separation", 2)

		# 物品名 + 分类
		var name_lbl := Label.new()
		var cat_text := ""
		match data.get("category", ""):
			"key":      cat_text = LocaleManager.t("cat_key")
			"food":     cat_text = LocaleManager.t("cat_food")
			"medicine": cat_text = LocaleManager.t("cat_medicine")
			"special":  cat_text = LocaleManager.t("cat_special")
		name_lbl.text = "%s  %s%s" % [data.name, cat_text, effect_text]
		name_lbl.add_theme_font_size_override("font_size", 34)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
		item_box.add_child(name_lbl)

		# 描述
		var desc_lbl := Label.new()
		desc_lbl.text = "    %s" % data.description
		desc_lbl.add_theme_font_size_override("font_size", 30)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.55))
		item_box.add_child(desc_lbl)

		items_vbox.add_child(item_box)
		has_any = true

	if not has_any:
		var empty := Label.new()
		empty.text = LocaleManager.t("no_items")
		empty.add_theme_font_size_override("font_size", 40)
		empty.add_theme_color_override("font_color", Color(0.4, 0.38, 0.45))
		items_vbox.add_child(empty)


## 更新语言按钮高亮，当前语言按钮显示为强调色。
func _update_lang_highlight() -> void:
	zh_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "zh" else Color(0.6, 0.6, 0.65, 1)
	en_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "en" else Color(0.6, 0.6, 0.65, 1)
	ja_btn.modulate = Color(1, 1, 1, 1) if LocaleManager.current_locale == "ja" else Color(0.6, 0.6, 0.65, 1)


## 清空容器的所有子节点。
## [param node] 要清空的容器节点。
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


## 重新开始当前关卡。
func _on_restart_pressed() -> void:
	var scene_path := get_tree().current_scene.scene_file_path
	visible = false
	get_tree().paused = false
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)


## 退出游戏。
func _on_quit_pressed() -> void:
	get_tree().quit()
