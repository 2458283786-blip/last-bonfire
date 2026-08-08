class_name GameConfig
extends Resource
## 开局经济配置：库存与容量，数值在 game_config.tres 中手动调整。

## 开局库存（资源 ID -> 数量）
@export var starting_stock: Dictionary = {"wood": 10, "stone": 5}
## 初始库存容量（未建仓库时）
@export var default_capacity: int = 20
