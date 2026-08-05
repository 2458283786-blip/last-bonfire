extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_input_map.gd",
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var code := 0
	var godot_exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	for script_path in TEST_SCRIPTS:
		var output: Array = []
		var args := PackedStringArray(["--headless", "--path", project_dir, "--script", script_path])
		var exit_code := OS.execute(godot_exe, args, output, true)
		if exit_code != 0:
			print("=== FAIL: ", script_path)
			for line in output:
				print(line)
			code = 1
		else:
			print("[PASS] ", script_path)
	if code == 0:
		print("[PASS] 全部测试通过")
	else:
		push_error("[FAIL] 存在失败的测试")
	quit(code)
