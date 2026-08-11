class_name ResourceDef
extends Resource
## 资源定义（UI 显示）：显示名/短名/颜色，数据驱动（resources/data/resources/*.tres）。
## 新资源 = 新增一个 .tres，UI 自动读取；注意与 ResourceData（资源节点配置）区分。

## 唯一 ID（与 EconomyManager 库存键一致）
@export var id: String = "resource"
## 显示名（拾取提示/详情等完整场景）
@export var display_name: String = "资源"
## 短名（建造卡片等紧凑场景）
@export var short_name: String = "资"
## 占位颜色（美术接入后替换为 icon 资源）
@export var icon_color: Color = Color(0.7, 0.7, 0.7, 1)
