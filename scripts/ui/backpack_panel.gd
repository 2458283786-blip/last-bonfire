extends PanelContainer
## 背包占位面板：先展示金币/材料，装备系统随地下城开发。

@onready var gold_label: Label = $VBox/GoldLabel
@onready var material_label: Label = $VBox/MaterialLabel

func _ready() -> void:
	EconomyManager.stock_changed.connect(_update)
	_update()

func open_panel() -> void:
	visible = true
	_update()

func _update(_resource_id: String = "", _amount: int = 0) -> void:
	gold_label.text = "金币 %d" % EconomyManager.get_amount("gold")
	material_label.text = "怪物材料 %d" % EconomyManager.get_amount("monster_material")
