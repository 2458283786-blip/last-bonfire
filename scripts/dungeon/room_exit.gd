extends Interactable
## 房间出口：清场后激活，交互后由房间推进流程。

var _active := false

func _ready() -> void:
	super._ready()
	self_handled = true
	prompt = "按 E 离开房间"
	interacted.connect(_on_interacted)
	visible = false

func set_active(active: bool) -> void:
	_active = active
	visible = active

func try_interact(player_pos: Vector2) -> bool:
	if not _active:
		return false
	return super.try_interact(player_pos)

func _on_interacted() -> void:
	var room := get_parent() as DungeonRoom
	if room != null:
		room.on_exit()
