extends Control

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const FIRE_EVENT_SAVE_NAME := "test_runner_fired_events.json"
const UPGRADE_SAVE_NAME := "test_runner_upgrade_restore.json"

var _log_label
var _failure_messages = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_log("Playthrough test runner starting...")
	await get_tree().process_frame
	await get_tree().process_frame

	await _run_check("autoload availability", _check_autoloads)
	await _run_check("fired-event persistence", _check_fired_event_persistence)
	await _run_check("upgrade restore on load", _check_upgrade_restore)

	if _failure_messages.is_empty():
		_log("All playthrough checks passed.")
		get_tree().quit(0)
	else:
		_log("Playthrough checks failed:")
		for message in _failure_messages:
			_log("- %s" % message)
		get_tree().quit(1)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Playthrough Test Runner"
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Runs automated checks for save/load and upgrade restoration."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	_log_label = RichTextLabel.new()
	_log_label.fit_content = true
	_log_label.scroll_active = true
	_log_label.scroll_following = true
	_log_label.custom_minimum_size = Vector2(0, 320)
	_log_label.bbcode_enabled = false
	vbox.add_child(_log_label)

func _log(message: String) -> void:
	print("[TEST] %s" % message)
	if _log_label:
		_log_label.append_text(message + "\n")

func _fail(message: String) -> void:
	_failure_messages.append(message)
	_log("FAIL: %s" % message)

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _run_check(check_name: String, check_method: Callable) -> void:
	_log("Running check: %s" % check_name)
	var result = await check_method.call()
	if bool(result):
		_log("PASS: %s" % check_name)
	else:
		_fail("%s did not pass" % check_name)

func _check_autoloads() -> bool:
	var ok := true
	ok = _expect(GameManager != null, "GameManager autoload missing") and ok
	ok = _expect(CrisisEventSystem != null, "CrisisEventSystem autoload missing") and ok
	ok = _expect(TimeManager != null, "TimeManager autoload missing") and ok
	return ok

func _check_fired_event_persistence() -> bool:
	if not _expect(GameManager != null and CrisisEventSystem != null, "Required autoloads are unavailable"):
		return false

	GameManager.ensure_saves_dir()
	var save_path := "user://saves/%s" % FIRE_EVENT_SAVE_NAME
	var expected_key := "__runner_event_persistence__"

	CrisisEventSystem.set_fired_events_state({expected_key: true})
	GameManager.save_game(FIRE_EVENT_SAVE_NAME)

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not _expect(file != null, "Could not open fired-event save file for reading"):
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not _expect(typeof(parsed) == TYPE_DICTIONARY, "Saved JSON was invalid"):
		return false

	var fired_events = parsed.get("fired_events", {})
	if not _expect(typeof(fired_events) == TYPE_DICTIONARY, "Saved file did not contain a fired_events dictionary"):
		return false
	if not _expect(fired_events.has(expected_key), "Saved fired_events dictionary did not contain the expected key"):
		return false

	CrisisEventSystem.set_fired_events_state({})
	await GameManager.load_game(save_path)

	var restored_state = CrisisEventSystem.get_fired_events_state()
	if not _expect(typeof(restored_state) == TYPE_DICTIONARY, "Restored fired-event state was not a dictionary"):
		_cleanup_temp_file(save_path)
		return false
	if not _expect(restored_state.has(expected_key), "Load did not restore the expected fired-event key"):
		_cleanup_temp_file(save_path)
		return false

	_cleanup_temp_file(save_path)
	return true

