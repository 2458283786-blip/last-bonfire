extends PanelContainer
## 商店面板：货品列表 + 购买（金币），购入进背包。数据来自 ShopData.goods。

signal close_requested

@onready var title_label: Label = $VBox/TitleLabel
@onready var goods_list: VBoxContainer = $VBox/GoodsList
@onready var close_button: Button = $VBox/CloseButton

var _shop: Node = null

func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	InventoryManager.inventory_changed.connect(func() -> void: _refresh())
	EconomyManager.stock_changed.connect(func(_a = null, _b = null) -> void: _refresh())

func open_shop(shop: Node) -> void:
	_shop = shop
	visible = true
	_refresh()

func _refresh() -> void:
	if _shop == null:
		return
	var data: ShopData = _shop.get("shop_data")
	title_label.text = data.display_name if data != null else "商店"
	for child in goods_list.get_children():
		child.queue_free()
	if data == null:
		return
	for item_id in data.goods:
		var item := InventoryManager.get_item(item_id)
		if item == null:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s　%s（%d 金）" % [item.display_name, item.description, item.price]
		row.add_child(label)
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.disabled = EconomyManager.get_amount("gold") < item.price
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		row.add_child(buy_btn)
		goods_list.add_child(row)

func _on_buy_pressed(item: ItemData) -> void:
	if EconomyManager.withdraw("gold", item.price):
		InventoryManager.add_item(item.id, 1)
	_refresh()
