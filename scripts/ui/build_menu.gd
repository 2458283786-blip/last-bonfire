extends PanelContainer
## 底部建造菜单：卡片来自 BuildingData 配置（entry_paths 在场景中配置），资源不足自动置灰。

signal building_selected(data: BuildingData)
signal close_requested

## 建筑配置路径列表（Inspector 中配置）
@export var entry_paths: Array[String] = []

var entries: Array[BuildingData] = []
var _visible_entries: Array[BuildingData] = []

@onready var cards: HBoxContainer = $HBox

func _ready() -> void:
	# 未手动注入条目时，从建筑数据库按 build_menu_order 构建（单一注册表）。
	if entries.is_empty():
		entries = BuildingDatabase.all_data()
		entries.sort_custom(func(a: BuildingData, b: BuildingData) -> bool:
			return a.build_menu_order < b.build_menu_order)
	_rebuild_cards()
	EconomyManager.stock_changed.connect(_on_stock_changed)

func _rebuild_cards() -> void:
	for child in cards.get_children():
		child.queue_free()
	_visible_entries.clear()
	for entry in entries:
		if entry.requires_unlock and not DebugManager.blueprint_unlocked(entry.id, TownRegistry.is_blueprint_unlocked(entry.id)):
			continue
		_visible_entries.append(entry)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 90)
		btn.text = "%s\n%s" % [entry.display_name, _format_cost(entry.cost)]
		btn.tooltip_text = entry.description
		btn.pressed.connect(_on_card_pressed.bind(entry))
		cards.add_child(btn)
	_refresh()

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%s%d" % [ResourceDatabase.short_name(id), int(cost[id])])
	return " ".join(parts)

func _on_card_pressed(entry: BuildingData) -> void:
	building_selected.emit(entry)

func can_afford(data: BuildingData) -> bool:
	for id in data.cost:
		if EconomyManager.get_amount(id) < int(data.cost[id]):
			return false
	return true

func _refresh() -> void:
	for i in _visible_entries.size():
		var btn: Button = cards.get_child(i)
		btn.disabled = not can_afford(_visible_entries[i])

func _on_stock_changed(_resource_id: String, _amount: int) -> void:
	_refresh()
