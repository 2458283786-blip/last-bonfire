class_name Villager
extends CharacterBody2D
## 居民 AI：通用工作流（找目标→移动→工作→捡取→搬运→入库）+ 职业策略。
## 新增职业：在 scripts/villager/jobs/ 加一个类（实现 find_target / work），
## 并在 _create_job 中注册即可，无需改动通用流程。

enum WorkState { IDLE, FIND_WORK, TRAVEL_TO_WORK, WORKING, PICKUP, TRAVEL_TO_STORAGE, DEPOSIT, WANDER, GO_HOME, FLEE, GUARD }

## 撤退/逃跑时的速度倍率（"慌不择路"）
const FLEE_SPEED_MULT := 1.2
const INJURED_SPEED_MULT := 0.5
const IDLE_EMOTES := ["Zzz", "…", "♪", "☕", "🌿"]
## 重力（默认值，可由 game_config 覆盖）
var gravity := 1200.0
var flee_speed_mult := FLEE_SPEED_MULT
var injured_speed_mult := INJURED_SPEED_MULT

## 行走速度（像素/秒）
@export var move_speed: float = 180.0
## 离目标多近算"到了"（用于工作/捡取/入库）
@export var interact_range: float = 30.0
## 每多少秒执行一次工作动作（如砍一下）
@export var work_interval: float = 1.0
## 一次最多背多少份资源
@export var carry_capacity: int = 3
## 无职业居民在出生点附近的漫游半径
@export var wander_radius: float = 150.0
## 无职业居民每次停下休息的最短秒数
@export var wander_wait_min: float = 1.5
## 无职业居民每次停下休息的最长秒数
@export var wander_wait_max: float = 4.0
## 移动被卡住多少帧后重新找目标
@export var stuck_frames_limit: int = 30
## 居民最大生命（被怪物攻击用）
@export var max_hp: float = 20.0
## 受伤后失去工作能力的天数
@export var injured_days: int = 3
## 居民显示名（UI 列表用，可在场景中配置）
@export var display_name: String = "居民"

var villager_id := 0
var job := "idle"
var state := WorkState.IDLE
var carry: Dictionary = {}
var current_job: RefCounted = null
var work_target: Node2D = null
var target_pickup: Pickup = null
var target_storage: Node2D = null
var work_timer := 0.0
var home_position := Vector2.ZERO
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var wander_wait := 0.0
var _last_position := Vector2.ZERO
var _stuck_frames := 0
var hp: float = 20.0
var is_injured := false
var injured_remaining_days := 0
## 所属住宅（没有住宅不能工作；夜晚回家）
var home: Node2D = null
var _fleeing := false

@onready var emote_label: Label = $IdleEmote

func _ready() -> void:
	villager_id = get_instance_id()
	add_to_group("villagers")
	collision_layer = PhysicsLayers.VILLAGER
	collision_mask = PhysicsLayers.MASK_WORLD_ONLY
	var cfg := load("res://resources/data/game_config.tres") as GameConfig
	if cfg != null:
		gravity = cfg.gravity
		flee_speed_mult = cfg.villager_flee_speed_mult
		injured_speed_mult = cfg.villager_injured_speed_mult
	home_position = global_position
	_last_position = global_position
	hp = max_hp
	move_speed = move_speed * randf_range(0.9, 1.1)
	DayManager.day_changed.connect(_on_day_changed)
	EventBus.threat_broadcast.connect(_on_threat_broadcast)
	TownRegistry.register_villager(self)

func _exit_tree() -> void:
	if is_instance_valid(TownRegistry):
		TownRegistry.unregister_villager(self)
	if EventBus.threat_broadcast.is_connected(_on_threat_broadcast):
		EventBus.threat_broadcast.disconnect(_on_threat_broadcast)

## 被怪物攻击：血量归零后进入受伤状态（非死亡），失去 N 日工作能力。
func take_damage(amount: float) -> void:
	if is_injured or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_injure()

func _injure() -> void:
	is_injured = true
	injured_remaining_days = injured_days
	hp = 0.0
	release_from_job()
	work_target = null
	state = WorkState.IDLE
	EventBus.villager_injured.emit(str(villager_id))

## 释放当前职业：从所属职业小屋名额中移除并转空闲。
## 受伤/住宅被毁/手动调整/读档恢复统一走这里，避免各处重复扫描逻辑。
func release_from_job() -> void:
	for hut in TownRegistry.get_job_huts():
		if hut.has_method("release_villager") and hut.get("assigned") != null:
			var hut_assigned: Array = hut.assigned
			if hut_assigned.has(self):
				hut.release_villager(self)
	if job != "idle":
		set_job("idle")

