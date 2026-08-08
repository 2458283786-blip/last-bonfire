class_name Villager
extends CharacterBody2D
## 居民 AI：通用工作流（找目标→移动→工作→捡取→搬运→入库）+ 职业策略。
## 新增职业：在 scripts/villager/jobs/ 加一个类（实现 find_target / work），
## 并在 _create_job 中注册即可，无需改动通用流程。

enum WorkState { IDLE, FIND_WORK, TRAVEL_TO_WORK, WORKING, PICKUP, TRAVEL_TO_STORAGE, DEPOSIT, WANDER }

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

func _ready() -> void:
	villager_id = get_instance_id()
	add_to_group("villagers")
	home_position = global_position
	_last_position = global_position

func set_job(new_job: String) -> void:
	job = new_job
	current_job = _create_job(new_job)
	state = WorkState.IDLE
	work_target = null
	target_pickup = null
	work_timer = 0.0

func _create_job(job_name: String) -> RefCounted:
	match job_name:
		"woodcutter":
			return WoodcutterJob.new()
	return null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 1200.0 * delta
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
	move_and_slide()

func _update_idle() -> void:
	if job != "idle":
		state = WorkState.FIND_WORK
		return
	if _try_auto_convert():
		return
	wander_timer = 0.0
	wander_wait = randf_range(wander_wait_min, wander_wait_max)
	state = WorkState.WANDER

func _try_auto_convert() -> bool:
	var hut := _nearest_in_group("job_huts")
	if hut != null and hut.has_method("can_accept_villager") and hut.can_accept_villager(self):
		hut.assign_villager(self)
		return true
	return false

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
	if _try_auto_convert():
		return
	if wander_target == Vector2.ZERO:
		wander_timer += delta
		velocity.x = 0.0
		if wander_timer >= wander_wait:
			_pick_wander_target()
		return
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

func _move_toward(target_pos: Vector2, delta: float) -> bool:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist <= interact_range:
		velocity.x = 0.0
		return true
	velocity.x = to_target.normalized().x * move_speed
	return false
