extends LevelBaseV2
## 结局 - 细思极恐的收尾
## "她在说谎"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 避免 rule_paper.open() 暂停影响本场景协程
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	GameManager.change_floor(GameManager.Floor.ENDING)
	
	# 确保音频状态干净（尤其是从开发者模式跳转时）
	AudioManager.exit_silence_mode()
	AudioManager._bgm_playlist_active = false
	AudioManager._bgm_playlist.clear()
	AudioManager.bgm_player.stop()
	AudioManager.ambience_player.stop()
	
	# 直接播放结局BGM（绕过异步fade避免tween冲突）
	var demo_bgm_path = "res://assets/audio/bgm/demo结尾.mp3"
	if ResourceLoader.exists(demo_bgm_path):
		AudioManager.bgm_player.stream = load(demo_bgm_path)
		AudioManager.bgm_player.volume_db = -20.0
		AudioManager.bgm_player.play()
		var fade_in = create_tween()
		fade_in.tween_property(AudioManager.bgm_player, "volume_db", -5.0, 3.0)
	
	# 纯黑背景（覆盖全屏）
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	
	# 创建CanvasLayer来显示结局文字
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	
	# 规则纸条UI（setup_ui未调用，手动初始化）
	var rules_layer = CanvasLayer.new()
	rules_layer.layer = 15
	add_child(rules_layer)
	rule_paper = load("res://scenes/ui/rule_paper_ui.tscn").instantiate()
	rules_layer.add_child(rule_paper)
	
	await get_tree().create_timer(2.0).timeout
	_play_ending(ui_layer)

## 通用：逐行显示一组文字，显示完后淡出
func _show_text_block(ui_layer: CanvasLayer, lines: Array) -> void:
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -800
	container.offset_right = 800
	container.offset_top = -160
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_layer.add_child(container)
	
	for line in lines:
		var label = Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 60)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		label.modulate.a = 0.0
		container.add_child(label)
		
		if line != "":
			var tw = create_tween()
			tw.tween_property(label, "modulate:a", 1.0, 0.7)
			await tw.finished
			await get_tree().create_timer(0.4).timeout
		else:
			await get_tree().create_timer(0.15).timeout
	
	await get_tree().create_timer(1.0).timeout
	
	var fade = create_tween()
	fade.tween_property(container, "modulate:a", 0.0, 1.0)
	await fade.finished
	container.queue_free()

func _play_ending(ui_layer: CanvasLayer) -> void:
	# ===== 电梯中：主角掏出纸条 =====
	await _show_text_block(ui_layer, [
		"电梯缓缓上行。",
		"",
		"夏桐下意识地掏出口袋里的规则纸条，想再看一眼。",
	])
	
	await get_tree().create_timer(0.8).timeout
	
	# ===== 打开规则纸条 + 诡异音效同时出现，"她在说谎"缓缓渗出 =====
	var _sfx_gen = preload("res://scripts/utils/procedural_sfx.gd")
	AudioManager.play_sfx(_sfx_gen.ground_rumble(), -8.0)
	AudioManager.play_sfx(_sfx_gen.metal_clang(), -12.0)
	
	if rule_paper and rule_paper.has_method("open"):
		# 先打开纸条（显示已有规则，不含"她在说谎"）
		rule_paper.open()
		# 等纸条淡入（open() 暂停游戏树，但本场景是 PROCESS_MODE_ALWAYS）
		await get_tree().create_timer(0.4).timeout
		# 此时再添加规则，_animate_new_rule 会触发（因为 is_open == true）
		rule_paper.add_rule_with_effect(LocaleManager.t("rule_final_lie"))
		await rule_paper.closed  # 玩家按R关闭
	else:
		# 回退：直接显示文字
		var lie_text_fb = Label.new()
		lie_text_fb.text = StoryText.ENDING_TEXT["the_lie"]
		lie_text_fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lie_text_fb.set_anchors_preset(Control.PRESET_CENTER)
		lie_text_fb.offset_left = -400
		lie_text_fb.offset_right = 400
		lie_text_fb.add_theme_font_size_override("font_size", 88)
		lie_text_fb.add_theme_color_override("font_color", Color(0.8, 0.05, 0.05))
		lie_text_fb.modulate.a = 0.0
		ui_layer.add_child(lie_text_fb)
		var tw_fb = create_tween()
		tw_fb.tween_property(lie_text_fb, "modulate:a", 1.0, 4.0)
		await tw_fb.finished
		await get_tree().create_timer(3.0).timeout
	
	# 清除所有文字
	for child in ui_layer.get_children():
		child.queue_free()
	
	await get_tree().create_timer(2.0).timeout
	
	# ===== Demo End + 感谢文字（居中对齐合并显示）=====
	var end_container = VBoxContainer.new()
	end_container.alignment = BoxContainer.ALIGNMENT_CENTER
	end_container.set_anchors_preset(Control.PRESET_CENTER)
	end_container.offset_left = -400
	end_container.offset_right = 400
	end_container.offset_top = -160
	end_container.offset_bottom = 160
	end_container.modulate.a = 0.0
	ui_layer.add_child(end_container)
	
	var end_label = Label.new()
	end_label.text = StoryText.ENDING_TEXT["demo_end"]
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 60)
	end_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	end_container.add_child(end_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	end_container.add_child(spacer)
	
	var thanks = Label.new()
	thanks.text = StoryText.ENDING_TEXT["thanks"]
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.add_theme_font_size_override("font_size", 56)
	thanks.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	end_container.add_child(thanks)
	
	var tw8 = create_tween()
	tw8.tween_property(end_container, "modulate:a", 1.0, 1.5)
	await tw8.finished
	
	await get_tree().create_timer(4.0).timeout
	
	# 回到主菜单
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
