extends SceneTree
## 场景截图自测工具：窗口模式加载指定场景，等待若干帧后截图保存并退出。
## 用法：
##   godot --path 项目 --script res://tools/scene_screenshot.gd ++ scene=res://scenes/x.tscn out=C:/shot.png frames=45
## 需要 GPU 渲染（不能加 --headless）。

var _scene := ""
var _out := ""
var _frames := 45
var _count := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_scene = arg.substr(6)
		elif arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("frames="):
			_frames = int(arg.substr(7))
	if _scene != "":
		change_scene_to_file(_scene)
	print("SCREENSHOT_TOOL: scene=%s out=%s frames=%d" % [_scene, _out, _frames])

func _process(_delta: float) -> bool:
	_count += 1
	if _count % 150 == 0:
		print("FRAME_PROGRESS: %d" % _count)
	if _count < _frames:
		return false
	var img := root.get_texture().get_image()
	if _out != "":
		var err := img.save_png(_out)
		print("SAVED(%s): %s" % [_out, error_string(err)])
	else:
		print("NO_OUT_PATH")
	return true
