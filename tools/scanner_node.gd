extends Node

## 运行时扫描器：在 autoload 已加载的真实环境下，
## 编译所有脚本、实例化所有场景（短暂挂树）并收集错误。

var _pending_scenes: Array[String] = []
var _current_scene_path: String = ""
var _error_count: int = 0

## 入口：收集所有脚本与场景文件。
func _ready() -> void:
	var script_files: Array[String] = []
	_pending_scenes = []
	_collect_files("res://scenes", script_files, _pending_scenes)
	_collect_files("res://scripts", script_files, _pending_scenes)

	print("=== 运行时扫描开始: %d 个脚本, %d 个场景 ===" % [script_files.size(), _pending_scenes.size()])
	for path in script_files:
		_check_script(path)
	_run_scene_checks()

## 递归收集目录下的脚本与场景文件。
func _collect_files(dir_path: String, script_files: Array[String], scene_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: " + dir_path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_files(full, script_files, scene_files)
		else:
			if name.ends_with(".gd") and not full.begins_with("res://tools/"):
				script_files.append(full)
			elif name.ends_with(".tscn"):
				scene_files.append(full)
		name = dir.get_next()

## 编译单个脚本（autoload 已注册，可验证跨单例引用）。
func _check_script(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		_report("脚本加载失败: " + path)
		return

## 逐个场景实例化并挂树两帧后释放，捕获 @onready 与路径错误。
func _run_scene_checks() -> void:
	_check_next_scene()

## 处理下一个场景（异步链式调用）。
func _check_next_scene() -> void:
	if _pending_scenes.is_empty():
		print("=== 扫描完成: 共捕获 %d 个错误 ===" % _error_count)
		get_tree().quit(0)
		return
	_current_scene_path = _pending_scenes.pop_front()
	var packed: PackedScene = load(_current_scene_path)
	if packed == null:
		_report("场景加载失败: " + _current_scene_path)
		_check_next_scene.call_deferred()
		return
	var inst := packed.instantiate()
	if inst == null:
		_report("场景实例化失败: " + _current_scene_path)
		_check_next_scene.call_deferred()
		return
	add_child(inst)
	for i in range(60):
		await get_tree().process_frame
	_check_export_paths(inst)
	_print_speed_info(inst)
	inst.queue_free()
	await get_tree().process_frame
	_check_next_scene()

## 检查场景内所有节点的导出 NodePath 是否能解析。
func _check_export_paths(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: GDScript = node.get_script() as GDScript
		if script != null:
			var props: Array[Dictionary] = script.get_script_property_list()
			for p: Dictionary in props:
				if p.usage & PROPERTY_USAGE_EDITOR:
					var val: Variant = node.get(p.name)
					if val is NodePath and not (val as NodePath).is_empty():
						var target := node.get_node_or_null(val)
						if target == null:
							_report("%s: 节点 '%s' 属性 '%s' 指向不存在的节点 -> %s" % [_current_scene_path, node.name, p.name, str(val)])
		for child in node.get_children():
			stack.push_back(child)

## 输出该场景的速度基准信息（world_scale / 玩家实际速度），汇总成全关卡速度表。
func _print_speed_info(root: Node) -> void:
	var line := _current_scene_path.get_file()
	var ws_v: Variant = root.get("world_scale")
	if ws_v != null:
		line += " | world_scale=%.2f" % ws_v
	var player_v: Variant = root.get("player")
	if player_v is CharacterBody2D and is_instance_valid(player_v):
		var walk: Variant = (player_v as Node).get("walk_speed")
		var run: Variant = (player_v as Node).get("run_speed")
		if walk != null:
			line += " | 玩家 walk=%.0f" % walk
		if run != null:
			line += " run=%.0f" % run
	print("[SPEED] " + line)

## 记录并打印一条错误。
func _report(msg: String) -> void:
	_error_count += 1
	printerr("[SCANNER] " + msg)
