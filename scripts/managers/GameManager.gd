extends Node

# Signals for UI and systems to respond to global game state changes
# Emitted when the hope/order slider changes
signal hope_order_changed(new_value: float)
# Emitted when a named character dies
signal named_character_died(character_name: String)

# ══════════════════════════════════════════════════════════════════════════════
# CHARACTER METADATA 
# ══════════════════════════════════════════════════════════════════════════════
const CHARACTER_METADATA: Dictionary = {
	"yuna": {"name": "Yuna Tran", "role": "Head Medic", "portrait": "res://assets/characters/Yuna.png"},
	"rook": {"name": "Rook", "role": "Scout", "portrait": "res://assets/characters/Rook.png"},
	"vasquez": {"name": "Harlan Vasquez", "role": "Grid-9 Director", "portrait": "res://assets/characters/Vasquez.png"},
	"meridian": {"name": "MERIDIAN", "role": "AI", "portrait": "res://assets/characters/MERDIAN.png"},
	"kael": {"name": "Kael", "role": "Grid-7 Director", "portrait": "res://assets/characters/Kael.png"}
}

# ═════════════════════════════════════════════════════════════════════════════=
# GLOBAL GAME STATE
# Central primitive game state exposed to systems (population, resources)
# ═════════════════════════════════════════════════════════════════════════════=

# Current total colonist count
var current_population: int = GameConstants.STARTING_POPULATION
# Workers available to assign to buildings
var available_workers: int = GameConstants.STARTING_WORKERS
# Number of currently sick colonists
var sick_count: int = 0
# Current in-game day
var current_day: int = 1
# Global materials stockpile
var materials: int = GameConstants.STARTING_MATERIALS
# Flag used while loading saved game state to suppress ticks
var is_loading_game: bool = false

# Float 0-100. Starts at 50 (Neutral)
var _hope_order_slider: float = 50.0
var hope_order_slider: float:
	get:
		return _hope_order_slider
	set(value):
		var next_value = clampf(value, 0.0, 100.0)
		if is_equal_approx(next_value, _hope_order_slider):
			return
		_hope_order_slider = next_value
		hope_order_changed.emit(_hope_order_slider)

# ═════════════════════════════════════════════════════════════════════════════=
# CHARACTER ALIVE FLAGS (All true on Day 1)
# Simple booleans tracking whether named characters are alive
# ═════════════════════════════════════════════════════════════════════════════=

var yuna_alive: bool = true
var rook_alive: bool = true
var vasquez_alive: bool = true
var meridian_alive: bool = true

# ══════════════════════════════════════════════════════════════════════════════
# NARRATIVE STATE FLAGS (set by CrisisEventSystem as story events resolve)
# ══════════════════════════════════════════════════════════════════════════════

var med_clinic_built: bool = false # Set TRUE by BuildingSystem on placement
var med_clinic_upgraded_to_tier_2: bool = false # Set TRUE by BuildingInspector on upgrade
var rook_militia_stopped: bool = false # Set TRUE by CrisisEventSystem Day 24 Option B
var rook_militia_sanctioned: bool = false # Set TRUE by CrisisEventSystem Day 24 Option A
var rook_reconciliation_taken: bool = false # Set TRUE by CrisisEventSystem reconciliation dialogue
var vasquez_trade_accepted: bool = false # Set TRUE by CrisisEventSystem on Day 11 Option A
var meridian_trusted: bool = false # Set TRUE by CrisisEventSystem Day 21 Option A
var vasquez_intel_shared: bool = false # Set TRUE by CrisisEventSystem Vasquez counter-offer
var deserters_lockdown_taken: bool = false

# ═════════════════════════════════════════════════════════════════════════════=
# MEMORIAL WALL STATE
# Tracks memorial wall placement and recorded named-character deaths
# ═════════════════════════════════════════════════════════════════════════════=

