# 建筑损坏联动设计方案（v0.1）

> 状态：待确认（2026-08-10）；确认后编写实施计划再动代码。
> 目的：让"建筑被毁"真正产生后果（功能下线），修复/重建后恢复功能。
> 当前漏洞：仓库被毁容量不失效；职业小屋被毁名额不释放；资源建筑被毁
> 场内树/石头不清理；篝火被毁无特殊处理；玩家死亡复活点组名错误。

## 1. 设计原则

- **功能型建筑有"在线/离线"状态**：`is_destroyed = 离线`，功能下线；
  `repair()` / `rebuild()` = 上线，功能恢复。
- **幂等钩子**：上线/下线钩子可重复调用而不重复生效（用布尔标志保护），
  存档加载时统一调用一次同步。
- **资源归属建筑**：伐木场/采石场生成的场内资源是建筑的"财产"，
  建筑离线时随之下线（删除），上线时重新生成满编。

## 2. Building 基类：功能钩子

新增三个方法：

```gdscript
func _on_function_offline() -> void:  # 子类覆盖；建筑被摧毁时调用
func _on_function_online() -> void:   # 子类覆盖；修复/重建时调用
func refresh_function_state() -> void: # 存档加载后同步一次
```

- `take_damage` 血量归零 → `is_destroyed = true` → 发 destroyed 信号 →
  基类 `_on_destroyed` 中调用 `_on_function_offline()`（保留现有
  `building_destroyed` 事件）。
- `repair()` / `rebuild()` → 恢复满血与可见 → 调用 `_on_function_online()`。
- `refresh_function_state()`：`is_destroyed` 为真调 offline，否则调 online
  （幂等，由子类布尔标志保证不重复生效）。

## 3. 各建筑联动

| 建筑 | 被毁（offline） | 修复/重建（online） |
| --- | --- | --- |
| 仓库 | 容量 -boost（幂等） | 容量 +boost（幂等） |
| 伐木屋/矿工小屋 | 释放全部名额，居民转空闲 | 无动作（居民自动/手动重新分配） |
| 伐木场/采石场 | 删除全部场内资源 | 重新生成满编资源 |
| 篝火 | 标记熄灭，发专用事件 | 重燃，发专用事件 |

### 3.1 JobHut

`_on_function_offline()`：遍历 `assigned.duplicate()`，逐个
`release_villager(v)` + `v.set_job("idle")`——居民恢复空闲后由现有
`_try_auto_convert` 自动转职到其他有空位的小屋（如果有）。

### 3.2 StorageBuilding

容量状态机（防重复加减）：

```gdscript
var _capacity_active := false
# _ready: set_capacity(+boost); _capacity_active = true
# offline: if _capacity_active: set_capacity(-boost); _capacity_active = false
# online:  if not _capacity_active: set_capacity(+boost); _capacity_active = true
# _exit_tree: if _capacity_active: set_capacity(-boost)
```

存档场景：加载被毁仓库时 `_ready` 先扩容，随后
`refresh_function_state()` 调用 offline 减回去，净效果为 0。

### 3.3 ResourceCamp

`_on_function_offline()`：`queue_free` 所有子 `ResourceNode`；
`_on_function_online()`：若无子资源则 `_spawn_resources()`。

存档场景：加载被毁伐木场/采石场时先生成资源，随后 offline 删除，
重建时 online 重新生成满编。

### 3.4 Bonfire + 玩家复活（修复隐藏 bug）

- `_on_function_offline()`：发 `EventBus.bonfire_lost`；
  `_on_function_online()`：发 `EventBus.bonfire_restored`。
- **修复玩家复活组名 bug**：`player.gd` 死亡时查 `"bonfires"` 组，
  但篝火实际在 `"core_buildings"` 组，导致真实游戏死亡不传送。
  改为：找最近的 `Bonfire` 且未摧毁 → 传送到篝火；
  篝火被毁（或不存在）→ 传送到 `town_stockpile`（临时堆点），
  仍无则原地复活（无彻底失败兜底）。
- `test_player_hp.gd` 改为实例化真实 `bonfire.tscn`（不再手动加组）。

## 4. 事件与 UI

- `EventBus` 新增 `building_repaired(building_id)`、
  `bonfire_lost`、`bonfire_restored`。
- HUD toast：建筑修复/重建提示"X 已修复/重建"；篝火熄灭"篝火熄灭了！
  尽快重建"；重燃"篝火重燃"。

## 5. 存档兼容

- 存档格式与版本不变（`is_destroyed` 已保存）。
- `SaveManager._apply_buildings` 在恢复血量/状态后调用
  `b.refresh_function_state()`，保证容量、名额、场内资源与建筑状态一致。

## 6. 测试计划（TDD）

1. `StorageBuilding`：被毁 → 容量减；修复 → 恢复；重复调用幂等；
   移除建筑 → 容量释放正确。
2. `JobHut`：被毁 → 名额释放、居民转空闲；重建后可再分配。
3. `ResourceCamp`：被毁 → 场内资源清零；重建 → 重新生成满编。
4. `Bonfire`：被毁/重建发出专用事件。
5. 玩家复活：篝火完好 → 死亡回篝火；篝火被毁 → 回临时堆点。
6. 存档：被毁仓库读档后容量未错误扩容；被毁采石场读档后无场内资源。
7. 现有 53 个测试保持全绿。

## 7. 明确不做（本次）

- 建筑升级实际效果（仍为占位）
- 篝火被毁导致的额外惩罚（如资源损失）
- 城墙/箭塔等防御建筑
