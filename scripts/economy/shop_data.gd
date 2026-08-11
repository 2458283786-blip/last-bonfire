class_name ShopData
extends Resource
## 商店配置：货品列表（物品 ID 数组），全部数据驱动（resources/data/shops/*.tres）。
## 新商店 = 新 .tres 引用已有物品；新货品 = 往数组加物品 ID。

## 商店显示名
@export var display_name: String = "商店"
## 货品（物品 ID，按顺序展示）
@export var goods: Array[String] = []
