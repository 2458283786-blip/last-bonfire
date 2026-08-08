# 资源经济系统（自动采集/搬运/仓储 + 建筑）实施计划

> **For agentic workers:** 本计划由主代理按 superpowers:executing-plans 内联执行，任务用 checkbox 跟踪。

**Goal:** 实现居民自动采集资源的完整闭环：伐木屋转职伐木工 → 砍伐资源（树/石头，无碰撞、按天重生）→ 捡掉落物 → 运回仓库 → 库存增加；支持伐木场提供城内树、野外随机限量生成树；玩家作为管理者只做建造/扩容/分配。

**Architecture:** 全局单例 DayManager（天数）与 EconomyManager（库存/容量）；资源节点 ResourceNode（Area2D，无物理碰撞）；掉落物 Pickup；居民 Villager 用工作状态机驱动；建筑（仓库/伐木屋/伐木场）以场景+脚本形式提供，由用户在场景中手动摆放。

**Tech Stack:** Godot 4.7.1 / GDScript 2.0 / 现有测试框架 `tests/run_all.gd`

## Global Constraints

- 树/石头/掉落物一律 **不挂 StaticBody2D**（玩家与居民可穿过）。
- 资源数值全部进 `resources/data/` 的 `.tres`（ResourceData）。
- 树重生与野外生成都基于 `DayManager.day`（游戏天数），不使用现实秒数。
- 居民工作状态机统一用 `WorkState` 枚举 + 预留机制（`reserved_by`），防两人砍同一棵树。
- 仓库容量 = `EconomyManager.capacity`；开局库存 `{wood: 10, stone: 5}`，默认容量 20。
- 跨系统通过 Autoload 单例（DayManager / EconomyManager）与 group 查询通信。
- 每个功能先写失败测试，再实现，全部测试必须 `godot --headless` 可跑。

---

### Task 1: 全局单例 DayManager 与 EconomyManager

**Files:**
- Create: `scripts/autoload/day_manager.gd`
- Create: `scripts/autoload/economy_manager.gd`
- Modify: `project.godot`（[autoload] 增加两项）
- Create: `tests/test_day_manager.gd`、`tests/test_economy_manager.gd`

**Interfaces:**
- `DayManager.day: int`、`DayManager.advance_day()`、信号 `day_changed(day: int)`；调试快捷键 F7 推进一天。
- `EconomyManager.stock: Dictionary`、`capacity: int`、`get_amount(id)`、`deposit(id, amount) -> int`（受容量限制）、`withdraw(id, amount) -> bool`、`set_capacity(v)`；信号 `stock_changed(resource_id, amount)`。

- [ ] **Step 1: 写失败测试**（测试先于实现，含运行器注册）

`tests/test_day_manager.gd`:
```gdscript
extends SceneTree
var failures: Array[String] = []
var assertions := 0
func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	_run()
func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出"); quit(1)
func _run() -> void:
	await process_frame
	check(DayManager.day >= 1, "day 应从 1 开始")
	var before := DayManager.day
	DayManager.advance_day()
	check(DayManager.day == before + 1, "advance_day 应 +1")
	_finish()
func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond: failures.append(msg)
func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_day_manager: %d 断言全部通过" % assertions); quit(0)
	else:
		for f in failures: push_error("[FAIL] " + f)
		print("[FAIL] test_day_manager: %d 个断言失败" % failures.size()); quit(1)
```

