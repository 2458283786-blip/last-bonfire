class_name BuildingData
extends Resource
## 建筑配置：建造菜单卡片与放置所需数据，全部在 .tres 中配置。

@export var id: String = "building"
@export var display_name: String = "建筑"
@export_multiline var description: String = ""
## 造价：resource_id -> 数量
@export var cost: Dictionary = {"wood": 10}
## 占位图标颜色（美术接入后替换为 icon 资源）
@export var icon_color: Color = Color(0.6, 0.6, 0.6)
## 对应建筑场景
@export var scene: PackedScene
## 占地半宽（放置间距校验用）
@export var footprint_half_width: float = 48.0
## 升级造价（预留）
@export var upgrade_cost: Dictionary = {}
## 升级效果描述（预留）
@export var upgrade_effect: String = ""
## 最高等级（升级链上限）
@export var max_level: int = 3
## 需要解锁才能建造（商店等 NPC 建筑用；DebugManager.unlock_all_blueprints 可强制解锁）
@export var requires_unlock: bool = false
## 建造菜单排序（BuildMenu 从数据库构建时按此升序排列）
@export var build_menu_order: int = 999
