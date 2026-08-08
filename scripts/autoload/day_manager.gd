extends Node
## 游戏天数管理：推进天数，供资源重生/野外生成等系统使用。
## 调试：按 F7 推进一天。

signal day_changed(day: int)

var day := 1

func reset() -> void:
	day = 1

func advance_day() -> void:
	day += 1
	day_changed.emit(day)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		advance_day()
		print("[DayManager] 天数推进到第 %d 天" % day)
