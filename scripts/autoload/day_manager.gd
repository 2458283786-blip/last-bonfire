extends Node
## 游戏天数管理：推进天数，供资源重生/野外生成等系统使用。
## 昼夜阶段：白天 → 黄昏 → 夜晚 → 白天（自动按秒推进）。
## 调试：F9 推进一天，F10 推进一个阶段（避开编辑器的 F5-F8 运行控制快捷键）。

signal day_changed(day: int)
signal phase_changed(phase: int)

enum TimePhase { DAY, DUSK, NIGHT }
const PHASE_COUNT := 3

var day := 1
var phase := TimePhase.DAY
var phase_length_seconds: float = 60.0
var _phase_timer := 0.0

func reset() -> void:
	day = 1
	phase = TimePhase.DAY
	_phase_timer = 0.0

func advance_day() -> void:
	day += 1
	day_changed.emit(day)

func advance_phase() -> void:
	phase = (phase + 1) % PHASE_COUNT
	phase_changed.emit(phase)
	if phase == TimePhase.DAY:
		advance_day()

func _process(delta: float) -> void:
	_phase_timer += delta
	if _phase_timer >= phase_length_seconds:
		_phase_timer = 0.0
		advance_phase()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			advance_day()
			print("[DayManager] 天数推进到第 %d 天" % day)
		elif event.keycode == KEY_F10:
			advance_phase()
			print("[DayManager] 阶段推进到 %s" % TimePhase.keys()[phase])

## ---- 存档支持：快照与静默恢复（不发射信号，避免加载中间态副作用） ----

func phase_elapsed() -> float:
	return _phase_timer

func collect_state() -> Dictionary:
	return {"day": day, "phase": phase, "phase_elapsed": _phase_timer}

func restore_state(data: Dictionary) -> void:
	day = maxi(int(data.get("day", 1)), 1)
	phase = int(data.get("phase", 0)) % PHASE_COUNT
	_phase_timer = maxf(float(data.get("phase_elapsed", 0.0)), 0.0)

func phase_remaining() -> float:
	return maxf(phase_length_seconds - _phase_timer, 0.0)
