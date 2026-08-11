class_name HousingBuilding
extends Building
## 住宅：提供住宅容量；没房子不能工作（自动转职/手动转职均需先有家）。
## 夜晚居民回家并点亮窗户；被毁时释放住户与其职业。

signal resident_homed(villager: Villager)
signal resident_left(villager: Villager)

## 基础住宅容量
@export var capacity: int = 2
## 每级增加的容量
@export var capacity_per_level: int = 2

var assigned: Array[Villager] = []

@onready var window_light: CanvasItem = $WindowLight

func _ready() -> void:
	super._ready()
	add_to_group("housing_buildings")
	DayManager.phase_changed.connect(_on_phase_changed)
	_update_light()

func _exit_tree() -> void:
	if DayManager.phase_changed.is_connected(_on_phase_changed):
		DayManager.phase_changed.disconnect(_on_phase_changed)

func effective_capacity() -> int:
	return capacity + maxi(level - 1, 0) * capacity_per_level

func can_accept_villager(_v: Villager) -> bool:
	return assigned.size() < effective_capacity()

func assign_villager(v: Villager) -> bool:
	if not can_accept_villager(v) or assigned.has(v):
		return false
	assigned.append(v)
	v.home = self
	resident_homed.emit(v)
	_update_light()
	return true

func release_villager(v: Villager) -> void:
	var removed := assigned.has(v)
	assigned.erase(v)
	if not removed:
		return
	if v.home == self:
		v.home = null
	resident_left.emit(v)
	_update_light()

## 被摧毁：住户失去住宅，连带释放职业（没房子不能工作）。
func _on_function_offline() -> void:
	for v in assigned.duplicate():
		release_villager(v)
		_release_job(v)
	_update_light()

func _on_function_online() -> void:
	_update_light()

func _apply_level_effects() -> void:
	_update_light()

func _release_job(v: Villager) -> void:
	v.release_from_job()

func _on_phase_changed(_phase: int) -> void:
	_update_light()

func _update_light() -> void:
	if window_light == null:
		return
	window_light.visible = DayManager.phase == DayManager.TimePhase.NIGHT and assigned.size() > 0
