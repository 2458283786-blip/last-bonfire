class_name DefenseHut
extends JobHut
## 防御建筑基类：把空闲居民转职为防御职业（民兵/箭塔驻守），站桩守卫城镇。
## 数值（攻击范围/伤害/间隔/是否远程/弹道）在场景中配置，升级加名额。
## 新防御建筑 = 新 .tscn + .tres + 新防御职业类，无需复制逻辑。

## 防御职业名（militia / tower_guard / 未来新职业）
@export var defense_job_name: String = "militia"
## 守卫攻击范围（像素）
@export var attack_range: float = 60.0
## 单次攻击伤害
@export var attack_damage: int = 1
## 攻击间隔（秒）
@export var attack_interval: float = 1.0
## 是否远程（箭塔驻守）
@export var is_ranged: bool = false
## 远程弹道场景（默认 arrow.tscn / tower_bolt.tscn）
@export var projectile_scene: PackedScene
## 弹道飞行速度
@export var projectile_speed: float = 520.0

func _ready() -> void:
	job_name = defense_job_name
	super._ready()

func assign_villager(v: Villager) -> void:
	super.assign_villager(v)
	_configure_defense_job(v)

func _configure_defense_job(v: Villager) -> void:
	var j := v.current_job
	if j is DefenseJob:
		j.configure(self)
