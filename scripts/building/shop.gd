class_name ShopBuilding
extends Building
## 商店（功能型建筑，不占职业名额）：详情面板打开商店购买。
## 蓝图默认锁定（NPC 解救解锁，占位），调试期用 DebugManager.unlock_all_blueprints 解锁。

## 商店配置路径（.tres）
@export var shop_data_path: String = "res://resources/data/shops/basic_shop.tres"

var shop_data: ShopData = null

func _ready() -> void:
	super._ready()
	add_to_group("shops")
	shop_data = load(shop_data_path) as ShopData

## 详情面板据此判断是否显示"打开商店"。
func open_shop() -> bool:
	return shop_data != null
