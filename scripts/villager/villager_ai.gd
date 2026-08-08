class_name Villager
extends CharacterBody2D
## 居民 AI：工作状态机（当前支持伐木工：砍树→捡掉落物→运回仓库→入库）。
## 移动为直线走向目标，后续复杂地图再接 NavigationAgent2D。

enum WorkState { IDLE, FIND_TREE, TRAVEL_TO_TREE, CHOPPING, PICKUP, TRAVEL_TO_STORAGE, DEPOSIT }

## 行走速度（像素/秒）
@export var move_speed: float = 180.0
## 离目标多近算"到了"（用于砍树/捡取/入库）
@export var interact_range: float = 30.0
## 每多少秒砍一下
@export var chop_interval: float = 1.0
## 一次最多背多少份资源
@export var carry_capacity: int = 3

var villager_id := 0
var job := "idle"
var state := WorkState.IDLE
var carry: Dictionary = {}
var target_tree: ResourceNode = null
var target_pickup: Pickup = null
var target_storage: Node2D = null
var chop_timer := 0.0

func _ready() -> void:
	villager_id = get_instance_id()
	add_to_group("villagers")

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
	move_and_slide()

func _update_idle() -> void:
	if job == "woodcutter":
		state = WorkState.FIND_TREE
	elif job == "idle":
		_try_auto_convert()

func _try_auto_convert() -> void:
	var hut := _nearest_in_group("job_huts")
	if hut != null and hut.has_method("can_accept_villager") and hut.can_accept_villager(self):
		hut.assign_villager(self)

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
		return
	var deposited_any := false
	for id in carry.keys():
		var amount: int = carry[id]
		var accepted := EconomyManager.deposit(id, amount)
		if accepted > 0:
			carry[id] = amount - accepted
			deposited_any = true
		if carry[id] <= 0:
			carry.erase(id)
	if deposited_any:
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
