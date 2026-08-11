class_name StorageBuilding
extends Building
## 仓库：扩容全局库存容量，并作为居民的搬运目标。
## 被摧毁时容量失效，修复/重建后恢复（_capacity_active 状态机保证幂等）。

## 建仓库后库存容量增加多少
@export var capacity_boost: int = 80

## 当前已计入 EconomyManager 的容量贡献（差值法保证幂等）
var _capacity_contribution := 0

func _ready() -> void:
	super._ready()
	add_to_group("storage_buildings")
	_capacity_contribution = 0
	_apply_capacity()

func _exit_tree() -> void:
	if _capacity_contribution != 0:
		EconomyManager.set_capacity(maxi(EconomyManager.capacity - _capacity_contribution, 0))
		_capacity_contribution = 0

## 按当前等级把容量贡献同步到 EconomyManager（差值法，幂等）。
func _apply_capacity() -> void:
	var target := capacity_boost * level
	if target == _capacity_contribution:
		return
	EconomyManager.set_capacity(EconomyManager.capacity - _capacity_contribution + target)
	_capacity_contribution = target

func _on_function_offline() -> void:
	if _capacity_contribution != 0:
		EconomyManager.set_capacity(maxi(EconomyManager.capacity - _capacity_contribution, 0))
		_capacity_contribution = 0

func _on_function_online() -> void:
	_apply_capacity()

func _apply_level_effects() -> void:
	_apply_capacity()
