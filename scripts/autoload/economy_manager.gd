extends Node
## 全局资源池：库存、容量、出入库。
## 建筑/居民通过本单例读写资源；仓库扩容 = set_capacity。

signal stock_changed(resource_id: String, amount: int)

const DEFAULT_CAPACITY := 20
const STARTING_STOCK := {"wood": 10, "stone": 5}
const CONFIG_PATH := "res://resources/data/game_config.tres"

var stock: Dictionary = {}
var capacity: int = DEFAULT_CAPACITY
var _config: GameConfig = null

func _ready() -> void:
	_config = load(CONFIG_PATH) as GameConfig
	reset()

func reset() -> void:
	stock.clear()
	if _config != null:
		capacity = _config.default_capacity
		for id in _config.starting_stock:
			stock[id] = _config.starting_stock[id]
	else:
		capacity = DEFAULT_CAPACITY
		for id in STARTING_STOCK:
			stock[id] = STARTING_STOCK[id]
	emit_changed("", 0)

func get_amount(resource_id: String) -> int:
	return stock.get(resource_id, 0)

func total_used() -> int:
	var total := 0
	for v in stock.values():
		total += v
	return total

func deposit(resource_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var space := capacity - total_used()
	var accepted := mini(amount, space)
	if accepted > 0:
		stock[resource_id] = get_amount(resource_id) + accepted
		emit_changed(resource_id, accepted)
	return accepted

func withdraw(resource_id: String, amount: int) -> bool:
	if get_amount(resource_id) < amount:
		return false
	stock[resource_id] = get_amount(resource_id) - amount
	emit_changed(resource_id, -amount)
	return true

func set_capacity(new_capacity: int) -> void:
	capacity = maxi(new_capacity, 0)
	emit_changed("", 0)

func emit_changed(resource_id: String, amount: int) -> void:
	stock_changed.emit(resource_id, amount)

## ---- 存档支持 ----

func collect_state() -> Dictionary:
	return {"stock": stock.duplicate(), "capacity": capacity}

func restore(data: Dictionary) -> void:
	stock = (data.get("stock", {}) as Dictionary).duplicate()
	capacity = maxi(int(data.get("capacity", DEFAULT_CAPACITY)), 0)
	emit_changed("", 0)