var memorial_wall_built: bool = false # Set TRUE by BuildingSystem when wall placed
var memorial_prompt_consumed: bool = false # Set TRUE after first death prompt shown and wall built
var named_death_days: Dictionary = {} # Maps character id to day of death

# ═════════════════════════════════════════════════════════════════════════════=
# DATA CLASS INSTANCES
# Thin data-holder objects used by managers and UI (pop/resource/colonists)
# ═════════════════════════════════════════════════════════════════════════════=

var population_state: PopulationStateData

var resource_power: ResourceData
var resource_food: ResourceData
var resource_morale: ResourceData
var resource_materials: ResourceData

var colonist_kael: ColonistData
var colonist_yuna: ColonistData
var colonist_rook: ColonistData
var colonist_vasquez: ColonistData
var colonist_meridian: ColonistData

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

# Initialize game state managers and load persisted data.
func _ready() -> void:
	_initialize_data_classes()
	hope_order_slider = GameConstants.SLIDER_STARTING_VALUE
	TimeManager.day_changed.connect(_on_day_changed)

## Reset all game state for a new session
func reset_for_new_game() -> void:
	current_population = GameConstants.STARTING_POPULATION
	available_workers = GameConstants.STARTING_WORKERS
	sick_count = 0
	current_day = 1
	materials = GameConstants.STARTING_MATERIALS

	yuna_alive = true
	rook_alive = true
	vasquez_alive = true
	meridian_alive = true

	med_clinic_built = false
	med_clinic_upgraded_to_tier_2 = false
	rook_militia_stopped = false
	rook_militia_sanctioned = false
	rook_reconciliation_taken = false
	vasquez_trade_accepted = false
	meridian_trusted = false
	vasquez_intel_shared = false
	deserters_lockdown_taken = false

	memorial_wall_built = false
	memorial_prompt_consumed = false
	named_death_days.clear()

	_initialize_data_classes()
	hope_order_slider = GameConstants.SLIDER_STARTING_VALUE

	if population_state:
		population_state.total_population = current_population
		population_state.available_workers = available_workers
		population_state.sick_count = 0
		population_state.max_workers = GameConstants.MAX_WORKERS_LATE_GAME
		population_state.outbreak_active = false
		population_state.disease_resistance_active = false

	if colonist_kael:
		colonist_kael.is_alive = true
		colonist_kael.death_day = -1
		colonist_kael.death_cause = ""
		colonist_kael.memorial_text = ""
	if colonist_yuna:
		colonist_yuna.is_alive = true
		colonist_yuna.death_day = -1
		colonist_yuna.death_cause = ""
		colonist_yuna.memorial_text = ""
	if colonist_rook:
		colonist_rook.is_alive = true
		colonist_rook.death_day = -1
		colonist_rook.death_cause = ""
		colonist_rook.memorial_text = ""
	if colonist_vasquez:
		colonist_vasquez.is_alive = true
		colonist_vasquez.death_day = -1
		colonist_vasquez.death_cause = ""
		colonist_vasquez.memorial_text = ""
	if colonist_meridian:
		colonist_meridian.is_alive = true
		colonist_meridian.death_day = -1
		colonist_meridian.death_cause = ""
		colonist_meridian.memorial_text = ""

