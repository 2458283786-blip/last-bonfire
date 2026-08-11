extends CanvasLayer
## 两门选择：清房后左右两门二选一（类小骨）；阶段末不经过这里（直接 BOSS 门）。

@onready var left_button: Button = $UI/Buttons/LeftButton
@onready var right_button: Button = $UI/Buttons/RightButton
@onready var stage_label: Label = $UI/StageLabel
@onready var time_label: Label = $UI/TimeLabel
@onready var abandon_button: Button = $UI/AbandonButton

func _ready() -> void:
	if DungeonManager.run == null or DungeonManager.run.pending_choice.is_empty():
		DungeonManager.make_choice()
	_refresh()
	left_button.pressed.connect(_on_door_pressed.bind(0))
	right_button.pressed.connect(_on_door_pressed.bind(1))
	abandon_button.pressed.connect(_on_abandon_pressed)

func _process(_delta: float) -> void:
	time_label.text = "距天黑 %d 秒" % int(ceilf(DungeonManager.remaining_to_night))

func _refresh() -> void:
	if DungeonManager.run == null:
		return
	stage_label.text = "第 %d 阶段 · 选择下一房间" % DungeonManager.run.current_stage
	var choice: Array = DungeonManager.run.pending_choice
	if choice.size() >= 1:
		left_button.text = "左门：%s" % choice[0].display_name
	if choice.size() >= 2:
		right_button.text = "右门：%s" % choice[1].display_name

func _on_door_pressed(index: int) -> void:
	var node := DungeonManager.choose_node(index)
	if node != null and node.room_scene != null:
		GameManager.change_scene(node.room_scene.resource_path)

func _on_abandon_pressed() -> void:
	DungeonManager.finish_run_to_town()
	GameManager.change_scene(DungeonManager.TOWN_SCENE)
