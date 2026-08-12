class_name DungeonRoom
extends Node2D
## 房间基类：从 DungeonManager 当前节点读取数据，清场后激活出口。
## 子类实现 _populate / is_cleared；出口交互后 on_exit() 推进流程。

var node: DungeonNodeData = null
var _exit_node: Node = null

func _ready() -> void:
	node = DungeonManager.current_node()
	_exit_node = get_node_or_null("Exit")
	if node != null:
		_populate(node)

func _populate(_node: DungeonNodeData) -> void:
	pass

func is_cleared() -> bool:
	return true

func _process(_delta: float) -> void:
	if node != null and not is_cleared():
		return
	_set_exit_active(true)

## 房间场景独立加载，需要自行处理 interact 输入（城镇 HUD 不在场），否则清场后无法交互出口/囚笼
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for node in get_tree().get_nodes_in_group("interactables"):
		var ia := node as Interactable
		if ia != null and ia.try_interact(players[0].global_position):
			return

func _set_exit_active(active: bool) -> void:
	if _exit_node != null and _exit_node.has_method("set_active"):
		_exit_node.set_active(active)

## 出口交互：普通房 → 二选一；BOSS 房 → 阶段推进或通关回城。
func on_exit() -> void:
	if node != null and node.type == "boss":
		DungeonManager.stage_boss_cleared()
		if DungeonManager.is_run_completed():
			DungeonManager.finish_run_to_town()
			GameManager.change_scene(DungeonManager.TOWN_SCENE)
		else:
			DungeonManager.make_choice()
			GameManager.change_scene(SceneRegistry.DOOR_CHOICE)
		return
	DungeonManager.room_cleared()
	if DungeonManager.should_enter_boss():
		var boss := DungeonManager.enter_boss_room()
		if boss != null and boss.room_scene != null:
			GameManager.change_scene(boss.room_scene.resource_path)
	else:
		DungeonManager.make_choice()
		GameManager.change_scene(SceneRegistry.DOOR_CHOICE)