`tests/test_economy_manager.gd`:
```gdscript
extends SceneTree
var failures: Array[String] = []
var assertions := 0
func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout); _run()
func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出"); quit(1)
func _run() -> void:
	await process_frame
	EconomyManager.set_capacity(20)
	check(EconomyManager.get_amount("wood") == 10, "开局应有 10 木材")
	var accepted := EconomyManager.deposit("wood", 30)
	check(accepted == 10, "容量 20 时再入 30 只应接受 10")
	check(EconomyManager.get_amount("wood") == 20, "库存应封顶 20")
	check(EconomyManager.withdraw("wood", 5), "应有足够木材可取")
	check(EconomyManager.get_amount("wood") == 15, "取出后应剩 15")
	check(not EconomyManager.withdraw("stone", 99), "不足时应取款失败")
	EconomyManager.set_capacity(100)
	check(EconomyManager.capacity == 100, "set_capacity 应生效")
	_finish()
func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond: failures.append(msg)
func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_economy_manager: %d 断言全部通过" % assertions); quit(0)
	else:
		for f in failures: push_error("[FAIL] " + f)
		print("[FAIL] test_economy_manager: %d 个断言失败" % failures.size()); quit(1)
```

- [ ] **Step 2: 运行确认失败**（两个测试分别报错：DayManager/EconomyManager 未注册）
- [ ] **Step 3: 实现两个单例并在 project.godot 注册**

`scripts/autoload/day_manager.gd`:
```gdscript
extends Node
## 游戏天数管理：推进天数，供资源重生/野外生成等使用。F7 调试推进一天。
signal day_changed(day: int)
var day := 1
func advance_day() -> void:
	day += 1
	day_changed.emit(day)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		advance_day()
		print("[DayManager] 天数推进到第 %d 天" % day)
```

`scripts/autoload/economy_manager.gd`:
```gdscript
extends Node
## 全局资源池：库存、容量、出入库。建筑/居民通过本单例读写。
signal stock_changed(resource_id: String, amount: int)
const DEFAULT_CAPACITY := 20
const STARTING_STOCK := {"wood": 10, "stone": 5}
var stock: Dictionary = {}
var capacity: int = DEFAULT_CAPACITY
func _ready() -> void:
	for id in STARTING_STOCK:
		stock[id] = STARTING_STOCK[id]
	emit_changed("", 0)
func get_amount(resource_id: String) -> int:
	return stock.get(resource_id, 0)
func total_used() -> int:
	var total := 0
	for v in stock.values():
		total += v
	return total
func deposit(resource_id: String, amount: int) -> int:
	if amount <= 0: return 0
	var space := capacity - total_used()
	var accepted := mini(amount, space)
	if accepted > 0:
		stock[resource_id] = get_amount(resource_id) + accepted
		emit_changed(resource_id, accepted)
	return accepted
func withdraw(resource_id: String, amount: int) -> bool:
	if get_amount(resource_id) < amount: return false
	stock[resource_id] = get_amount(resource_id) - amount
	emit_changed(resource_id, -amount)
	return true
func set_capacity(new_capacity: int) -> void:
	capacity = maxi(new_capacity, 0)
	emit_changed("", 0)
func emit_changed(resource_id: String, amount: int) -> void:
	stock_changed.emit(resource_id, amount)
```

`project.godot` 的 [autoload] 增加：
```ini
DayManager="*res://scripts/autoload/day_manager.gd"
EconomyManager="*res://scripts/autoload/economy_manager.gd"
```

