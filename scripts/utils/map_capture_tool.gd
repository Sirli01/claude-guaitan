class_name MapCaptureTool
## 全地图截图工具 — 从 player.gd 提取的调试截图功能
## 按 F12 触发，自动计算场景边界并保存截图到桌面

## 执行全地图截图
## [param player] 玩家节点（需要 camera）
static func capture_full_map(player: CharacterBody2D) -> void:
	if not player or not player.camera:
		return
	var camera: Camera2D = player.camera
	var scene_root: Node = player.get_tree().current_scene

	# 计算场景中所有可见节点的边界
	var bounds: Rect2 = _calc_scene_bounds(scene_root)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_warning("MapCapture: 未找到可见节点，无法截图")
		return

	# 加一圈 padding
	var padding: float = 40.0
	bounds = bounds.grow(padding)
	var map_size: Vector2 = bounds.size
	var map_center: Vector2 = bounds.position + bounds.size / 2.0

	# 保存原始状态
	var old_zoom: Vector2 = camera.zoom
	var old_pos: Vector2 = player.global_position
	var old_smoothing: bool = camera.position_smoothing_enabled

	# 计算合适的 zoom 使地图刚好填满视口
	var viewport_size := player.get_viewport().get_visible_rect().size
	var zoom_x := viewport_size.x / map_size.x
	var zoom_y := viewport_size.y / map_size.y
	var fit_zoom := minf(zoom_x, zoom_y) * 0.95

	# 关闭摄像头平滑，移动到地图中心
	camera.position_smoothing_enabled = false
	player.global_position = map_center
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	camera.force_update_scroll()

	# 临时隐藏各类节点
	var hidden_data := _hide_nodes_for_capture(scene_root)

	# 等渲染更新
	await player.get_tree().process_frame
	await player.get_tree().process_frame

	# 截图保存
	var img := player.get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var desktop_dir := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	var path := "map_screenshot_%s.png" % timestamp
	var absolute_path := ""
	if desktop_dir != "":
		absolute_path = desktop_dir.path_join(path)
	else:
		absolute_path = ProjectSettings.globalize_path("user://".path_join(path))
	var save_error := img.save_png(absolute_path)
	if save_error != OK:
		absolute_path = ProjectSettings.globalize_path("user://".path_join(path))
		img.save_png(absolute_path)
		push_warning("MapCapture: 桌面截图保存失败，已回退到: %s" % absolute_path)
	else:
		push_warning("MapCapture: 地图截图已保存: " + absolute_path)
	push_warning("MapCapture: 地图范围: %s ~ %s (%s)" % [bounds.position, bounds.end, map_size])

	# 恢复所有状态
	player.global_position = old_pos
	camera.zoom = old_zoom
	camera.position_smoothing_enabled = old_smoothing
	camera.force_update_scroll()
	_restore_nodes_after_capture(scene_root, hidden_data)

# ====== 内部方法 ======

## 计算场景中所有可见节点的边界
static func _calc_scene_bounds(root: Node) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	_calc_bounds_recursive(root, min_pos, max_pos)
	if min_pos.x == INF:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)

## 递归累加可见节点的边界范围（跳过 CanvasLayer、粒子、灯光等）。
## [param node] 当前遍历节点。
## [param min_pos] 累计最小坐标。
## [param max_pos] 累计最大坐标。
## [return] 更新后的 [min_pos, max_pos] 数组。
static func _calc_bounds_recursive(node: Node, min_pos: Vector2, max_pos: Vector2) -> Array:
	if node is CanvasLayer or node is GPUParticles2D or node is PointLight2D or node is CanvasModulate:
		return [min_pos, max_pos]
	if node is ColorRect and node.visible:
		var ctrl: ColorRect = node
		if ctrl.size.x >= 8 and ctrl.size.y >= 8 and ctrl.z_index < 10:
			var pos := ctrl.global_position
			min_pos.x = minf(min_pos.x, pos.x)
			min_pos.y = minf(min_pos.y, pos.y)
			max_pos.x = maxf(max_pos.x, pos.x + ctrl.size.x)
			max_pos.y = maxf(max_pos.y, pos.y + ctrl.size.y)
	elif node is Polygon2D and node.visible:
		var poly_node: Polygon2D = node
		for pt in poly_node.polygon:
			var world_pt: Vector2 = poly_node.global_position + pt
			min_pos.x = minf(min_pos.x, world_pt.x)
			min_pos.y = minf(min_pos.y, world_pt.y)
			max_pos.x = maxf(max_pos.x, world_pt.x)
			max_pos.y = maxf(max_pos.y, world_pt.y)
	elif node is StaticBody2D and node.visible:
		var body_node: StaticBody2D = node
		var pos: Vector2 = body_node.global_position
		min_pos.x = minf(min_pos.x, pos.x - 16)
		min_pos.y = minf(min_pos.y, pos.y - 16)
		max_pos.x = maxf(max_pos.x, pos.x + 16)
		max_pos.y = maxf(max_pos.y, pos.y + 16)
	for child in node.get_children():
		var result := _calc_bounds_recursive(child, min_pos, max_pos)
		min_pos = result[0]
		max_pos = result[1]
	return [min_pos, max_pos]

