class_name ResourceData
extends Resource
## 资源节点配置（树/石头等），数值全部来自 .tres。

## 唯一 ID（存档/事件用），如 tree / rock
@export var id: String = "tree"
## 显示名称
@export var display_name: String = "树木"
## 贴图（可留空，先用占位色块）
@export var texture: Texture2D
## 需要砍/挖几次才倒
@export var max_hp: int = 3
## 每次砍伐扣除的血量
@export var chop_damage: int = 1
## 产出的资源 ID（wood / stone）
@export var drop_resource: String = "wood"
## 每次产出的数量
@export var drop_amount: int = 1
## 砍倒后多少游戏天重生
@export var respawn_days: int = 2
## 需要什么职业才能采集（woodcutter）
@export var required_job: String = "woodcutter"
