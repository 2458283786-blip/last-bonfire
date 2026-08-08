class_name WoodcutterHut
extends Building
## 伐木屋（职业转换建筑）：把空闲居民转职为伐木工，提供名额。
## 不产资源，资源生成由伐木场负责。

## 可转职为伐木工的居民名额
@export var job_slots: int = 2

var assigned: Array[Villager] = []

func _ready() -> void:
	super._ready()
	add_to_group("job_huts")
	TownRegistry.register_job_hut(self)

func _exit_tree() -> void:
	if is_instance_valid(TownRegistry):
		TownRegistry.unregister_job_hut(self)

func can_accept_villager(_v: Villager) -> bool:
	return assigned.size() < job_slots

func assign_villager(v: Villager) -> void:
	if can_accept_villager(v) and not assigned.has(v):
		assigned.append(v)
		v.set_job("woodcutter")

## 释放名额：居民死亡/被调离时调用，避免残留引用。
func release_villager(v: Villager) -> void:
	assigned.erase(v)
