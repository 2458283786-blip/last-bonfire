# 代码加固与架构收口实施计划（2026-08-11）

> 来源：2026-08-11 代码审计报告。目标：消除"数据驱动与硬编码并存"的两套真相，按危害排序逐项收口。
> 状态：R1-R4 已实现并全绿（79 个测试脚本）；R5 可选，按需再做。

## 目标与原则

- 不改变现有玩法行为与数值手感（显式迁移除外）。
- 新扩展点统一走"注册表 + .tres 配置"，代码里只留行为类。
- 每项改动都有对应测试：要么新测试，要么更新既有测试。
- 验证基线：当前 72 个测试全绿；完成后预计 ~78 个。

---

## R1 数据契约层（高风险快赢，先做）

### R1.1 资源注册表 + UI 显示统一

**问题**：`hud.resource_name()`、`build_menu` 卡片文案（只显示木/石）、`building_panel.RESOURCE_SHORT` 三处各自维护资源显示名，新资源会漏显示。

**Files:**
- Add: `scripts/economy/resource_data.gd`（`ResourceData`：id / display_name / short_name / icon_color）
- Add: `resources/data/resources/*.tres`（wood / stone / gold / monster_material 四个）
- Add: `scripts/economy/resource_database.gd`（Autoload，扫描目录，同 BuildingDatabase 模式）
- Modify: `project.godot`（注册 ResourceDatabase）
- Modify: `scripts/ui/hud.gd`（`resource_name()` 改查注册表）
- Modify: `scripts/ui/build_menu.gd`（卡片显示全部 cost，短名来自注册表）
- Modify: `scripts/ui/building_panel.gd`（删除 `RESOURCE_SHORT`，改查注册表）
- Test: `tests/test_resource_database.gd`（新资源自动入表；三处 UI 显示一致）

### R1.2 物理层常量收口

**问题**：collision_layer/mask 以魔法数字散落在各 .tscn（9/3/8/4…），新物理层漏改即静默失效。

**Files:**
- Add: `scripts/utils/physics_layers.gd`（`PhysicsLayers` 常量：WORLD/PLAYER/VILLAGER/ENEMY 与常用掩码组合）
- Modify: `scripts/player/player.gd`、`scripts/player/arrow.gd`、`scripts/villager/villager_ai.gd`、`scripts/enemy/enemy.gd`（`_ready` 从常量赋值；.tscn 占位值保留）
- Test: `tests/test_physics_layers.gd`（断言各节点掩码与常量一致）

### R1.3 威胁半径跟随敌人数据

**问题**：`Villager.THREAT_RADIUS = 600` 与夜狼 `aggro_range` 重复定义，调敌人感知会脱节。

**Files:**
- Modify: `scripts/villager/villager_ai.gd`（`_any_threat_nearby` 改用敌人各自的 `data.aggro_range` 判断，删除固定 600 常量）
- Modify: `tests/test_threat_retreat.gd`（用自定义 aggro_range 的敌人验证远近）

### R1.4 场景路径收口

**问题**：town/boot/villager 等场景路径硬编码 4+ 处，重命名即白屏。

**Files:**
- Add: `scripts/utils/scene_registry.gd`（`SceneRegistry` 静态常量：BOOT / TOWN / DUNGEON / VILLAGER / LOADING_OVERLAY）
- Modify: `scripts/main/boot.gd`、`scripts/ui/hud.gd`、`scripts/autoload/dungeon_manager.gd`、`scripts/dungeon/dungeon_entrance.gd`、`scripts/autoload/town_registry.gd`、`scripts/autoload/save_manager.gd`、`scripts/town/town.gd`
- Test: `tests/test_scene_paths.gd`（所有常量路径均可 load）

---

## R2 注册表一致性

### R2.1 职业注册表

**问题**：新职业要改 `Villager._create_job` match + `TownRegistry.JOB_DISPLAY_NAMES` + 行为类，漏一处静默出错。

**Files:**
- Add: `scripts/villager/jobs/job_registry.gd`（job_name → {script_path, display_name} 注册表）
- Modify: `scripts/villager/villager_ai.gd`（`_create_job` 改从注册表按脚本路径实例化）
- Modify: `scripts/autoload/town_registry.gd`（`JOB_DISPLAY_NAMES` 删除，改查注册表）
- Test: `tests/test_job_registry.gd`（注册表完整性：每个注册职业都能实例化且 display_name 存在）

