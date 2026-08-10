class_name Bonfire
extends Building
## 篝火：城镇核心建筑、玩家出生/复活点、重建原点。

func _ready() -> void:
	super._ready()
	add_to_group("core_buildings")

func _on_function_offline() -> void:
	EventBus.bonfire_lost.emit()

func _on_function_online() -> void:
	EventBus.bonfire_restored.emit()
