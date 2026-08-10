# 《最后的篝火》存档系统设计文档

> 版本：v0.1（2026-08-10，方案确认阶段）
> 状态：已与需求方确认启用存档；本方案作为实现依据，随开发迭代更新（实现记录见文末）。

## 1. 目标与原则

- **目标**：玩家能随时保存/恢复城镇进度——建筑（含状态）、资源（树/石头的剩余与重生）、居民（职业/伤势/搬运物）、库存与容量、昼夜进度、玩家位置与血量。
- **格式**：JSON 单文件 `user://save_game.json`，含版本号，便于调试、迁移与手工检查。
- **稳定性**：保存发生在状态稳定的时刻（新的一天开始/手动），不保存"进行中"的战斗与夜晚波次，加载后世界处于可继续游玩的确定状态。
- **可测试**：存档读写做成纯逻辑（快照 → JSON → 恢复），加载后各系统状态可断言。
- **扩展**：结构按"系统分节"，后续加背包/装备、解锁、地下城进度时在各节内扩展，不破坏旧存档（靠 version 迁移）。

## 2. 存档范围（数据清单）

| 系统 | 保存内容 | 来源 |
| --- | --- | --- |
| 全局 | `version`、`saved_at`（时间戳） | SaveManager |
| 昼夜 | `day`、`phase`、`phase_elapsed`（本阶段已过秒数） | DayManager |
| 经济 | `stock`（全部资源字典）、`capacity` | EconomyManager |
| 玩家 | `position`、`hp` | Player（组 `players`） |
| 建筑 | 每栋：`scene_path`、`position`、`hp`、`is_destroyed`、`level` | 组 `buildings` |
| 资源节点 | 每个：`scene_path`、`position`、`current_hp`、`is_depleted`、`respawn_day`、`is_wild` | 组 `resources` |
| 居民 | 每个：`display_name`、`job`、`position`、`carry`、`hp`、`is_injured`、`injured_remaining_days`、`home_position` | 组 `villagers` |

**明确不保存**：

- 活动敌人与夜晚波次（只在新的一天开始/安全时刻存档，夜晚敌人下次夜晚重新生成）。
- 居民 `state`（加载后统一回到空闲/按职业重新找活）。
- `TownRegistry.adjusted_today`（每日重置数据，加载后当天可重新调整，保持简单）。
- 伐木屋 `assigned` 列表（由居民的 `job` 恢复后重新分配）。
- 伐木场生成的城内树、`WildTreeSpawner` 的随机位置（树作为资源节点整体保存，覆盖随机生成结果）。

## 3. 存档格式（JSON 示例）

```json
{
  "version": 1,
  "saved_at": "2026-08-10T12:00:00",
  "day": { "day": 3, "phase": 0, "phase_elapsed": 12.5 },
  "economy": {
    "stock": { "wood": 12, "stone": 5, "gold": 30, "monster_material": 4 },
    "capacity": 100
  },
  "player": { "position": [400, 850], "hp": 70.0 },
  "buildings": [
    {
      "scene_path": "res://scenes/buildings/storage.tscn",
      "position": [841, 862],
      "hp": 100,
      "is_destroyed": false,
      "level": 1
    }
  ],
  "resources": [
    {
      "scene_path": "res://scenes/resources/tree.tscn",
      "position": [300, 810],
      "current_hp": 2,
      "is_depleted": false,
      "respawn_day": -1,
      "is_wild": true
    }
  ],
  "villagers": [
    {
      "display_name": "阿强",
      "job": "woodcutter",
      "position": [280, 850],
      "carry": { "wood": 2 },
      "hp": 20.0,
      "is_injured": false,
      "injured_remaining_days": 0,
      "home_position": [277, 853]
    }
  ]
}
```

## 4. 保存时机

- **自动存档**：每次推进到"新的一天（白天）"时自动保存一次——此时无活动敌人、状态稳定、资源重生已结算。
- **手动存档**：暂停菜单"存档"按钮（现有占位）→ 写入并 toast 提示"已存档"。
- **手动读档**：暂停菜单"读档"按钮（新增）→ 确认后重载当前城镇并恢复。
- **启动入口**：boot 场景检测到 `has_save()` 时显示"继续游戏"按钮（点击 → 进入城镇 → 恢复存档）；无存档则显示"开始新游戏"。

