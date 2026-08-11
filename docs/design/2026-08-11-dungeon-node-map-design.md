# 地下城"两门二选一"结构 & 救援/商店解锁 设计（2026-08-11 v0.2）

> 状态：已实现（2026-08-11），按反馈落地：层间过渡用**两门二选一**（类小骨），**不做节点树**；
> 居民救援房**不保底**（概率出现 + 每局上限）；商人等固定 NPC 改为**固定阶段解锁**（不放进房间随机）。

## 1. 目标

- 把线性 demo 升级为"阶段制 + 两门二选一"：每阶段若干房间，房间清完后出现**两扇门**，各自标注下个房间类型，玩家二选一；阶段末尾固定进 BOSS 房。
- 新增**居民救援房**（概率出现）：救回居民 → 回城后成为无职业居民（需住宅才能工作，复用现有规则）。
- 商人等固定 NPC：**固定阶段解锁**（默认第 2 阶段 BOSS 后解锁商店蓝图），不依赖房间随机。
- 与"距天黑"倒计时天然联动（选门/路线 = 时间决策），不新增系统。

## 2. 地下城结构

### 2.1 运行态（DungeonRun，存于 DungeonManager）

```text
DungeonRun
├─ current_stage: int                 # 当前阶段（1..stages）
├─ rooms_cleared_in_stage: int        # 当前阶段已清房间数
├─ stages: int                        # 阶段总数（默认 3）
├─ rooms_per_stage: int               # 每阶段普通房间数（默认 3，之后进 BOSS）
├─ seed
├─ pending_choice: Array[DungeonNodeData]  # 当前二选一的 2 个候选
├─ rescued_villagers: int             # 本次已救居民数（含上限控制）
└─ shop_unlocked: bool                # 固定阶段解锁结果
```

`DungeonNodeData`（Resource，数据驱动）：id / display_name / type（combat / elite / chest / rescue / boss）/ room_scene / enemy_ids / loot。

### 2.2 生成规则（DungeonMapGenerator）

- 每次清房后 `make_choice()` 生成 **2 个候选房间**（类型按权重随机：战斗 60% / 精英 15% / 宝箱 15% / 救援 10%，可配），同一选择内两个候选不重复。
- **居民救援不保底**：只按权重出现，且每局受 `max_rescues_per_run`（默认 2）上限控制——超上限后候选不再出救援房。
- 阶段流程：`rooms_per_stage` 个普通房间后，不再给选择，直接进入该阶段 **BOSS 房**；BOSS 击杀 = 阶段完成。
- 阶段完成：非最终阶段 → 进入下一阶段（重新出现两门选择）；最终阶段 → 整局通关回城。
- 全部参数（阶段数/房间数/权重/救援上限/商人解锁阶段）为配置，不写死。

## 3. 房间系统（预制件 + 动态填充）

- 房间预制件（`scenes/dungeon/rooms/`）：
  - `combat_room.tscn`：按 `enemy_ids` 生成敌人，清怪后出口激活。
  - `elite_room.tscn`：同战斗房但敌人更强（单独权重，可后续差异化）。
  - `chest_room.tscn`：按 `loot` 生成拾取物，拾光后出口激活。
  - `rescue_room.tscn`：守卫 + 囚笼，守卫清完后可交互解救居民（不包含商人）。
  - `boss_room.tscn`：阶段 BOSS，击杀后阶段完成/通关。
- 房间脚本从 `DungeonManager` 当前节点读取数据并填充；房间本地记录生成的敌人/拾取物做清场判定。
- 出口：普通房 → 回到"两门选择"界面；BOSS 房 → 阶段完成（下一阶段两门 / 最终通关回城）。

## 4. 救援与解锁

- **居民救援**：救援房概率出现（不保底，每局上限默认 2）。救回 → `rescued_villagers += 1`；回城时生成对应数量无职业居民（临时堆点，需住宅才能工作）。
- **商人（固定 NPC）**：不出现在房间。默认**第 2 阶段 BOSS 击杀后**自动解锁商店蓝图（`TownRegistry.unlock_blueprint("shop")`），带 toast 提示"商人加入了你的城镇"。解锁阶段可配置。
- 死亡/放弃本局：保留已救居民与已解锁蓝图（无彻底失败），本局进度丢弃。

## 5. 商店正式解锁链路

- `TownRegistry` 新增 `unlocked_blueprints` 表 / `is_blueprint_unlocked(id)` / `unlock_blueprint(id)`。
- `BuildMenu` 过滤改为：`DebugManager.blueprint_unlocked(id, TownRegistry.is_blueprint_unlocked(id))`。
- 商店 `.tres` 保持 `requires_unlock = true`；正式解锁 = 固定阶段达成；Debug 开关仅调试覆盖。

## 6. 存档扩展（v2 → v3）

- 游戏内只有城镇可存档，地下城不能存 → **运行进度不落盘**（会话态）。
- 持久成果：被救居民回城后已是城镇居民（走既有 villagers 存档）；商人解锁写入新增 `"unlocked_blueprints"` 节。
- `SAVE_VERSION` → 3，迁移链补 2→3（旧档补默认空表）。

## 7. 实施任务拆分

- T1：`DungeonNodeData` + `DungeonMapGenerator.make_choice()`（两候选/权重/救援上限）+ `DungeonRun` 状态机（阶段/房间计数/BOSS 判定）+ 测试
- T2：五类房间预制件（战斗/精英/宝箱/救援/BOSS）+ 房间脚本动态填充 + 清场判定 + 测试
- T3：两门选择界面（`door_choice.tscn`，左右两门标注房间类型）+ 进房/回选/阶段过渡/通关流程 + 测试
- T4：居民救援（人口增长）+ 商人固定阶段解锁 + BuildMenu 正式条件 + 测试
- T5：存档 v3（`unlocked_blueprints` + 2→3 迁移）+ 往返测试

## 8. 明确不做（后续迭代）

- 节点树/路线图 UI（本次按反馈用两门二选一）。
- 商店房/事件房/临时货币（讨论稿未决问题，继续砍掉）。
- 深层装备与 Boss 掉落解锁链、美术（占位色块继续）。
