# 存档系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整存档：白天自动存档 + 暂停菜单手动存/读档 + 启动“继续游戏”，覆盖昼夜/经济/玩家/建筑/资源/居民并可按版本迁移。

**Architecture:** `SaveManager`（Autoload）负责 JSON 单文件读写与版本；各系统提供 `collect_state` / `restore` 纯逻辑接口；加载采用“清场重建”，恢复顺序为 昼夜 → 建筑 → 资源 → 居民 → 玩家 → 经济（最后覆盖，避免仓库 `_ready` 扩容干扰）→ 城镇登记清空。加载期间静默恢复、不触发信号，`WildTreeSpawner` 加 `refill_enabled` 抑制即时补树。

**Tech Stack:** Godot 4.7.1 / GDScript 2.0 / 现有测试框架 `tests/run_all.gd`。

## Global Constraints

- 实现前从 `main` 创建分支 `feature/save-system`；完成且全绿后按惯例询问合并方式。
- 测试命令（必须用 cmd 重定向等待真实退出码，直接 `&` 调用 Godot 会异步返回假 0）：
  `cmd /c "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\横板游戏" res://tests/run_all.tscn > "D:\横板游戏\.superpowers\sdd\2026-08-10-save-system\out.txt" 2>&1`
  退出码 0 即通过；控制台中文可能乱码，以退出码与 `[PASS] 全部测试通过` 为准。
- 新测试脚本必须注册进 `tests/run_all.gd` 的 `TEST_SCRIPTS`。
- 存档格式 JSON 单文件，含 `version`（当前 1）；存档路径可注入（测试用 `user://save_test_*.json`，用完删除）。
- 加载期间静默恢复（DayManager 不发射信号），避免中间态副作用。
- 中文 UI 文案；所有新文件沿用 `scripts/`、`scenes/`、`tests/` 现有惯例。
- 存档相关数值/路径集中在 `SaveManager`，不散落写死。

---

### Task 1: SaveManager 核心（版本 / JSON / 错误处理）

**Files:**
- Modify: `scripts/autoload/save_manager.gd`（重写）
- Test: `tests/test_save_manager_core.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: 无（仅 FileAccess / JSON）。
- Produces: `SaveManager.save_path`（可注入）、`save_game() -> bool`、`load_game() -> bool`（异步，内部 await）、`has_save() -> bool`、`last_error: String`、信号 `save_failed(reason)` / `load_failed(reason)`、`migrate(data) -> Dictionary`、`_collect() -> Dictionary` / `_apply(data)`（骨架，后续任务填充各节）。

- [ ] **Step 1: 写失败测试** `tests/test_save_manager_core.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://save_test_core.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	check(not SaveManager.has_save(), "初始不应有存档")
	check(SaveManager.save_game(), "保存应成功")
	check(SaveManager.has_save(), "保存后应有存档文件")
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	check(typeof(parsed) == TYPE_DICTIONARY, "存档应为 JSON 字典")
	check(int(parsed.get("version", -1)) == 1, "存档版本应为 1")
	var w := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	w.store_string("{broken")
	w.close()
	check(not await SaveManager.load_game(), "损坏文件读档应失败")
	check(SaveManager.last_error != "", "失败应记录原因")
	DirAccess.remove_absolute(SaveManager.save_path)
	check(not SaveManager.has_save(), "清理后应无存档")
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 2: 运行确认失败**（SaveManager 未实现，`save_game` 返回 null / 报错）
- [ ] **Step 3: 重写 `scripts/autoload/save_manager.gd`**

```gdscript
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
	return {}

func _apply(_data: Dictionary) -> void:
	pass
```

