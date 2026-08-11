extends Node2D
## 测试运行器：按顺序在游戏模式下运行全部测试，退出码 0/1。
## 用法：godot --headless --path . res://tests/run_all.tscn
## 可选：--only test_name 只跑单个测试。

const TEST_SCRIPTS := [
	"res://tests/test_input_map.gd",
	"res://tests/test_player_movement.gd",
	"res://tests/test_player_jump.gd",
	"res://tests/test_player_animations.gd",
	"res://tests/test_player_attack.gd",
	"res://tests/test_player_bow.gd",
	"res://tests/test_town_scene.gd",
	"res://tests/test_dungeon_template.gd",
	"res://tests/test_day_manager.gd",
	"res://tests/test_economy_manager.gd",
	"res://tests/test_resource_node.gd",
	"res://tests/test_pickup.gd",
	"res://tests/test_villager_work_cycle.gd",
	"res://tests/test_buildings.gd",
	"res://tests/test_wild_spawner.gd",
	"res://tests/test_wild_spawner_visual.gd",
	"res://tests/test_villager_passes_player.gd",
	"res://tests/test_villager_deposit_idle.gd",
	"res://tests/test_villager_idle_wanders.gd",
	"res://tests/test_villager_auto_convert.gd",
	"res://tests/test_villager_job_filter.gd",
	"res://tests/test_villager_carry_capacity.gd",
	"res://tests/test_villager_stuck_wall.gd",
	"res://tests/test_woodcutter_hut_release.gd",
	"res://tests/test_job_hut_destruction.gd",
	"res://tests/test_storage_capacity.gd",
	"res://tests/test_camp_destruction.gd",
	"res://tests/test_miner_job.gd",
	"res://tests/test_miner_hut.gd",
	"res://tests/test_quarry.gd",
	"res://tests/test_enemy.gd",
	"res://tests/test_enemy_ai.gd",
	"res://tests/test_player_hp.gd",
	"res://tests/test_player_respawn.gd",
	"res://tests/test_building.gd",
	"res://tests/test_villager_injury.gd",
	"res://tests/test_player_combat_enemy.gd",
	"res://tests/test_night_wave.gd",
	"res://tests/test_building_data.gd",
	"res://tests/test_town_registry.gd",
	"res://tests/test_top_bar.gd",
	"res://tests/test_build_menu.gd",
	"res://tests/test_placement.gd",
	"res://tests/test_building_panel.gd",
	"res://tests/test_toast_queue.gd",
	"res://tests/test_interact_hint.gd",
	"res://tests/test_night_overlay.gd",
	"res://tests/test_villager_panel.gd",
	"res://tests/test_pause_menu.gd",
	"res://tests/test_build_flow.gd",
	"res://tests/test_save_manager_core.gd",
	"res://tests/test_save_global.gd",
	"res://tests/test_save_buildings.gd",
	"res://tests/test_save_destroyed_buildings.gd",
	"res://tests/test_save_resources.gd",
	"res://tests/test_save_villagers.gd",
	"res://tests/test_save_miner.gd",
	"res://tests/test_save_flow.gd",
	"res://tests/test_building_upgrade.gd",
	"res://tests/test_housing.gd",
	"res://tests/test_threat_retreat.gd",
	"res://tests/test_villager_speed_variance.gd",
	"res://tests/test_debug_manager.gd",
	"res://tests/test_defense.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_shop.gd",
	"res://tests/test_recruit.gd",
	"res://tests/test_dungeon_time.gd",
	"res://tests/test_wave_formula.gd",
	"res://tests/test_save_progress.gd",
	"res://tests/test_wave_spawn_position.gd",
	"res://tests/test_resource_database.gd",
	"res://tests/test_physics_layers.gd",
	"res://tests/test_scene_paths.gd",
	"res://tests/test_job_registry.gd",
	"res://tests/test_enemy_targets.gd",
	"res://tests/test_save_migration.gd",
	"res://tests/test_save_roundtrip.gd",
	"res://tests/test_game_config.gd",
	"res://tests/test_dungeon_map.gd",
	"res://tests/test_dungeon_rooms.gd",
	"res://tests/test_dungeon_flow.gd",
	"res://tests/test_unlocks.gd",
	"res://tests/test_save_dungeon.gd",
]
const INPUT_ACTIONS := ["move_left", "move_right", "jump", "attack", "bow"]

var _only := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	_run_all()

func _run_all() -> void:
	var code := 0
	for path in TEST_SCRIPTS:
		var script_name: String = path.get_file().get_basename()
		if _only != "" and script_name != _only:
			continue
		for action in INPUT_ACTIONS:
			Input.action_release(action)
		print("=== 运行测试: ", script_name)
		var script_res: Resource = load(path)
		var gd_script := script_res as GDScript
		if gd_script == null or not gd_script.can_instantiate():
			push_error("[FAIL] 无法加载或编译测试脚本: " + path)
			code = 1
			continue
		var test: Node = gd_script.new()
		test.name = script_name
		add_child(test)
		var ok: bool = await test.finished
		if not ok:
			code = 1
		test.queue_free()
		# 清理本测试遗留到当前场景的节点（存档恢复/招募等直接挂 current_scene 的），避免跨测试污染。
		for leftover in get_children():
			if leftover != test:
				leftover.queue_free()
		await get_tree().process_frame
	if code == 0:
		print("[PASS] 全部测试通过")
	else:
		push_error("[FAIL] 存在失败的测试")
	get_tree().quit(code)
