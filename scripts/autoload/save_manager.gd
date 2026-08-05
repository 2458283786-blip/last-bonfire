extends Node
## 存档管理（预留）：
## Demo 阶段决定启用后，在此实现 JSON 存档。
## 设计覆盖：建筑、居民、资源、昼夜、玩家背包/装备、解锁状态。

const SAVE_PATH := "user://save_game.json"

func save_game() -> void:
	# TODO: 收集 GameManager / 建筑 / 居民 / 资源状态后写入 SAVE_PATH
	pass

func load_game() -> void:
	# TODO: 读取 SAVE_PATH 并恢复各系统状态
	pass

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
