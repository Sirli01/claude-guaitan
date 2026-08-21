extends SceneTree
## 代码质量扫描器：统计函数注释覆盖率、检测潜在类型推断问题。
## 用法：godot --headless --path 项目 --script res://tools/code_quality_scan.gd

func _init() -> void:
	var files: PackedStringArray = []
	_collect_files("res://scripts", files)
	_collect_files("res://tools", files)
	_collect_files("res://data", files)

	var total_funcs := 0
	var commented_funcs := 0
	var type_issues: Array[String] = []
	# 每文件统计：path -> [总数, 已注释]
	var per_file := {}

	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var content := f.get_as_text()
		f.close()
		var lines := content.split("\n")
		var file_total := 0
		var file_commented := 0
		for i in lines.size():
			var line: String = lines[i]
			var stripped := line.strip_edges()
			# 函数注释统计：func 定义上一行是 ## 文档注释
			if stripped.begins_with("func ") or stripped.begins_with("static func "):
				total_funcs += 1
				file_total += 1
				var prev := ""
				if i > 0:
					prev = lines[i - 1].strip_edges()
				if prev.begins_with("##"):
					commented_funcs += 1
					file_commented += 1
			# 类型推断风险：var x := ... 且右侧含 .get( 或 [ 下标（返回 Variant）
			if ":=" in line and stripped.begins_with("var ") or (":=" in line and stripped.begins_with("for ")):
				if ".get(" in line or "[" in line:
					type_issues.append("%s:%d  %s" % [path.replace("res://", ""), i + 1, stripped])
		per_file[path] = [file_total, file_commented]

	print("=== 代码质量报告 ===")
	print("扫描文件数: %d" % files.size())
	print("函数总数: %d" % total_funcs)
	print("有文档注释: %d" % commented_funcs)
	if total_funcs > 0:
		print("注释覆盖率: %.1f%%" % (float(commented_funcs) / float(total_funcs) * 100.0))
	print("")
	print("--- 缺注释最多的文件（前 25）---")
	var ranked: Array = []
	for path in per_file:
		var stat: Array = per_file[path]
		if stat[0] > 0:
			ranked.append([stat[0] - stat[1], path.replace("res://", ""), stat[0], stat[1]])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(25, ranked.size()):
		var r: Array = ranked[i]
		print("%3d 缺 | %3d 函数 | %s" % [r[0], r[2], r[1]])
	print("")
	print("--- 潜在类型推断问题 (%d 处) ---" % type_issues.size())
	for issue in type_issues:
		print(issue)
	quit(0)

## 递归收集目录下所有 .gd 文件路径。
## [param path] 起始目录。[param out] 结果数组。
func _collect_files(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_files(path + "/" + name, out)
		elif name.ends_with(".gd"):
			out.append(path + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