## 隐藏截图时不需要的节点
static func _hide_nodes_for_capture(root: Node) -> Dictionary:
	var hidden := {
		"dark_nodes": [], "dark_parents": [],
		"atmo_nodes": [], "light_nodes": [], "old_light_visible": [],
		"ui_nodes": [], "npc_labels": [], "character_sprites": [],
		"ceiling_nodes": [], "labels_hidden": false,
	}
	# 黑暗层、氛围层、灯光
	_find_nodes_by_type(root, hidden["dark_nodes"], hidden["atmo_nodes"], hidden["light_nodes"])
	for n in hidden["dark_nodes"]:
		hidden["dark_parents"].append(n.get_parent())
		n.get_parent().remove_child(n)
	for n in hidden["atmo_nodes"]:
		n.visible = false
	for n in hidden["light_nodes"]:
		hidden["old_light_visible"].append(n.visible)
		n.visible = false
	# 世界标签
	var level := _find_level_root(root)
	if level and level.has_method("set_world_labels_visible"):
		level.set_world_labels_visible(false)
		hidden["labels_hidden"] = true
	# UI 和角色
	_find_ui_nodes(root, hidden["ui_nodes"], hidden["npc_labels"])
	_find_character_sprites(root, hidden["character_sprites"])
	for node in hidden["ui_nodes"]:
		node.visible = false
	for label in hidden["npc_labels"]:
		label.visible = false
	for sprite in hidden["character_sprites"]:
		sprite.visible = false
	# 天花板
	_find_ceilings(root, hidden["ceiling_nodes"])
	for n in hidden["ceiling_nodes"]:
		n.visible = false
	return hidden

## 恢复截图前的状态
static func _restore_nodes_after_capture(root: Node, hidden: Dictionary) -> void:
	for i in hidden["dark_nodes"].size():
		hidden["dark_parents"][i].add_child(hidden["dark_nodes"][i])
	for n in hidden["atmo_nodes"]:
		n.visible = true
	for i in hidden["light_nodes"].size():
		hidden["light_nodes"][i].visible = hidden["old_light_visible"][i]
	for n in hidden["ceiling_nodes"]:
		n.visible = true
	var level := _find_level_root(root)
	if hidden["labels_hidden"] and level and level.has_method("set_world_labels_visible"):
		level.set_world_labels_visible(true)
	for node in hidden["ui_nodes"]:
		node.visible = true
	for label in hidden["npc_labels"]:
		label.visible = true
	for sprite in hidden["character_sprites"]:
		sprite.visible = true

## 向上查找拥有 set_world_labels_visible 方法的关卡根节点。
## [param node] 起始节点。
## [return] 关卡根节点，找不到时为 null。
static func _find_level_root(node: Node) -> Node:
	var n: Node = node
	while n:
		if n.has_method("set_world_labels_visible"):
			return n
		n = n.get_parent()
	return null

## 递归收集黑暗层、氛围层与点光源节点。
## [param node] 当前遍历节点。
## [param dark] 收集 CanvasModulate 的数组。
## [param atmo] 收集 AtmosphereLayer 的数组。
## [param lights] 收集 PointLight2D 的数组。
static func _find_nodes_by_type(node: Node, dark: Array, atmo: Array, lights: Array) -> void:
	if node is CanvasModulate:
		dark.append(node)
	elif node is AtmosphereLayer:
		atmo.append(node)
	elif node is PointLight2D:
		lights.append(node)
	for child in node.get_children():
		_find_nodes_by_type(child, dark, atmo, lights)

## 递归收集可见的 UI 层与 NPC 名牌标签。
## [param node] 当前遍历节点。
## [param ui_nodes] 收集 CanvasLayer 的数组。
## [param npc_labels] 收集 NPC Label 的数组。
static func _find_ui_nodes(node: Node, ui_nodes: Array[CanvasItem], npc_labels: Array[Label]) -> void:
	if node is CanvasLayer and node.visible:
		ui_nodes.append(node)
	if node is Label and node.name == "Label" and node.get_parent() is CharacterBody2D and node.visible:
		npc_labels.append(node)
	for child in node.get_children():
		_find_ui_nodes(child, ui_nodes, npc_labels)

## 递归收集角色（CharacterBody2D 子级）的 Sprite2D。
## [param node] 当前遍历节点。
## [param sprites] 收集到的精灵数组。
static func _find_character_sprites(node: Node, sprites: Array[CanvasItem]) -> void:
	if node is Sprite2D and node.get_parent() is CharacterBody2D and node.visible:
		sprites.append(node)
	for child in node.get_children():
		_find_character_sprites(child, sprites)

## 递归收集天花板色块（高 z_index 且不受光照的 ColorRect）。
## [param node] 当前遍历节点。
## [param ceilings] 收集到的天花板节点数组。
static func _find_ceilings(node: Node, ceilings: Array) -> void:
	if node is CanvasLayer:
		return
	if node is ColorRect and node.z_index >= 10 and node.light_mask == 0:
		ceilings.append(node)
	for child in node.get_children():
		_find_ceilings(child, ceilings)
