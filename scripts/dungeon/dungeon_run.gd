class_name DungeonRun
extends RefCounted
## 地下城一局运行态：阶段/房间计数/二选一候选/救援数/解锁结果。
## 生成规则见 docs/design/2026-08-11-dungeon-node-map-design.md（v0.2）。

const TYPE_NAMES := {
	"combat": "战斗房",
	"elite": "精英房",
	"chest": "宝箱房",
	"rescue": "救援房",
	"boss": "BOSS 房",
}
const ROOM_SCENES := {
	"combat": "res://scenes/dungeon/rooms/combat_room.tscn",
	"elite": "res://scenes/dungeon/rooms/elite_room.tscn",
	"chest": "res://scenes/dungeon/rooms/chest_room.tscn",
	"rescue": "res://scenes/dungeon/rooms/rescue_room.tscn",
	"boss": "res://scenes/dungeon/rooms/boss_room.tscn",
}

## 阶段总数（默认 3）
var stages := 3
## 每阶段普通房间数（之后强制进 BOSS 房）
var rooms_per_stage := 3
## 每局救援房上限（不保底，仅概率出现）
var max_rescues_per_run := 2
## 救援房权重（0-1，其余按 战斗:精英:宝箱 = 6:1.5:1.5 折算）
var rescue_weight := 0.10

var seed := 0
var current_stage := 1
var rooms_cleared_in_stage := 0
var pending_choice: Array[DungeonNodeData] = []
var rescued_villagers := 0
var shop_unlocked := false
var completed := false

var _rng := RandomNumberGenerator.new()
var _rescue_rooms_used := 0

func begin(p_seed: int) -> void:
	seed = p_seed
	_rng.seed = p_seed
	current_stage = 1
	rooms_cleared_in_stage = 0
	rescued_villagers = 0
	shop_unlocked = false
	completed = false
	_rescue_rooms_used = 0
	pending_choice.clear()

## 生成下一组"两门二选一"候选（同一组内类型不重复）。
func make_choice() -> void:
	pending_choice.clear()
	while pending_choice.size() < 2:
		var type := _roll_type()
		if not pending_choice.any(func(n: DungeonNodeData) -> bool: return n.type == type):
			pending_choice.append(_make_node(type))

## 阶段 BOSS 节点（阶段末强制，不参与二选一）。
func make_boss_node() -> DungeonNodeData:
	return _make_node("boss")

func _roll_type() -> String:
	var rescue_available := _rescue_rooms_used < max_rescues_per_run
	var roll := _rng.randf()
	if rescue_available and roll < rescue_weight:
		_rescue_rooms_used += 1
		return "rescue"
	var rescue_part := rescue_weight if rescue_available else 0.0
	var rest := 1.0 - rescue_part
	if rest <= 0.0:
		return "combat"
	var r := (roll - rescue_part) / rest
	if r < 0.15 / rest:
		return "elite"
	if r < 0.30 / rest:
		return "chest"
	return "combat"

func _make_node(type: String) -> DungeonNodeData:
	var node := DungeonNodeData.new()
	node.id = "%s_%d" % [type, _rng.randi()]
	node.type = type
	node.display_name = TYPE_NAMES.get(type, type)
	node.room_scene = load(ROOM_SCENES.get(type, ROOM_SCENES["combat"])) as PackedScene
	match type:
		"combat":
			node.enemy_ids = ["night_wolf", "night_wolf"]
		"elite":
			node.enemy_ids = ["night_wolf", "night_wolf", "night_wolf"]
		"chest":
			node.loot = [
				{"resource_id": "gold", "min": 2, "max": 4},
				{"resource_id": "monster_material", "min": 1, "max": 2},
			]
		"rescue":
			node.enemy_ids = ["night_wolf", "night_wolf"]
		"boss":
			node.enemy_ids = ["boss_wolf"]
	return node
