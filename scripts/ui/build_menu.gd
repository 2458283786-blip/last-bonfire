extends PanelContainer
## 底部建造菜单：卡片来自 BuildingData 配置（entry_paths 在场景中配置），资源不足自动置灰。

signal building_selected(data: BuildingData)
signal close_requested

## 建筑配置路径列表（Inspector 中配置）
@export var entry_paths: Array[String] = []

var entries: Array[BuildingData] = []

@onready var cards: HBoxContainer = $HBox

func _ready() -> void:
	for path in entry_paths:
		var data := load(path) as BuildingData
		if data != null:
			entries.append(data)
	_rebuild_cards()
	EconomyManager.stock_changed.connect(_on_stock_changed)

func _rebuild_cards() -> void:
	for child in cards.get_children():
		child.queue_free()
	for entry in entries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 90)
		btn.text = "%s\n木 %d 石 %d" % [entry.display_name, int(entry.cost.get("wood", 0)), int(entry.cost.get("stone", 0))]
		btn.tooltip_text = entry.description
		btn.pressed.connect(_on_card_pressed.bind(entry))
		cards.add_child(btn)
	_refresh()

func _on_card_pressed(entry: BuildingData) -> void:
	building_selected.emit(entry)

func can_afford(data: BuildingData) -> bool:
	for id in data.cost:
		if EconomyManager.get_amount(id) < int(data.cost[id]):
			return false
	return true

func _refresh() -> void:
	for i in entries.size():
		var btn: Button = cards.get_child(i)
		btn.disabled = not can_afford(entries[i])

func _on_stock_changed(_resource_id: String, _amount: int) -> void:
	_refresh()