- [ ] **Step 4: 注册 `res://tests/test_save_manager_core.gd`，运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager_core.gd tests/run_all.gd
git commit -m "feat: SaveManager 核心（JSON/版本/错误处理）"
```

---

### Task 2: 全局状态快照（昼夜 / 经济 / 玩家）

**Files:**
- Modify: `scripts/autoload/day_manager.gd`（`phase_elapsed()`、`collect_state()`、`restore_state()` 静默恢复）
- Modify: `scripts/autoload/economy_manager.gd`（`collect_state()`、`restore()`）
- Modify: `scripts/autoload/save_manager.gd`（填充 day/economy/player 节）
- Test: `tests/test_save_global.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: `DayManager.day/phase/_phase_timer`、`EconomyManager.stock/capacity`、玩家组 `players`。
- Produces: `DayManager.collect_state() -> Dictionary` / `restore_state(data)`（不发射信号）；`EconomyManager.collect_state() -> Dictionary` / `restore(data)`；`SaveManager._collect_player()/_apply_player()`。

- [ ] **Step 1: 写失败测试** `tests/test_save_global.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_global.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	DayManager.day = 3
	DayManager.phase = 1
	DayManager._phase_timer = 12.5
	EconomyManager.deposit("wood", 7)
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(500, 800)
	player.take_damage(30.0)
	await get_tree().process_frame
	check(SaveManager.save_game(), "全局状态应可保存")
	DayManager.day = 9
	DayManager.phase = 2
	DayManager._phase_timer = 0.0
	EconomyManager.reset()
	player.global_position = Vector2(100, 100)
	player.hp = 100.0
	check(await SaveManager.load_game(), "应可读档")
	check(DayManager.day == 3, "天数应恢复")
	check(DayManager.phase == 1, "阶段应恢复")
	check(absf(DayManager._phase_timer - 12.5) < 0.01, "阶段计时应恢复")
	check(EconomyManager.get_amount("wood") == 17, "木材库存应恢复（10+7）")
	check(player.global_position.distance_to(Vector2(500, 800)) < 1.0, "玩家位置应恢复")
	check(int(player.hp) == 70, "玩家血量应恢复")
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: 各系统提供快照/恢复接口**

`scripts/autoload/day_manager.gd` 末尾追加：

```gdscript
## ---- 存档支持：快照与静默恢复（不发射信号，避免加载中间态副作用） ----

func phase_elapsed() -> float:
	return _phase_timer

func collect_state() -> Dictionary:
	return {"day": day, "phase": phase, "phase_elapsed": _phase_timer}

func restore_state(data: Dictionary) -> void:
	day = maxi(int(data.get("day", 1)), 1)
	phase = int(data.get("phase", 0)) % PHASE_COUNT
	_phase_timer = maxf(float(data.get("phase_elapsed", 0.0)), 0.0)
```

`scripts/autoload/economy_manager.gd` 末尾追加：

```gdscript
## ---- 存档支持 ----

func collect_state() -> Dictionary:
	return {"stock": stock.duplicate(), "capacity": capacity}

func restore(data: Dictionary) -> void:
	stock = (data.get("stock", {}) as Dictionary).duplicate()
	capacity = maxi(int(data.get("capacity", DEFAULT_CAPACITY)), 0)
	emit_changed("", 0)
```

- [ ] **Step 4: SaveManager 填充三节**

`scripts/autoload/save_manager.gd` 的 `_collect()` 与 `_apply()` 改为：

```gdscript
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
```

- [ ] **Step 5: 注册 `res://tests/test_save_global.gd`，运行确认通过**
- [ ] **Step 6: 提交**

```bash
git add scripts/autoload/day_manager.gd scripts/autoload/economy_manager.gd scripts/autoload/save_manager.gd tests/test_save_global.gd tests/run_all.gd
git commit -m "feat: 昼夜/经济/玩家存档快照与静默恢复"
```

---

### Task 3: 建筑存档

