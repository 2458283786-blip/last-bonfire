extends Node
## 地下城状态管理（P11）：进入时记录"距天黑剩余时间"，探索超时强制入夜。
## 城镇时间照常流逝（DayManager 为全局单例），玩家在关卡内只受倒计时压力。

signal dungeon_entered(remaining_to_night: float)
signal dungeon_exited
signal night_forced_triggered

const TOWN_SCENE := SceneRegistry.TOWN

## 运行配置（默认值；后续可迁入配置表）
var run_stages := 3
var run_rooms_per_stage := 3
var run_max_rescues := 2
var run_rescue_weight := 0.10
var merchant_unlock_stage := 2

var in_dungeon := false
var remaining_to_night := 0.0
## 探索超时是否已强制入夜（波次晚归加成依据）
var night_forced := false
## 当前一局（两门二选一运行态）
var run: DungeonRun = null

var _current_node: DungeonNodeData = null

func reset() -> void:
	in_dungeon = false
	remaining_to_night = 0.0
	night_forced = false
	run = null
	_current_node = null

func enter_dungeon() -> void:
	in_dungeon = true
	night_forced = false
	remaining_to_night = _time_until_night()
	dungeon_entered.emit(remaining_to_night)

func _process(delta: float) -> void:
	if not in_dungeon:
		return
	remaining_to_night = maxf(remaining_to_night - delta, 0.0)
	if remaining_to_night <= 0.0 and not night_forced:
		night_forced = true
		_force_night()
		night_forced_triggered.emit()

func exit_dungeon() -> void:
	in_dungeon = false
	dungeon_exited.emit()

## ---- 两门二选一运行态 ----

func start_run() -> void:
	run = DungeonRun.new()
	run.stages = run_stages
	run.rooms_per_stage = run_rooms_per_stage
	run.max_rescues_per_run = run_max_rescues
	run.rescue_weight = run_rescue_weight
	run.begin(randi())
	_current_node = null
	make_choice()

func make_choice() -> void:
	if run != null:
		run.make_choice()

func choose_node(index: int) -> DungeonNodeData:
	if run == null or index < 0 or index >= run.pending_choice.size():
		return null
	_current_node = run.pending_choice[index]
	return _current_node

func current_node() -> DungeonNodeData:
	return _current_node

func enter_boss_room() -> DungeonNodeData:
	if run == null:
		return null
	_current_node = run.make_boss_node()
	return _current_node

func should_enter_boss() -> bool:
	return run != null and run.rooms_cleared_in_stage >= run.rooms_per_stage

func room_cleared() -> void:
	if run != null:
		run.rooms_cleared_in_stage += 1

func rescue_villager() -> void:
	if run != null:
		run.rescued_villagers += 1

## 阶段 BOSS 击杀：固定阶段解锁商人；最终阶段标记通关。
func stage_boss_cleared() -> void:
	if run == null:
		return
	if run.current_stage >= merchant_unlock_stage and not run.shop_unlocked:
		run.shop_unlocked = true
	if run.current_stage >= run.stages:
		run.completed = true
	else:
		run.current_stage += 1
		run.rooms_cleared_in_stage = 0

func is_run_completed() -> bool:
	return run != null and run.completed

## 结束一局（通关/死亡/放弃共用）：应用持久成果（解锁/救援）并清空运行态。
func finish_run_to_town() -> void:
	if run != null:
		if run.shop_unlocked:
			TownRegistry.unlock_blueprint("shop")
		if run.rescued_villagers > 0:
			TownRegistry.add_rescued_villagers(run.rescued_villagers)
	run = null
	_current_node = null
	exit_dungeon()

## 城镇波次消费晚归标记（只生效一次，防止重复加强）。
func consume_night_forced() -> bool:
	var value := night_forced
	night_forced = false
	return value

## 距天黑剩余秒数：白天 = 白天剩余 + 黄昏整段；黄昏 = 黄昏剩余；夜晚 = 0。
func _time_until_night() -> float:
	match DayManager.phase:
		DayManager.TimePhase.NIGHT:
			return 0.0
		DayManager.TimePhase.DAY:
			return DayManager.phase_remaining() + DayManager.phase_length_seconds
		DayManager.TimePhase.DUSK:
			return DayManager.phase_remaining()
	return 0.0

func _force_night() -> void:
	var guard := 0
	while DayManager.phase != DayManager.TimePhase.NIGHT and guard < DayManager.PHASE_COUNT:
		DayManager.advance_phase()
		guard += 1
