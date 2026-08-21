extends Area2D
## 损坏的贩卖机 - 踢一脚消耗体力，随机掉落物品

var _level: Node

## 触发场景通过 meta 注册的交互回调，实现踢贩卖机逻辑。
func interact() -> void:
	var callback = get_meta("interact_callback", Callable())
	if callback.is_valid():
		callback.call()
