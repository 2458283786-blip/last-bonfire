class_name Villager
extends CharacterBody2D
## 居民 AI：工作状态机（当前支持伐木工：砍树→捡掉落物→运回仓库→入库）。
## 移动为直线走向目标，后续复杂地图再接 NavigationAgent2D。

enum WorkState { IDLE, FIND_TREE, TRAVEL_TO_TREE, CHOPPING, PICKUP, TRAVEL_TO_STORAGE, DEPOSIT, WANDER }

## 行走速度（像素/秒）
@export var move_speed: float = 180.0
## 离目标多近算"到了"（用于砍树/捡取/入库）
@export var interact_range: float = 30.0
## 每多少秒砍一下
@export var chop_interval: float = 1.0
## 一次最多背多少份资源
@export var carry_capacity: int = 3
## 无职业居民在出生点附近的漫游半径
@export var wander_radius: float = 150.0
## 无职业居民每次停下休息的最短秒数
@export var wander_wait_min: float = 1.5
## 无职业居民每次停下休息的最长秒数
@export var wander_wait_max: float = 4.0

var villager_id := 0
var job := "idle"
var state := WorkState.IDLE
var carry: Dictionary = {}
var target_tree: ResourceNode = null
var target_pickup: Pickup = null
var target_storage: Node2D = null
var chop_timer := 0.0
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
	state = WorkState.IDLE
	target_tree = null
	target_pickup = null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 1200.0 * delta
	velocity.x = 0.0
	match state:
		WorkState.IDLE:
			_update_idle()
		WorkState.FIND_TREE:
			_find_tree()
		WorkState.TRAVEL_TO_TREE:
			_travel_to_tree(delta)
		WorkState.CHOPPING:
			_chop(delta)
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
	if job == "woodcutter":
		state = WorkState.FIND_TREE
	elif job == "idle":
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

## 无职业居民漫游：走 → 停下休息 → 再走，保持在家附近；
## 伐木屋一旦有空位立即转职；被墙挡住时换一个目标。
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
	if _stuck_frames >= 30:
		_stuck_frames = 0
		_pick_wander_target()

func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf_range(20.0, wander_radius)
	wander_target = home_position + Vector2.from_angle(angle) * radius
	wander_timer = 0.0

func _find_tree() -> void:
	target_tree = _nearest_available_tree()
	if target_tree != null:
		state = WorkState.TRAVEL_TO_TREE
	else:
		state = WorkState.IDLE

func _nearest_available_tree() -> ResourceNode:
	var best: ResourceNode = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree == null or tree.is_depleted:
			continue
		if tree.reserved_by != -1 and tree.reserved_by != villager_id:
			continue
		var d := global_position.distance_to(tree.global_position)
		if d < best_dist:
			best_dist = d
			best = tree
	return best

func _travel_to_tree(delta: float) -> void:
	if target_tree == null or not is_instance_valid(target_tree):
		state = WorkState.FIND_TREE
		return
	if not target_tree.try_reserve(villager_id):
		state = WorkState.FIND_TREE
		return
	if _move_toward(target_tree.global_position, delta):
		chop_timer = 0.0
		state = WorkState.CHOPPING

func _chop(delta: float) -> void:
	if target_tree == null or not is_instance_valid(target_tree) or target_tree.is_depleted:
		state = WorkState.PICKUP
		return
	chop_timer += delta
	if chop_timer >= chop_interval:
		chop_timer = 0.0
		target_tree.chop(villager_id, target_tree.data.chop_damage)
		if target_tree.is_depleted:
			state = WorkState.PICKUP

func _pickup(delta: float) -> void:
	target_pickup = _nearest_pickup()
	if target_pickup == null:
		state = WorkState.FIND_TREE
		return
	if _move_toward(target_pickup.global_position, delta):
		var got := target_pickup.take()
		if not got.is_empty():
			carry[got["resource_id"]] = carry.get(got["resource_id"], 0) + got["amount"]
		state = WorkState.TRAVEL_TO_STORAGE

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

func _travel_to_storage(delta: float) -> void:
	target_storage = _get_storage()
	if target_storage == null:
		state = WorkState.IDLE
		return
	if _move_toward(target_storage.global_position, delta):
		state = WorkState.DEPOSIT

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
		state = WorkState.FIND_TREE

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
