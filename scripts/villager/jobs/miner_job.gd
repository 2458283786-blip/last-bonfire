class_name MinerJob
extends HarvestJob
## 矿工职业策略：寻找未被预留且职业匹配的石头并挖掘。
## 逻辑全部在 HarvestJob 基类。

func _init() -> void:
	job_name = "miner"
