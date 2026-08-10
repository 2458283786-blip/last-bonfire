class_name StorageBuilding
extends Building
## 仓库：扩容全局库存容量，并作为居民的搬运目标。
## 被摧毁时容量失效，修复/重建后恢复（_capacity_active 状态机保证幂等）。

## 建仓库后库存容量增加多少
@export var capacity_boost: int = 80

var _capacity_active := false

func _ready() -> void:
	super._ready()
	add_to_group("storage_buildings")
	_capacity_active = true
	EconomyManager.set_capacity(EconomyManager.capacity + capacity_boost)

func _exit_tree() -> void:
	if _capacity_active:
		EconomyManager.set_capacity(maxi(EconomyManager.capacity - capacity_boost, 0))

func _on_function_offline() -> void:
	if _capacity_active:
		_capacity_active = false
		EconomyManager.set_capacity(maxi(EconomyManager.capacity - capacity_boost, 0))

func _on_function_online() -> void:
	if not _capacity_active:
		_capacity_active = true
		EconomyManager.set_capacity(EconomyManager.capacity + capacity_boost)
