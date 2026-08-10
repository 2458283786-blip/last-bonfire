class_name WoodcutterHut
extends JobHut
## 伐木屋（职业转换建筑）：把空闲居民转职为伐木工，提供名额。
## 不产资源，资源生成由伐木场负责。逻辑全部在 JobHut 基类。

func _ready() -> void:
	job_name = "woodcutter"
	super._ready()
