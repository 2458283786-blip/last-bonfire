extends Node2D
## 启动场景：后续替换为主菜单。
## 目前用于验证框架的场景切换链路：按 Enter 进入城镇场景。

func _ready() -> void:
	print("[Boot] 框架启动成功，按 Enter 进入城镇场景。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameManager.change_scene("res://scenes/town/town.tscn")
