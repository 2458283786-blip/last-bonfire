extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	check(EconomyManager.get_amount("wood") == 10, "开局应有 10 木材")
	check(EconomyManager.get_amount("stone") == 5, "开局应有 5 石头")
	EconomyManager.withdraw("stone", 5)
	var accepted := EconomyManager.deposit("wood", 30)
	check(accepted == 10, "容量 20（已用 10）时再入 30 只应接受 10")
	check(EconomyManager.get_amount("wood") == 20, "库存应封顶 20")
	check(EconomyManager.withdraw("wood", 5), "应有足够木材可取")
	check(EconomyManager.get_amount("wood") == 15, "取出后应剩 15")
	check(not EconomyManager.withdraw("stone", 99), "不足时应取款失败")
	EconomyManager.set_capacity(100)
	check(EconomyManager.capacity == 100, "set_capacity 应生效")
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
