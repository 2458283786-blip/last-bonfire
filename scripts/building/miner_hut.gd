class_name MinerHut
extends JobHut
## 矿工小屋（职业转换建筑）：把空闲居民转职为矿工，提供名额。
## 不产资源，资源生成由采石场负责。逻辑全部在 JobHut 基类。

func _ready() -> void:
	job_name = "miner"
	super._ready()
