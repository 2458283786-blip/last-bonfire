# 石头资源链实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐石头采集链：新增矿工小屋（职业转换）+ 采石场（资源生成）+ 矿工职业，让石头可持续生产；抽公共基类避免复制代码；职业显示名统一；存档重新分配泛化。

**Architecture:** 与伐木链对称——`JobHut`（职业建筑基类：job_slots/job_name/分配/释放）与 `ResourceCamp`（资源建筑基类：resource_scene/count/radius 环形生成）；`HarvestJob`（采集职业基类：find_target/work）；`MinerJob` 与 `MinerHut`、`Quarry` 为薄子类。职业显示名收敛到 `TownRegistry.job_display_name()`。存档按 `scene_path` 自动兼容新建筑/资源，仅需把 `_assign_woodcutters` 泛化为 `_assign_job_villagers`。

**Tech Stack:** Godot 4.7.1 / GDScript 2.0 / 现有测试框架 `tests/run_all.gd`（支持 `--only=test_xxx` 单跑）。

## Global Constraints

- 实现前从 `main` 创建分支 `feature/stone-resource`；完成且全绿后按惯例询问合并方式。
- 测试命令（必须用 cmd 重定向等待真实退出码，直接 `&` 调用 Godot 会异步返回假 0）：
  `cmd /c "D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\横板游戏" res://tests/run_all.tscn -- --only=test_xxx > "D:\横板游戏\.superpowers\sdd\2026-08-10-stone-resource\out.txt" 2>&1`
  退出码 0 即通过；控制台中文可能乱码，以退出码与 `[PASS] 全部测试通过` 为准。
- 新测试脚本必须注册进 `tests/run_all.gd` 的 `TEST_SCRIPTS`。
- TDD：先写失败测试，再实现到绿；重构任务（无新行为）以现有全套测试为安全网。
- 中文 UI 文案；所有新文件沿用 `scripts/`、`scenes/`、`tests/`、`resources/data/buildings/` 现有惯例。
- 数值全部进 `.tres` / Inspector 导出，不写死在逻辑里。

---

### Task 1: JobHut 基类 + 伐木屋重构

**Files:**
- Add: `scripts/building/job_hut.gd`
- Modify: `scripts/building/woodcutter_hut.gd`（改为继承 JobHut）

**Interfaces:**
- Produces: `JobHut extends Building`：`job_slots: int`、`job_name: String = "woodcutter"`、`assigned: Array[Villager]`、`can_accept_villager(v) -> bool`、`assign_villager(v)`（`v.set_job(job_name)` + 发 `villager_converted`）、`release_villager(v)`；`_ready` 注册 job_huts。
- WoodcutterHut 保留类名与对外 API，仅改继承。

- [x] **Step 1:** 新建 `job_hut.gd`，`woodcutter_hut.gd` 改继承。
- [x] **Step 2:** 跑现有全套测试，确认全绿（重构安全网）。

### Task 2: HarvestJob 基类 + 伐木工重构

**Files:**
- Add: `scripts/villager/jobs/harvest_job.gd`
- Modify: `scripts/villager/jobs/woodcutter_job.gd`（改为继承 HarvestJob）

**Interfaces:**
- Produces: `HarvestJob extends RefCounted`：`job_name: String = "woodcutter"`、`work_timer: float`、`find_target(villager) -> Node2D`（按 `required_job == job_name` 过滤）、`work(villager, delta) -> bool`。

- [x] **Step 1:** 新建 `harvest_job.gd`，`woodcutter_job.gd` 改继承。
- [x] **Step 2:** 跑现有全套测试，确认全绿。

### Task 3: 矿工职业 + 矿工小屋（TDD）

**Files:**
- Add: `scripts/villager/jobs/miner_job.gd`、`scripts/building/miner_hut.gd`、`tests/test_miner_job.gd`、`tests/test_miner_hut.gd`
- Modify: `scripts/villager/villager_ai.gd`（`_create_job` 注册 "miner"）、`tests/run_all.gd`

**Interfaces:**
- `MinerJob extends HarvestJob`（job_name = "miner"）。
- `MinerHut extends JobHut`（job_name = "miner"）。

