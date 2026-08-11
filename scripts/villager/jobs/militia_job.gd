class_name MilitiaJob
extends DefenseJob
## 民兵：近战站桩守卫，伤害较高、攻击范围近（风险换伤害）。

func _init() -> void:
	job_name = "militia"
	attack_range = 50.0
	damage = 2
	attack_interval = 1.0