## 5. 加载流程

恢复顺序固定，依赖关系自上而下：

1. **清理现场**：删除当前场景中 `buildings` / `resources` / `villagers` 组的所有节点（避免与存档内容重复；仓库 `_exit_tree` 会回退容量，随后由存档覆盖）。
2. **DayManager**：恢复 `day` / `phase` / `phase_elapsed`，触发对应信号让监听者（夜晚波次、资源重生、城镇登记）重算。
3. **EconomyManager**：`reset()` 后直接写入 `stock` 与 `capacity`。
4. **建筑**：按存档逐栋 `load(scene_path).instantiate()` → 设置 `position` / `hp` / `is_destroyed` / `level` → 加入场景。恢复顺序保证伐木屋/伐木场/仓库的 `_ready` 副作用（名额、容量、城内树）正常发生。
5. **资源节点**：按存档逐棵实例化并覆盖位置/血量/耗尽/重生天数/野生标记。
6. **居民**：按存档逐名实例化 `villager.tscn` 并设置字段；`job == "woodcutter"` 的居民加载后自动分配到有空位的伐木屋。
7. **玩家**：恢复 `position` / `hp`。
8. **TownRegistry**：`adjusted_today` 清空（不存档）。

读档入口统一为 `SaveManager.load_game()`，由城镇场景调用（`GameManager.change_scene(town)` 完成后触发）。

## 6. 错误处理与版本迁移

- 存档文件不存在：`load_game()` 返回 false，不报错。
- JSON 解析失败或 `version` 不匹配：返回 false，toast 提示"存档损坏或版本不兼容"，保留原文件（便于排查）。
- 恢复过程中某个节点实例化失败：跳过该项并记录警告，不中断整体加载。
- `version` 字段预留迁移入口：`migrate(data: Dictionary) -> Dictionary`，Demo 阶段仅校验 `version == 1`，后续版本升级在此扩展。

## 7. 前置小改动（实现时顺带完成）

- 各建筑场景补唯一 `building_id`（`storage` / `woodcutter_hut` / `lumber_camp` / `bonfire`），与 `BuildingData.id` 对齐，供存档标识与后续存档校验。
- `DayManager` 提供 `phase_elapsed()`（或公开 `_phase_timer` 的读取方法），供存档读取；恢复时用 `phase_length_seconds - elapsed` 反设计时器。
- `SaveManager` 增加 `last_error: String` 与 `save_failed` / `load_failed` 信号，便于 UI 提示。

## 8. 测试策略

- **Round-trip 测试**：构造一个城镇状态（建仓库、砍树使一棵树耗尽、推进天数到第 3 天、居民受伤）→ `save_game()` → 修改各系统状态 → `load_game()` → 断言库存/容量/天数/阶段/建筑 hp 与位置/树状态/居民职业与伤势/玩家血量全部恢复。
- **文件层测试**：`save_game()` 后 `has_save()` 为 true；JSON 可解析且 `version` 为 1。
- **异常测试**：写入非法 JSON 文件 → `load_game()` 返回 false 且不崩溃。
- 沿用 `tests/run_all.gd` 框架，全部 `godot --headless` 可跑。

## 9. 实施顺序

1. **SaveManager 核心**：版本、快照/恢复骨架、JSON 读写、错误处理（纯逻辑，先测）。
2. **全局系统存档**：DayManager / EconomyManager / 玩家。
3. **建筑存档**：`building_id` 补全 + 清空重建 + 状态恢复。
4. **资源节点存档**：状态快照 + 重建覆盖。
5. **居民存档**：删除重建 + 职业关联恢复。
6. **接入时机**：白天自动存档 + 暂停菜单存/读档 + boot 继续按钮。
7. **全量验证与文档更新**（本方案的"实现记录"节同步更新）。

## 10. 待确认决策点

1. **保存时机**：推荐"新的一天自动存档 + 手动存/读档"；备选：仅手动。
2. **存档槽**：推荐单槽（Demo）；备选：多槽位。
3. **恢复方式**：推荐"清空重建"（建筑/资源/居民全部按存档重造，支持玩家后建建筑与任意状态）；备选：只恢复玩家后建内容。

## 11. 实现记录

- （待实现后按实施顺序追加，保持与代码同步）
