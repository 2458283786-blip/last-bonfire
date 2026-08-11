# 玩法循环耦合 & 城镇深化实施计划（2026-08-11）

> 来源：`2026-08-11-loop-coupling-and-villager-ai-design.pdf`（讨论稿 v0.2）。
> 状态：2026-08-11 归档细化为正式实施计划；Phase A/B 已实现；Phase C 的 P11/P12/P13 线性 demo 已实现并全绿（69 个测试），节点图随机/商店解锁/公式调参待后续。

## Goal

解决"城镇经营"与"地下城探索"两条线弱耦合的问题：先深化城镇玩法（升级/住宅/撤退/生活感/调试开关），为地下城接入预留接口；怪物材料立即接入建筑升级消耗形成经济出口。

## Architecture

- **升级系统**：`Building` 基类新增 `upgrade()`，效果由子类 `_apply_level_effects()` 实现；配置仍全部在 `resources/data/buildings/*.tres`（`upgrade_cost` / `upgrade_effect` / `max_level`）。新增 Autoload `BuildingDatabase` 按 `building_id` 索引全部建筑配置，建筑实例不再重复配置造价。
- **住宅约束**：新增 `HousingBuilding`（住宅）提供容量；居民"没房子不能工作"在**产生职业的入口**强制：自动转职、居民面板手动转职、读档恢复均要求先有家；住宅被毁释放居民职业与容量。直接 `set_job`（调试/测试路径）不额外拦截，保证工作流测试稳定。
- **威胁撤退**：怪物生成时（`NightWaveSpawner`）经 `EventBus.threat_broadcast` 广播威胁事件，居民按距离判断后把 `FLEE` 插队为高优先级状态，撤退回家速度 ×1.2；威胁清除后恢复原工作流。
- **生活感第一层**：夜晚非防御居民统一回家（复用 `GO_HOME` 状态）；住宅窗户亮/熄灯；空闲休息随机小动作。
- **调试开关**：新增 Autoload `DebugManager`，正式条件 OR 调试开关，发布构建用 `OS.has_feature("debug")` 屏蔽。

## Global Constraints

- 遵循项目惯例：数据驱动、场景与逻辑分离、EventBus 解耦、先设计后实现（本文件即设计）、TDD（新测试注册进 `tests/run_all.gd`）。
- 测试命令：`godot --headless --path . res://tests/run_all.tscn`；以退出码 0 与 `[PASS] 全部测试通过` 为准。
- 存档：`move_speed` 与住宅归属加入存档；版本保持 1（字段增量兼容）。
- 中文 UI 文案；新文件沿用 `scripts/`、`scenes/`、`tests/` 现有惯例。
- 受伤天数 2 → 3（讨论稿 9.2）；同步更新 `test_villager_injury`。

---

## Phase A（本轮实现）：P1-P6

### Task 1：P1 建筑升级生效 + 怪物材料接入升级消耗

**Files:**
- Modify: `scripts/building/building_data.gd`（`max_level`、`requires_unlock`）
- Add: `scripts/building/building_database.gd`（Autoload）
- Modify: `project.godot`（注册 BuildingDatabase）
- Modify: `scripts/building/building.gd`（`get_data` / `can_upgrade` / `upgrade` / `_apply_level_effects` / `upgraded` 信号）
- Modify: `scripts/building/storage.gd`（等级化容量，幂等）
- Modify: `scripts/building/job_hut.gd`（`effective_slots`）
- Modify: `scripts/building/resource_camp.gd`（等级化资源数量，补足式生成）
- Modify: `resources/data/buildings/*.tres`（升级造价加入怪物材料）
- Modify: `scripts/ui/building_panel.gd`（升级按钮可用/置灰/满级文案）
- Modify: `scripts/autoload/event_bus.gd`、`scripts/ui/hud.gd`（`building_upgraded` 信号 + toast）
- Modify: `scripts/ui/villager_panel.gd`（名额显示用 `effective_slots`）
- Test: `tests/test_building_upgrade.gd`（新）

**Interfaces:**
- Consumes: `BuildingDatabase.get_data(building_id)`、`EconomyManager`、`BuildingData.upgrade_cost/max_level`。
- Produces: `Building.upgrade() -> bool`（扣费、升级、触发效果）、`Building.can_upgrade() -> bool`、`Building._apply_level_effects()`（子类钩子）。

要点：
- 升级失败路径：已摧毁 / 满级 / 资源不足均返回 false 且不扣费。
- 仓库容量按 `capacity_boost * level` 幂等计算（`_capacity_contribution` 差值法），避免存档加载重复扩容。
- 职业小屋名额 = `job_slots + (level-1) * slots_per_level`；资源建筑数量 = `resource_count + (level-1) * resources_per_level`，升级/重建后补足到有效数量。
- 造价示例：仓库升级 `{"wood":15,"stone":8,"monster_material":2}`；伐木场 `{"wood":25,"stone":8,"monster_material":2}`；采石场 `{"wood":30,"monster_material":2}`；伐木屋/矿工小屋保持纯木（早期不卡）。

### Task 2：P2 住宅容量约束居民工作状态

**Files:**
- Add: `scripts/building/housing.gd`（`HousingBuilding`）
- Add: `scenes/buildings/house.tscn`、`resources/data/buildings/house.tres`
- Modify: `scenes/ui/hud.tscn`（BuildMenu entry_paths 追加住宅）
- Modify: `scenes/town/town.tscn`（开局放一座住宅）
- Modify: `scripts/villager/villager_ai.gd`（`home`、`has_home`、`_try_assign_home`；自动转职先要有家）
- Modify: `scripts/ui/villager_panel.gd`（手动转职要求有家）
- Modify: `scripts/autoload/save_manager.gd`（读档 `_assign_homes` → 无家者释放职业 → `_assign_job_villagers`）
- Modify: `tests/test_villager_auto_convert.gd`、`test_miner_hut.gd`、`test_villager_panel.gd`、`test_save_villagers.gd`、`test_save_miner.gd`（补住宅）
- Test: `tests/test_housing.gd`（新，含 P5 夜晚回家/亮灯）

