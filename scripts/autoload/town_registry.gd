extends Node
## 城镇登记表：UI 的唯一查询入口（居民/职业建筑/每日调整次数）。
## 每日推进时重置手动调整次数。

signal villager_registered(villager: Villager)
signal villager_unregistered(villager: Villager)
signal daily_adjustments_reset

var _villagers: Array[Villager] = []
var _job_huts: Array[Node] = []
var _adjusted_today: Dictionary = {}
var _config: GameConfig = null
## 上次招募居民的天数（冷却用；存档保存）
var last_recruit_day := -1000
## 正式解锁的蓝图（建筑 id → true；商人等固定 NPC 解锁写入）
var unlocked_blueprints: Dictionary = {}
## 待生成到城镇的救援居民数（回城结算；生成后归零，不单独存档）
var pending_rescued_villagers := 0

## 职业显示名统一入口：新职业只改这里，UI 不再各自硬编码。
static func job_display_name(job: String) -> String:
	if job == "idle":
		return "空闲"
	return JobRegistry.display_name(job)

func _ready() -> void:
	DayManager.day_changed.connect(_on_day_changed)
	_config = load("res://resources/data/game_config.tres") as GameConfig

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

## ---------- 临时人口招募（调试期方案；正式解锁位预留） ----------

func recruit_cost() -> int:
	return _config.recruit_cost if _config != null else 100

func recruit_cooldown_days() -> int:
	return _config.recruit_cooldown_days if _config != null else 2

func max_villagers() -> int:
	return _config.max_villagers if _config != null else 8

## 是否可招募：正式条件 OR 调试开关（当前正式条件未定，先由 DebugManager.instant_recruit 门控）。
func can_recruit() -> bool:
	if not DebugManager.instant_recruit:
		return false
	if _villagers.size() >= max_villagers():
		return false
	if DayManager.day - last_recruit_day < recruit_cooldown_days():
		return false
	return EconomyManager.get_amount("gold") >= recruit_cost()

func recruit_villager() -> bool:
	if not can_recruit():
		return false
	if not EconomyManager.withdraw("gold", recruit_cost()):
		return false
	last_recruit_day = DayManager.day
	_spawn_recruit()
	return true

func _spawn_recruit() -> void:
	var scene := load(SceneRegistry.VILLAGER) as PackedScene
	if scene == null:
		return
	var v := scene.instantiate()
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(v)
	var spawn := _recruit_spawn_point()
	v.global_position = spawn
	v.home_position = spawn

func _recruit_spawn_point() -> Vector2:
	for node in get_tree().get_nodes_in_group("core_buildings"):
		return node.global_position
	for node in get_tree().get_nodes_in_group("town_stockpile"):
		return node.global_position
	return Vector2(400, 850)

## ---- 存档支持 ----

func collect_state() -> Dictionary:
	return {"last_recruit_day": last_recruit_day}

func restore_state(data: Dictionary) -> void:
	last_recruit_day = int(data.get("last_recruit_day", last_recruit_day))

## ---------- 蓝图正式解锁（商人等固定 NPC） ----------

func unlock_blueprint(building_id: String) -> bool:
	if unlocked_blueprints.get(building_id, false):
		return false
	unlocked_blueprints[building_id] = true
	EventBus.blueprint_unlocked.emit(building_id)
	return true

func is_blueprint_unlocked(building_id: String) -> bool:
	return unlocked_blueprints.get(building_id, false)

## ---------- 救援居民（回城结算） ----------

func add_rescued_villagers(count: int) -> void:
	if count > 0:
		pending_rescued_villagers += count

## 城镇加载时生成救援居民（无职业，需住宅才能工作，复用现有 IDLE 逻辑）。
func spawn_pending_rescues() -> void:
	if pending_rescued_villagers <= 0:
		return
	var scene := load(SceneRegistry.VILLAGER) as PackedScene
	if scene == null or get_tree().current_scene == null:
		return
	var spawn := _recruit_spawn_point()
	for i in pending_rescued_villagers:
		var v := scene.instantiate()
		get_tree().current_scene.add_child(v)
		v.global_position = spawn + Vector2(i * 30, 0)
		v.home_position = v.global_position
	pending_rescued_villagers = 0
