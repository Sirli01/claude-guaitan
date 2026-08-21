class_name RbSceneRegistry
## rebuild 场景注册表 —— 所有场景路径的唯一真源。
##
## 其他脚本一律使用这里的 key 常量，禁止在业务代码里写 "res://..." 字符串。

const MAIN_MENU: String = "main_menu"
const PROLOGUE_STREET: String = "prologue_street"
const PROLOGUE_ROOM: String = "prologue_room"

const PATHS: Dictionary = {
	MAIN_MENU: "res://rebuild/ui/rb_main_menu.tscn",
	PROLOGUE_STREET: "res://rebuild/scenes/rb_prologue_street.tscn",
	PROLOGUE_ROOM: "res://rebuild/scenes/rb_prologue_room.tscn",
}


static func has_key(scene_key: String) -> bool:
	return PATHS.has(scene_key)


static func resolve_path(scene_key: String) -> String:
	return str(PATHS.get(scene_key, ""))