func _check_upgrade_restore() -> bool:
	if not _expect(GameManager != null, "GameManager autoload missing"):
		return false

	var main_scene := load(MAIN_SCENE_PATH)
	if not _expect(main_scene != null, "Could not load Main scene"):
		return false

	var main_instance = main_scene.instantiate()
	main_instance.name = "Main"
	add_child(main_instance)

	if not await _wait_for_main_ready():
		main_instance.queue_free()
		return false

	GameManager.ensure_saves_dir()
	var save_path := "user://saves/%s" % UPGRADE_SAVE_NAME
	var load_target := {
		"game_manager": {
			"current_population": GameManager.current_population,
			"available_workers": GameManager.available_workers,
			"sick_count": GameManager.sick_count,
			"hope_order_slider": GameManager.hope_order_slider,
			"current_day": GameManager.current_day,
			"materials": GameManager.materials,
			"yuna_alive": GameManager.yuna_alive,
			"rook_alive": GameManager.rook_alive,
			"vasquez_alive": GameManager.vasquez_alive,
			"meridian_alive": GameManager.meridian_alive,
			"med_clinic_built": GameManager.med_clinic_built,
			"med_clinic_upgraded_to_tier_2": GameManager.med_clinic_upgraded_to_tier_2,
			"rook_militia_stopped": GameManager.rook_militia_stopped,
			"rook_reconciliation_taken": GameManager.rook_reconciliation_taken,
			"vasquez_trade_accepted": GameManager.vasquez_trade_accepted,
			"vasquez_intel_shared": GameManager.vasquez_intel_shared,
			"deserters_lockdown_taken": GameManager.deserters_lockdown_taken,
			"meridian_trusted": GameManager.meridian_trusted,
			"rook_militia_sanctioned": GameManager.rook_militia_sanctioned,
			"memorial_wall_built": GameManager.memorial_wall_built,
			"memorial_prompt_consumed": GameManager.memorial_prompt_consumed,
			"named_death_days": {}
		},
		"time_manager": {
			"current_day": 1,
			"time_elapsed": 0.0,
			"current_speed": 1
		},
		"resource_manager": {
			"power_capacity": 0.0,
			"power_draw": 0.0,
			"net_power": 0.0,
			"food": 0.0,
			"max_food": 0.0,
			"days_starving": 0,
			"materials": 0,
			"morale": 50.0,
			"ration_buffer": 0.0,
			"ration_buffer_max": 0.0,
			"ration_store_exists": false,
			"auto_rationing_active": false
		},
		"buildings": [
			{
				"grid_x": 0,
				"grid_y": 0,
				"type": BuildingData.BuildingType.COAL_GENERATOR,
				"workers": 1,
				"is_upgraded": true,
				"is_damaged": false,
				"is_shielded": false,
				"is_shielding": false,
				"shield_days_accumulated": 0
			}
		],
		"fired_events": {},
		"journal_entries": [],
		"tutorial_shown_flags": {}
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not _expect(file != null, "Could not create upgrade restore save file"):
		main_instance.queue_free()
		return false
	file.store_string(JSON.stringify(load_target))
	file.close()

	await GameManager.load_game(save_path)
	var loaded_building_system = main_instance.get_node_or_null("BuildingSystem")
	if loaded_building_system:
		_log("Loaded building keys: %s" % str(loaded_building_system.active_buildings.keys()))
		_log("Loaded building count: %d" % loaded_building_system.active_buildings.size())
	if not await _wait_for_loaded_building(main_instance, Vector2i(0, 0)):
		_cleanup_temp_file(save_path)
		main_instance.queue_free()
		return false

	var building_system = main_instance.get_node_or_null("BuildingSystem")
	if not _expect(building_system != null, "BuildingSystem was not available after load"):
		main_instance.queue_free()
		return false

	var grid_pos := Vector2i(0, 0)
	if not _expect(building_system.active_buildings.has(grid_pos), "Loaded upgrade test building was not restored"):
		main_instance.queue_free()
		return false

	var building_data: BuildingData = building_system.active_buildings[grid_pos]
	if not _expect(building_data.is_upgraded, "Loaded building did not keep its upgraded flag"):
		_cleanup_temp_file(save_path)
		main_instance.queue_free()
		return false
	if not _expect(is_equal_approx(building_data.base_production_power, GameConstants.COAL_POWER_T2), "Loaded coal generator did not restore T2 production"):
		_cleanup_temp_file(save_path)
		main_instance.queue_free()
		return false

	_cleanup_temp_file(save_path)
	main_instance.queue_free()
	return true

func _wait_for_main_ready() -> bool:
	for _i in range(30):
		var main_node = get_node_or_null("Main")
		var building_system = main_node.get_node_or_null("BuildingSystem") if main_node else null
		var grid_system = main_node.get_node_or_null("GameWorld/GridSystem") if main_node else null
		if main_node and building_system and grid_system and ResourceManager and PopulationManager and ResourceManager.building_system == building_system and PopulationManager.building_system == building_system:
			return true
		await get_tree().process_frame
	return false

func _wait_for_loaded_building(main_instance: Node, grid_pos: Vector2i) -> bool:
	for _i in range(60):
		var building_system = main_instance.get_node_or_null("BuildingSystem")
		if building_system and building_system.active_buildings.has(grid_pos):
			_log("Loaded building present at %s after %d frames" % [str(grid_pos), _i])
			return true
		await get_tree().process_frame
	_log("Loaded building never appeared at %s" % str(grid_pos))
	return false

func _cleanup_temp_file(save_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(global_path)



# Filler to force reparse
func _test_noop() -> void:
	# noop
	pass


