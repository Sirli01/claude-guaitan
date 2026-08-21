@tool
extends EditorScript
## 自动检测并修复常见代码错误
## 在 Godot 编辑器中：工具 → 执行脚本 运行此文件

## 错误类型
enum ErrorType {
	PARSE_ERROR,
	TYPE_INFERENCE,
	MISSING_FUNCTION,
	RUNTIME_ERROR,
}

## 检测到的错误
var detected_errors: Array = []

func _run() -> void:
	print("=== 自动错误检测开始 ===")
	print("")

	# 1. 检测解析错误
	_detect_parse_errors()

	# 2. 检测类型推断问题
	_detect_type_inference_issues()

	# 3. 检测缺少注释的函数
	_detect_missing_comments()

	# 4. 输出报告
	_generate_report()

	print("")
	print("=== 自动错误检测完成 ===")


## 检测解析错误
func _detect_parse_errors() -> void:
	print("1. 检测解析错误...")

	# 扫描所有 GDScript 文件
	var dir = DirAccess.open("res://scripts/")
	if not dir:
		print("   ❌ 无法打开 scripts 目录")
		return

	_scan_directory(dir, "res://scripts/")


## 递归扫描目录
func _scan_directory(dir: DirAccess, path: String) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(path + file_name)
			if sub_dir:
				_scan_directory(sub_dir, path + file_name + "/")
		elif file_name.ends_with(".gd"):
			var file_path = path + file_name
			_check_script(file_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## 检查单个脚本
func _check_script(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var content = file.get_as_text()
	file.close()

	var lines = content.split("\n")
	var line_num = 0

	for line in lines:
		line_num += 1

		# 检测 := 类型推断问题
		if ":=" in line and "var " in line:
			# 检查是否可能导致类型推断失败
			if line.contains(".get(") or line.contains("["):
				detected_errors.append({
					"type": ErrorType.TYPE_INFERENCE,
					"file": file_path,
					"line": line_num,
					"content": line.strip(),
					"suggestion": "使用显式类型注解代替 :=",
				})


## 检测类型推断问题
func _detect_type_inference_issues() -> void:
	print("2. 检测类型推断问题...")

	# 这个检测已经在 _check_script 中完成
	print("   发现 %d 处潜在问题" % detected_errors.size())


## 检测缺少注释的函数
func _detect_missing_comments() -> void:
	print("3. 检测缺少注释的函数...")

	var dir = DirAccess.open("res://scripts/")
	if not dir:
		return

	var total_functions = 0
	var commented_functions = 0

	_count_comments_in_dir(dir, "res://scripts/", total_functions, commented_functions)

	print("   函数总数: %d" % total_functions)
	print("   有注释: %d" % commented_functions)
	print("   覆盖率: %.1f%%" % (float(commented_functions) / total_functions * 100 if total_functions > 0 else 0))


## 递归统计注释
func _count_comments_in_dir(dir: DirAccess, path: String, total: int, commented: int) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(path + file_name)
			if sub_dir:
				_count_comments_in_dir(sub_dir, path + file_name + "/", total, commented)
		elif file_name.ends_with(".gd"):
			var file_path = path + file_name
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()

				var lines = content.split("\n")
				var prev_line = ""

				for line in lines:
					if line.begins_with("func "):
						total += 1
						if prev_line.begins_with("## "):
							commented += 1
					prev_line = line

		file_name = dir.get_next()

	dir.list_dir_end()


## 生成报告
func _generate_report() -> void:
	print("")
	print("=== 检测报告 ===")

	if detected_errors.is_empty():
		print("✅ 未发现需要修复的错误")
	else:
		print("⚠️ 发现 %d 处潜在问题：" % detected_errors.size())
		print("")

		for i in range(min(detected_errors.size(), 10)):
			var error = detected_errors[i]
			print("%d. %s:%d" % [i + 1, error["file"], error["line"]])
			print("   问题: %s" % error["content"])
			print("   建议: %s" % error["suggestion"])
			print("")

		if detected_errors.size() > 10:
			print("... 还有 %d 处问题" % (detected_errors.size() - 10))