## Create and initialize helper data class instances
func _initialize_data_classes() -> void:
	# 1. Population State
	population_state = PopulationStateData.new()
	population_state.total_population = current_population
	population_state.available_workers = available_workers
	population_state.sick_count = sick_count
	population_state.max_workers = GameConstants.MAX_WORKERS_LATE_GAME

	# 2. Resource Data
	resource_power = ResourceData.new()
	resource_power.res_name = "Power"
	resource_power.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_power.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_food = ResourceData.new()
	resource_food.res_name = "Food"
	resource_food.current_value = GameConstants.STARTING_FOOD
	resource_food.max_value = GameConstants.STARTING_FOOD
	resource_food.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_food.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_morale = ResourceData.new()
	resource_morale.res_name = "Morale"
	resource_morale.current_value = GameConstants.STARTING_MORALE
	resource_morale.max_value = 100.0
	resource_morale.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_morale.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_materials = ResourceData.new()
	resource_materials.res_name = "Materials"
	resource_materials.warning_threshold = 0.0
	resource_materials.critical_threshold = 0.0

	# 3. Colonist Data
	colonist_kael = ColonistData.new()
	colonist_kael.character_name = "Kael"
	colonist_kael.role = "Director"
	colonist_kael.is_alive = true

	colonist_yuna = ColonistData.new()
	colonist_yuna.character_name = "Yuna"
	colonist_yuna.role = "Head Medic"
	colonist_yuna.is_alive = yuna_alive

	colonist_rook = ColonistData.new()
	colonist_rook.character_name = "Rook"
	colonist_rook.role = "Scout"
	colonist_rook.is_alive = rook_alive

	colonist_vasquez = ColonistData.new()
	colonist_vasquez.character_name = "Vasquez"
	colonist_vasquez.role = "Grid-9 Director"
	colonist_vasquez.is_alive = vasquez_alive

	colonist_meridian = ColonistData.new()
	colonist_meridian.character_name = "MERIDIAN"
	colonist_meridian.role = "Fragmented AI"
	colonist_meridian.is_alive = meridian_alive

## Apply a delta to the hope/order slider (clamped)
func apply_hope_order_delta(delta: float) -> void:
	hope_order_slider = hope_order_slider + delta

## Set a named character alive/dead and emit death events
func set_character_alive(identifier: String, is_alive: bool) -> void:
	if current_day > 33:
		return # Locks permanently after Day 33
	
	var changed = false
	var lower_id = identifier.to_lower()
	match lower_id:
		"yuna":
			if yuna_alive != is_alive:
				yuna_alive = is_alive
				colonist_yuna.is_alive = is_alive
				changed = true
		"rook":
			if rook_alive != is_alive:
				rook_alive = is_alive
				colonist_rook.is_alive = is_alive
				changed = true
		"vasquez":
			if vasquez_alive != is_alive:
				vasquez_alive = is_alive
				colonist_vasquez.is_alive = is_alive
				changed = true
		"meridian":
			if meridian_alive != is_alive:
				meridian_alive = is_alive
				colonist_meridian.is_alive = is_alive
				changed = true

	if changed and not is_alive:
		named_character_died.emit(lower_id)

## Record a named character's death day and update flags
func record_named_death(identifier: String) -> void:
	if current_day > 33:
		return 
	
	var lower_id = identifier.to_lower()
	
	# Record death day if not already recorded
	if not named_death_days.has(lower_id):
		named_death_days[lower_id] = current_day
	
	# Set alive flag to false
	set_character_alive(lower_id, false)

## Return memorial entries for dead named characters (sorted by day)
func get_memorial_entries() -> Array:
	var entries: Array = []
	
	# Return entries for all dead characters, sorted by day
	for char_id in named_death_days.keys():
		var day = named_death_days[char_id]
		if day > 0:
			var char_info = CHARACTER_METADATA.get(char_id, {"name": char_id.capitalize(), "role": ""})
			entries.append({
				"id": char_id,
				"name": char_info.get("name", ""),
				"role": char_info.get("role", ""),
				"day": day
			})
	
	# Sort by day ascending
	entries.sort_custom(func(a, b): return a.day < b.day)
	return entries

# Handler for TimeManager day changed events
func _on_day_changed(new_day: int) -> void:
	current_day = new_day

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════
const SAVES_DIR = "user://saves/"

func ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)

