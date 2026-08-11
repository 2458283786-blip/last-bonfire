extends PanelContainer
## 背包面板：装备槽（近战/远程/护甲/饰品）+ 物品列表（最简版本，数据驱动）。
## 后续扩展：词条/稀有度/更多槽位只改配置与面板展示，不动数据层。

@onready var gold_label: Label = $VBox/GoldLabel
@onready var material_label: Label = $VBox/MaterialLabel
@onready var melee_label: Label = $VBox/MeleeLabel
@onready var ranged_label: Label = $VBox/RangedLabel
@onready var armor_label: Label = $VBox/ArmorLabel
@onready var accessory_label: Label = $VBox/AccessoryLabel
@onready var item_list: VBoxContainer = $VBox/ItemList

func _ready() -> void:
	InventoryManager.inventory_changed.connect(func() -> void: _update())
	EconomyManager.stock_changed.connect(_update)
	_update()

func open_panel() -> void:
	visible = true
	_update()

func _update(_resource_id: String = "", _amount: int = 0) -> void:
	gold_label.text = "金币 %d" % EconomyManager.get_amount("gold")
	material_label.text = "怪物材料 %d" % EconomyManager.get_amount("monster_material")
	melee_label.text = "近战：%s" % _slot_name("melee")
	ranged_label.text = "远程：%s" % _slot_name("ranged")
	armor_label.text = "护甲：%s" % _slot_name("armor")
	accessory_label.text = "饰品：%s" % _slot_name("accessory")
	for child in item_list.get_children():
		child.queue_free()
	for item_id in InventoryManager.items:
		var data := InventoryManager.get_item(item_id)
		if data == null:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s ×%d" % [data.display_name, int(InventoryManager.items[item_id])]
		row.add_child(label)
		if data.item_type == "consumable":
			var use_btn := Button.new()
			use_btn.text = "使用"
			use_btn.pressed.connect(_on_use_pressed.bind(item_id))
			row.add_child(use_btn)
		elif data.slot != "":
			if InventoryManager.equipped(data.slot) == item_id:
				var unequip_btn := Button.new()
				unequip_btn.text = "卸下"
				unequip_btn.pressed.connect(_on_unequip_pressed.bind(data.slot))
				row.add_child(unequip_btn)
			else:
				var equip_btn := Button.new()
				equip_btn.text = "装备"
				equip_btn.pressed.connect(_on_equip_pressed.bind(data.slot, item_id))
				row.add_child(equip_btn)
		item_list.add_child(row)

func _slot_name(slot: String) -> String:
	var item_id := InventoryManager.equipped(slot)
	if item_id == "":
		return "—"
	var data := InventoryManager.get_item(item_id)
	return data.display_name if data != null else item_id

func _on_equip_pressed(slot: String, item_id: String) -> void:
	InventoryManager.equip(slot, item_id)
	_update()

func _on_unequip_pressed(slot: String) -> void:
	InventoryManager.unequip(slot)
	_update()

func _on_use_pressed(item_id: String) -> void:
	InventoryManager.use_consumable(item_id)
	_update()
