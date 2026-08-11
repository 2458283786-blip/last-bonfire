extends CanvasLayer
## 地下城 HUD：天黑倒计时 + 状态提示（P11 探索-城防张力）。

@onready var time_label: Label = $VBox/TimeLabel
@onready var status_label: Label = $VBox/StatusLabel

func _process(_delta: float) -> void:
	if DungeonManager.night_forced:
		time_label.text = "城镇已入夜！"
		status_label.text = "怪物正在袭击城镇，尽快撤离！"
	else:
		time_label.text = "距天黑 %d 秒" % int(ceilf(DungeonManager.remaining_to_night))
		status_label.text = "小心：探索越久，城镇越危险"