**Interfaces:**
- Consumes: `Villager.home`、组 `housing_buildings`、`TownRegistry`。
- Produces: `HousingBuilding.capacity/capacity_per_level/effective_capacity/assign_villager/release_villager`、`Villager._try_assign_home() -> bool`。

要点：
- 住宅容量 2 + 每级 2；被毁释放居民并使其转空闲（连带释放职业名额），重建后容量恢复。
- 初始 3 名居民开局可正常转职（城镇场景预置一座住宅）。
- 旧存档无住宅：读档后居民无家 → 释放职业转空闲漫游，玩家建住宅后自动入住（IDLE 逻辑复用）。

### Task 3：P3 居民威胁事件广播 + 撤退状态插队

**Files:**
- Modify: `scripts/autoload/event_bus.gd`（`threat_broadcast(origin, radius)`）
- Modify: `scripts/enemy/night_wave_spawner.gd`（生成后广播）
- Modify: `scripts/villager/villager_ai.gd`（`FLEE` 状态、威胁监听、撤退回家 ×1.2）
- Modify: `tests/test_villager_injury.gd`（受伤 3 天 + 补住宅）
- Test: `tests/test_threat_retreat.gd`（新）

**Interfaces:**
- Consumes: `EventBus.threat_broadcast`、组 `enemies`。
- Produces: `Villager._on_threat_broadcast(origin, radius)`、`_any_threat_nearby()`、`_move_toward(..., speed_mult)`。

要点：
- 广播半径复用怪物 `aggro_range`（夜狼 600），居民不做第二套感知半径；威胁是否解除按"附近是否还有敌人"判断（敌人数量少，开销可接受）。
- 受伤居民不参与撤退（已失去工作能力且不再受伤）。
- `injured_days` 默认 2 → 3。

### Task 4：P4 居民移速 ±10% 个体差异

**Files:**
- Modify: `scripts/villager/villager_ai.gd`（`_ready` 随机化）
- Modify: `scripts/autoload/save_manager.gd`（存档 `move_speed`）
- Test: `tests/test_villager_speed_variance.gd`（新）

要点：`move_speed *= randf_range(0.9, 1.1)`；读档恢复存档值，避免反复读档速度漂移。

### Task 5：P5 生活感第一层（回家关灯、空闲小动作）

**Files:**
- Modify: `scripts/villager/villager_ai.gd`（`GO_HOME` 状态：夜晚回家不工作；空闲休息随机小动作）
- Modify: `scenes/villagers/villager.tscn`（`IdleEmote` 标签）
- Modify: `scripts/building/housing.gd`（窗户亮/熄灯）
- 测试并入 `tests/test_housing.gd`

要点：夜晚非防御居民回家（有房回房、无房保持漫游）；住宅窗户夜晚且有住户时点亮；空闲休息随机显示 `Zzz/…/♪/☕/🌿`。

### Task 6：P6 DebugManager 统一调试开关

**Files:**
- Add: `scripts/autoload/debug_manager.gd`
- Modify: `project.godot`（注册 DebugManager）
- Modify: `scripts/ui/build_menu.gd`（`requires_unlock` 过滤）
- Modify: `scripts/ui/placement_controller.gd`（`skip_costs`）
- Test: `tests/test_debug_manager.gd`（新）

**Interfaces:**
- Produces: `DebugManager.unlock_all_blueprints / instant_recruit / skip_costs / is_debug_build()`。

要点：解锁判断写为"正式条件 OR Debug 开关"；本轮先把开关框架与两处消费（蓝图过滤、跳过造价）落地，商店/招募（P9/P10）直接复用。

---

## Phase B（后续迭代）：P7-P10

- P7 民兵营/箭塔建筑 + 士兵简化站桩 AI（防御职业基类，复用转职型机制；右侧边缘站桩，受伤复用居民机制，不做阵亡）。
- P8 背包最简版本（装备/道具入口，商店前置依赖）。
- P9 商店建筑（DebugManager 强制解锁蓝图）+ 装备数值梯度 + 换装外观联动。
- P10 临时人口招募（金币每 N 天招募 1 人，上限 6-8 人，DebugManager 门控）。

## Phase C（后续迭代）：P11-P13

- P11 地下城时间限制：进入地下城后城镇时间照常流逝，探索超时提前触发夜晚波次（+强度加成），关卡内显示"距天黑 xx 秒"；回城结算细节需在正式地下城计划中定稿。
- P12 夜袭强度动态公式（天数基线 + 居民数/建筑数 + 仓库囤积惩罚 + ±20% 浮动），需先有测试人口/建筑数据再调参。
- P13 地下城第一版 demo：固定线性路线（3-4 战斗房 + 1 宝箱房 + 1 BOSS 房），房间预制件拼装，验证"时间限制 → 材料反哺城防 → 装备解锁深层"链路；节点图随机与商店/事件房后置。

## 未决问题（沿用讨论稿）

- 装备词条/稀有度第一版不做。
- 夜袭公式系数待实测。
- 撤退 +20% 是否需要动画/音效表现。
- 地下通道入口位置（右侧 vs 中心）。
- 地下城商店/事件房临时货币是否做。
