extends PanelContainer
## 顶部状态栏：血条/天数/昼夜阶段/资源/容量/居民/建造入口。
## 数据全部来自信号与全局单例，不写死数值。

const RESOURCE_IDS := ["wood", "stone", "gold", "monster_material"]
const RESOURCE_NAMES := {"wood": "木头", "stone": "石头", "gold": "金币", "monster_material": "材料"}
const PHASE_NAMES := {0: "白天", 1: "黄昏", 2: "夜晚"}

signal open_build_menu
signal open_villager_panel
signal open_backpack

@onready var health_bar: ProgressBar = $HBox/HealthBar
@onready var day_label: Label = $HBox/DayLabel
@onready var phase_label: Label = $HBox/PhaseLabel
@onready var phase_time_label: Label = $HBox/PhaseTimeLabel
@onready var capacity_label: Label = $HBox/CapacityLabel
@onready var villagers_button: Button = $HBox/VillagersButton
@onready var build_button: Button = $HBox/BuildButton
@onready var backpack_button: Button = $HBox/BackpackButton

var _resource_labels: Dictionary = {}

func _ready() -> void:
	for id in RESOURCE_IDS:
		_resource_labels[id] = get_node("HBox/" + _label_name(id))
	EconomyManager.stock_changed.connect(_on_stock_changed)
	DayManager.day_changed.connect(_on_day_changed)
	DayManager.phase_changed.connect(_on_phase_changed)
	villagers_button.pressed.connect(func() -> void: open_villager_panel.emit())
	build_button.pressed.connect(func() -> void: open_build_menu.emit())
	backpack_button.pressed.connect(func() -> void: open_backpack.emit())
	_on_day_changed(DayManager.day)
	_on_phase_changed(DayManager.phase)
	_refresh_resources()
	_refresh_capacity()

func _label_name(id: String) -> String:
	if id == "monster_material":
		return "MaterialLabel"
	return id.capitalize() + "Label"

func _process(_delta: float) -> void:
	phase_time_label.text = "剩余 %ds" % ceili(DayManager.phase_remaining())
	_update_health()
	_update_villager_count()

func _on_stock_changed(_resource_id: String, _amount: int) -> void:
	_refresh_resources()
	_refresh_capacity()

func _on_day_changed(day: int) -> void:
	day_label.text = "第 %d 天" % day

func _on_phase_changed(phase: int) -> void:
	phase_label.text = PHASE_NAMES.get(phase, "白天")

func _refresh_resources() -> void:
	for id in RESOURCE_IDS:
		var label: Label = _resource_labels.get(id)
		if label != null:
			label.text = "%s %d" % [RESOURCE_NAMES[id], EconomyManager.get_amount(id)]

func _refresh_capacity() -> void:
	capacity_label.text = "库存 %d/%d" % [EconomyManager.total_used(), EconomyManager.capacity]

func _update_health() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var player := players[0]
	health_bar.max_value = player.max_hp
	health_bar.value = player.hp

func _update_villager_count() -> void:
	var villagers := get_tree().get_nodes_in_group("villagers")
	var injured := 0
	for v in villagers:
		if v.is_injured:
			injured += 1
	villagers_button.text = "居民 %d · 受伤 %d" % [villagers.size(), injured]