- [ ] **Step 4: 运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add project.godot scripts/autoload/day_manager.gd scripts/autoload/economy_manager.gd tests/test_day_manager.gd tests/test_economy_manager.gd tests/run_all.gd
git commit -m "feat: 天数与库存全局单例（DayManager/EconomyManager）"
```

---

### Task 2: 资源配置、资源节点与掉落物

**Files:**
- Create: `scripts/economy/resource_data.gd`、`resources/data/tree.tres`、`resources/data/rock.tres`
- Create: `scripts/economy/resource_node.gd`、`scenes/resources/tree.tscn`、`scenes/resources/rock.tscn`
- Create: `scripts/economy/pickup.gd`、`scenes/resources/pickup.tscn`
- Create: `tests/test_resource_node.gd`、`tests/test_pickup.gd`

**Interfaces:**
- `ResourceData`：id/display_name/texture/max_hp/chop_damage/drop_resource/drop_amount/respawn_days/required_job。
- `ResourceNode extends Area2D`：`current_hp`、`reserved_by`、`is_depleted`、`respawn_day`、`is_wild`、`try_reserve(worker_id) -> bool`、`release_reservation(worker_id)`、`chop(worker_id, amount)`、信号 `depleted(node)`；`_ready` 加入 `resources` 组并监听 `DayManager.day_changed` 重生；**无 StaticBody2D**。
- `Pickup extends Area2D`：`resource_id`、`amount`、`taken`、`take() -> Dictionary`；加入 `pickups` 组。

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: 实现数据类、资源节点、掉落物及场景**

`scripts/economy/resource_data.gd`:
```gdscript
class_name ResourceData
extends Resource
@export var id: String = "tree"
@export var display_name: String = "树木"
@export var texture: Texture2D
@export var max_hp: int = 3
@export var chop_damage: int = 1
@export var drop_resource: String = "wood"
@export var drop_amount: int = 1
@export var respawn_days: int = 2
@export var required_job: String = "woodcutter"
```

`scripts/economy/resource_node.gd`:
```gdscript
class_name ResourceNode
extends Area2D
## 可砍伐/挖掘的资源（树/石头）：无物理碰撞，靠预留机制被居民砍伐，按天数重生。
signal depleted(node: ResourceNode)
@export var data: ResourceData
@export var pickup_scene: PackedScene
@export var instance_id: String = ""
var current_hp := 0
var reserved_by := -1
var is_depleted := false
var respawn_day := -1
var is_wild := false
@onready var visual: Node2D = $Visual
func _ready() -> void:
	add_to_group("resources")
	current_hp = data.max_hp
	DayManager.day_changed.connect(_on_day_changed)
	_update_visual()
func try_reserve(worker_id: int) -> bool:
	if is_depleted or (reserved_by != -1 and reserved_by != worker_id):
		return false
	reserved_by = worker_id
	return true
func release_reservation(worker_id: int) -> void:
	if reserved_by == worker_id:
		reserved_by = -1
func chop(worker_id: int, amount: int) -> void:
	if is_depleted or (reserved_by != -1 and reserved_by != worker_id):
		return
	reserved_by = worker_id
	current_hp -= amount
	if current_hp <= 0:
		_deplete()
func _deplete() -> void:
	is_depleted = true
	reserved_by = -1
	respawn_day = DayManager.day + data.respawn_days
	if pickup_scene != null:
		var pickup: Pickup = pickup_scene.instantiate()
		pickup.resource_id = data.drop_resource
		pickup.amount = data.drop_amount
		get_parent().add_child(pickup)
		pickup.global_position = global_position
	_update_visual()
	depleted.emit(self)
func _on_day_changed(day: int) -> void:
	if is_depleted and day >= respawn_day:
		current_hp = data.max_hp
		is_depleted = false
		respawn_day = -1
		_update_visual()
func _update_visual() -> void:
	visible = not is_depleted
```

`scripts/economy/pickup.gd`:
```gdscript
class_name Pickup
extends Area2D
## 掉落物：待居民捡起，无碰撞。
@export var resource_id: String = "wood"
@export var amount: int = 1
var taken := false
func _ready() -> void:
	add_to_group("pickups")
func take() -> Dictionary:
	if taken:
		return {}
	taken = true
	queue_free()
	return {"resource_id": resource_id, "amount": amount}
