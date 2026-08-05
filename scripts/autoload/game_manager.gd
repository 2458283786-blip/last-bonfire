extends Node
## 全局游戏状态：场景切换、暂停控制。
## 后续承载：全局进度、关卡解锁、昼夜状态等高层状态。

var is_paused: bool = false

func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
