extends Node
## 玩家背包：装备槽（近战/远程/护甲/饰品）+ 物品背包，全部数据驱动。
## 物品定义在 resources/data/items/*.tres，按 id 索引；新物品只加配置。

signal inventory_changed

const ITEMS_DIR := "res://resources/data/items/"
const EQUIP_SLOTS := ["melee", "ranged", "armor", "accessory"]

## 装备槽 -> 物品 ID
var equipment: Dictionary = {}
## 物品 ID -> 数量
var items: Dictionary = {}

var _items_by_id: Dictionary = {}

func _ready() -> void:
	reload_items()

func reload_items() -> void:
	_items_by_id.clear()
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var data := load(ITEMS_DIR + file) as ItemData
		if data != null and data.id != "":
			_items_by_id[data.id] = data

func get_item(item_id: String) -> ItemData:
	return _items_by_id.get(item_id)

func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in _items_by_id:
		out.append(_items_by_id[id])
	return out

func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0 or get_item(item_id) == null:
		return
	items[item_id] = items.get(item_id, 0) + count
	inventory_changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
	if items.get(item_id, 0) < count:
		return false
	items[item_id] = items[item_id] - count
	if items[item_id] <= 0:
		items.erase(item_id)
	inventory_changed.emit()
	return true

func count_item(item_id: String) -> int:
	return items.get(item_id, 0)

func equip(slot: String, item_id: String) -> bool:
	var data := get_item(item_id)
	if data == null or data.slot != slot:
		return false
	equipment[slot] = item_id
	inventory_changed.emit()
	return true

func unequip(slot: String) -> void:
	if equipment.erase(slot):
		inventory_changed.emit()

func equipped(slot: String) -> String:
	return equipment.get(slot, "")

func melee_bonus() -> int:
	return _slot_bonus("melee", "damage_bonus")

func ranged_bonus() -> int:
	return _slot_bonus("ranged", "damage_bonus")

func defense_bonus() -> int:
	var total := 0
	for slot in equipment:
		var data := get_item(equipment[slot])
		if data != null:
			total += data.defense_bonus
	return total

func _slot_bonus(slot: String, field: String) -> int:
	var item_id: String = equipment.get(slot, "")
	if item_id == "":
		return 0
	var data := get_item(item_id)
	if data == null:
		return 0
	return int(data.get(field))

## 使用消耗品：对玩家生效（如治疗）。
func use_consumable(item_id: String) -> bool:
	var data := get_item(item_id)
	if data == null or data.item_type != "consumable" or data.heal_amount <= 0:
		return false
	if not remove_item(item_id, 1):
		return false
	var players := get_tree().get_nodes_in_group("players")
	if not players.is_empty() and players[0].has_method("heal"):
		players[0].heal(data.heal_amount)
	return true

## ---- 存档支持 ----

func collect_state() -> Dictionary:
	return {"equipment": equipment.duplicate(), "items": items.duplicate()}

func restore(data: Dictionary) -> void:
	equipment = (data.get("equipment", {}) as Dictionary).duplicate()
	items = (data.get("items", {}) as Dictionary).duplicate()
	inventory_changed.emit()