```

`scenes/resources/pickup.tscn`：Area2D + RectangleShape2D（16x16）+ Visual ColorRect（木色）；脚本 pickup.gd。
`scenes/resources/tree.tscn`：Area2D（脚本 resource_node.gd，data=tree.tres，pickup_scene=pickup.tscn）+ CollisionShape2D（Rect 32x48）+ Visual ColorRect（绿色）。
`scenes/resources/rock.tscn`：同树，data=rock.tres，Visual 灰色。
`resources/data/tree.tres`：`max_hp=3, drop_resource="wood", drop_amount=1, respawn_days=2`。
`resources/data/rock.tres`：`max_hp=5, drop_resource="stone", drop_amount=1, respawn_days=3`。

测试要点（`tests/test_resource_node.gd`）：tree.tres 字段正确；树无 StaticBody2D 子节点（可穿过）；try_reserve 占用后他人失败；chop 三次后 is_depleted、生成 1 个 pickup、respawn_day = day+2；advance_day ×2 后重新可见。`tests/test_pickup.gd`：take 返回资源字典、二次 take 返回空。

- [ ] **Step 4: 运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/economy/ scenes/resources/ resources/data/ tests/test_resource_node.gd tests/test_pickup.gd
git commit -m "feat: 资源节点与掉落物（无碰撞、按天重生、数据驱动）"
```

---

### Task 3: 居民与伐木工工作状态机

**Files:**
- Create: `scripts/villager/villager_ai.gd`、`scenes/villagers/villager.tscn`
- Create: `tests/test_villager_work_cycle.gd`

**Interfaces:**
- `Villager extends CharacterBody2D`：`villager_id`、`job`、`state`、`carry: Dictionary`、`set_job(job)`、`chop_interval`、`move_speed`、`carry_capacity`、`interact_range`；加入 `villagers` 组。
- 状态机：`IDLE → FIND_TREE → TRAVEL_TO_TREE → CHOPPING → PICKUP → TRAVEL_TO_STORAGE → DEPOSIT`；搬运目标优先 `storage_buildings` 组，其次 `town_stockpile` 组。

- [ ] **Step 1: 写失败测试**（关键端到端：砍树→捡→运→存）

`tests/test_villager_work_cycle.gd`：构造地面+仓库+树（max_hp=1），居民 set_job("woodcutter")，每帧推进，最多 600 帧，断言 `EconomyManager.get_amount("wood")` 增加、居民 carry 清空、树 is_depleted。仓库为一个加入 `storage_buildings` 组的 Node2D。

- [ ] **Step 2: 运行确认失败**（Villager 类不存在）
- [ ] **Step 3: 实现居民脚本与场景**

`scripts/villager/villager_ai.gd` 核心（完整状态机见实现）：
```gdscript
class_name Villager
extends CharacterBody2D
enum WorkState { IDLE, FIND_TREE, TRAVEL_TO_TREE, CHOPPING, PICKUP, TRAVEL_TO_STORAGE, DEPOSIT }
@export var move_speed: float = 180.0
@export var interact_range: float = 30.0
@export var chop_interval: float = 1.0
@export var carry_capacity: int = 3
var villager_id := 0
var job := "idle"
var state := WorkState.IDLE
var carry: Dictionary = {}
var target_tree: ResourceNode = null
var target_pickup: Pickup = null
var target_storage: Node2D = null
var chop_timer := 0.0
```

`scenes/villagers/villager.tscn`：CharacterBody2D + CapsuleShape2D + Visual ColorRect（占位）+ 脚本。

测试中可调 `villager.chop_interval = 0.05`、`villager.move_speed = 400` 加速。

