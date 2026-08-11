class_name PhysicsLayers
## 2D 物理层常量（与 project.godot [layer_names] 对齐）：
## 1 世界 / 2 玩家 / 4 居民 / 8 敌人。
## 新物理层加入时在这里定义并用 | 组合掩码；禁止在场景/脚本里写裸数字。

const WORLD := 1
const PLAYER := 2
const VILLAGER := 4
const ENEMY := 8

## 常用掩码组合
const MASK_WORLD_ONLY := WORLD                    # 居民：只与世界碰撞
const MASK_WORLD_PLAYER := WORLD | PLAYER          # 敌人：世界 + 玩家
const MASK_WORLD_ENEMY := WORLD | ENEMY            # 玩家/箭矢：世界 + 敌人
