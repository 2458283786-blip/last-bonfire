extends Node
## 存档管理：JSON 单文件、版本化、错误信号。
## 保存/恢复顺序与细节见 docs/design/2026-08-10-save-system-design.md。

signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_VERSION := 1

var save_path := "user://save_game.json"
var last_error := ""

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_game() -> bool:
	var data := _collect()
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		last_error = "无法写入存档文件"
		save_failed.emit(last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	last_error = ""
	return true

func load_game() -> bool:
	if not has_save():
		last_error = "没有存档"
		load_failed.emit(last_error)
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		last_error = "无法读取存档文件"
		load_failed.emit(last_error)
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "存档文件损坏"
		load_failed.emit(last_error)
		return false
	parsed = migrate(parsed)
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		last_error = "存档版本不兼容"
		load_failed.emit(last_error)
		return false
	await _apply(parsed)
	last_error = ""
	return true

func migrate(data: Dictionary) -> Dictionary:
	return data

func _collect() -> Dictionary:
	return {
		"day": DayManager.collect_state(),
		"economy": EconomyManager.collect_state(),
		"player": _collect_player(),
	}

func _apply(data: Dictionary) -> void:
	DayManager.restore_state(data.get("day", {}))
	_apply_player(data.get("player", {}))
	EconomyManager.restore(data.get("economy", {}))

func _collect_player() -> Dictionary:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return {}
	var p := players[0]
	return {
		"position": [p.global_position.x, p.global_position.y],
		"hp": p.hp,
	}

func _apply_player(data: Dictionary) -> void:
	if data.is_empty():
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var p := players[0]
	p.global_position = Vector2(data["position"][0], data["position"][1])
	p.hp = clampf(float(data.get("hp", p.max_hp)), 1.0, p.max_hp)
