extends Node

# ══════════════════════════════════════════════════════════════════════════════
# GLOBAL GAME STATE
# ══════════════════════════════════════════════════════════════════════════════

var current_population: int = GameConstants.STARTING_POPULATION
var available_workers: int = GameConstants.STARTING_WORKERS
var sick_count: int = 0
var current_day: int = 1
var materials: int = GameConstants.STARTING_MATERIALS

# Float 0-100. Starts at 50 (Neutral)
var hope_order_slider: float = 50.0 

# ══════════════════════════════════════════════════════════════════════════════
# CHARACTER ALIVE FLAGS (All true on Day 1)
# ══════════════════════════════════════════════════════════════════════════════

var yuna_alive: bool = true
var rook_alive: bool = true
var vasquez_alive: bool = true
var meridian_alive: bool = true

# ══════════════════════════════════════════════════════════════════════════════
# NARRATIVE STATE FLAGS (set by CrisisEventSystem as story events resolve)
# ══════════════════════════════════════════════════════════════════════════════

var med_clinic_built: bool = false           # Set TRUE by BuildingSystem on placement
var rook_militia_stopped: bool = false       # Set TRUE by CrisisEventSystem Day 24 Option B
var rook_reconciliation_taken: bool = false  # Set TRUE by CrisisEventSystem reconciliation dialogue
var vasquez_trade_accepted: bool = false     # Set TRUE by CrisisEventSystem on Day 11 Option A

# ══════════════════════════════════════════════════════════════════════════════
# DATA CLASS INSTANCES
# ══════════════════════════════════════════════════════════════════════════════

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

func _ready() -> void:
	_initialize_data_classes()
	
	print("--- GameManager Initialized ---")
	print("Current Population: ", current_population)
	print("Available Workers: ", available_workers)
	print("Sick Count: ", sick_count)
	print("Hope/Order Slider: ", hope_order_slider)
	print("Alive Flags - Yuna: ", yuna_alive, " | Rook: ", rook_alive, " | Vasquez: ", vasquez_alive, " | Meridian: ", meridian_alive)
	print("Current Day: ", current_day)
	print("-------------------------------")

func _initialize_data_classes() -> void:
	# 1. Initialize Population State Data
	population_state = PopulationStateData.new()
	population_state.total_population = current_population
	population_state.available_workers = available_workers
	population_state.sick_count = sick_count
	population_state.max_workers = GameConstants.MAX_WORKERS_LATE_GAME 

	# 2. Initialize Resource Data Instances
	resource_power = ResourceData.new()
	resource_power.res_name = "Power"
	resource_power.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_power.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_food = ResourceData.new()
	resource_food.res_name = "Food"
	resource_food.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_food.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_morale = ResourceData.new()
	resource_morale.res_name = "Morale"
	resource_morale.warning_threshold = GameConstants.WARNING_THRESHOLD
	resource_morale.critical_threshold = GameConstants.CRITICAL_THRESHOLD

	resource_materials = ResourceData.new()
	resource_materials.res_name = "Materials"
	resource_materials.warning_threshold = 0.0 
	resource_materials.critical_threshold = 0.0

	# 3. Initialize Colonist Data Instances (with roles added back in)
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

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════
const SAVES_DIR = "user://saves/"

func ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)

func save_game(filename: String) -> void:
	ensure_saves_dir()
	
	var building_sys = get_tree().root.get_node_or_null("Main/BuildingSystem")
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
				"is_shielded": b_data.is_shielded
			})
	
	# Try to safely find TimeManager and ResourceManager (they are Autoloads, so this is safe)
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
			"rook_militia_stopped": rook_militia_stopped,
			"rook_reconciliation_taken": rook_reconciliation_taken,
			"vasquez_trade_accepted": vasquez_trade_accepted
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
			"morale": mor
		},
		"buildings": serialized_buildings
	}
	
	var file_path = SAVES_DIR + filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("Game saved successfully to: ", file_path)
	else:
		push_error("Failed to open file for writing: ", file_path)

func load_game(filepath: String) -> void:
	if not FileAccess.file_exists(filepath):
		print("Save file not found at: ", filepath)
		return
		
	var file = FileAccess.open(filepath, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		push_error("Failed to parse JSON file: ", filepath)
		return
		
	var data = json.get_data()

	# Restore GameManager
	var gm_data = data.get("game_manager", {})
	current_population = gm_data.get("current_population", current_population)
	available_workers = gm_data.get("available_workers", available_workers)
	sick_count = gm_data.get("sick_count", sick_count)
	hope_order_slider = gm_data.get("hope_order_slider", hope_order_slider)
	current_day = gm_data.get("current_day", current_day)
	materials = gm_data.get("materials", materials)
	yuna_alive = gm_data.get("yuna_alive", yuna_alive)
	rook_alive = gm_data.get("rook_alive", rook_alive)
	vasquez_alive = gm_data.get("vasquez_alive", vasquez_alive)
	meridian_alive = gm_data.get("meridian_alive", meridian_alive)
	med_clinic_built = gm_data.get("med_clinic_built", med_clinic_built)
	rook_militia_stopped = gm_data.get("rook_militia_stopped", rook_militia_stopped)
	rook_reconciliation_taken = gm_data.get("rook_reconciliation_taken", rook_reconciliation_taken)
	vasquez_trade_accepted = gm_data.get("vasquez_trade_accepted", vasquez_trade_accepted)

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
		ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)

	# Restore Buildings
	var building_sys = get_tree().root.get_node_or_null("Main/BuildingSystem")
	var grid_manager = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
	if building_sys and grid_manager:
		# First clear the board natively
		grid_manager.clear_grid()
		building_sys.active_buildings.clear()

		var b_arr = data.get("buildings", [])
		for b in b_arr:
			var pos = Vector2i(b.get("grid_x", 0), b.get("grid_y", 0))
			var ty = b.get("type", 0)
			
			# Map integer BuildingType to string key if required by spawn function
			var b_type_str = ""
			if ty == BuildingData.BuildingType.COAL_GENERATOR: b_type_str = "coal"
			elif ty == BuildingData.BuildingType.HYDROPONIC_BAY: b_type_str = "hydro"
			elif ty == BuildingData.BuildingType.SHELTER_BLOCK: b_type_str = "shelter"
			else:
				# Future mapping fallback
				b_type_str = "coal"

			# Safely spawn it physically and then rewrite the visual configuration.
			grid_manager.spawn_building_from_save(b_type_str, pos)
			
			if building_sys.active_buildings.has(pos):
				var b_data = building_sys.active_buildings[pos]
				b_data.workers_assigned = b.get("workers", 0)
				b_data.is_upgraded = b.get("is_upgraded", false)
				b_data.is_damaged = b.get("is_damaged", false)
				b_data.is_shielded = b.get("is_shielded", false)
				
				if b_data.is_damaged:
					building_sys.set_building_damaged(pos, true)
	
	print("Game loaded successfully from: ", filepath)
