class_name DungeonNodeData
extends Resource
## 地下城房间数据：类型/房间/敌人/掉落，全部数据驱动。
## 类型：combat / elite / chest / rescue / boss。

## 唯一 ID
@export var id: String = "room"
## 显示名（门选择/房间标题）
@export var display_name: String = "房间"
## 类型：combat / elite / chest / rescue / boss
@export var type: String = "combat"
## 房间预制件（生成器按类型注入）
@export var room_scene: PackedScene
## 敌人配置 id 列表（EnemyDatabase 索引，如 night_wolf / boss_wolf）
@export var enemy_ids: Array[String] = []
## 宝箱房掉落 [{resource_id, min, max}]
@export var loot: Array[Dictionary] = []
