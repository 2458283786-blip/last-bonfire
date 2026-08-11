class_name TowerGuardJob
extends DefenseJob
## 箭塔驻守：远程站桩守卫，射程远、伤害低（稳但弱）。

func _init() -> void:
	job_name = "tower_guard"
	attack_range = 260.0
	damage = 1
	attack_interval = 1.2
	is_ranged = true
