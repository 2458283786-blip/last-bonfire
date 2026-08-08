extends CanvasLayer
## HUD 总控：键盘入口与面板开合。

@onready var top_bar: PanelContainer = $TopBar
@onready var build_menu: PanelContainer = $BuildMenu
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var toast_queue: VBoxContainer = $ToastQueue
@onready var interact_hint: Label = $InteractHint
@onready var night_overlay: Control = $NightOverlay
@onready var villager_panel: PanelContainer = $VillagerPanel
@onready var pause_menu: PanelContainer = $PauseMenu
@onready var backpack_panel: PanelContainer = $BackpackPanel
@onready var placement_hint: Label = $PlacementHint

var _selector: BuildingSelector = null

func _ready() -> void:
	top_bar.open_build_menu.connect(_toggle_build_menu)
	top_bar.open_villager_panel.connect(_toggle_villager_panel)
	build_menu.building_selected.connect(_on_building_selected)
	building_panel.close_requested.connect(func() -> void: building_panel.visible = false)
	villager_panel.close_requested.connect(func() -> void: villager_panel.visible = false)
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.settings_requested.connect(func() -> void: toast_queue.push("设置功能开发中"))
	pause_menu.save_requested.connect(func() -> void: toast_queue.push("存档功能预留中"))
	pause_menu.exit_requested.connect(func() -> void: GameManager.change_scene("res://scenes/main/boot.tscn"))
	top_bar.open_backpack.connect(_toggle_backpack)
	_selector = BuildingSelector.new()
	get_tree().current_scene.add_child(_selector)
	_selector.building_selected.connect(_on_building_clicked)
	EventBus.villager_injured.connect(func(id: String) -> void: toast_queue.push("居民受伤了（ID %s），将休养数日" % id))
	EventBus.building_destroyed.connect(func(id: String) -> void: toast_queue.push("建筑被摧毁：" + id))
	EventBus.building_built.connect(func(id: String) -> void: toast_queue.push("建筑建成：" + id))
	EventBus.pickup_collected.connect(func(resource_id: String, amount: int) -> void: toast_queue.push("%s +%d" % [resource_name(resource_id), amount]))
	EventBus.wave_spawned.connect(func(count: int) -> void: toast_queue.push("夜晚波次来袭（%d 只怪物）" % count))
	EventBus.villager_converted.connect(func(display_name: String, job: String) -> void: toast_queue.push("%s 成为%s" % [display_name, "伐木工" if job == "woodcutter" else job]))

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_placing:
		return
	if event.is_action_pressed("build_menu"):
		_toggle_build_menu()
	elif event.is_action_pressed("villager_panel"):
		_toggle_villager_panel()
	elif event.is_action_pressed("backpack"):
		_toggle_backpack()
	elif event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("interact"):
		_try_interact()

func _toggle_build_menu() -> void:
	build_menu.visible = not build_menu.visible

func _toggle_villager_panel() -> void:
	if villager_panel.visible:
		villager_panel.visible = false
	else:
		villager_panel.open_panel()

func _toggle_pause() -> void:
	if GameManager.is_paused:
		GameManager.resume_game()
		pause_menu.visible = false
	else:
		GameManager.pause_game()
		pause_menu.visible = true

func _toggle_backpack() -> void:
	if backpack_panel.visible:
		backpack_panel.visible = false
	else:
		backpack_panel.open_panel()

func _on_building_selected(data: BuildingData) -> void:
	build_menu.visible = false
	var controller := PlacementController.new()
	get_tree().current_scene.add_child(controller)
	controller.begin(data)
	controller.placement_confirmed.connect(_on_placement_confirmed.bind(controller))
	controller.placement_canceled.connect(_on_placement_canceled.bind(controller))
	controller.placement_rejected.connect(func(reason: String) -> void: toast_queue.push("无法建造：" + reason))
	GameManager.set_placing(true)
	placement_hint.visible = true
	placement_hint.text = "左键 / 空格 / 回车：放置　·　右键 / Esc：取消（%s）" % data.display_name

func _on_placement_confirmed(_data: BuildingData, _pos: Vector2, controller: PlacementController) -> void:
	GameManager.set_placing(false)
	placement_hint.visible = false
	controller.queue_free()

func _on_placement_canceled(controller: PlacementController) -> void:
	GameManager.set_placing(false)
	placement_hint.visible = false
	controller.queue_free()

func _on_building_clicked(b: Building) -> void:
	building_panel.show_building(b)

func resource_name(id: String) -> String:
	match id:
		"wood": return "木头"
		"stone": return "石头"
		"gold": return "金币"
		"monster_material": return "怪物材料"
	return id

func _try_interact() -> void:
	var player := _get_player()
	if player == null:
		return
	for node in get_tree().get_nodes_in_group("interactables"):
		var ia := node as Interactable
		if ia != null and ia.try_interact(player.global_position):
			toast_queue.push(ia.prompt)
			return

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	return players[0] as Node2D if not players.is_empty() else null