**Files:**
- Modify: `scenes/buildings/storage.tscn`、`woodcutter_hut.tscn`、`lumber_camp.tscn`、`bonfire.tscn`（补 `building_id`）
- Modify: `scripts/autoload/save_manager.gd`（buildings 节）
- Test: `tests/test_save_buildings.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: 组 `buildings`、`Building`（hp/is_destroyed/level/`_update_visual()`）。
- Produces: `SaveManager._collect_buildings() -> Array` / `_apply_buildings(data)`（清场后按存档实例化并覆盖字段）。

- [ ] **Step 1: 给四个建筑场景补唯一 ID**

各场景根节点追加一行（如 `storage.tscn` 加 `building_id = "storage"`；`woodcutter_hut.tscn` 加 `"woodcutter_hut"`；`lumber_camp.tscn` 加 `"lumber_camp"`；`bonfire.tscn` 加 `"bonfire"`）。

- [ ] **Step 2: 写失败测试** `tests/test_save_buildings.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_buildings.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var storage: Building = load("res://scenes/buildings/storage.tscn").instantiate()
	add_child(storage)
	storage.global_position = Vector2(300, 850)
	storage.take_damage(30)
	var hut: Building = load("res://scenes/buildings/woodcutter_hut.tscn").instantiate()
	add_child(hut)
	hut.global_position = Vector2(700, 860)
	await get_tree().process_frame
	check(SaveManager.save_game(), "建筑状态应可保存")
	storage.queue_free()
	hut.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	check(get_tree().get_nodes_in_group("buildings").size() >= 2, "应重建建筑")
	var restored := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(Vector2(300, 850)) < 1.0:
			check(b is StorageBuilding, "恢复的应是仓库")
			check(b.hp == 70, "仓库血量应恢复")
			restored = true
	check(restored, "应在原位置恢复仓库")
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 3: 运行确认失败**
- [ ] **Step 4: SaveManager 实现 buildings 节**

`scripts/autoload/save_manager.gd` 的 `_collect()` 增加 `"buildings": _collect_buildings()`，`_apply()` 开头增加清场与建筑恢复（顺序：清场 → 昼夜 → 建筑 → 资源 → 居民 → 玩家 → 经济），并新增：

```gdscript
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
```

`_apply()` 改为：

```gdscript
func _apply(data: Dictionary) -> void:
	await _clear_world()
	DayManager.restore_state(data.get("day", {}))
	_apply_buildings(data.get("buildings", []))
	# 资源/居民/玩家/经济由后续任务填充
	_apply_player(data.get("player", {}))
	EconomyManager.restore(data.get("economy", {}))
	for s in get_tree().get_nodes_in_group("wild_spawners"):
		s.refill_enabled = true
	TownRegistry.reset_daily_adjustments()
```

- [ ] **Step 5: 注册 `res://tests/test_save_buildings.gd`，运行确认通过**
- [ ] **Step 6: 提交**

```bash
git add scenes/buildings/ scripts/autoload/save_manager.gd tests/test_save_buildings.gd tests/run_all.gd
git commit -m "feat: 建筑存档（清场重建/状态恢复）"
```

---

### Task 4: 资源节点存档

**Files:**
- Modify: `scripts/economy/wild_tree_spawner.gd`（`refill_enabled`）
- Modify: `scripts/autoload/save_manager.gd`（resources 节）
- Test: `tests/test_save_resources.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: 组 `resources`、`ResourceNode`（current_hp/is_depleted/respawn_day/is_wild/`_update_visual()`）。
- Produces: `WildTreeSpawner.refill_enabled`（默认 true，`_refill()` 开头检查）；`SaveManager._collect_resources() / _apply_resources()`。

- [ ] **Step 1: 写失败测试** `tests/test_save_resources.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_resources.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var tree: ResourceNode = load("res://scenes/resources/tree.tscn").instantiate()
	add_child(tree)
	tree.global_position = Vector2(400, 800)
	tree.current_hp = 0
	tree.is_depleted = true
	tree.respawn_day = DayManager.day + 2
	tree.is_wild = true
	tree._update_visual()
	await get_tree().process_frame
	check(SaveManager.save_game(), "资源状态应可保存")
	tree.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	var restored := false
	for r in get_tree().get_nodes_in_group("resources"):
		if r.global_position.distance_to(Vector2(400, 800)) < 1.0:
			check(r.is_depleted, "耗尽状态应恢复")
			check(r.respawn_day == DayManager.day + 2, "重生天数应恢复")
			check(r.is_wild, "野生标记应恢复")
			check(not r.visible, "耗尽树应不可见")
			restored = true
	check(restored, "应在原位置恢复资源节点")
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: WildTreeSpawner 增加抑制开关**

