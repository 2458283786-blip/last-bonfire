class_name EnemyData
extends Resource
## 敌人配置：属性全部来自 enemy_*.tres。
## loot_table 每项：{resource_id, min, max, chance}。

## 唯一 ID（存档/掉落用）
@export var id: String = "enemy"
## 显示名称
@export var display_name: String = "怪物"
## 视觉（先占位色块）
@export var texture: Texture2D
## 血量
@export var max_hp: int = 3
## 移动速度
@export var move_speed: float = 110.0
## 单次攻击伤害
@export var damage: int = 1
## 攻击间隔（秒）
@export var attack_interval: float = 1.2
## 近战攻击距离
@export var attack_range: float = 28.0
## 发现目标的距离
@export var aggro_range: float = 600.0
## 攻击优先级（按顺序找目标）：villager / building / player
@export var attack_priority: Array[String] = ["villager", "building", "player"]
## 类型预留：melee / ranged / boss / flier
@export var enemy_type: String = "melee"
## 减伤（预留）
@export var armor: int = 0
## 经验（预留）
@export var experience: int = 0
## 碰撞半径
@export var collision_radius: float = 10.0
## 掉落表
@export var loot_table: Array[Dictionary] = []
