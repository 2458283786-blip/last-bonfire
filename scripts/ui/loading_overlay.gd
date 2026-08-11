extends CanvasLayer
## 读档进度遮罩：跟随 SaveManager 进度信号更新，读档结束自动隐藏。

@onready var progress_bar: ProgressBar = $Center/VBox/ProgressBar
@onready var status_label: Label = $Center/VBox/StatusLabel

func _ready() -> void:
	SaveManager.load_progress.connect(_on_progress)
	SaveManager.load_finished.connect(_on_finished)

func _exit_tree() -> void:
	if SaveManager.load_progress.is_connected(_on_progress):
		SaveManager.load_progress.disconnect(_on_progress)
	if SaveManager.load_finished.is_connected(_on_finished):
		SaveManager.load_finished.disconnect(_on_finished)

func _on_progress(percent: float, label: String) -> void:
	progress_bar.value = percent
	status_label.text = label

func _on_finished(_ok: bool) -> void:
	queue_free()
