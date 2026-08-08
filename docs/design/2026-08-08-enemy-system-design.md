# 敌人系统设计稿（v0.1）

> 状态：待需求方确认，确认后按此实现。

## 1. 定位

敌人是**两套玩法共用的地基**：

- 城镇夜晚防御：怪物袭击建筑（玩家可帮忙防守）。
- 地下城探索：怪物攻击玩家，击杀掉落金币/材料。

设计原则：一个通用敌人场景 + 脚本，属性全部来自 `enemy_*.tres` 配置；新怪物 = 新配置 + 新视觉，不复制脚本。

## 2. 属性设计（EnemyData）

| 字段 | 类型 | 说明 | 首版默认（夜狼） |
| --- | --- | --- | --- |
| id | String | 唯一标识（存档/掉落用） | `night_wolf` |
| display_name | String | 显示名 | 夜狼 |
| texture | Texture2D | 视觉（先占位色块） | — |
| max_hp | int | 血量 | 3 |
| move_speed | float | 移动速度 | 110 |
| damage | int | 单次攻击伤害 | 1 |
| attack_interval | float | 攻击间隔（秒） | 1.2 |
| attack_range | float | 近战攻击距离 | 28 |
| aggro_range | float | 发现目标的距离 | 600 |
| attack_priority | Array[String] | 攻击优先级（按顺序找目标）：villager / building / player | ["villager", "building", "player"] |
| enemy_type | String | 类型预留：melee / ranged / boss / flier | melee |
| armor | int | 减伤（预留，v1 恒为 0） | 0 |
| experience | int | 经验（预留，暂无经验系统） | 0 |
| collision_radius | float | 碰撞半径 | 10 |
| loot_table | Array[LootEntry] | 掉落表 | 见下 |

**LootEntry**（掉落条目）：`resource_id`（如 gold / monster_material）、`min`、`max`（掉落数量区间）、`chance`（概率 0~1）。

首版夜狼掉落：金币 1~2（60%）、怪物材料 1（30%）。

## 3. 行为 AI（状态机）

```
IDLE → CHASE → ATTACK → DIE
          ↑        │
          └────────┘ (目标脱离/冷却结束)
```

- **IDLE**：站在出生点；目标进入 `aggro_range` 后进入 CHASE。
- **CHASE**：直线追击目标（复用居民的移动与卡死检测思路）；进入 `attack_range` 后转为 ATTACK。
- **ATTACK**：按 `attack_interval` 造成 `damage` 伤害，然后回到 CHASE。
- **DIE**：血量归零 → 播放死亡表现 → 按 `loot_table` 生成掉落 → 移除。
- **目标选择（按 attack_priority）**：按优先级列表顺序找目标——夜狼 `["villager", "building", "player"]`：先找最近的居民，其次建筑，最后玩家；地下城怪 `["player"]` 只打玩家。攻城怪可配 `["building", "villager"]`。
- 追击被挡住（如玩家堵路）时：若阻挡者在攻击范围内且可攻击，转攻击它；否则卡死检测后重新选目标。
- v1 直线移动、不做寻路；复杂地形阶段再统一上 NavigationAgent2D（与居民共用方案）。

## 4. 战斗结算

- **玩家 → 敌人**：玩家近战攻击框（Area2D）和箭矢命中敌人 → 扣 1 点血（武器系统上线后再扩展攻击力）。
- **敌人 → 目标**：
  - 打建筑：建筑扣 `damage` 血，血量归零进入"损坏"状态（可重建）。
  - 打玩家：玩家扣 1 点生命，受击后 1 秒无敌（防连击秒杀）。
- **玩家生命（血条制）**：`max_hp = 100`、HUD 显示血条；受击 1 秒无敌；城镇死亡 → 篝火复活（无惩罚），地下城死亡 → 回城。
- **居民受伤（非死亡）**：被怪物攻击后进入"受伤"状态，**失去 N 日工作能力**（`injured_days`，默认 2 天）；受伤时释放职业名额（复用 release_villager），伤愈后自动恢复（有空位重新转职）。
- **击退**：v1 做轻量击退（命中把敌人推开一小段），优化手感，不做硬直系统。

