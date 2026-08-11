class_name ResourceData
extends Resource
## 资源节点配置：血量、产出、重生天数等（tree.tres / rock.tres）。
## 注意：这是"可采集资源节点"的配置；UI 显示用的资源定义在 ResourceDef（resources/data/resources/）。

## 唯一 ID（存档/掉落用）
@export var id: String = "resource"
## 显示名称
@export var display_name: String = "资源"
## 视觉（先占位）
@export var texture: Texture2D
## 血量
@export var max_hp: int = 3
## 每次采集伤害（砍一下扣多少）
@export var chop_damage: int = 1
## 产出资源 ID
@export var drop_resource: String = "wood"
## 每次产出数量
@export var drop_amount: int = 1
## 重生天数
@export var respawn_days: int = 2
## 需要职业
@export var required_job: String = "woodcutter"
