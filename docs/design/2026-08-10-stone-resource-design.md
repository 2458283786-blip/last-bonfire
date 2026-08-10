# 石头资源链设计方案（v0.1）

> 状态：待确认（2026-08-10）；确认后编写实施计划再动代码。
> 目的：补齐石头断链——当前 `rock.tres` 要求 `miner` 职业，但职业与对应
> 建筑都不存在，石头无法采集；仓库/伐木场/升级都要石头，会导致游戏断供。

## 1. 设计原则

与伐木资源链完全对称，复用现有模式，不复制代码：

| 功能 | 木头（已有） | 石头（本次新增） |
| --- | --- | --- |
| 职业转换建筑 | 伐木屋 | 矿工小屋 |
| 资源生成建筑 | 伐木场（城内树） | 采石场（城内石头） |
| 采集职业 | 伐木工 | 矿工 |
| 资源节点 | tree.tscn / tree.tres | rock.tscn / rock.tres（已存在） |

## 2. 建筑与职业

### 2.1 矿工小屋（miner_hut）

- 职业转换建筑：提供矿工名额（默认 2，Inspector 可调），空闲居民自动转职。
- 造价建议：`{wood: 15}`（纯木头——采石还没起来前不该要石头，避免死锁）。
- 升级预留：`upgrade_cost {wood: 20}`、`upgrade_effect "矿工名额 +1"`。

### 2.2 采石场（quarry）

- 资源生成建筑：在周围生成固定数量石头（默认 6 块、半径 120，Inspector 可调）。
- 造价建议：`{wood: 25}`（纯木头，同样避免"要先有石头才能采石"的死锁）。
- 升级预留：`upgrade_cost {wood: 30}`、`upgrade_effect "城内石头 +3"`。
- 石头重生沿用 `rock.tres`：5 血、3 天重生、掉落 1 石头、`required_job = "miner"`。

### 2.3 矿工职业（miner）

- `MinerJob` 策略类，仿 `WoodcutterJob`：找 `required_job == "miner"` 且未预留、
  未耗尽的石头 → 挖掘 → 掉落 → 搬运入库。
- `Villager._create_job` 注册 `"miner"`。
- 自动转职、手动转职、每日限一次：全部复用现有通用逻辑（job_huts 机制），无需新逻辑。

## 3. 代码结构：抽公共基类（避免复制粘贴）

第二个职业建筑/资源建筑出现，正是开始复制代码的点。做两个轻量基类：

- `scripts/building/job_hut.gd`（`class_name JobHut extends Building`）：
  `job_slots` + `job_name: String`（默认 "woodcutter"）+ 名额/分配/释放逻辑；
  `WoodcutterHut extends JobHut`（job_name="woodcutter"）、
  `MinerHut extends JobHut`（job_name="miner"）。对外 API 不变，现有测试不受影响。
- `scripts/building/resource_camp.gd`（`class_name ResourceCamp extends Building`）：
  `resource_scene` + `resource_count` + `spawn_radius` 环形生成逻辑；
  `LumberCamp extends ResourceCamp`、`Quarry extends ResourceCamp`。

## 4. 职业显示名统一

目前"伐木工"在居民面板、HUD toast、建筑面板三处硬编码。新增 `TownRegistry`
静态方法 `job_display_name(job: String) -> String`（woodcutter→伐木工、
miner→矿工、其余→职业原文），三处统一调用，后续新职业只改一处。

## 5. UI 接入

- `scenes/ui/hud.tscn` 的建造菜单 `entry_paths` 增加
  `miner_hut.tres`、`quarry.tres`。
- 居民面板转职列表自动出现矿工小屋（job_huts 通用，无需改）。
- 建筑详情面板职业名额显示走统一显示名。

## 6. 存档兼容

- 建筑/资源按 `scene_path` 存读 → 新建筑与新石头自动兼容，无需改存档格式。
- **需要改一处**：`SaveManager._assign_woodcutters()` 泛化为
  `_assign_job_villagers()`——遍历所有 job_huts，把 `job` 匹配的居民重新
  分配回对应小屋；否则读档后矿工不会被重新分配（伐木工逻辑保留）。
- 采石场生成的石头存档后恢复在正确坐标（沿用现有资源恢复逻辑，与伐木场树一致）。

## 7. 测试计划（TDD，全部沿用现有框架）

1. `MinerJob`：找到石头、忽略已预留/耗尽、`work` 扣血并产出掉落。
2. `JobHut` 基类：`MinerHut` 名额分配、`set_job("miner")`、释放。
3. `ResourceCamp` 基类：`Quarry` 生成 N 块 `rock.tres` 石头（数量/半径可配）。
4. 自动转职：空闲居民靠近矿工小屋转矿工。
5. 完整流程：矿工挖石 → 掉落 → 入库（stone +1）。
6. 存档：矿工职业读档后重新分配进矿工小屋。
7. 建造菜单含矿工小屋/采石场；居民面板显示"矿工"。
8. 现有 49 个测试保持全绿（WoodcutterHut/LumberCamp 重构后行为不变）。

## 8. 明确不做（本次）

- 人口招募（后续地下城解救设计）
- 建筑损坏联动（仓库容量失效/名额释放/场内资源清理）
- 建筑升级实际效果（仅预留配置）
- 野生石头生成器（城外随机石头，后续需要再加）
- 金币/怪物材料消耗出口
