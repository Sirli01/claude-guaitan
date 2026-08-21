extends SceneTree
## 临时验证脚本：加载并实例化序章房间场景，检查 tscn 与脚本能否正常解析。

func _init() -> void:
	var ps: PackedScene = load("res://scenes/levels/prologue_room.tscn")
	if ps == null:
		push_error("FAIL: 无法加载 prologue_room.tscn")
		quit(1)
		return
	var inst: Node = ps.instantiate()
	if inst == null:
		push_error("FAIL: 无法实例化场景")
		quit(1)
		return
	var errors: PackedStringArray = []
	# 检查关键节点是否存在
	for required in ["Player", "PhoneArea", "DoorArea", "HUDLayer"]:
		if inst.get_node_or_null(NodePath(required)) == null:
			errors.append("缺少节点: " + required)
	# 检查唯一名称可用
	for uname in ["Player", "PhoneArea", "DoorArea", "HUDLayer", "FloorLabel", "StaminaBar", "SanityBar"]:
		if not inst.has_node("%" + uname):
			errors.append("唯一名称不可用: %" + uname)
	# 检查玩家可编辑子节点（灯光）
	var player_node: Node = inst.get_node_or_null("Player")
	if player_node and player_node.get_node_or_null("PointLight2D") == null:
		errors.append("Player 缺少 PointLight2D")
	if errors.is_empty():
		print("SCENE_OK: 所有节点与唯一名称校验通过")
		quit(0)
	else:
		for e in errors:
			push_error("FAIL: " + e)
		quit(1)
