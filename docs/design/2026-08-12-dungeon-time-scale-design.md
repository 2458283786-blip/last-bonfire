# 地下城时间流速调整设计（2026-08-12）

> 状态：定稿并已实现（2026-08-12）。本文是《地下城时间限制 & 夜袭强度动态公式》（2026-08-11，已实现）的补充附录，讨论稿版本见 `2026-08-12-dungeon-time-scale-design.pdf`。

## 1. 问题

`DayManager.phase_length_seconds` 默认 60 秒/阶段，白天+黄昏最多给玩家 120 秒地下城预算，探索节奏偏紧，很难打得尽兴。

## 2. 思路

DayManager 保持全局单例、时间不为地下城暂停的既有设计不变，只在"玩家人在地下城内"这个状态下，让 DayManager 计时变慢——地下城里的 2 秒只算城镇的 1 秒，实际可探索时长翻倍，但城镇本体的昼夜节奏、夜袭间隔（城镇时间维度）完全不受影响。

## 3. 关键分析：现有两套时钟

实现前必须先解决一个矛盾：当前代码里存在**两套并行的时钟**。

| 时钟 | 位置 | 行为 |
| --- | --- | --- |
| 城镇时钟 | `DayManager._process` | `_phase_timer += delta`（真实时间），60 秒/阶段 |
| 地下城倒计时 | `DungeonManager._process` | 进入时快照 `remaining_to_night`，每帧 `-= delta`（真实时间），归零强制入夜 |

地下城 HUD（`dungeon_hud.gd`、`door_choice.gd`）每帧读取 `DungeonManager.remaining_to_night`。

**如果只缩放 DayManager 的 delta，两套时钟会脱同步**：倒计时仍按真实秒递减，探索预算不增加；且强制入夜会在 DayManager 尚未走到黄昏结束时就触发，等于把城镇的白天提前掐断，违背"城镇节奏完全不受影响"的目标。

示例：白天剩 30 秒时进入（倒计时快照 90 秒）。只缩放 DayManager 后，90 真实秒时 DungeonManager 强制入夜，而放慢后的 DayManager 才走到白天 45 秒处。

## 4. 最终方案

### 4.1 缩放只放在 DayManager

新增可配置 `dungeon_time_scale`（起点 0.5）。地下城内 `effective_delta = delta * dungeon_time_scale`，城镇内照常 1:1。村民、波次生成器均不直接依赖真实时间推进（波次由 `phase_changed` 信号驱动），不受影响。

### 4.2 配置进 game_config.tres

DayManager 是脚本 autoload，`@export` 无法在编辑器持久编辑；按项目"数值进 .tres、脚本只留行为"的约定，把 `dungeon_time_scale` 放进 `GameConfig`，DayManager 启动时加载，代码内保留默认值兜底。

### 4.3 地下城倒计时改为从 DayManager 推导

`DungeonManager._process` 不再独立递减 `remaining_to_night`，改为每帧 `remaining_to_night = _time_until_night()`（按 DayManager 阶段 + 剩余时间计算，函数已存在）。单一事实来源，根治脱同步；`night_forced` 与 `_force_night()` 保留作兜底，强制入夜时机与自然入夜完全一致，晚归波次加成语义不变。

### 4.4 状态联动收敛在 enter/exit

`DungeonManager.enter_dungeon()` 调 `DayManager.set_in_dungeon(true)`，`exit_dungeon()` 调 `set_in_dungeon(false)`（死亡、弃赛、通关均经 `finish_run_to_town → exit_dungeon` 汇聚）。依赖保持单向：DungeonManager → DayManager，DayManager 不反向引用。

### 4.5 存档与 HUD

- `dungeon_time_scale` 是配置值，不需要存档字段；`_in_dungeon` 是运行时状态，跟随场景切换重新判定，不持久化。
- HUD 不改：倒计时仍显示城镇剩余秒数，只是真实消耗速度随缩放变慢，符合直觉。

## 5. 具体改动

- `resources/data/game_config.gd` / `.tres`：新增 `dungeon_time_scale = 0.5`。
- `scripts/autoload/day_manager.gd`：新增 `dungeon_time_scale`（默认 0.5，启动时由配置覆盖）、`_in_dungeon` + `set_in_dungeon()`；`_process` 用 `effective_delta`；`reset()` 清理 `_in_dungeon`。
- `scripts/autoload/dungeon_manager.gd`：`enter_dungeon()` / `exit_dungeon()` / `reset()` 同步 `set_in_dungeon`；`_process` 改为推导 `remaining_to_night`。
- `tests/test_dungeon_time.gd`、`tests/test_game_config.gd`：按新行为更新与新增断言。

## 6. 影响范围

- 只影响地下城内的计时速率；城镇本体（白天造建筑、黄昏预警、夜晚波次间隔）在城镇时间维度完全不变。
- 地下城 HUD 的"距天黑 xx 秒"倒计时显示的仍是城镇时间（不是地下城内主观时间）。
- 存档格式不变。

## 7. 未决问题

- `dungeon_time_scale` 具体数值（0.5 只是起点）需实测：若 0.5 倍后预算仍不够宽松，可调低（如 0.33），或与"方案 A（调大 `phase_length_seconds`）"叠加使用，两者不冲突。
- 是否在地下城 HUD 额外说明"时间流速变慢"（纯提示性文案），避免玩家困惑，属体验细节，待实现后观察反馈再定。
