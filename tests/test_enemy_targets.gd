extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var dir := DirAccess.open("res://resources/data/")
	check(dir != null, "资源配置目录应可打开")
	var checked := 0
	if dir != null:
		for file in dir.get_files():
			if not file.begins_with("enemy_") or not file.ends_with(".tres"):
				continue
			var data := load("res://resources/data/" + file) as EnemyData
			if data == null:
				continue
			checked += 1
			for target in data.attack_priority:
				check(Enemy.SUPPORTED_TARGET_TYPES.has(target),
					"%s 的目标类型 %s 应有映射（防拼错静默失效）" % [file, target])
	check(checked >= 2, "应至少校验到夜狼与狼王两份配置")
	check(Enemy.SUPPORTED_TARGET_TYPES.size() == 3, "支持类型表应包含三个基础目标")
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
