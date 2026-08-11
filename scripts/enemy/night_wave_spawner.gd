class_name NightWaveSpawner
extends Node2D
## 夜晚波次生成器：夜晚阶段（或玩家晚归强制入夜）在城镇边缘生成一波怪物。
## 强度 = 天数基线 + 城镇规模加成（居民/建筑/囤积）± 随机浮动，上限封顶。
## 探索超时强制入夜时波次额外加强（away_bonus_multiplier）。
## 所有系数均为导出配置，待实测调参。

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
## 刷怪带（世界坐标矩形）：设置后怪物在带内随机位置生成（屏幕外），替代 spawn_offsets。
## 未设置（size 为 0）时回退到 spawn_offsets。
@export var spawn_band: Rect2 = Rect2()
## 城镇范围：刷怪位置必须落在城镇之外（带内随机点若落入城镇则重试）。
@export var town_bounds: Rect2 = Rect2()
## 夜袭怪物的行军目标（朝城镇推进，直到发现目标；Vector2.INF 表示不推进）。
@export var march_point: Vector2 = Vector2.INF
## 额外威胁预警半径：以行军目标为中心广播威胁（提醒居民避险）；0 关闭。
@export var warning_radius: float = 0.0
## 每多少名居民 +1 波次
@export var villagers_per_point: int = 2
@export var villagers_bonus: int = 1
## 每多少座未摧毁建筑 +1 波次
@export var buildings_per_point: int = 3
@export var buildings_bonus: int = 1
## 库存囤积惩罚：总量超过阈值后每 hoard_per_point +1
@export var hoard_threshold: int = 60
@export var hoard_per_point: int = 30
@export var hoard_bonus: int = 1
## 随机浮动幅度（±）
@export var random_variance: float = 0.2
## 玩家探索超时强制入夜时的波次倍率
@export var away_bonus_multiplier: float = 1.5

func _ready() -> void:
	add_to_group("night_wave_spawners")
	DayManager.phase_changed.connect(_on_phase_changed)
	# 晚归/读档在夜晚：补刷当晚波次（wave_triggered_tonight 防重复）
	if DayManager.phase == DayManager.TimePhase.NIGHT:
		_spawn_wave()

func _on_phase_changed(phase: int) -> void:
	if phase == DayManager.TimePhase.NIGHT:
		_spawn_wave()

func _spawn_wave() -> void:
	if enemy_scene == null:
		return
	if DayManager.wave_triggered_tonight:
		return
	DayManager.wave_triggered_tonight = true
	var count := _wave_size()
	for i in count:
		var enemy: Enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = _spawn_position(i)
		enemy.march_target = march_point
		EventBus.threat_broadcast.emit(enemy.global_position, enemy.data.aggro_range)
	if warning_radius > 0.0 and march_point != Vector2.INF:
		EventBus.threat_broadcast.emit(march_point, warning_radius)
	EventBus.wave_spawned.emit(count)

## 选择刷怪位置：优先在刷怪带内随机（且不在城镇内）；否则用偏移。
func _spawn_position(index: int) -> Vector2:
	if spawn_band.size.x > 0.0 and spawn_band.size.y > 0.0:
		for attempt in 20:
			var pos := Vector2(
				randf_range(spawn_band.position.x, spawn_band.position.x + spawn_band.size.x),
				randf_range(spawn_band.position.y, spawn_band.position.y + spawn_band.size.y))
			if not _inside_town(pos):
				return pos
		# 带内全部落在城镇内（配置错误）时退回带中心，避免死循环。
		return spawn_band.position + spawn_band.size / 2.0
	var offset := Vector2(index * 40.0, 0.0)
	if not spawn_offsets.is_empty():
		offset = spawn_offsets[index % spawn_offsets.size()]
	return global_position + offset

func _inside_town(pos: Vector2) -> bool:
	if town_bounds.size.x <= 0.0 or town_bounds.size.y <= 0.0:
		return false
	return town_bounds.has_point(pos)

## 波次数量：天数基线 + 城镇规模加成 + 囤积惩罚，乘以晚归倍率与随机浮动，上限封顶。
func _wave_size() -> int:
	var base := mini(base_wave_size + (DayManager.day - 1) * wave_growth, max_wave_size)
	base += _villager_bonus() + _building_bonus() + _hoard_bonus()
	if DungeonManager.consume_night_forced():
		base = roundi(base * away_bonus_multiplier)
	var variance := randf_range(1.0 - random_variance, 1.0 + random_variance)
	return clampi(roundi(base * variance), 0, max_wave_size)

func _villager_bonus() -> int:
	var count := get_tree().get_nodes_in_group("villagers").size()
	return count / maxi(villagers_per_point, 1) * villagers_bonus

func _building_bonus() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Building
		if b != null and not b.is_destroyed:
			count += 1
	return count / maxi(buildings_per_point, 1) * buildings_bonus

func _hoard_bonus() -> int:
	var used := EconomyManager.total_used()
	if used <= hoard_threshold:
		return 0
	return (used - hoard_threshold) / maxi(hoard_per_point, 1) * hoard_bonus
