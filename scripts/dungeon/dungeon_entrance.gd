extends Interactable
## 城镇地下通道入口：进入地下城（两门二选一流程）。

func _ready() -> void:
	super._ready()
	self_handled = true
	prompt = "按 E 进入地下通道"
	interacted.connect(_on_interacted)

func _on_interacted() -> void:
	DungeonManager.enter_dungeon()
	DungeonManager.start_run()
	GameManager.change_scene(SceneRegistry.DOOR_CHOICE)
