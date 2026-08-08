extends VBoxContainer
## 左上角通知队列：最多 MAX_VISIBLE 条，按秒自动消失。

const MAX_VISIBLE := 4
const TOAST_SECONDS := 3.0

func push(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void: _remove(label))
	_trim()

func _trim() -> void:
	while get_child_count() > MAX_VISIBLE:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()

func _remove(label: Label) -> void:
	if is_instance_valid(label) and label.get_parent() == self:
		label.queue_free()
