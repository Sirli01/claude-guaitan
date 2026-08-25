extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://scenes/ui/phone_ui.tscn")
	if ps == null:
		print("PHONE_FAIL")
		quit(1)
		return
	var inst := ps.instantiate()
	print("PHONE_OK" if inst != null else "PHONE_FAIL")
	if inst: inst.free()
	quit(0)
