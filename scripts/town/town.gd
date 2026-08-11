extends Node2D
## 城镇场景（占位）：
## 后续实现——居民采集、建筑放置与升级、昼夜循环、夜晚防御、地下通道入口。
## 地图在场景内用 TileMap / 手绘节点搭建（主场景内绘制）。

func _ready() -> void:
	print("[Town] 城镇场景已加载。")
	if GameManager.pending_load:
		GameManager.pending_load = false
		_show_loading_overlay()
		SaveManager.load_game()
	TownRegistry.spawn_pending_rescues()

## 读档前显示进度遮罩（SaveManager 进度信号驱动，完成后自动隐藏）。
func _show_loading_overlay() -> void:
	var overlay := (load(SceneRegistry.LOADING_OVERLAY) as PackedScene).instantiate()
	add_child(overlay)