`scripts/economy/wild_tree_spawner.gd`：

```gdscript
## 加载存档期间置 false，阻止即时补树（加载完由 SaveManager 恢复）
var refill_enabled := true
```

`_refill()` 开头加：

```gdscript
	if not refill_enabled:
		return
```

- [ ] **Step 4: SaveManager 实现 resources 节**

`_collect()` 增加 `"resources": _collect_resources()`；`_apply()` 在建筑后调用 `_apply_resources(data.get("resources", []))`；新增：

```gdscript
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
```

- [ ] **Step 5: 注册 `res://tests/test_save_resources.gd`，运行确认通过**
- [ ] **Step 6: 提交**

```bash
git add scripts/economy/wild_tree_spawner.gd scripts/autoload/save_manager.gd tests/test_save_resources.gd tests/run_all.gd
git commit -m "feat: 资源节点存档（含野生树补足抑制）"
```

---

### Task 5: 居民存档

**Files:**
- Modify: `scripts/autoload/save_manager.gd`（villagers 节）
- Test: `tests/test_save_villagers.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: 组 `villagers`、`Villager`（display_name/job/carry/hp/is_injured/injured_remaining_days/home_position/set_job）、`TownRegistry.get_job_huts()`、`WoodcutterHut.assign_villager()`。
- Produces: `SaveManager._collect_villagers() / _apply_villagers()`（含伐木工重新分配）。

- [ ] **Step 1: 写失败测试** `tests/test_save_villagers.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_villagers.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var hut: WoodcutterHut = load("res://scenes/buildings/woodcutter_hut.tscn").instantiate()
	add_child(hut)
	var v: Villager = load("res://scenes/villagers/villager.tscn").instantiate()
	v.display_name = "阿强"
	add_child(v)
	v.set_physics_process(false)
	v.global_position = Vector2(260, 840)
	v.home_position = Vector2(260, 840)
	v.carry = {"wood": 2}
	v.hp = 10.0
	v.is_injured = true
	v.injured_remaining_days = 2
	v.set_job("woodcutter")
	await get_tree().process_frame
	check(SaveManager.save_game(), "居民状态应可保存")
	v.queue_free()
	hut.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	var restored := false
	for n in get_tree().get_nodes_in_group("villagers"):
		if n.global_position.distance_to(Vector2(260, 840)) < 1.0:
			check(n.display_name == "阿强", "名字应恢复")
			check(n.job == "woodcutter", "职业应恢复")
			check(int(n.carry.get("wood", 0)) == 2, "搬运物应恢复")
			check(n.is_injured, "伤势应恢复")
			check(n.injured_remaining_days == 2, "伤势天数应恢复")
			restored = true
	check(restored, "应在原位置恢复居民")
	var assigned := false
	for hut_n in get_tree().get_nodes_in_group("job_huts"):
		if hut_n.assigned.size() > 0:
			assigned = true
	check(assigned, "伐木工应重新分配进伐木屋")
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: SaveManager 实现 villagers 节**

`_collect()` 增加 `"villagers": _collect_villagers()`；`_apply()` 在资源后调用 `_apply_villagers(data.get("villagers", []))`；新增：

```gdscript
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
```

