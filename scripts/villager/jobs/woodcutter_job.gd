class_name WoodcutterJob
extends HarvestJob
## 伐木工职业策略：寻找未被预留且职业匹配的树并砍伐。
## 逻辑全部在 HarvestJob 基类。

func _init() -> void:
	job_name = "woodcutter"
