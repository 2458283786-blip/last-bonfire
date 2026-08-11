extends Node2D
## 启动场景：有存档显示"继续游戏"，否则"新游戏"；Enter 兼容旧流程（新游戏）。

@onready var continue_button: Button = $ContinueButton
@onready var new_game_button: Button = $NewGameButton

func _ready() -> void:
	print("[Boot] 框架启动成功。")
	continue_button.visible = SaveManager.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)

func _on_continue_pressed() -> void:
	GameManager.pending_load = true
	GameManager.change_scene(SceneRegistry.TOWN)

func _on_new_game_pressed() -> void:
	GameManager.change_scene(SceneRegistry.TOWN)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_new_game_pressed()
