class_name RbSceneLoader
## rebuild 场景切换器。
##
## 设计约束：
## - 不持有 SceneTree 的全局引用，调用方必须传入自己所在的节点作为上下文，
##   避免 Engine.get_main_loop() 这类隐式全局访问。
## - 出生点通过 RbGameState 传递，而不是直接改写目标场景的内部变量。

## 切换到注册表中的场景。
## context: 发起切换的节点（用于取得 SceneTree）。
## scene_key: RbSceneRegistry 中的 key。
## spawn_id: 目标关卡 SpawnPoints 下的 Marker2D 名称，空字符串表示用关卡默认出生点。
static func change_to(context: Node, scene_key: String, spawn_id: String = "") -> bool:
	if context == null or not is_instance_valid(context):
		push_error("[RbSceneLoader] context 无效，无法切换场景: %s" % scene_key)
		return false

	if not RbSceneRegistry.has_key(scene_key):
		push_error("[RbSceneLoader] 未注册的场景 key: %s" % scene_key)
		return false

	var path: String = RbSceneRegistry.resolve_path(scene_key)
	if not ResourceLoader.exists(path):
		push_error("[RbSceneLoader] 场景文件不存在: %s" % path)
		return false

	var tree: SceneTree = context.get_tree()
	if tree == null:
		push_error("[RbSceneLoader] context 不在场景树中: %s" % context.name)
		return false

	RbGameState.set_pending_spawn_id(spawn_id)
	# 延迟到本帧信号处理完毕后再切换，避免在信号回调中销毁当前场景。
	tree.change_scene_to_file.call_deferred(path)
	return true
