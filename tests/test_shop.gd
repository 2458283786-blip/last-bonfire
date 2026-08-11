extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	var shop: Node = (load("res://scenes/buildings/shop.tscn") as PackedScene).instantiate()
	add_child(shop)
	check(shop.shop_data != null, "商店应加载货品配置")
	check(shop.open_shop(), "商店应可打开")
	var panel: PanelContainer = (load("res://scenes/ui/shop_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.open_shop(shop)
	var goods_list: VBoxContainer = panel.get_node("VBox/GoodsList")
	check(goods_list.get_child_count() == 3, "应展示 3 件货品")
	EconomyManager.stock["gold"] = 50
	var sword := InventoryManager.get_item("wooden_sword")
	panel._on_buy_pressed(sword)
	check(EconomyManager.get_amount("gold") == 30, "购买应扣金币")
	check(InventoryManager.count_item("wooden_sword") == 1, "购买应入背包")
	EconomyManager.stock["gold"] = 0
	panel._on_buy_pressed(sword)
	check(InventoryManager.count_item("wooden_sword") == 1, "金币不足不应再购入")
	# 装备数值生效（攻击/防御）
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_physics_process(false)
	InventoryManager.equip("melee", "wooden_sword")
	check(player.effective_attack_damage() == 2, "装备木剑后近战攻击应为 2")
	InventoryManager.equip("armor", "leather_armor")
	player.take_damage(3.0)
	check(absf(player.hp - 98.0) < 0.01, "皮甲应减免 1 点伤害")
	# 商店蓝图默认锁定（NPC 解救解锁占位，调试期 DebugManager 解锁）
	var data := load("res://resources/data/buildings/shop.tres") as BuildingData
	check(data.requires_unlock, "商店蓝图应默认锁定")
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
