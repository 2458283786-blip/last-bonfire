extends Node
## 敌人数据库：扫描 resources/data/enemy_*.tres 按 id 索引（房间生成等用）。
## 新敌人 = 新增一个 enemy_*.tres，自动入表。

const DATA_DIR := "res://resources/data/"

var _by_id: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	_by_id.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.begins_with("enemy_") or not file.ends_with(".tres"):
			continue
		var data := load(DATA_DIR + file) as EnemyData
		if data != null and data.id != "":
			_by_id[data.id] = data

func get_data(enemy_id: String) -> EnemyData:
	return _by_id.get(enemy_id)
