extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://save_test_core.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	check(not SaveManager.has_save(), "初始不应有存档")
	check(SaveManager.save_game(), "保存应成功")
	check(SaveManager.has_save(), "保存后应有存档文件")
	var f := FileAccess.open(SaveManager.save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	check(typeof(parsed) == TYPE_DICTIONARY, "存档应为 JSON 字典")
	check(int(parsed.get("version", -1)) == 1, "存档版本应为 1")
	var w := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	w.store_string("{broken")
	w.close()
	check(not await SaveManager.load_game(), "损坏文件读档应失败")
	check(SaveManager.last_error != "", "失败应记录原因")
	DirAccess.remove_absolute(SaveManager.save_path)
	check(not SaveManager.has_save(), "清理后应无存档")
	finish(failures.is_empty())

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
