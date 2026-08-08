class_name NightWaveSpawner
extends Node2D
## 夜晚波次生成器：夜晚阶段在城镇边缘生成一波怪物，强度随天数递增。
## 生成位置 = 本节点位置 + spawn_offsets（循环使用）。

## 夜晚生成的怪物场景
@export var enemy_scene: PackedScene
## 第一晚怪物数量
@export var base_wave_size: int = 2
## 每晚增加数量
@export var wave_growth: int = 1
## 波次数量上限
@export var max_wave_size: int = 10
## 出生点偏移（相对本节点位置，循环使用）
@export var spawn_offsets: Array[Vector2] = [Vector2(-200, 0), Vector2(200, 0)]

func _ready() -> void:
	add_to_group("night_wave_spawners")
	DayManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: int) -> void:
	if phase == DayManager.TimePhase.NIGHT:
		_spawn_wave()

func _spawn_wave() -> void:
	if enemy_scene == null:
		return
	var count := mini(base_wave_size + (DayManager.day - 1) * wave_growth, max_wave_size)
	for i in count:
		var enemy: Enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		var offset := Vector2(i * 40.0, 0.0)
		if not spawn_offsets.is_empty():
			offset = spawn_offsets[i % spawn_offsets.size()]
		enemy.global_position = global_position + offset
	EventBus.wave_spawned.emit(count)
