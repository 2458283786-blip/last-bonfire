# 建筑损坏联动实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建筑被毁真正下线功能、修复/重建恢复：仓库容量、职业名额、场内资源、篝火核心状态联动；修复玩家复活组名 bug；存档加载后状态同步。

**Architecture:** `Building` 基类新增幂等钩子 `_on_function_offline()` / `_on_function_online()` 与 `refresh_function_state()`；`take_damage` 摧毁时调 offline，`repair()/rebuild()` 调 online；`SaveManager._apply_buildings` 加载后调 `refresh_function_state()`。各子类实现对应联动（JobHut 释放名额、StorageBuilding 容量状态机、ResourceCamp 资源删除/重生、Bonfire 专用事件）。玩家复活改为找真实 Bonfire，被毁时回临时堆点。

**Tech Stack:** Godot 4.7.1 / GDScript 2.0 / 现有测试框架 `tests/run_all.gd`（支持 `--only=test_xxx` 单跑）。

## Global Constraints

- 实现前从 `main` 创建分支 `feature/building-destruction`；完成且全绿后按惯例询问合并方式。
- 测试命令（必须用 cmd 重定向等待真实退出码）：
  `cmd /c "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\横板游戏" res://tests/run_all.tscn -- --only=test_xxx > "D:\横板游戏\.superpowers\sdd\2026-08-10-building-destruction\out.txt" 2>&1`
- 新增 `class_name` 脚本后必须 `--headless --import` 刷新全局类缓存再跑测试。
- 新测试脚本必须注册进 `tests/run_all.gd` 的 `TEST_SCRIPTS`。
- TDD：先写失败测试，再实现到绿；重构任务以现有全套测试为安全网。
- 中文 UI 文案；钩子必须幂等（可重复调用不重复生效）。

---

### Task 1: Building 基类功能钩子

**Files:**
- Modify: `scripts/building/building.gd`

**Interfaces:**
- Produces: `_on_function_offline()`、`_on_function_online()`（空实现，子类覆盖）、`refresh_function_state()`（is_destroyed → offline，否则 online）。
- `_on_destroyed`：保留 `building_destroyed` 事件，同时调 `_on_function_offline()`。
- `repair()` / `rebuild()`：调用 `_on_function_online()`。

- [x] **Step 1:** 实现钩子。
- [x] **Step 2:** 跑 `test_building` / `test_buildings`，绿。

### Task 2: JobHut 被毁释放名额（TDD）

**Files:**
- Modify: `scripts/building/job_hut.gd`
- Add: `tests/test_job_hut_destruction.gd`；Modify: `tests/run_all.gd`

- [x] **Step 1:** 失败测试：小屋被毁 → assigned 清空、居民 job 变 idle；重建后可再分配。
- [x] **Step 2:** 实现 `_on_function_offline`（释放 + 转空闲）。
- [x] **Step 3:** 单跑绿。

### Task 3: StorageBuilding 容量状态机（TDD）

**Files:**
- Modify: `scripts/building/storage.gd`
- Add: `tests/test_storage_capacity.gd`；Modify: `tests/run_all.gd`

- [x] **Step 1:** 失败测试：建仓库 → 容量 +boost；摧毁 → 容量回退；修复 → 恢复；重复摧毁/修复幂等；queue_free → 容量正确释放。
- [x] **Step 2:** 实现 `_capacity_active` 状态机。
- [x] **Step 3:** 单跑绿（注意现有 `test_buildings` 断言容量扩容仍成立）。

### Task 4: ResourceCamp 资源下线/重生（TDD）

**Files:**
- Modify: `scripts/building/resource_camp.gd`
- Add: `tests/test_camp_destruction.gd`；Modify: `tests/run_all.gd`

- [x] **Step 1:** 失败测试：伐木场/采石场被毁 → 场内资源清零；rebuild → 重新生成满编。
- [x] **Step 2:** 实现 offline 删除子资源 / online 无子资源时重新生成。
- [x] **Step 3:** 单跑绿。

### Task 5: Bonfire 事件 + HUD toast

**Files:**
- Modify: `scripts/autoload/event_bus.gd`、`scripts/building/bonfire.gd`、`scripts/ui/hud.gd`

**Interfaces:**
- `EventBus.building_repaired(building_id)`、`bonfire_lost`、`bonfire_restored`。
- Bonfire：offline → `bonfire_lost`；online → `bonfire_restored`。
- HUD：建筑修复/重建 toast；篝火熄灭/重燃 toast。

- [x] **Step 1:** 实现信号与 toast。
- [x] **Step 2:** 单跑 `test_toast_queue` 等，绿。

### Task 6: 玩家复活修复（TDD）

**Files:**
- Modify: `scripts/player/player.gd`、`tests/test_player_hp.gd`
- Add: `tests/test_player_respawn.gd`；Modify: `tests/run_all.gd`

- [x] **Step 1:** 失败测试：真实 bonfire.tscn 未毁 → 死亡回篝火；篝火被毁 → 回 `town_stockpile`。
- [x] **Step 2:** 修改 `_die()`（找 Bonfire 且未毁，否则找 town_stockpile）；`test_player_hp.gd` 改实例化真实篝火场景。
- [x] **Step 3:** 单跑绿。

### Task 7: 存档加载状态同步（TDD）

**Files:**
- Modify: `scripts/autoload/save_manager.gd`
- Add: `tests/test_save_destroyed_buildings.gd`；Modify: `tests/run_all.gd`

- [x] **Step 1:** 失败测试：被毁仓库读档后容量未错误扩容；被毁采石场读档后无场内资源；完好建筑读档功能正常。
- [x] **Step 2:** `_apply_buildings` 调用 `refresh_function_state()`；场内资源不单独存档（避免读档重复）。
- [x] **Step 3:** 单跑绿；修复测试间建筑残留导致的污染。

### Task 8: 全量验证 + 提交

- [x] **Step 1:** 全套测试通过、退出码 0（58 个测试全绿）。
- [x] **Step 2:** 提交 `feat: 建筑损坏联动（容量/名额/资源/篝火）`，按惯例询问合并方式。
