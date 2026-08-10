class_name JobHut
extends Building
## 职业转换建筑基类：提供职业名额，把空闲居民转职为 job_name 对应的职业。
## 新职业小屋 = 子类（或场景配置 job_name）+ 新职业策略，无需复制分配逻辑。

## 可转职的居民名额
@export var job_slots: int = 2
## 本建筑提供的职业（woodcutter / miner / ...）
@export var job_name: String = "woodcutter"

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
		v.set_job(job_name)
		EventBus.villager_converted.emit(v.display_name, job_name)

## 释放名额：居民受伤/被调离/建筑被毁时调用，避免残留引用。
func release_villager(v: Villager) -> void:
	assigned.erase(v)