- [ ] **Step 4: 注册 `res://tests/test_save_villagers.gd`，运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_villagers.gd tests/run_all.gd
git commit -m "feat: 居民存档（含伐木工重新分配）"
```

---

### Task 6: 保存时机与入口

**Files:**
- Modify: `scripts/autoload/save_manager.gd`（`_ready` 接 `day_changed` 自动存档，仅在城镇场景）
- Modify: `scripts/autoload/game_manager.gd`（`pending_load`）
- Modify: `scenes/ui/pause_menu.tscn`、`scripts/ui/pause_menu.gd`（"读档"按钮与信号；"存档"去掉"（预留）"）
- Modify: `scenes/ui/hud.gd`（存档/读档处理）
- Modify: `scenes/main/boot.tscn`、`scripts/main/boot.gd`（"继续游戏"/"新游戏"按钮）
- Modify: `scripts/town/town.gd`（`_ready` 检测 `pending_load` 调 `SaveManager.load_game()`）
- Test: `tests/test_save_flow.gd`
- Modify: `tests/run_all.gd`

**Interfaces:**
- Consumes: `DayManager.day_changed`、`GameManager.change_scene`、`SaveManager.save_game/load_game`。
- Produces: `GameManager.pending_load: bool`；`PauseMenu.load_requested` 信号；boot 两个按钮。

- [ ] **Step 1: 写失败测试** `tests/test_save_flow.gd`

```gdscript
extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_flow.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var old_name := get_tree().current_scene.name
	get_tree().current_scene.name = "Town"
	DayManager.advance_day()
	await get_tree().process_frame
	check(SaveManager.has_save(), "城镇内推进一天应自动存档")
	get_tree().current_scene.name = old_name
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("PauseMenu").get_node("VBox/SaveButton").pressed.emit()
	await get_tree().process_frame
	check(SaveManager.has_save(), "暂停菜单存档按钮应可存档")
	check(hud.get_node("PauseMenu").get_node("VBox/LoadButton") != null, "暂停菜单应有读档按钮")
	check(not GameManager.pending_load, "初始不应待读档")
	GameManager.pending_load = true
	var town: Node2D = load("res://scenes/town/town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not GameManager.pending_load, "进入城镇后应消费待读档标记")
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
```

- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: 自动存档 + 暂停菜单**

`scripts/autoload/save_manager.gd` 增加：

```gdscript
func _ready() -> void:
	DayManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int) -> void:
	if get_tree().current_scene != null and get_tree().current_scene.name == "Town":
		save_game()
```

`scripts/autoload/game_manager.gd` 增加：

```gdscript
## 进入城镇后自动读档（boot"继续游戏"与暂停菜单"读档"置 true）
var pending_load := false
```

`scenes/ui/pause_menu.tscn`：`SaveButton` 文本改为 `存档`；在 `SaveButton` 后插入：

```ini
[node name="LoadButton" type="Button" parent="VBox"]
text = "读档"
```

`scripts/ui/pause_menu.gd`：增加 `signal load_requested` 与连接：

```gdscript
@onready var load_button: Button = $VBox/LoadButton
load_button.pressed.connect(func() -> void: load_requested.emit())
```

`scripts/ui/hud.gd` `_ready()` 中替换原存档连接并新增读档连接：

```gdscript
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.load_requested.connect(_on_load_requested)
```

并新增：

```gdscript
func _on_save_requested() -> void:
	if SaveManager.save_game():
		toast_queue.push("已存档")
	else:
		toast_queue.push("存档失败：" + SaveManager.last_error)

func _on_load_requested() -> void:
	GameManager.pending_load = true
	GameManager.change_scene("res://scenes/town/town.tscn")
```

- [ ] **Step 4: boot 继续/新游戏 + 城镇读档钩子**

`scenes/main/boot.tscn` 在 Hint 节点后追加两个按钮：

```ini
[node name="ContinueButton" type="Button" parent="."]
visible = false
offset_left = 610.0
offset_top = 660.0
offset_right = 910.0
offset_bottom = 710.0
text = "继续游戏"

