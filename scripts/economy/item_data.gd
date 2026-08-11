class_name ItemData
extends Resource
## 物品配置：背包/商店/装备全部数据驱动（resources/data/items/*.tres）。
## 新物品 = 新增一个 .tres，无需改代码。

## 唯一 ID
@export var id: String = "item"
## 显示名
@export var display_name: String = "物品"
## 描述
@export_multiline var description: String = ""
## 类型：weapon / armor / accessory / consumable
@export var item_type: String = "consumable"
## 装备槽位：melee / ranged / armor / accessory（非装备类留空）
@export var slot: String = ""
## 攻击加成（武器）
@export var damage_bonus: int = 0
## 防御加成（护甲/饰品）
@export var defense_bonus: int = 0
## 使用效果：治疗量（消耗品）
@export var heal_amount: int = 0
## 商店售价（金币）
@export var price: int = 0
## 占位图标颜色（美术接入后替换为 icon 资源）
@export var icon_color: Color = Color(0.7, 0.7, 0.7, 1)
