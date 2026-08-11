class_name JobRegistry
## 职业注册表：job_name → 行为脚本路径 + 显示名。
## 新职业 = 注册一行 + 新建行为类（scripts/villager/jobs/），无需再改 villager_ai 与 town_registry。
## 若要完全配置化，可迁移为 .tres；当前集中到一处静态表，避免四处手写映射。

const JOBS := {
	"woodcutter": {"script": "res://scripts/villager/jobs/woodcutter_job.gd", "display": "伐木工"},
	"miner": {"script": "res://scripts/villager/jobs/miner_job.gd", "display": "矿工"},
	"militia": {"script": "res://scripts/villager/jobs/militia_job.gd", "display": "民兵"},
	"tower_guard": {"script": "res://scripts/villager/jobs/tower_guard_job.gd", "display": "箭塔驻守"},
}

static func has(job_name: String) -> bool:
	return JOBS.has(job_name)

static func display_name(job_name: String) -> String:
	var info: Dictionary = JOBS.get(job_name, {})
	return str(info.get("display", job_name))

static func create(job_name: String) -> RefCounted:
	var info: Dictionary = JOBS.get(job_name, {})
	if info.is_empty():
		return null
	var script := load(str(info.get("script", ""))) as GDScript
	if script == null:
		return null
	return script.new()