[node name="NewGameButton" type="Button" parent="."]
offset_left = 1010.0
offset_top = 660.0
offset_right = 1310.0
offset_bottom = 710.0
text = "新游戏"
```

`scripts/main/boot.gd` 重写：

```gdscript
extends Node2D
## 启动场景：有存档显示"继续游戏"，否则"新游戏"；Enter 兼容旧流程（新游戏）。

@onready var continue_button: Button = $ContinueButton
@onready var new_game_button: Button = $NewGameButton

func _ready() -> void:
	print("[Boot] 框架启动成功。")
	continue_button.visible = SaveManager.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)

func _on_continue_pressed() -> void:
	GameManager.pending_load = true
	GameManager.change_scene("res://scenes/town/town.tscn")

func _on_new_game_pressed() -> void:
	GameManager.change_scene("res://scenes/town/town.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_new_game_pressed()
```

`scripts/town/town.gd`：

```gdscript
func _ready() -> void:
	print("[Town] 城镇场景已加载。")
	if GameManager.pending_load:
		GameManager.pending_load = false
		SaveManager.load_game()
```

- [ ] **Step 5: 注册 `res://tests/test_save_flow.gd`，运行确认通过**
- [ ] **Step 6: 提交**

```bash
git add scripts/autoload/save_manager.gd scripts/autoload/game_manager.gd scenes/ui/pause_menu.tscn scripts/ui/pause_menu.gd scripts/ui/hud.gd scenes/main/boot.tscn scripts/main/boot.gd scripts/town/town.gd tests/test_save_flow.gd tests/run_all.gd
git commit -m "feat: 自动存档/手动存读档/启动继续游戏"
```

---

### Task 7: 全量集成验证与文档同步

**Files:**
- Modify: `tests/run_all.gd`（确认 6 个新测试全部注册）
- Modify: `README.md`（存档说明）
- Modify: `docs/design/2026-08-10-save-system-design.md`（状态行 + 实现记录；修正加载顺序为"经济最后覆盖"、补充静默恢复与 spawner 抑制说明）

**Interfaces:**
- Consumes: 全部前序任务产物。
- Produces: 可提交的完整存档功能。

- [ ] **Step 1: 核对 `tests/run_all.gd` 注册了全部新测试**

`TEST_SCRIPTS` 应包含：

```gdscript
	"res://tests/test_save_manager_core.gd",
	"res://tests/test_save_global.gd",
	"res://tests/test_save_buildings.gd",
	"res://tests/test_save_resources.gd",
	"res://tests/test_save_villagers.gd",
	"res://tests/test_save_flow.gd",
```

- [ ] **Step 2: 更新 README.md**

在"运行方式"后新增：

```markdown
## 存档

- 自动存档：城镇内每天天亮（新的一天开始）自动保存。
- 手动存档/读档：Esc 暂停菜单 → 存档 / 读档。
- 启动界面：有存档时显示"继续游戏"。
- 存档位置：`user://save_game.json`（JSON 单文件，含版本号）。
```

- [ ] **Step 3: 同步设计文档**

`docs/design/2026-08-10-save-system-design.md`：状态行改为"已实现"；在"实现记录"节追加：加载顺序实际为 清场 → 昼夜（静默）→ 建筑 → 资源 → 居民 → 玩家 → 经济（最后覆盖，避免仓库扩容干扰）→ 城镇登记清空 → 恢复 spawner；说明加载期间不触发信号。

- [ ] **Step 4: 全量测试**

用 Global Constraints 中的 cmd 重定向命令运行，预期全部通过、退出码 0。

- [ ] **Step 5: 冒烟运行**

```bash
cmd /c "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\横板游戏" --quit-after 60 > "D:\横板游戏\.superpowers\sdd\2026-08-10-save-system\smoke.txt" 2>&1
```

预期：无脚本报错，正常退出。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "docs: 存档系统全量验证与文档同步"
```

- [ ] **Step 7: 全量测试再确认一次（退出码 0），然后按惯例询问用户合并方式**

