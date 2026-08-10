class_name LumberCamp
extends ResourceCamp
## 伐木场（资源生成建筑）：在周围生成固定数量的城内树，供伐木工砍伐。
## 逻辑全部在 ResourceCamp 基类。

func _ready() -> void:
	super._ready()
	add_to_group("lumber_camps")
