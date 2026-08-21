@tool
extends EditorScript
## 测试恐怖游戏 MCP 工具
## 在 Godot 编辑器中：工具 → 执行脚本 运行此文件。

func _run() -> void:
	print("=== 测试恐怖游戏 MCP 工具 ===")

	# 测试 Director 系统
	test_director_system()

	# 测试 GameManager
	test_game_manager()

	# 测试角色系统
	test_character_system()

	# 测试事件系统
	test_event_system()

	# 测试物品系统
	test_inventory_system()

	print("=== 测试完成 ===")


## 测试 Director 系统：验证张力、阶段切换与高峰计数。
func test_director_system() -> void:
	print("\n--- 测试 Director 系统 ---")

	if not Engine.has_meta("Director"):
		print("❌ Director autoload 未找到")
		return

	var director = Engine.get_meta("Director")
	if not director:
		print("❌ Director 实例为空")
		return

	print("✅ Director 系统可用")
	print("  当前张力: ", director.tension)
	print("  当前阶段: ", director.phase)
	print("  总高峰次数: ", director.total_peaks)

	# 测试设置张力
	director.tension = 0.5
	print("  设置张力为 0.5: ", director.tension)

	# 测试触发高峰
	director._enter_phase(2)  # Phase.PEAK
	print("  触发高峰后阶段: ", director.phase)
	print("  新总高峰次数: ", director.total_peaks)


## 测试 GameManager：验证状态、楼层与角色存活数据读写。
func test_game_manager() -> void:
	print("\n--- 测试 GameManager ---")

	if not Engine.has_meta("GameManager"):
		print("❌ GameManager autoload 未找到")
		return

	var gm = Engine.get_meta("GameManager")
	if not gm:
		print("❌ GameManager 实例为空")
		return

	print("✅ GameManager 可用")
	print("  当前状态: ", gm.current_state)
	print("  当前楼层: ", gm.current_floor)
	print("  灵魂交换: ", gm.is_soul_swapped)
	print("  存活角色数: ", gm.alive_characters.size())

	# 测试设置状态
	var old_state = gm.current_state
	gm.set_state(1)  # PLAYING
	print("  设置状态为 PLAYING: ", gm.current_state)
	gm.set_state(old_state)  # 恢复原状态


## 测试角色系统：验证存活角色的状态修改与恢复。
func test_character_system() -> void:
	print("\n--- 测试角色系统 ---")

	if not Engine.has_meta("GameManager"):
		print("❌ GameManager autoload 未找到")
		return

	var gm = Engine.get_meta("GameManager")
	if not gm:
		print("❌ GameManager 实例为空")
		return

	print("✅ 角色系统可用")
	print("  存活角色: ", gm.alive_characters)

	# 测试设置角色状态
	var old_status = gm.alive_characters.get("cool_npc", true)
	gm.alive_characters["cool_npc"] = false
	print("  设置 cool_npc 为死亡: ", gm.alive_characters["cool_npc"])
	gm.alive_characters["cool_npc"] = old_status  # 恢复


## 测试事件系统：验证事件标记与已发现规则的增删。
func test_event_system() -> void:
	print("\n--- 测试事件系统 ---")

	if not Engine.has_meta("GameManager"):
		print("❌ GameManager autoload 未找到")
		return

	var gm = Engine.get_meta("GameManager")
	if not gm:
		print("❌ GameManager 实例为空")
		return

	print("✅ 事件系统可用")
	print("  事件标记数: ", gm.event_flags.size())
	print("  已发现规则数: ", gm.discovered_rules.size())

	# 测试设置事件标记
	gm.event_flags["test_flag"] = true
	print("  设置测试标记: ", gm.event_flags["test_flag"])
	gm.event_flags.erase("test_flag")  # 清理

	# 测试发现规则
	var rule_count_before = gm.discovered_rules.size()
	gm.discovered_rules.append("测试规则")
	print("  添加测试规则后数量: ", gm.discovered_rules.size())
	gm.discovered_rules.pop_back()  # 清理


## 测试物品系统：验证背包添加与清理测试物品。
func test_inventory_system() -> void:
	print("\n--- 测试物品系统 ---")

	if not Engine.has_meta("InventoryManager"):
		print("❌ InventoryManager autoload 未找到")
		return

	var inv = Engine.get_meta("InventoryManager")
	if not inv:
		print("❌ InventoryManager 实例为空")
		return

	print("✅ 物品系统可用")
	print("  当前物品数: ", inv.inventory.size())
	print("  物品列表: ", inv.inventory)

	# 测试添加物品
	var item_count_before = inv.inventory.size()
	inv.inventory.append("test_item")
	inv.item_counts["test_item"] = 1
	print("  添加测试物品后数量: ", inv.inventory.size())

	# 清理
	inv.inventory.erase("test_item")
	inv.item_counts.erase("test_item")
