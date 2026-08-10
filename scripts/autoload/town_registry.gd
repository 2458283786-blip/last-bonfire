extends Node
## 城镇登记表：UI 的唯一查询入口（居民/职业建筑/每日调整次数）。
## 每日推进时重置手动调整次数。

signal villager_registered(villager: Villager)
signal villager_unregistered(villager: Villager)
signal daily_adjustments_reset

const JOB_DISPLAY_NAMES := {
	"idle": "空闲",
	"woodcutter": "伐木工",
	"miner": "矿工",
}

var _villagers: Array[Villager] = []
var _job_huts: Array[Node] = []
var _adjusted_today: Dictionary = {}

## 职业显示名统一入口：新职业只改这里，UI 不再各自硬编码。
static func job_display_name(job: String) -> String:
	return JOB_DISPLAY_NAMES.get(job, job)

func _ready() -> void:
	DayManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int) -> void:
	reset_daily_adjustments()

func register_villager(v: Villager) -> void:
	if not _villagers.has(v):
		_villagers.append(v)
		villager_registered.emit(v)

func unregister_villager(v: Villager) -> void:
	if _villagers.has(v):
		_villagers.erase(v)
		villager_unregistered.emit(v)

func get_villagers() -> Array[Villager]:
	return _villagers.duplicate()

func register_job_hut(hut: Node) -> void:
	if not _job_huts.has(hut):
		_job_huts.append(hut)

func unregister_job_hut(hut: Node) -> void:
	_job_huts.erase(hut)

func get_job_huts() -> Array:
	return _job_huts.duplicate()

func adjusted_today(villager_id: int) -> bool:
	return _adjusted_today.get(villager_id, false)

func mark_adjusted(villager_id: int) -> void:
	_adjusted_today[villager_id] = true

func reset_daily_adjustments() -> void:
	_adjusted_today.clear()
	daily_adjustments_reset.emit()
