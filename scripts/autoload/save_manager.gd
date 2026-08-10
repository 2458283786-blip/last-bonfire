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
		"buildings": _collect_buildings(),
		"resources": _collect_resources(),
		"villagers": _collect_villagers(),
	}

func _apply(data: Dictionary) -> void:
	await _clear_world()
	DayManager.restore_state(data.get("day", {}))
	_apply_buildings(data.get("buildings", []))
	_apply_resources(data.get("resources", []))
	_apply_villagers(data.get("villagers", []))
	_apply_player(data.get("player", {}))
	EconomyManager.restore(data.get("economy", {}))
	for s in get_tree().get_nodes_in_group("wild_spawners"):
		s.refill_enabled = true
	TownRegistry.reset_daily_adjustments()

func _clear_world() -> void:
	for node in get_tree().get_nodes_in_group("buildings"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("resources"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("villagers"):
		node.queue_free()
	for s in get_tree().get_nodes_in_group("wild_spawners"):
		s.refill_enabled = false
	await get_tree().process_frame

func _collect_buildings() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Building
		if b == null:
			continue
		out.append({
			"scene_path": node.scene_file_path,
			"position": [node.global_position.x, node.global_position.y],
			"hp": b.hp,
			"is_destroyed": b.is_destroyed,
			"level": b.level,
		})
	return out

func _apply_buildings(data: Array) -> void:
	for entry in data:
		var scene := load(str(entry["scene_path"])) as PackedScene
		if scene == null:
			continue
		var b := scene.instantiate() as Building
		get_tree().current_scene.add_child(b)
		b.global_position = Vector2(entry["position"][0], entry["position"][1])
		b.hp = int(entry.get("hp", b.max_hp))
		b.is_destroyed = bool(entry.get("is_destroyed", false))
		b.level = int(entry.get("level", 1))
		b._update_visual()

func _collect_resources() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("resources"):
		var r := node as ResourceNode
		if r == null:
			continue
		out.append({
			"scene_path": node.scene_file_path,
			"position": [node.global_position.x, node.global_position.y],
			"current_hp": r.current_hp,
			"is_depleted": r.is_depleted,
			"respawn_day": r.respawn_day,
			"is_wild": r.is_wild,
		})
	return out

func _apply_resources(data: Array) -> void:
	for entry in data:
		var scene := load(str(entry["scene_path"])) as PackedScene
		if scene == null:
			continue
		var r := scene.instantiate() as ResourceNode
		get_tree().current_scene.add_child(r)
		r.global_position = Vector2(entry["position"][0], entry["position"][1])
		r.current_hp = int(entry.get("current_hp", r.data.max_hp))
		r.is_depleted = bool(entry.get("is_depleted", false))
		r.respawn_day = int(entry.get("respawn_day", -1))
		r.is_wild = bool(entry.get("is_wild", false))
		r._update_visual()

func _collect_villagers() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v == null:
			continue
		out.append({
			"scene_path": node.scene_file_path,
			"display_name": v.display_name,
			"job": v.job,
			"position": [node.global_position.x, node.global_position.y],
			"home_position": [v.home_position.x, v.home_position.y],
			"carry": v.carry.duplicate(),
			"hp": v.hp,
			"is_injured": v.is_injured,
			"injured_remaining_days": v.injured_remaining_days,
		})
	return out

func _apply_villagers(data: Array) -> void:
	for entry in data:
		var scene_path := str(entry.get("scene_path", "res://scenes/villagers/villager.tscn"))
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var v := scene.instantiate() as Villager
		get_tree().current_scene.add_child(v)
		v.set_physics_process(false)
		v.global_position = Vector2(entry["position"][0], entry["position"][1])
		v.home_position = Vector2(entry["home_position"][0], entry["home_position"][1])
		v.display_name = str(entry.get("display_name", "居民"))
		v.carry = (entry.get("carry", {}) as Dictionary).duplicate()
		v.hp = float(entry.get("hp", v.max_hp))
		v.is_injured = bool(entry.get("is_injured", false))
		v.injured_remaining_days = int(entry.get("injured_remaining_days", 0))
		v.set_job(str(entry.get("job", "idle")))
	_assign_woodcutters()

func _assign_woodcutters() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v == null or v.job != "woodcutter":
			continue
		for hut in TownRegistry.get_job_huts():
			if hut.has_method("can_accept_villager") and hut.can_accept_villager(v):
				hut.assign_villager(v)
				break

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