- [ ] **Step 4: 运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/villager/ scenes/villagers/ tests/test_villager_work_cycle.gd
git commit -m "feat: 居民伐木工工作状态机（砍树/捡取/运仓）"
```

---

### Task 4: 建筑（仓库 / 伐木屋 / 伐木场）

**Files:**
- Create: `scripts/building/storage.gd`、`scenes/buildings/storage.tscn`
- Create: `scripts/building/woodcutter_hut.gd`、`scenes/buildings/woodcutter_hut.tscn`
- Create: `scripts/building/lumber_camp.gd`、`scenes/buildings/lumber_camp.tscn`
- Create: `tests/test_buildings.gd`

**Interfaces:**
- `StorageBuilding extends Node2D`：`capacity_boost`（默认 80），`_ready` 加入 `storage_buildings` 组并扩容 EconomyManager。
- `WoodcutterHut extends Node2D`：`job_slots`（默认 2）、`assigned: Array[Villager]`、`can_accept_villager(v) -> bool`、`assign_villager(v)`（调用 `v.set_job("woodcutter")`）；加入 `job_huts` 组。
- `LumberCamp extends Node2D`：`tree_scene`、`tree_count`（默认 6）、`spawn_radius`（默认 120），`_ready` 在周围生成城内树（is_wild=false）；加入 `lumber_camps` 组。

- [ ] **Step 1: 写失败测试**
  - 仓库：实例化后 `EconomyManager.capacity` 增加 capacity_boost。
  - 伐木屋：空闲居民（job="idle"）经 `assign_villager` 后 job=="woodcutter"；满员后 `can_accept_villager` 返回 false。
  - 伐木场：实例化后 `resources` 组新增 tree_count 棵树，且树是伐木场子节点。
- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: 实现三个建筑场景与脚本**（占位视觉为 ColorRect，用户后续替换素材）
- [ ] **Step 4: 运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/building/ scenes/buildings/ tests/test_buildings.gd
git commit -m "feat: 仓库/伐木屋/伐木场三建筑"
```

---

### Task 5: 野外树随机生成器 + 城镇集成

**Files:**
- Create: `scripts/economy/wild_tree_spawner.gd`
- Modify: `scenes/town/town.tscn`（加入 `TownStockpile`，组 `town_stockpile`）
- Modify: `tests/test_town_scene.gd`（断言 TownStockpile 存在）
- Create: `tests/test_wild_spawner.gd`

**Interfaces:**
- `WildTreeSpawner extends Node2D`：`tree_scene`、`zones: Array[Rect2]`、`max_trees`（默认 10）、`min_spacing`（默认 64）；`_refill()` 补足到 max_trees（统计 `is_wild` 的资源），监听 `DayManager.day_changed`。

- [ ] **Step 1: 写失败测试**
  - 生成器配 1 个 Rect2(0,0,400,300)、max_trees=5，`_refill()` 后资源组中 is_wild 树数量为 5 且都在区域内。
  - 手动砍掉 2 棵（is_depleted）后再次 `_refill()`，wild 计数恢复为 5（重生由 DayManager 负责，生成器只补数量）。
- [ ] **Step 2: 运行确认失败**
- [ ] **Step 3: 实现生成器并给城镇加 TownStockpile**

`scripts/economy/wild_tree_spawner.gd` 要点：`_ready` 加入 `wild_spawners` 组、连接 day_changed、`_refill()`；`_random_free_position()` 在 zones 内随机取点并检查 `min_spacing`；生成的树 `tree.is_wild = true`、`get_parent().add_child(tree)`。

- [ ] **Step 4: 运行确认通过**
- [ ] **Step 5: 提交**

```bash
git add scripts/economy/wild_tree_spawner.gd scenes/town/town.tscn tests/
git commit -m "feat: 野外树按天随机限量生成 + 城镇临时堆点"
```

---

### Task 6: 文档更新与全量验证

**Files:**
- Modify: `docs/design/2026-08-05-demo-design.md`（修正建筑分工：伐木屋=职业转换、伐木场=资源生成、仓库=容量/搬运；新增资源经济章节）
- Modify: `README.md`（当前状态、F7 调试说明）
- Modify: `tests/run_all.gd`（注册全部新测试）

- [ ] **Step 1: 更新文档**
- [ ] **Step 2: 全量运行** `godot --headless --path . --script res://tests/run_all.gd`，确认全部 PASS、退出码 0
- [ ] **Step 3: 主场景冒烟运行** `godot --headless --path . --quit-after 60`，无报错
- [ ] **Step 4: 提交**

```bash
git add -A && git commit -m "docs: 资源经济系统设计与全量验证"
```
