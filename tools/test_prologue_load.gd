extends SceneTree
## 临时验证脚本：加载并实例化已迁移的场景，检查 tscn 与脚本能否正常解析、关键节点齐全。

## 待验证的场景与各自必需的节点
const CHECKS := [
	{
		"scene": "res://scenes/levels/prologue_room.tscn",
		"nodes": ["Player", "PhoneArea", "DoorArea", "HUDLayer"],
		"uniques": ["Player", "PhoneArea", "DoorArea", "HUDLayer", "FloorLabel", "StaminaBar", "SanityBar"],
		"player_child": "PointLight2D",
	},
	{
		"scene": "res://scenes/levels/prologue_street.tscn",
		"nodes": ["Player", "HUDLayer", "ParallaxBG", "FgBuildings", "LeftBorder", "RightBorder", "HomeEntrance", "ApartmentEntrance", "Interactables", "InventoryLayer"],
		"uniques": ["Player", "HUDLayer", "FloorLabel", "StaminaBar", "SanityBar", "ParallaxBG", "FgBuildings", "Interactables", "InventoryLayer"],
		"player_child": "PointLight2D",
	},
]

func _init() -> void:
	var failed := false
	for check in CHECKS:
		var errors := _check_scene(check)
		if errors.is_empty():
			print("SCENE_OK: ", check["scene"])
		else:
			failed = true
			for e in errors:
				push_error("FAIL [%s]: %s" % [check["scene"], e])
	if failed:
		quit(1)
	else:
		quit(0)

## 校验单个场景：加载、实例化、节点存在性、唯一名称、玩家可编辑子节点。
## [param check] CHECKS 中的一项配置。[return] 错误列表（空表示通过）。
func _check_scene(check: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var ps: PackedScene = load(check["scene"])
	if ps == null:
		errors.append("无法加载场景文件")
		return errors
	var inst: Node = ps.instantiate()
	if inst == null:
		errors.append("无法实例化场景")
		return errors
	for required in check["nodes"]:
		if inst.get_node_or_null(NodePath(required)) == null:
			errors.append("缺少节点: " + required)
	for uname in check["uniques"]:
		if not inst.has_node("%" + uname):
			errors.append("唯一名称不可用: %" + uname)
	var player_node: Node = inst.get_node_or_null("Player")
	if player_node and player_node.get_node_or_null(NodePath(check["player_child"])) == null:
		errors.append("Player 缺少 " + check["player_child"])
	inst.free()
	return errors
