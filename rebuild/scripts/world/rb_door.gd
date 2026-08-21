class_name RbDoor
extends RbInteractable
## rebuild 门 —— 请求切换到另一个场景。
##
## 门本身不调用场景加载器，只发 scene_change_requested，由关卡根节点执行切换。

## 请求切换场景。spawn_id 表示到达目标关卡后站在哪个出生点。
signal scene_change_requested(scene_key: String, spawn_id: String)

## RbSceneRegistry 中的 key。
@export var target_scene_key: String = ""
## 目标关卡 SpawnPoints 下的 Marker2D 名称。
@export var target_spawn_id: String = "default"
@export var locked: bool = false
## 上锁时播放的对话 id（可留空表示无反馈）。
@export var locked_dialogue_id: String = ""


func _do_interact(_by: Node) -> void:
	if locked:
		if locked_dialogue_id != "":
			dialogue_requested.emit(locked_dialogue_id)
		return

	if target_scene_key == "":
		push_warning("[RbDoor] %s 未设置 target_scene_key" % name)
		return

	scene_change_requested.emit(target_scene_key, target_spawn_id)