## 5. 掉落与入库

- 敌人死亡按 `loot_table` 生成 `Pickup`（复用现有掉落物场景）。
- 城镇与地下城一致：生成拾取物。
- **拾取方式**：玩家走过拾取物自动拾取；居民空闲/工作中靠近也会自动拾取（复用现有搬运逻辑）。
- **入库**：拾取即入库存（EconomyManager）；背包系统后续版本再做。

## 6. 与现有系统衔接

### 碰撞层（新增）

| 层 | 内容 | 说明 |
| --- | --- | --- |
| 1 | 世界（地面/墙壁） | 已有 |
| 2 | 玩家 | 已有；mask 改为 1\|4（世界+敌人） |
| 3 | 居民 | 已有 |
| 4 | 敌人（新增） | CharacterBody2D，mask = 1\|2（世界+玩家），与玩家互相阻挡 |

### 建筑血量

- 新建一个 `Building` 基类（id、max_hp、hp、take_damage、损坏/重建状态），仓库/伐木屋/伐木场/篝火统一继承——这是对现有三个建筑的小重构。
- **需要新建"篝火"建筑**（城镇核心/出生点/重建点，现在城镇里还没有这个节点）。

### 夜晚波次生成器

- `NightWaveSpawner`：监听 DayManager 的时段（白天→黄昏→夜晚），夜晚在城镇边缘生成一波怪物，目标按攻击优先级自动选择。
- 波次强度随天数递增（第一晚 2 只，每晚 +1~2，设上限）。

### 居民

- 夜晚怪物**优先攻击居民**（attack_priority 第一位）；居民受伤但不死亡，受伤 N 日无法工作（释放职业名额，伤愈恢复）。

## 7. 文件落位

```
scenes/enemies/basic_enemy.tscn      # 通用敌人场景（占位视觉）
scripts/enemy/enemy.gd               # 敌人 AI 状态机
scripts/enemy/enemy_data.gd          # EnemyData 资源类
scripts/enemy/night_wave_spawner.gd  # 夜晚波次生成器
resources/data/enemy_night_wolf.tres # 夜狼配置
scenes/buildings/bonfire.tscn        # 篝火（新建核心建筑）
```

## 8. 测试计划（TDD）

- 配置加载与字段默认值
- 敌人受伤 → 死亡 → 掉落表生成正确数量的 Pickup
- 追击：目标进入感知范围后移动靠近
- 攻击：进入攻击范围后按间隔造成伤害
- 玩家近战/箭矢命中敌人扣血
- 夜晚波次：按天数生成指定数量、目标为建筑
- 建筑受损与损坏状态
- 玩家受击扣血、死亡复活回篝火/回城

## 9. 待确认的点

**已确认的决定：**

1. 掉落：生成拾取物，玩家/居民靠近拾取，拾取即入库。
2. 敌人阻挡玩家：是（互相碰撞）。
3. 玩家生命：血条制（max_hp 100 + 受击无敌），死亡规则如上。
4. 首版怪物：1 种近战（夜狼），地下城阶段再加第二种。
5. 居民：会被攻击，受伤（非死亡），失去 N 日工作能力。
6. 夜晚袭击：每晚一波，强度随天数递增。
7. 新建篝火建筑。
8. 怪物新增攻击优先级属性（attack_priority），便于后期不同怪物优先攻击建筑等。

**实现时的配套假设（如不同意请指出）：**

- 居民受伤默认 2 天，受伤时释放职业名额，伤愈后有空位自动恢复。
- 夜狼攻击优先级默认 `["villager", "building", "player"]`。
- 玩家走过拾取物自动拾取并入库；地下城暂不做背包系统。
