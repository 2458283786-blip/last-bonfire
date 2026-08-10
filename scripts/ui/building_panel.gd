extends PanelContainer
## 建筑详情面板：展示基础信息并提供修复/重建/拆除入口；升级链开发中。

signal close_requested

@onready var title_label: Label = $VBox/TitleLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var hp_label: Label = $VBox/HpLabel
@onready var slots_label: Label = $VBox/SlotsLabel
@onready var assigned_label: Label = $VBox/AssignedLabel
@onready var upgrade_button: Button = $VBox/UpgradeButton
@onready var repair_button: Button = $VBox/RepairButton
@onready var demolish_button: Button = $VBox/DemolishButton
@onready var close_button: Button = $VBox/CloseButton
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

var _building: Building = null

func _ready() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	demolish_button.pressed.connect(_on_demolish_pressed)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	confirm_dialog.confirmed.connect(_on_demolish_confirmed)

func show_building(b: Building) -> void:
	_building = b
	visible = true
	_refresh()

func _refresh() -> void:
	if _building == null or not is_instance_valid(_building):
		visible = false
		return
	title_label.text = _building.display_name
	level_label.text = "等级 %d" % _building.level
	hp_label.text = "HP %d/%d" % [_building.hp, _building.max_hp]
	slots_label.text = _slots_text()
	assigned_label.text = _assigned_text()
	repair_button.visible = _building.hp < _building.max_hp or _building.is_destroyed
	repair_button.text = "重建" if _building.is_destroyed else "修复"

func _slots_text() -> String:
	if _building.get("job_slots") != null and _building.get("job_name") != null:
		return "%s %d/%d" % [TownRegistry.job_display_name(_building.job_name), _building.job_slots - _building.assigned.size(), _building.job_slots]
	return "—"

func _assigned_text() -> String:
	if _building.get("assigned") != null:
		var names: Array[String] = []
		for v in _building.assigned:
			names.append(v.display_name)
		return "已分配：" + (", ".join(names) if not names.is_empty() else "无")
	return "—"

func _on_upgrade_pressed() -> void:
	pass  # 升级链开发中，按钮常驻禁用

func _on_repair_pressed() -> void:
	if _building != null:
		_building.repair()
		_refresh()

func _on_demolish_pressed() -> void:
	confirm_dialog.popup_centered()

func _on_demolish_confirmed() -> void:
	if _building != null and is_instance_valid(_building):
		_building.queue_free()
	_building = null
	visible = false