func _on_day_changed(_day: int) -> void:
	if is_injured:
		injured_remaining_days -= 1
		if injured_remaining_days <= 0:
			is_injured = false
			hp = max_hp

func set_job(new_job: String) -> void:
	job = new_job
	current_job = _create_job(new_job)
	state = WorkState.IDLE
	work_target = null
	target_pickup = null
	work_timer = 0.0

func _create_job(job_name: String) -> RefCounted:
	return JobRegistry.create(job_name)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	match state:
		WorkState.IDLE:
			_update_idle()
		WorkState.FIND_WORK:
			_find_work()
		WorkState.TRAVEL_TO_WORK:
			_travel_to_work(delta)
		WorkState.WORKING:
			_work(delta)
		WorkState.PICKUP:
			_pickup(delta)
		WorkState.TRAVEL_TO_STORAGE:
			_travel_to_storage(delta)
		WorkState.DEPOSIT:
			_deposit()
		WorkState.WANDER:
			_wander(delta)
		WorkState.GO_HOME:
			_go_home(delta)
		WorkState.FLEE:
			_flee(delta)
		WorkState.GUARD:
			_guard(delta)
	move_and_slide()

func _update_idle() -> void:
	if is_injured:
		_start_wander()
		return
	if DayManager.phase == DayManager.TimePhase.NIGHT:
		if current_job is DefenseJob:
			state = WorkState.GUARD
		elif not _is_near_home():
			state = WorkState.GO_HOME
		return
	if job != "idle":
		state = WorkState.GUARD if current_job is DefenseJob else WorkState.FIND_WORK
		return
	if not has_home() and _try_assign_home():
		return
	if _try_auto_convert():
		return
	_start_wander()

func _start_wander() -> void:
	wander_timer = 0.0
	wander_wait = randf_range(wander_wait_min, wander_wait_max)
	_show_idle_emote()
	state = WorkState.WANDER

func _try_auto_convert() -> bool:
	if not has_home():
		return false
	var hut := _nearest_in_group("job_huts")
	if hut != null and hut.has_method("can_accept_villager") and hut.can_accept_villager(self):
		hut.assign_villager(self)
		return true
	return false

## ---------- 住宅 ----------

func has_home() -> bool:
	return home != null and is_instance_valid(home)

func _try_assign_home() -> bool:
	var house := _nearest_in_group("housing_buildings")
	if house != null and house.has_method("can_accept_villager") and house.can_accept_villager(self):
		return house.assign_villager(self)
	return false

func _home_pos() -> Vector2:
	if has_home():
		return home.global_position
	return home_position

func _is_near_home() -> bool:
	return global_position.distance_to(_home_pos()) <= interact_range

## ---------- 威胁撤退 / 夜晚回家 ----------

func _on_threat_broadcast(origin: Vector2, radius: float) -> void:
	if is_injured or current_job is DefenseJob or DayManager.phase == DayManager.TimePhase.NIGHT:
		return
	if global_position.distance_to(origin) > radius:
		return
	_fleeing = true
	work_target = null
	target_pickup = null
	state = WorkState.FLEE

func _flee(delta: float) -> void:
	if not _any_threat_nearby():
		_fleeing = false
		state = WorkState.IDLE
		return
	if _move_toward(_home_pos(), delta, flee_speed_mult):
		velocity.x = 0.0

func _any_threat_nearby() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.data == null:
			continue
		# 威胁半径跟随敌人自身感知范围（避免与配置脱节）。
		if global_position.distance_to(e.global_position) <= e.data.aggro_range:
			return true
	return false

func _go_home(delta: float) -> void:
	if DayManager.phase != DayManager.TimePhase.NIGHT:
		state = WorkState.IDLE
		return
	if _move_toward(_home_pos(), delta):
		state = WorkState.IDLE

## ---------- 防御站桩 ----------

func _guard(delta: float) -> void:
	var job := current_job as DefenseJob
	if job == null:
		state = WorkState.IDLE
		return
	var post := job.get_post(self)
	if post != Vector2.ZERO and global_position.distance_to(post) > interact_range:
		if _move_toward(post, delta):
			velocity.x = 0.0
		return
	job.work(self, delta)

## ---------- 通用工作流 ----------

