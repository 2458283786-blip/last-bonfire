extends CanvasLayer
## HUD 总控：键盘入口与面板开合。

@onready var top_bar: PanelContainer = $TopBar
@onready var build_menu: PanelContainer = $BuildMenu

func _ready() -> void:
	top_bar.open_build_menu.connect(_toggle_build_menu)
	top_bar.open_villager_panel.connect(_toggle_villager_panel)
	build_menu.building_selected.connect(_on_building_selected)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_placing:
		return
	if event.is_action_pressed("build_menu"):
		_toggle_build_menu()

func _toggle_build_menu() -> void:
	build_menu.visible = not build_menu.visible

func _toggle_villager_panel() -> void:
	pass  # Task 8 实现

func _on_building_selected(data: BuildingData) -> void:
	build_menu.visible = false
	var controller := PlacementController.new()
	get_tree().current_scene.add_child(controller)
	controller.begin(data)
	controller.placement_confirmed.connect(_on_placement_confirmed.bind(controller))
	controller.placement_canceled.connect(_on_placement_canceled.bind(controller))
	GameManager.set_placing(true)

func _on_placement_confirmed(_data: BuildingData, _pos: Vector2, controller: PlacementController) -> void:
	GameManager.set_placing(false)
	controller.queue_free()

func _on_placement_canceled(controller: PlacementController) -> void:
	GameManager.set_placing(false)
	controller.queue_free()
