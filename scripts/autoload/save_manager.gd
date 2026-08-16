extends Node
## 存档管理：JSON 单文件、版本化、错误信号。
## 保存/恢复顺序与细节见 docs/design/2026-08-10-save-system-design.md。

signal save_failed(reason: String)
signal load_failed(reason: String)
signal load_started
signal load_progress(percent: float, label: String)
signal load_finished(ok: bool)

const SAVE_VERSION := 3
## 读档分帧批量大小（每帧恢复多少个实体，配合进度条避免卡顿）
const LOAD_BATCH_SIZE := 12

var save_path := "user://save_game.json"
var last_error := ""

func _ready() -> void:
	DayManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int) -> void:
	if get_tree().current_scene != null and get_tree().current_scene.name == "Town":
		save_game()

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
	load_started.emit()
	if not has_save():
		last_error = "没有存档"
		load_failed.emit(last_error)
		load_finished.emit(false)
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		last_error = "无法读取存档文件"
		load_failed.emit(last_error)
		load_finished.emit(false)
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "存档文件损坏"
		load_failed.emit(last_error)
		load_finished.emit(false)
		return false
	parsed = migrate(parsed)
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		last_error = "存档版本不兼容"
		load_failed.emit(last_error)
		load_finished.emit(false)
		return false
	await _apply(parsed)
	last_error = ""
	load_finished.emit(true)
	return true

func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		# 未来版本存档不能静默降级读取，交给 load_game 的版本校验拦截。
		return data
	while version < SAVE_VERSION:
		version += 1
		match version:
			2:
				data = _migrate_v1_to_v2(data)
			3:
				data = _migrate_v2_to_v3(data)
			_:
				push_warning("SaveManager: 未知迁移目标版本 %d" % version)
				break
	data["version"] = SAVE_VERSION
	return data

## v1 → v2：旧档无背包与城镇招募字段，补默认值。
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	if not data.has("inventory"):
		data["inventory"] = {"equipment": {}, "items": {}}
	if not data.has("town"):
		data["town"] = {"last_recruit_day": -1000}
	return data

## v2 → v3：补充蓝图解锁表（旧档默认空）。
func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	if not data.has("unlocked_blueprints"):
		data["unlocked_blueprints"] = {}
	return data

func _collect() -> Dictionary:
	return {
		"day": DayManager.collect_state(),
		"economy": EconomyManager.collect_state(),
		"player": _collect_player(),
		"buildings": _collect_buildings(),
		"resources": _collect_resources(),
		"villagers": _collect_villagers(),
		"inventory": InventoryManager.collect_state(),
		"town": TownRegistry.collect_state(),
		"unlocked_blueprints": TownRegistry.unlocked_blueprints.duplicate(),
	}

func _apply(data: Dictionary) -> void:
	_emit_progress(0.05, "正在清场…")
	await _clear_world()
	DayManager.restore_state(data.get("day", {}))
	await _apply_entries_chunked(data.get("buildings", []), _apply_building, 0.10, 0.35, "恢复建筑…")
	await _apply_entries_chunked(data.get("resources", []), _apply_resource, 0.38, 0.60, "恢复资源…")
	await _apply_entries_chunked(data.get("villagers", []), _apply_villager, 0.63, 0.82, "恢复居民…")
	_assign_homes()
	_release_homeless_jobs()
	_assign_job_villagers()
	_resume_villagers()
	_apply_player(data.get("player", {}))
	EconomyManager.restore(data.get("economy", {}))
	InventoryManager.restore(data.get("inventory", {}))
	TownRegistry.restore_state(data.get("town", {}))
	TownRegistry.unlocked_blueprints = (data.get("unlocked_blueprints", {}) as Dictionary).duplicate()
	_emit_progress(0.92, "恢复经济与背包…")
	for s in get_tree().get_nodes_in_group("wild_spawners"):
		s.refill_enabled = true
	TownRegistry.reset_daily_adjustments()
	_emit_progress(1.0, "读档完成")

## 分帧恢复实体：每帧处理一批，按完成比例发进度信号。
func _apply_entries_chunked(data: Array, apply_fn: Callable, start_pct: float, end_pct: float, label: String) -> void:
	if data.is_empty():
		_emit_progress(end_pct, label)
		return
	for i in range(0, data.size(), LOAD_BATCH_SIZE):
		for entry in data.slice(i, mini(i + LOAD_BATCH_SIZE, data.size())):
			apply_fn.call(entry)
		var done := mini(i + LOAD_BATCH_SIZE, data.size())
		_emit_progress(start_pct + (end_pct - start_pct) * float(done) / float(data.size()), label)
		await get_tree().process_frame

