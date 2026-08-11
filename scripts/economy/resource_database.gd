extends Node
## 资源数据库：加载 resources/data/resources/ 下所有 ResourceDef 并按 id 索引。
## UI 显示名/短名统一从这里读，禁止在代码里手写资源文案。

const DATA_DIR := "res://resources/data/resources/"

var _by_id: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	_by_id.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("ResourceDatabase: 无法打开配置目录 " + DATA_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var data := load(DATA_DIR + file) as ResourceDef
		if data != null and data.id != "":
			_by_id[data.id] = data

func get_data(resource_id: String) -> ResourceDef:
	return _by_id.get(resource_id)

func display_name(resource_id: String) -> String:
	var data := get_data(resource_id)
	return data.display_name if data != null else resource_id

func short_name(resource_id: String) -> String:
	var data := get_data(resource_id)
	return data.short_name if data != null else resource_id

func all_data() -> Array[ResourceDef]:
	var out: Array[ResourceDef] = []
	for id in _by_id:
		out.append(_by_id[id])
	return out
