extends PanelContainer
## 居民管理面板：列表 + 转职选项，每人每天限一次手动调整。

signal close_requested

const STATE_NAMES := {
	0: "空闲", 1: "找活", 2: "去工作", 3: "工作中", 4: "搬运",
	5: "运回仓库", 6: "入库", 7: "漫游",
}

@onready var villager_list: VBoxContainer = $HBox/Left/VillagerList
@onready var job_options: VBoxContainer = $HBox/Right/JobOptions
@onready var hint_label: Label = $HBox/Right/HintLabel
@onready var close_button: Button = $HBox/Right/CloseButton

var _selected: Villager = null

func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	TownRegistry.villager_registered.connect(func(_v: Villager) -> void: refresh())
	TownRegistry.villager_unregistered.connect(func(_v: Villager) -> void: refresh())
	TownRegistry.daily_adjustments_reset.connect(func() -> void: refresh())

func open_panel() -> void:
	visible = true
	_selected = null
	refresh()

func refresh() -> void:
	for child in villager_list.get_children():
		villager_list.remove_child(child)
		child.queue_free()
	for v in TownRegistry.get_villagers():
		var btn := Button.new()
		btn.text = "%s · %s · %s" % [v.display_name, "伐木工" if v.job == "woodcutter" else "空闲", _status_text(v)]
		btn.pressed.connect(_on_villager_pressed.bind(v))
		villager_list.add_child(btn)
	if _selected == null or not is_instance_valid(_selected):
		_rebuild_job_options(null)
	else:
		_rebuild_job_options(_selected)

func _status_text(v: Villager) -> String:
	if v.is_injured:
		return "受伤 %d 天" % v.injured_remaining_days
	return STATE_NAMES.get(v.state, "空闲")

func _on_villager_pressed(v: Villager) -> void:
	_selected = v
	_rebuild_job_options(v)

func _rebuild_job_options(v: Villager) -> void:
	for child in job_options.get_children():
		job_options.remove_child(child)
		child.queue_free()
	if v == null:
		hint_label.text = "选择一名居民查看/调整职业"
		return
	if TownRegistry.adjusted_today(v.villager_id):
		hint_label.text = "今日已调整过该居民，明天可再调整"
		return
	hint_label.text = "选择目标职业（每天限一次）"
	for hut in TownRegistry.get_job_huts():
		if not hut.has_method("can_accept_villager"):
			continue
		var btn := Button.new()
		btn.text = "%s（剩余 %d）" % [hut.display_name, hut.job_slots - hut.assigned.size()]
		btn.disabled = not hut.can_accept_villager(v)
		btn.pressed.connect(_on_job_hut_pressed.bind(hut))
		job_options.add_child(btn)
	var idle_btn := Button.new()
	idle_btn.text = "转为空闲"
	idle_btn.pressed.connect(_on_idle_pressed.bind(v))
	job_options.add_child(idle_btn)

func _on_job_hut_pressed(hut: Node) -> void:
	try_assign_to_hut(_selected, hut)

func _on_idle_pressed(v: Villager) -> void:
	try_assign_idle(v)

func try_assign_to_hut(v: Villager, hut: Node) -> bool:
	if v == null or hut == null or TownRegistry.adjusted_today(v.villager_id):
		return false
	if not hut.has_method("can_accept_villager") or not hut.can_accept_villager(v):
		return false
	_release_from_huts(v)
	hut.assign_villager(v)
	TownRegistry.mark_adjusted(v.villager_id)
	refresh()
	return true

func try_assign_idle(v: Villager) -> bool:
	if v == null or TownRegistry.adjusted_today(v.villager_id):
		return false
	_release_from_huts(v)
	v.set_job("idle")
	TownRegistry.mark_adjusted(v.villager_id)
	refresh()
	return true

func _release_from_huts(v: Villager) -> void:
	for hut in TownRegistry.get_job_huts():
		if hut.has_method("release_villager") and hut.get("assigned") != null:
			var assigned: Array = hut.assigned
			if assigned.has(v):
				hut.release_villager(v)
