# 接手指南（2026-08-12）

> 给新会话/新开发者的快速上手文档。想了解背景与详细设计，先读本文，再按需看
> [README.md](../README.md)、[总设计方案](design/2026-08-10-master-plan.md)、[开发日志](dev-notes/2026-08-12.md)。

## 1. 项目定位

- 《最后的篝火》：Godot 4.7.1 的 2D 横版建造经营 + 探索战斗游戏。
- 核心循环：白天经营城镇（建造/分配居民）→ 地下城探索（两门二选一，打怪/拾取/救援）→ 回城用金币与材料升级/解锁商店 → 夜晚防守（右侧屏幕外波次行军来袭）。
- 仓库：https://github.com/2458283786-blip/last-bonfire （public，main）
- 本地路径：`D:\ai项目\篝火\last-bonfire-main\last-bonfire-main`

## 2. 运行与测试

- Godot 4.7.1（本机 Steam 版：`D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`）。
- 运行：用 Godot 打开 `project.godot` 按 F5；或 `godot --headless --path .`。
- 全量测试：
  `godot --headless --path . res://tests/run_all.tscn`
- 单跑测试：`godot --headless --path . res://tests/run_all.tscn -- --only=test_xxx`
- **新增测试必须注册进 `tests/run_all.gd` 的 `TEST_SCRIPTS`**；新增 `class_name` 后跑一次 `godot --headless --path . --import` 刷新类缓存。
- 测试日志会写在项目根目录（如 `tests_run_*.log`），用后删除，不入库。

## 3. 架构速览

### Autoload（project.godot 注册顺序）

`EventBus` → `DayManager` → `EconomyManager` → `TownRegistry` → `BuildingDatabase` → `GameManager` → `SaveManager` → `DebugManager` → `InventoryManager` → `DungeonManager` → `ResourceDatabase` → `EnemyDatabase` → `AudioManager`

### 数据驱动与注册表（新内容 = 加 .tres / 注册表，不写死）

| 类别 | 配置目录 | 注册表 |
| --- | --- | --- |
| 建筑 | resources/data/buildings/*.tres | BuildingDatabase（自动扫描） |
| 物品 | resources/data/items/*.tres | InventoryManager（自动扫描） |
| 资源（UI 显示名） | resources/data/resources/*.tres | ResourceDatabase（ResourceDef） |
| 敌人 | resources/data/enemy_*.tres | EnemyDatabase（自动扫描） |
| 职业 | scripts/villager/jobs/ | JobRegistry（静态表） |
| 场景路径 | — | SceneRegistry（静态常量） |
| 物理层 | — | PhysicsLayers（常量，禁止裸数字） |
| 商店货品 | resources/data/shops/*.tres | ShopData（物品 ID 数组） |

### 关键约定

- 场景与逻辑分离：`.tscn` 放场景，`.gd` 放脚本（一一对应）。
- 跨系统通信走 `EventBus` 信号，不直接互相引用。
- 存档 `user://save_game.json`：版本 v3，`migrate()` 链 1→2→3；**改存档格式必须 bump 版本 + 补迁移函数 + 测试**。
- 建筑/职业/敌人/物品的数值全部来自 `.tres`/场景导出，脚本里只留行为与默认值。

## 4. 当前进度（84 个测试全绿）

- 玩法循环 13 项优先级全部落地：建筑升级（含怪物材料消耗）、住宅约束、威胁撤退、移速差异、生活感、DebugManager、防御建筑（民兵/箭塔）、背包、商店、临时招募、地下城时间限制、夜袭动态公式、地下城两门二选一（含居民救援房 + 商人固定阶段解锁）。
- 代码加固 R1-R4：资源/职业/场景路径注册表、物理层常量、存档迁移、释放职业单点、数值入配置。
- 修复过的运行时问题：读档村民冻结、读档进度条、进地下城 toast 崩溃、威胁广播丢失、测试跨污染等（详见开发日志）。

## 5. 下一步候选（按优先级）

1. **地下城深化**：事件房/商店房/临时货币、深层装备与 Boss 掉落解锁链。
   设计：`docs/design/2026-08-11-dungeon-node-map-design.md`（第 8 节"明确不做"）。
2. **数值平衡**：夜袭波次公式系数（`NightWaveSpawner` 导出配置）需实测调参；造价/生产速率/昼夜时长首版平衡。
3. **内容扩展**：更多怪物/建筑/资源（铁矿/食物等）、装备词条/稀有度。
4. **结构（可选 R5）**：TownRegistry 拆分招募、SaveManager 领域拆分、Villager 状态机拆分（428 行单体，建议等新玩法需求时顺势拆）。

## 6. 已知坑（务必注意）

- `Array.all()` 的 lambda 参数**不能强类型 Node**（数组里出现已释放对象会报错），用无类型参数 + `is_instance_valid`。
- 测试容器里房间节点 `_process` 时序与真实场景不一致：测试里直接调用方法驱动（如 `rescue._process(0.016)`）。
- 会切换场景的交互物（地下城入口/房间出口/囚笼）必须设 `self_handled = true`，HUD 才不会在场景切换后往已释放的 toast 队列推提示（会导致 `create_timer on null` 崩溃）。
- 编辑器实例（`--editor`）与本机测试进程不要同时操作同一项目目录，避免 `.godot` 锁冲突；跑测试前确认没有残留 Godot 进程。
- 新增 `.tres` 后若 UI 没显示，检查是否忘了在对应注册表目录/菜单里（BuildMenu 现在从 BuildingDatabase 自动构建，按 `build_menu_order` 排序）。
- 存档兼容：老版本存档由 `migrate()` 升级；新增字段要么有默认值，要么补迁移。

## 7. git 说明

- 本地 `main` 已跟踪 `origin/main`（GitHub）。提交身份是仓库级配置的 noreply 邮箱，直接 `git commit`/`git push` 即可。
- 提交习惯：功能 + 测试一起提交；改文档/设计先于或同步于代码。
