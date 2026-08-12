class_name GameConfig
extends Resource
## 开局经济配置：库存与容量，数值在 game_config.tres 中手动调整。

## 开局库存（资源 ID -> 数量）
@export var starting_stock: Dictionary = {"wood": 10, "stone": 5}
## 初始库存容量（未建仓库时）
@export var default_capacity: int = 20

## 招募居民（测试期方案）：金币消耗、冷却天数、人口上限
@export var recruit_cost: int = 100
@export var recruit_cooldown_days: int = 2
@export var max_villagers: int = 8

## 物理与角色基础数值（默认值与当前脚本一致，避免手感漂移）
@export var gravity: float = 1200.0
@export var enemy_gravity: float = 1200.0
@export var villager_flee_speed_mult: float = 1.2
@export var villager_injured_speed_mult: float = 0.5

## 地下城时间流速倍率（相对城镇）：地下城内 2 秒只算城镇 1 秒，探索预算翻倍；0.5 为起点，待实测调参
@export var dungeon_time_scale: float = 0.5
