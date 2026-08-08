extends Node
## 全局游戏状态：场景切换、暂停控制。
## 后续承载：全局进度、关卡解锁、昼夜状态等高层状态。

var is_paused: bool = false
## 是否处于建筑放置模式（放置时屏蔽玩家移动/战斗输入）
var is_placing := false

func set_placing(v: bool) -> void:
	is_placing = v

func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