func _find_work() -> void:
	if current_job == null:
		state = WorkState.IDLE
		return
	var target: Node2D = current_job.find_target(self)
	if target == null:
		state = WorkState.IDLE
		return
	work_target = target
	state = WorkState.TRAVEL_TO_WORK

func _travel_to_work(delta: float) -> void:
	if work_target == null or not is_instance_valid(work_target):
		state = WorkState.FIND_WORK
		return
	if work_target.has_method("try_reserve") and not work_target.try_reserve(villager_id):
		state = WorkState.FIND_WORK
		return
	if _move_toward(work_target.global_position, delta):
		work_timer = 0.0
		state = WorkState.WORKING
		return
	_check_stuck(WorkState.FIND_WORK)

func _work(delta: float) -> void:
	if current_job == null or work_target == null or not is_instance_valid(work_target):
		state = WorkState.PICKUP
		return
	if current_job.work(self, delta):
		state = WorkState.PICKUP

func _pickup(delta: float) -> void:
	if _carry_total() >= carry_capacity:
		state = WorkState.TRAVEL_TO_STORAGE
		return
	target_pickup = _nearest_pickup()
	if target_pickup == null:
		state = WorkState.FIND_WORK
		return
	if _move_toward(target_pickup.global_position, delta):
		var got := target_pickup.take()
		if not got.is_empty():
			carry[got["resource_id"]] = carry.get(got["resource_id"], 0) + got["amount"]
		state = WorkState.TRAVEL_TO_STORAGE

func _carry_total() -> int:
	var total := 0
	for v in carry.values():
		total += v
	return total

func _travel_to_storage(delta: float) -> void:
	target_storage = _get_storage()
	if target_storage == null:
		state = WorkState.IDLE
		return
	if _move_toward(target_storage.global_position, delta):
		state = WorkState.DEPOSIT
		return
	_check_stuck(WorkState.FIND_WORK)

func _deposit() -> void:
	var storage: Node2D = _get_storage()
	if storage == null:
		state = WorkState.IDLE
		return
	for id in carry.keys():
		var amount: int = carry[id]
		var accepted := EconomyManager.deposit(id, amount)
		if accepted > 0:
			carry[id] = amount - accepted
		if carry[id] <= 0:
			carry.erase(id)
	if carry.is_empty():
		state = WorkState.FIND_WORK

func _check_stuck(fallback_state: WorkState) -> void:
	if global_position.distance_to(_last_position) < 1.0:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_position = global_position
	if _stuck_frames >= stuck_frames_limit:
		_stuck_frames = 0
		work_target = null
		state = fallback_state

## ---------- 无职业居民漫游 ----------

func _wander(delta: float) -> void:
	if not is_injured and _try_auto_convert():
		return
	if wander_target == Vector2.ZERO:
		wander_timer += delta
		velocity.x = 0.0
		if emote_label != null and emote_label.text == "":
			_show_idle_emote()
		if wander_timer >= wander_wait:
			_hide_idle_emote()
			_pick_wander_target()
		return
	_hide_idle_emote()
	if _move_toward(wander_target, delta):
		wander_target = Vector2.ZERO
		wander_timer = 0.0
		return
	if global_position.distance_to(_last_position) < 1.0:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_position = global_position
	if _stuck_frames >= stuck_frames_limit:
		_stuck_frames = 0
		_pick_wander_target()

func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(20.0, wander_radius)
	wander_target = home_position + Vector2.from_angle(angle) * radius
	wander_timer = 0.0

func _show_idle_emote() -> void:
	if emote_label == null:
		return
	emote_label.text = IDLE_EMOTES.pick_random()
	emote_label.visible = true

func _hide_idle_emote() -> void:
	if emote_label == null:
		return
	emote_label.text = ""
	emote_label.visible = false

## ---------- 工具 ----------

func _nearest_pickup() -> Pickup:
	var best: Pickup = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("pickups"):
		var p := node as Pickup
		if p == null or p.taken:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return best

func _get_storage() -> Node2D:
	var storage := _nearest_in_group("storage_buildings")
	if storage != null:
		return storage
	return _nearest_in_group("town_stockpile")

func _nearest_in_group(group: String) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node2D
		if n == null:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best = n
	return best

func _move_toward(target_pos: Vector2, delta: float, speed_mult: float = 1.0) -> bool:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist <= interact_range:
		velocity.x = 0.0
		return true
	var speed := move_speed * speed_mult
	if is_injured:
		speed *= injured_speed_mult
	velocity.x = to_target.normalized().x * speed
	return false
