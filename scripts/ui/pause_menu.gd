extends PanelContainer
## 暂停菜单：继续/设置/存档/返回标题。

signal resume_requested
signal settings_requested
signal save_requested
signal exit_requested

@onready var resume_button: Button = $VBox/ResumeButton
@onready var settings_button: Button = $VBox/SettingsButton
@onready var save_button: Button = $VBox/SaveButton
@onready var exit_button: Button = $VBox/ExitButton

func _ready() -> void:
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	save_button.pressed.connect(func() -> void: save_requested.emit())
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
