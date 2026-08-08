class_name StorageBuilding
extends Building
## 仓库：扩容全局库存容量，并作为居民的搬运目标。
## 占位视觉为色块，后续由美术替换。

## 建仓库后库存容量增加多少
@export var capacity_boost: int = 80

func _ready() -> void:
	super._ready()
	add_to_group("storage_buildings")
	EconomyManager.set_capacity(EconomyManager.capacity + capacity_boost)
