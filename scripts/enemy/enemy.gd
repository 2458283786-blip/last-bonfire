class_name Enemy
extends CharacterBody2D
## 敌人 AI：按攻击优先级找目标 → 追击 → 攻击 → 死亡掉落。
## 直线移动（与居民同一套方案），复杂地形阶段再上 NavigationAgent2D。

enum AIState { IDLE, CHASE, ATTACK, DIE }

## 支持的目标类型（EnemyData.attack_priority 可用值）。
## 新增目标类型时：在此登记 + 在 _nearest_in_type 加映射；测试会校验配置不越界。
const SUPPORTED_TARGET_TYPES := ["villager", "building", "player"]

## 敌人配置（enemy_*.tres）
@export var data: EnemyData
## 死亡后生成掉落物的场景
@export var pickup_scene: PackedScene

var current_hp := 0
var ai_state := AIState.IDLE
var target: Node2D = null
var attack_timer := 0.0
var _last_position := Vector2.ZERO
var _stuck_frames := 0
## 出生后朝城镇推进的目标点（夜袭用）；未设置则原地待机直到发现目标。
## 数据由波次生成器注入（march_point），地下城怪物不设置 → 保持站桩。
var march_target := Vector2.INF
## 重力（默认值，可由 game_config 覆盖）
var gravity := 1200.0

@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.MASK_WORLD_PLAYER
	var cfg := load("res://resources/data/game_config.tres") as GameConfig
	if cfg != null:
		gravity = cfg.enemy_gravity
	current_hp = data.max_hp
	_last_position = global_position

func take_damage(amount: int) -> void:
	if ai_state == AIState.DIE:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()

func _die() -> void:
	ai_state = AIState.DIE
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	if pickup_scene == null:
		return
	for entry in data.loot_table:
		var chance: float = entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var amount := randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		var pickup: Pickup = pickup_scene.instantiate()
		pickup.resource_id = str(entry.get("resource_id", "gold"))
		pickup.amount = amount
		get_parent().add_child(pickup)
		pickup.global_position = global_position

func _physics_process(delta: float) -> void:
	if ai_state == AIState.DIE:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	match ai_state:
		AIState.IDLE:
			_idle(delta)
		AIState.CHASE:
			_chase(delta)
		AIState.ATTACK:
			_attack(delta)
	move_and_slide()
	_update_visual()

func _update_visual() -> void:
	if visual == null:
		return
	if absf(velocity.x) > 0.1:
		visual.flip_h = velocity.x < 0

func _idle(delta: float) -> void:
	target = _find_target()
	if target != null:
		ai_state = AIState.CHASE
		return
	# 夜袭行军：朝城镇推进，直到进入感知范围发现目标。
	if march_target != Vector2.INF:
		if _move_toward(march_target, delta):
			velocity.x = 0.0

func _find_target() -> Node2D:
	for target_type in data.attack_priority:
		var node := _nearest_in_type(target_type, data.aggro_range)
		if node != null:
			return node
	return null

func _nearest_in_type(type_name: String, max_dist: float) -> Node2D:
	match type_name:
		"villager":
			return _nearest_in_group("villagers", max_dist)
		"building":
			var core := _nearest_in_group("core_buildings", max_dist)
			if core != null:
				return core
			return _nearest_in_group("buildings", max_dist)
		"player":
			return _nearest_in_group("players", max_dist)
	return null

func _nearest_in_group(group: String, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node2D
		if n == null:
			continue
		var d := global_position.distance_to(n.global_position)
		if d <= best_dist:
			best_dist = d
			best = n
	return best

func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		ai_state = AIState.IDLE
		return
	if global_position.distance_to(target.global_position) <= data.attack_range:
		attack_timer = 0.0
		ai_state = AIState.ATTACK
		return
	if _move_toward(target.global_position, delta):
		return
	_check_stuck()

func _attack(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		ai_state = AIState.IDLE
		return
	if global_position.distance_to(target.global_position) > data.attack_range:
		ai_state = AIState.CHASE
		return
	attack_timer += delta
	if attack_timer >= data.attack_interval:
		attack_timer = 0.0
		if target.has_method("take_damage"):
			target.take_damage(data.damage)

func _check_stuck() -> void:
	if global_position.distance_to(_last_position) < 1.0:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_position = global_position
	if _stuck_frames >= 30:
		_stuck_frames = 0
		target = null
		ai_state = AIState.IDLE

func _move_toward(target_pos: Vector2, delta: float) -> bool:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist <= 2.0:
		velocity.x = 0.0
		return true
	velocity.x = to_target.normalized().x * data.move_speed
	return false