- [x] **Step 1:** 写失败测试 `test_miner_job.gd`：矿工找到石头并砍倒、产出掉落入库；不砍树。
- [x] **Step 2:** 写失败测试 `test_miner_hut.gd`：名额分配 `set_job("miner")`、释放后可再接收；空闲居民自动转职矿工。
- [x] **Step 3:** 实现 `miner_job.gd` / `miner_hut.gd` / `_create_job` 注册。
- [x] **Step 4:** 单跑两个新测试，绿。

### Task 4: ResourceCamp 基类 + 采石场（TDD）

**Files:**
- Add: `scripts/building/resource_camp.gd`、`scripts/building/quarry.gd`、`tests/test_quarry.gd`
- Modify: `scripts/building/lumber_camp.gd`（改继承）、`scenes/buildings/lumber_camp.tscn`（`tree_scene`→`resource_scene`）

**Interfaces:**
- `ResourceCamp extends Building`：`resource_scene: PackedScene`、`resource_count: int = 6`、`spawn_radius: float = 120.0`；`_ready` 环形生成。
- `LumberCamp` 保留 `lumber_camps` 组；`Quarry` 无额外组。

- [x] **Step 1:** 写失败测试 `test_quarry.gd`：生成 N 块石头（data 为 rock.tres）、数量/半径可配。
- [x] **Step 2:** 实现 `resource_camp.gd` / `quarry.gd` / `lumber_camp.gd` 重构 + tscn 属性改名。
- [x] **Step 3:** 单跑 `test_quarry` 及现有 `test_buildings` 等，绿。

### Task 5: 场景与配置 + UI 接入

**Files:**
- Add: `scenes/buildings/miner_hut.tscn`、`scenes/buildings/quarry.tscn`、`resources/data/buildings/miner_hut.tres`、`resources/data/buildings/quarry.tres`
- Modify: `scenes/ui/hud.tscn`（`entry_paths` 加两个配置）

**数值：**
- 矿工小屋：造价 `{wood: 15}`、升级 `{wood: 20}` / "矿工名额 +1"。
- 采石场：造价 `{wood: 25}`、升级 `{wood: 30}` / "城内石头 +3"。

- [x] **Step 1:** 新建两个场景（占位色块 + 标签，仿伐木屋/伐木场）与两个 `.tres`。
- [x] **Step 2:** hud.tscn `entry_paths` 追加。
- [x] **Step 3:** 冒烟：`test_build_menu` 与新建筑配置加载。

### Task 6: 职业显示名统一

**Files:**
- Modify: `scripts/autoload/town_registry.gd`、`scripts/ui/villager_panel.gd`、`scripts/ui/hud.gd`、`scripts/ui/building_panel.gd`

**Interfaces:**
- Produces: `TownRegistry.job_display_name(job: String) -> String`（woodcutter→伐木工、miner→矿工、idle→空闲、其余原文）。

- [x] **Step 1:** 实现 `job_display_name`，三处硬编码替换；building_panel 名额行按 `job_name` 显示。
- [x] **Step 2:** 单跑 `test_villager_panel` / `test_building_panel` 等 UI 测试，绿。

### Task 7: 存档重新分配泛化（TDD）

**Files:**
- Modify: `scripts/autoload/save_manager.gd`（`_assign_woodcutters` → `_assign_job_villagers`）
- Add: `tests/test_save_miner.gd`；Modify: `tests/run_all.gd`

**Interfaces:**
- `_assign_job_villagers()`：遍历所有 job_huts，把 `v.job == hut.job_name` 且名额允许的居民重新分配。

- [x] **Step 1:** 写失败测试：矿工存档 → 读档 → 重新分配进矿工小屋。
- [x] **Step 2:** 泛化实现。
- [x] **Step 3:** 单跑存档测试，绿。

### Task 8: 全量验证 + 提交

- [x] **Step 1:** 全套测试（cmd 重定向）通过、退出码 0（53 个测试全绿）。
- [x] **Step 2:** 提交 `feat: 石头资源链（矿工小屋/采石场/矿工职业）`，按惯例询问合并方式。
