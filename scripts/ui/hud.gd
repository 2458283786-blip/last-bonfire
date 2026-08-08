extends CanvasLayer
## HUD 总控：键盘入口与面板开合（后续任务在此扩展）。

@onready var top_bar: PanelContainer = $TopBar

func _ready() -> void:
	top_bar.open_build_menu.connect(_toggle_build_menu)
	top_bar.open_villager_panel.connect(_toggle_villager_panel)

func _toggle_build_menu() -> void:
	pass  # Task 5 实现

func _toggle_villager_panel() -> void:
	pass  # Task 8 实现
