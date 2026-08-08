extends Control
## 夜晚预警：黄昏/夜晚压暗画面 + 顶部横幅提示；白天显示夜晚结算。

const DIM_ALPHA := {0: 0.0, 1: 0.08, 2: 0.18}
const BANNER_TEXT := {1: "夜晚将至，怪物即将来袭", 2: "夜晚来临，怪物来袭"}

@onready var dim: ColorRect = $Dim
@onready var banner: Label = $Banner

var _banner_timer := 0.0
var _night_seen := false

func _ready() -> void:
	DayManager.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(DayManager.phase)

func _on_phase_changed(phase: int) -> void:
	dim.color.a = DIM_ALPHA.get(phase, 0.0)
	if phase == DayManager.TimePhase.DAY:
		banner.visible = false
		if _night_seen:
			_show_banner("夜晚过去，损坏建筑 %d 处" % _destroyed_count(), 3.0)
			_night_seen = false
	else:
		if phase == DayManager.TimePhase.NIGHT:
			_night_seen = true
		_show_banner(BANNER_TEXT.get(phase, ""), 3.0)

func _show_banner(text: String, seconds: float) -> void:
	banner.text = text
	banner.visible = not text.is_empty()
	_banner_timer = seconds if not text.is_empty() else 0.0

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			banner.visible = false

func _destroyed_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Building
		if b != null and b.is_destroyed:
			count += 1
	return count
