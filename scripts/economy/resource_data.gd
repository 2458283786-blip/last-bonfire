class_name ResourceData
extends Resource
## 资源节点配置（树/石头等），数值全部来自 .tres。

@export var id: String = "tree"
@export var display_name: String = "树木"
@export var texture: Texture2D
@export var max_hp: int = 3
@export var chop_damage: int = 1
@export var drop_resource: String = "wood"
@export var drop_amount: int = 1
@export var respawn_days: int = 2
@export var required_job: String = "woodcutter"
