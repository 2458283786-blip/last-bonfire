extends Node
## 建筑数据库：加载 resources/data/buildings/ 下所有 BuildingData 并按 id 索引。
## 建筑实例通过 building_id 查询自己的配置（造价/升级/解锁），避免在场景里重复配置。

const DATA_DIR := "res://resources/data/buildings/"

var _by_id: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	_by_id.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("BuildingDatabase: 无法打开配置目录 " + DATA_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var data := load(DATA_DIR + file) as BuildingData
		if data != null and data.id != "":
			_by_id[data.id] = data

func get_data(building_id: String) -> BuildingData:
	return _by_id.get(building_id)

func all_data() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for id in _by_id:
		out.append(_by_id[id])
	return out
