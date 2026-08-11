class_name DefenseJob
extends RefCounted
## 防御职业基类：站桩守卫（不巡逻、不追击），敌人进入攻击范围自动攻击。
## 数值由所属防御建筑分配时注入（configure），新防御职业 = 子类 + 建筑配置，不改通用逻辑。

var job_name := "defense"
var attack_range := 60.0
var damage := 1
var attack_interval := 1.0
var is_ranged := false
var projectile_scene: PackedScene = null
var projectile_speed := 520.0

var _post: Node2D = null
var _cooldown := 0.0

## 从所属防御建筑注入数值（攻击范围/伤害/间隔/远程/弹道）。
func configure(hut: Node) -> void:
	_post = hut
	if hut == null:
		return
	if hut.get("attack_range") != null:
		attack_range = float(hut.attack_range)
	if hut.get("attack_damage") != null:
		damage = int(hut.attack_damage)
	if hut.get("attack_interval") != null:
		attack_interval = float(hut.attack_interval)
	if hut.get("is_ranged") != null:
		is_ranged = bool(hut.is_ranged)
	if hut.get("projectile_scene") != null:
		projectile_scene = hut.projectile_scene
	if hut.get("projectile_speed") != null:
		projectile_speed = float(hut.projectile_speed)

## 站岗位置：防御建筑坐标（建筑建在哪就守在哪，复用建造系统做布防决策）。
func get_post(_villager: Villager) -> Vector2:
	if _post != null and is_instance_valid(_post):
		return _post.global_position
	return Vector2.ZERO

## 站桩攻击：范围内有敌人就攻击；防御职业永不返回"完成"。
func work(villager: Villager, delta: float) -> bool:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := _nearest_enemy(villager, attack_range)
	if target == null:
		return false
	if _cooldown > 0.0:
		return false
	_cooldown = attack_interval
	if is_ranged and projectile_scene != null:
		_fire_projectile(villager, target)
	else:
		if target.has_method("take_damage"):
			target.take_damage(damage)
	return false

func _nearest_enemy(villager: Villager, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_dist := max_dist
	var post := get_post(villager)
	for node in villager.get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null:
			continue
		var d := post.distance_to(e.global_position)
		if d <= best_dist:
			best_dist = d
			best = e
	return best

func _fire_projectile(villager: Villager, target: Node2D) -> void:
	var bolt: Node = projectile_scene.instantiate()
	villager.get_parent().add_child(bolt)
	bolt.global_position = get_post(villager)
	if bolt.get("arrow_damage") != null:
		bolt.arrow_damage = damage
	if bolt.has_method("setup"):
		bolt.setup((target.global_position - bolt.global_position).normalized(), projectile_speed)
