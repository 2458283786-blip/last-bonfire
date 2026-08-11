extends Interactable
## 地下城出口：交互返回城镇（撤离决策点）。

func _ready() -> void:
	super._ready()
	prompt = "按 E 返回城镇"
	interacted.connect(_on_interacted)

func _on_interacted() -> void:
	DungeonManager.exit_dungeon()
	GameManager.change_scene(DungeonManager.TOWN_SCENE)