### R2.2 敌人目标类型映射测试兜底

**问题**：`attack_priority` 字符串由 `Enemy._nearest_in_type` 手写 match，拼错即静默发呆。

**Files:**
- Modify: `scripts/enemy/enemy.gd`（把支持的目标类型收成单一常量表，供映射与校验共用）
- Test: `tests/test_enemy_targets.gd`（遍历所有 EnemyData，断言 priority 每个字符串都有映射）

### R2.3 建造菜单单注册表

**问题**：BuildingDatabase 自动扫描，但 BuildMenu 用 hud.tscn 手写 `entry_paths`，双注册表必漂移。

**Files:**
- Modify: `scripts/building/building_data.gd`（增加 `build_menu_order: int = 999`）
- Modify: `scripts/ui/build_menu.gd`（从 `BuildingDatabase.all_data()` 按 order 构建，删除 entry_paths 依赖）
- Modify: `scenes/ui/hud.tscn`（移除 entry_paths 属性）
- Modify: 各 `resources/data/buildings/*.tres`（补充 order）
- Modify: `tests/test_build_menu.gd`（改用数据库条目 + order 断言）

---

## R3 存档健壮性

### R3.1 版本迁移落地

**问题**：`migrate()` 空壳、版本永远 1，改格式即废档且无提示。

**Files:**
- Modify: `scripts/autoload/save_manager.gd`（migrate 骨架：按版本号逐级升级函数表；示例实现 1→2）
- Test: `tests/test_save_migration.gd`（构造 v1 存档 → migrate → 断言 v2 字段补齐）

### R3.2 全量往返测试

**问题**：存档字段手写清单，漏存/漏恢复无感知。

**Files:**
- Test: `tests/test_save_roundtrip.gd`（满状态：建筑升级/住宅/装备/背包/招募冷却/受伤/资源耗尽 → 存 → 清 → 读 → 逐字段断言）

---

## R4 代码去重

### R4.1 "释放职业"单点收口

**问题**：`villager._injure` / `housing._release_job` / `villager_panel._release_from_huts` / `save_manager._release_homeless_jobs` 四处重复扫描 job_huts。

**Files:**
- Modify: `scripts/villager/villager_ai.gd`（新增 `release_from_job()` 单点实现）
- Modify: `scripts/building/housing.gd`、`scripts/ui/villager_panel.gd`、`scripts/autoload/save_manager.gd`（改调单点）
- Modify: 相关测试（test_villager_injury / test_job_hut_destruction / test_housing 等）

### R4.2 基础数值入配置

**问题**：重力 1200 三份拷贝；受伤 0.5 / 逃跑 1.2 在 villager 写死。

**Files:**
- Modify: `resources/data/game_config.gd`（新增 gravity、villager_flee_speed_mult、villager_injured_speed_mult、enemy_gravity 等，默认值与现状一致）
- Modify: `scripts/player/player.gd`、`scripts/villager/villager_ai.gd`、`scripts/enemy/enemy.gd`（读取配置，脚本导出默认值兜底）
- Test: 配置加载断言（并入既有经济/配置测试或新增小测试）

---

## R5 结构演进（可选，按需再做）

- `TownRegistry` 拆分：招募相关（费用/冷却/上限/落点）独立为 `RecruitManager`。
- `SaveManager` 按领域拆分或至少把字段清单集中为 SCHEMA 常量并配往返测试。
- **明确不做**：`Villager` 状态机大拆分（428 行单体，等新玩法需求出现时顺势拆）；美术视觉管线（等美术资产接入时统一做）。

---

## 验证方式

- 每阶段后跑全量测试（headless），要求退出码 0、无 SCRIPT ERROR。
- 城镇/地下城/启动场景 headless 冒烟各一次。
- R3 完成后手动验证"旧版本存档 → 迁移 → 可读"。

## 风险与注意

- R1.1/R2.3 改的是 UI 显示与菜单来源，数值与行为不变；短名保持 木/石/金/材 一致。
- R3.1 定版 v2 后，后续加字段必须 bump 版本或补迁移函数，否则测试拦截。
- R4.2 配置缺省值必须与现状逐项相等，避免手感漂移。
- 每项独立可回退（小步提交式推进），不改动与该项无关的代码。