func _emit_progress(percent: float, label: String) -> void:
	load_progress.emit(clampf(percent, 0.0, 1.0), label)

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

func _apply_building(entry: Dictionary) -> void:
	var scene := load(str(entry["scene_path"])) as PackedScene
	if scene == null:
		return
	var b := scene.instantiate() as Building
	get_tree().current_scene.add_child(b)
	b.global_position = Vector2(entry["position"][0], entry["position"][1])
	b.hp = int(entry.get("hp", b.max_hp))
	b.is_destroyed = bool(entry.get("is_destroyed", false))
	b.level = int(entry.get("level", 1))
	b._update_visual()
	b.refresh_function_state()

func _collect_resources() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("resources"):
		var r := node as ResourceNode
		if r == null:
			continue
		if r.get_parent() is ResourceCamp:
			continue  # 场内资源由资源建筑自动生成，不单独存档（避免读档重复）
		out.append({
			"scene_path": node.scene_file_path,
			"position": [node.global_position.x, node.global_position.y],
			"current_hp": r.current_hp,
			"is_depleted": r.is_depleted,
			"respawn_day": r.respawn_day,
			"is_wild": r.is_wild,
		})
	return out

func _apply_resource(entry: Dictionary) -> void:
	var scene := load(str(entry["scene_path"])) as PackedScene
	if scene == null:
		return
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
			"character_id": v.character_id,
			"job": v.job,
			"position": [node.global_position.x, node.global_position.y],
			"home_position": [v.home_position.x, v.home_position.y],
		"carry": v.carry.duplicate(),
		"hp": v.hp,
		"is_injured": v.is_injured,
		"injured_remaining_days": v.injured_remaining_days,
		"move_speed": v.move_speed,
	})
	return out

func _apply_villager(entry: Dictionary) -> void:
	var scene_path := str(entry.get("scene_path", SceneRegistry.VILLAGER))
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var v := scene.instantiate() as Villager
	get_tree().current_scene.add_child(v)
	# 恢复期间冻结物理，全部就位后再统一恢复（_resume_villagers），避免恢复中途乱跑。
	v.set_physics_process(false)
	v.global_position = Vector2(entry["position"][0], entry["position"][1])
	v.home_position = Vector2(entry["home_position"][0], entry["home_position"][1])
	v.display_name = str(entry.get("display_name", "居民"))
	v.character_id = str(entry.get("character_id", "soldier"))
	v.carry = (entry.get("carry", {}) as Dictionary).duplicate()
	v.hp = float(entry.get("hp", v.max_hp))
	v.is_injured = bool(entry.get("is_injured", false))
	v.injured_remaining_days = int(entry.get("injured_remaining_days", 0))
	v.move_speed = float(entry.get("move_speed", v.move_speed))
	v.set_job(str(entry.get("job", "idle")))
	v._build_visual()

## 恢复完成后重新开启居民物理处理（修复读档后村民站立不动）。
func _resume_villagers() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v != null:
			v.set_physics_process(true)

## 读档后按容量给居民分配住宅（建筑先恢复，住宅已存在）。
func _assign_homes() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v == null or v.has_home():
			continue
		for house in get_tree().get_nodes_in_group("housing_buildings"):
			if house.has_method("can_accept_villager") and house.can_accept_villager(v):
				house.assign_villager(v)
				break

## 没有住宅的居民不能工作：释放职业名额并转空闲（旧存档兼容）。
func _release_homeless_jobs() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v == null or v.job == "idle" or v.has_home():
			continue
		v.release_from_job()

## 读档后把有职业的居民重新分配回对应职业小屋（job_name 匹配 + 名额允许）。
func _assign_job_villagers() -> void:
	for node in get_tree().get_nodes_in_group("villagers"):
		var v := node as Villager
		if v == null or v.job == "idle":
			continue
		for hut in TownRegistry.get_job_huts():
			if not hut.has_method("can_accept_villager"):
				continue
			if hut.get("job_name") != v.job:
				continue
			if hut.can_accept_villager(v):
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
