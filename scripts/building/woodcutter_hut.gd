class_name WoodcutterHut
extends Node2D
## 伐木屋（职业转换建筑）：把空闲居民转职为伐木工，提供名额。
## 不产资源，资源生成由伐木场负责。

## 可转职为伐木工的居民名额
@export var job_slots: int = 2

var assigned: Array[Villager] = []

func _ready() -> void:
	add_to_group("job_huts")

func can_accept_villager(_v: Villager) -> bool:
	return assigned.size() < job_slots

func assign_villager(v: Villager) -> void:
	if can_accept_villager(v) and not assigned.has(v):
		assigned.append(v)
		v.set_job("woodcutter")