# Serialise the current game into a save file.
func save_game(filename: String) -> void:
	ensure_saves_dir()
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		main_node = get_tree().root.find_child("Main", true, false)
	if not main_node:
		for child in get_tree().root.get_children():
			if child.has_node("BuildingSystem") and child.has_node("GameWorld/GridSystem"):
				main_node = child
				break

	var building_sys = main_node.get_node_or_null("BuildingSystem") if main_node else null
	var serialized_buildings = []
	if building_sys:
		for pos in building_sys.active_buildings:
			var b_data = building_sys.active_buildings[pos]
			serialized_buildings.append({
				"grid_x": pos.x,
				"grid_y": pos.y,
				"type": b_data.building_type,
				"workers": b_data.workers_assigned,
				"is_upgraded": b_data.is_upgraded,
				"is_damaged": b_data.is_damaged,
				"is_shielded": b_data.is_shielded,
				"is_shielding": b_data.is_shielding,              
				"shield_days_accumulated": b_data.shield_days_accumulated 
			})
	
	var day = TimeManager.current_day if TimeManager else current_day
	var elapsed = TimeManager.time_elapsed if TimeManager else 0.0
	var speed = TimeManager.current_speed if TimeManager else 1
	var power_cap = ResourceManager.power_capacity if ResourceManager else 0.0
	var pd = ResourceManager.power_draw if ResourceManager else 0.0
	var net_pow = ResourceManager.net_power if ResourceManager else 0.0
	var f = ResourceManager.food if ResourceManager else 0.0
	var max_f = ResourceManager.max_food if ResourceManager else 0.0
	var d_s = ResourceManager.days_starving if ResourceManager else 0
	var mat = ResourceManager.materials if ResourceManager else materials
	var mor = ResourceManager.morale if ResourceManager else 100.0
	var ration_buf = ResourceManager.ration_buffer if ResourceManager else 0.0
	var ration_buf_max = ResourceManager.ration_buffer_max if ResourceManager else 0.0
	var ration_exists = ResourceManager.ration_store_exists if ResourceManager else false
	var auto_ration = ResourceManager.auto_rationing_active if ResourceManager else false
	var journal_entries_data: Variant = []
	var journal_node = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
	if journal_node and journal_node.has_method("serialise"):
		journal_entries_data = journal_node.serialise()

	var data = {
		"game_manager": {
			"current_population": current_population,
			"available_workers": available_workers,
			"sick_count": sick_count,
			"hope_order_slider": hope_order_slider,
			"current_day": current_day,
			"materials": materials,
			"yuna_alive": yuna_alive,
			"rook_alive": rook_alive,
			"vasquez_alive": vasquez_alive,
			"meridian_alive": meridian_alive,
			"med_clinic_built": med_clinic_built,
			"med_clinic_upgraded_to_tier_2": med_clinic_upgraded_to_tier_2,
			"rook_militia_stopped": rook_militia_stopped,
			"rook_reconciliation_taken": rook_reconciliation_taken,
			"vasquez_trade_accepted": vasquez_trade_accepted,
			"vasquez_intel_shared": vasquez_intel_shared,
			"deserters_lockdown_taken": deserters_lockdown_taken,
			"meridian_trusted": meridian_trusted,
			"rook_militia_sanctioned": rook_militia_sanctioned,
			"memorial_wall_built": memorial_wall_built,
			"memorial_prompt_consumed": memorial_prompt_consumed,
			"named_death_days": named_death_days
		},
		"time_manager": {
			"current_day": day,
			"time_elapsed": elapsed,
			"current_speed": speed
		},
		"resource_manager": {
			"power_capacity": power_cap,
			"power_draw": pd,
			"net_power": net_pow,
			"food": f,
			"max_food": max_f,
			"days_starving": d_s,
			"materials": mat,
			"morale": mor,
			"ration_buffer": ration_buf,
			"ration_buffer_max": ration_buf_max,
			"ration_store_exists": ration_exists,
			"auto_rationing_active": auto_ration
		},
		"buildings": serialized_buildings,
		"fired_events": CrisisEventSystem.get_fired_events_state() if CrisisEventSystem else {},
		"journal_entries": journal_entries_data,
		"tutorial_shown_flags": TutorialManager.shown_flags if TutorialManager else {},
	}
	
	var file_path = SAVES_DIR + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	else:
		push_error("Failed to open file for writing: ", file_path)

# Load game state from a save file.
func load_game(filepath: String) -> void:
	if not FileAccess.file_exists(filepath):
		return
		
	is_loading_game = true
	var file = FileAccess.open(filepath, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		push_error("Failed to parse JSON file: ", filepath)
		is_loading_game = false
		return
		
	var data = json.get_data()

	# Restore GameManager
	var gm_data = data.get("game_manager", {})
	var saved_hope = gm_data.get("hope_order_slider", hope_order_slider)
	var delta = saved_hope - hope_order_slider
	if not is_equal_approx(delta, 0.0):
		apply_hope_order_delta(delta)
	current_population = gm_data.get("current_population", current_population)
	available_workers = gm_data.get("available_workers", available_workers)
	sick_count = gm_data.get("sick_count", sick_count)
	current_day = gm_data.get("current_day", current_day)
	materials = gm_data.get("materials", materials)
	yuna_alive = gm_data.get("yuna_alive", yuna_alive)
	rook_alive = gm_data.get("rook_alive", rook_alive)
	vasquez_alive = gm_data.get("vasquez_alive", vasquez_alive)
	meridian_alive = gm_data.get("meridian_alive", meridian_alive)
	med_clinic_built = gm_data.get("med_clinic_built", med_clinic_built)
	med_clinic_upgraded_to_tier_2 = gm_data.get("med_clinic_upgraded_to_tier_2", med_clinic_upgraded_to_tier_2)
	rook_militia_stopped = gm_data.get("rook_militia_stopped", rook_militia_stopped)
	rook_reconciliation_taken = gm_data.get("rook_reconciliation_taken", rook_reconciliation_taken)
	vasquez_trade_accepted = gm_data.get("vasquez_trade_accepted", vasquez_trade_accepted)
	vasquez_intel_shared = gm_data.get("vasquez_intel_shared", vasquez_intel_shared)
	deserters_lockdown_taken = gm_data.get("deserters_lockdown_taken", false)
	meridian_trusted = gm_data.get("meridian_trusted", false)
	rook_militia_sanctioned = gm_data.get("rook_militia_sanctioned", false)
	memorial_wall_built = gm_data.get("memorial_wall_built", false)
	memorial_prompt_consumed = gm_data.get("memorial_prompt_consumed", false)
	named_death_days = gm_data.get("named_death_days", {})
	
	if population_state:
		population_state.total_population = current_population
		population_state.available_workers = available_workers
		population_state.sick_count = sick_count
	
	if colonist_yuna: colonist_yuna.is_alive = yuna_alive
	if colonist_rook: colonist_rook.is_alive = rook_alive
	if colonist_vasquez: colonist_vasquez.is_alive = vasquez_alive
	if colonist_meridian: colonist_meridian.is_alive = meridian_alive

	if TutorialManager:
		var tutorial_flags = data.get("tutorial_shown_flags", {})
		TutorialManager.shown_flags = tutorial_flags
		TutorialManager._intro_done = true
		TutorialManager._first_building_placed = \
			not tutorial_flags.get("first_placement", false) == false

	# Restore TimeManager
	var tm_data = data.get("time_manager", {})
	if TimeManager:
		TimeManager.current_day = tm_data.get("current_day", TimeManager.current_day)
		TimeManager.time_elapsed = tm_data.get("time_elapsed", TimeManager.time_elapsed)
		var speed = tm_data.get("current_speed", TimeManager.current_speed)
		# Trigger visual updates without SFX pop internally
		TimeManager.current_speed = speed
		TimeManager.day_changed.emit(TimeManager.current_day)

	# Restore ResourceManager
	var rm_data = data.get("resource_manager", {})
	if ResourceManager:
		ResourceManager.power_capacity = rm_data.get("power_capacity", ResourceManager.power_capacity)
		ResourceManager.power_draw = rm_data.get("power_draw", ResourceManager.power_draw)
		ResourceManager.net_power = rm_data.get("net_power", ResourceManager.net_power)
		ResourceManager.food = rm_data.get("food", ResourceManager.food)
		ResourceManager.max_food = rm_data.get("max_food", ResourceManager.max_food)
		ResourceManager.days_starving = rm_data.get("days_starving", ResourceManager.days_starving)
		ResourceManager.materials = rm_data.get("materials", ResourceManager.materials)
		ResourceManager.morale = rm_data.get("morale", ResourceManager.morale)
		ResourceManager.ration_buffer = rm_data.get("ration_buffer", ResourceManager.ration_buffer)
		ResourceManager.ration_buffer_max = rm_data.get("ration_buffer_max", ResourceManager.ration_buffer_max)
		ResourceManager.ration_store_exists = rm_data.get("ration_store_exists", ResourceManager.ration_store_exists)
		ResourceManager.auto_rationing_active = rm_data.get("auto_rationing_active", ResourceManager.auto_rationing_active)
		ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)

	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		main_node = get_tree().root.find_child("Main", true, false)
	if not main_node:
		for child in get_tree().root.get_children():
			if child.has_node("BuildingSystem") and child.has_node("GameWorld/GridSystem"):
				main_node = child
				break

	var building_sys = null
	var grid_manager = null
	if main_node:
		building_sys = main_node.get_node_or_null("BuildingSystem")
		grid_manager = main_node.get_node_or_null("GameWorld/GridSystem")

	for _i in range(60):
		var building_ready = building_sys and "load_ready" in building_sys and building_sys.load_ready
		var grid_ready = grid_manager and "load_ready" in grid_manager and grid_manager.load_ready
		if building_ready and grid_ready:
			break
		await get_tree().process_frame

	if building_sys and grid_manager:
		# First clear the board natively
		grid_manager.clear_grid()
		building_sys.active_buildings.clear()

		var saved_buildings: Array = data.get("buildings", [])
		var b_arr = data.get("buildings", [])
		for b in b_arr:
			var pos = Vector2i(b.get("grid_x", 0), b.get("grid_y", 0))
			var ty = int(b.get("type", 0))
			
			# Map integer BuildingType to string key if required by spawn function
			var type_map: Dictionary = {
				BuildingData.BuildingType.COAL_GENERATOR:  "coal",
				BuildingData.BuildingType.GEOTHERMAL_TAP:  "geothermal",
				BuildingData.BuildingType.HYDROPONIC_BAY:  "hydro",
				BuildingData.BuildingType.RATION_STORE:    "ration",
				BuildingData.BuildingType.WATER_RECYCLER:  "water",
				BuildingData.BuildingType.MED_CLINIC:      "med",
				BuildingData.BuildingType.SHELTER_BLOCK:   "shelter",
				BuildingData.BuildingType.ARCHIVE_HALL:    "archive",
				BuildingData.BuildingType.MEMORIAL_WALL:   "memorial",
			}
			var b_type_str: String = type_map.get(ty, "")
			if b_type_str == "":
				push_warning("GameManager.load_game: unknown building type %d, skipping" % ty)
				continue

			# Safely spawn it physically and then rewrite the visual configuration.
			grid_manager.spawn_building_from_save(b_type_str, pos)

			# If the placement signal fired before BuildingSystem connected, rebuild the
			# data entry directly so load restores the colony state deterministically.
			if not building_sys.active_buildings.has(pos):
				building_sys._on_building_placed(b_type_str, pos)
			
			if building_sys.active_buildings.has(pos):
				var b_data = building_sys.active_buildings[pos]
				b_data.workers_assigned = b.get("workers", 0)
				b_data.is_upgraded = b.get("is_upgraded", false)
				b_data.is_damaged = b.get("is_damaged", false)
				b_data.is_shielded = b.get("is_shielded", false)
				b_data.is_shielding = b.get("is_shielding", false)                       
				b_data.shield_days_accumulated = b.get("shield_days_accumulated", 0)      
				
				if b_data.is_damaged:
					building_sys.set_building_damaged(pos, true)
				# Refresh visuals after load
				# Re-apply any upgrade-side effects that are normally applied at runtime
				if b_data.is_upgraded:
					match b_data.building_type:
						BuildingData.BuildingType.COAL_GENERATOR:
							b_data.base_production_power = GameConstants.COAL_POWER_T2
						BuildingData.BuildingType.GEOTHERMAL_TAP:
							b_data.base_production_power = GameConstants.GEOTHERMAL_POWER_T2
						BuildingData.BuildingType.HYDROPONIC_BAY:
							b_data.base_production_food = GameConstants.UPGRADED_FOOD_RATE
						BuildingData.BuildingType.RATION_STORE:
							if ResourceManager:
								ResourceManager.on_ration_store_built(true)
						_:
							pass
				# Refresh visuals after load
				building_sys.update_building_visual(pos)

		await get_tree().process_frame

		# Reconcile once more after the scene tree has had a frame to finish
		# delivering the building_placed signal and any deferred _ready work.
		for b in saved_buildings:
			var pos := Vector2i(b.get("grid_x", 0), b.get("grid_y", 0))
			var ty := int(b.get("type", 0))
			var type_map: Dictionary = {
				BuildingData.BuildingType.COAL_GENERATOR:  "coal",
				BuildingData.BuildingType.GEOTHERMAL_TAP:  "geothermal",
				BuildingData.BuildingType.HYDROPONIC_BAY:  "hydro",
				BuildingData.BuildingType.RATION_STORE:    "ration",
				BuildingData.BuildingType.WATER_RECYCLER:  "water",
				BuildingData.BuildingType.MED_CLINIC:      "med",
				BuildingData.BuildingType.SHELTER_BLOCK:   "shelter",
				BuildingData.BuildingType.ARCHIVE_HALL:    "archive",
				BuildingData.BuildingType.MEMORIAL_WALL:   "memorial",
			}
			var b_type_str: String = type_map.get(ty, "")
			if b_type_str == "":
				continue

			var b_data: BuildingData = building_sys.active_buildings.get(pos, null)
			if b_data == null:
				b_data = BuildingData.new()
				b_data.grid_position = pos
				match b_type_str:
					"coal":
						b_data.building_type = BuildingData.BuildingType.COAL_GENERATOR
						b_data.building_name = "Coal Generator"
						b_data.worker_capacity = GameConstants.COAL_GENERATOR_SLOTS
						b_data.base_production_power = GameConstants.COAL_POWER_T1
					"geothermal":
						b_data.building_type = BuildingData.BuildingType.GEOTHERMAL_TAP
						b_data.building_name = "Geothermal Tap"
						b_data.worker_capacity = GameConstants.GEOTHERMAL_WORKER_SLOTS
						b_data.base_production_power = GameConstants.GEOTHERMAL_POWER_T1
					"hydro":
						b_data.building_type = BuildingData.BuildingType.HYDROPONIC_BAY
						b_data.building_name = "Hydroponic Bay"
						b_data.worker_capacity = GameConstants.HYDROPONIC_BAY_SLOTS
						b_data.base_production_food = GameConstants.BASE_FOOD_RATE
					"ration":
						b_data.building_type = BuildingData.BuildingType.RATION_STORE
						b_data.building_name = "Ration Store"
						b_data.worker_capacity = GameConstants.RATION_STORE_SLOTS
						b_data.power_draw = GameConstants.RATION_STORE_POWER_DRAW
					"water":
						b_data.building_type = BuildingData.BuildingType.WATER_RECYCLER
						b_data.building_name = "Water Recycler"
						b_data.worker_capacity = GameConstants.WATER_RECYCLER_SLOTS
						b_data.power_draw = GameConstants.WATER_RECYCLER_POWER_DRAW
					"med":
						b_data.building_type = BuildingData.BuildingType.MED_CLINIC
						b_data.building_name = "Med Clinic"
						b_data.worker_capacity = GameConstants.MED_CLINIC_SLOTS
						b_data.power_draw = GameConstants.MED_CLINIC_POWER_DRAW
					"shelter":
						b_data.building_type = BuildingData.BuildingType.SHELTER_BLOCK
						b_data.building_name = "Shelter Block"
						b_data.worker_capacity = GameConstants.SHELTER_BLOCK_SLOTS
						b_data.power_draw = GameConstants.SHELTER_POWER_DRAW
					"archive":
						b_data.building_type = BuildingData.BuildingType.ARCHIVE_HALL
						b_data.building_name = "Archive Hall"
						b_data.worker_capacity = GameConstants.ARCHIVE_HALL_SLOTS
						b_data.power_draw = GameConstants.ARCHIVE_HALL_POWER_DRAW
					"memorial":
						b_data.building_type = BuildingData.BuildingType.MEMORIAL_WALL
						b_data.building_name = "Memorial Wall"
						b_data.worker_capacity = 0
						b_data.power_draw = 0.0
					_:
						pass
				building_sys.active_buildings[pos] = b_data
				b_data.footprint_size = grid_manager.BUILDING_FOOTPRINTS.get(b_type_str, Vector2i(1, 1))

			b_data.workers_assigned = b.get("workers", 0)
			b_data.is_upgraded = b.get("is_upgraded", false)
			b_data.is_damaged = b.get("is_damaged", false)
			b_data.is_shielded = b.get("is_shielded", false)
			b_data.is_shielding = b.get("is_shielding", false)
			b_data.shield_days_accumulated = b.get("shield_days_accumulated", 0)
			if b_data.is_upgraded:
				match b_data.building_type:
					BuildingData.BuildingType.COAL_GENERATOR:
						b_data.base_production_power = GameConstants.COAL_POWER_T2
					BuildingData.BuildingType.GEOTHERMAL_TAP:
						b_data.base_production_power = GameConstants.GEOTHERMAL_POWER_T2
					BuildingData.BuildingType.HYDROPONIC_BAY:
						b_data.base_production_food = GameConstants.UPGRADED_FOOD_RATE
					BuildingData.BuildingType.RATION_STORE:
						if ResourceManager:
							ResourceManager.on_ration_store_built(true)
					_:
						pass
			building_sys.update_building_visual(pos)

		# Reconcile ration store capacity with saved values and upgrade state
		if ResourceManager:
			var saved_buffer: float = float(rm_data.get("ration_buffer", ResourceManager.ration_buffer))
			var saved_max: float = float(rm_data.get("ration_buffer_max", ResourceManager.ration_buffer_max))
			var has_store: bool = building_sys.has_building(BuildingData.BuildingType.RATION_STORE)
			var is_upgraded: bool = building_sys.is_building_upgraded(BuildingData.BuildingType.RATION_STORE)
			ResourceManager.restore_ration_store_from_save(saved_buffer, saved_max, has_store, is_upgraded)

	# Restore journal entries after world state is fully restored
	var journal_node = null
	if main_node:
		journal_node = main_node.get_node_or_null("UILayer/ColonyJournal")
	if journal_node == null:
		journal_node = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
	var journal_data: Variant = data.get("journal_entries", [])
	if journal_node and journal_node.has_method("deserialise"):
		journal_node.deserialise(journal_data)

	# Restore crisis event fired-state so events don't re-fire after load
	var fired_state = data.get("fired_events", {})
	if typeof(fired_state) == TYPE_DICTIONARY and CrisisEventSystem:
		CrisisEventSystem.set_fired_events_state(fired_state)
	
	is_loading_game = false
