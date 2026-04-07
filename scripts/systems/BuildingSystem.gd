extends Node
class_name BuildingSystem

signal workers_changed
signal building_selected_data(b_data: BuildingData) 
# signal building_upgraded
# signal building_damaged

var active_buildings: Dictionary = {}
var current_selected_grid_pos: Vector2i = Vector2i(-1, -1) 

@export var grid_manager: Node2D 

var floating_text_scene = preload("res://scenes/UI/FloatingText.tscn")

func _ready() -> void:
	if grid_manager:
		grid_manager.building_placed.connect(_on_building_placed)
		grid_manager.building_removed.connect(_on_building_removed)
		grid_manager.building_selected.connect(_on_building_selected)
		grid_manager.building_deselected.connect(_on_building_deselected)
	else:
		push_error("BuildingSystem: GridManager is not assigned!")

	# Wait one frame so all Autoloads are fully ready before registering
	await get_tree().process_frame
	ResourceManager.register_building_system(self)
	PopulationManager.register_building_system(self)
	TimeManager.day_changed.connect(_on_day_changed)


# ══════════════════════════════════════════════════════════════════════════════
# DAILY TICK — tracks unstaffed days for damage and Water Recycler disease
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(_day: int) -> void:
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]

		# Only track unstaffed days for buildings that require workers
		if b.worker_capacity == 0:
			continue

		if b.workers_assigned == 0:
			b.days_unstaffed += 1

			# Water Recycler: trigger disease after DISEASE_WATER_DELAY consecutive unstaffed days
			if b.building_type == BuildingData.BuildingType.WATER_RECYCLER:
				if b.days_unstaffed >= GameConstants.DISEASE_WATER_DELAY:
					PopulationManager.trigger_outbreak()
					b.days_unstaffed = 0   # Reset so it doesn't fire every day

			# Building damage: any building at 0 workers for BUILDING_DAMAGE_DAYS
			if b.days_unstaffed >= GameConstants.BUILDING_DAMAGE_DAYS and not b.is_damaged:
				b.is_damaged = true
				print("BuildingSystem: [%s] has become damaged from neglect." % b.building_name)
		else:
			b.days_unstaffed = 0   # Reset counter when staffed

# ══════════════════════════════════════════════════════════════════════════════
# SELECTION
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_selected(grid_pos: Vector2i) -> void:
	if not active_buildings.has(grid_pos):
		return
		
	current_selected_grid_pos = grid_pos
	var b: BuildingData = active_buildings[grid_pos]
	building_selected_data.emit(b)
	
	print("BuildingSystem: Selected [%s] | Workers: %d/%d | Output: %d%%" \
		% [b.building_name, b.workers_assigned, b.worker_capacity, int(b.staffing_ratio * 100)])

func _on_building_deselected() -> void:
	current_selected_grid_pos = Vector2i(-1, -1)
	building_selected_data.emit(null) # Tells the UI to hide itself

# ══════════════════════════════════════════════════════════════════════════════
# PLACEMENT & REMOVAL
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_placed(b_type: String, grid_pos: Vector2i) -> void:
	var new_data: BuildingData = BuildingData.new()
	new_data.grid_position = grid_pos
	
	match b_type:
		"coal":
			new_data.building_type          = BuildingData.BuildingType.COAL_GENERATOR
			new_data.building_name          = "Coal Generator"
			new_data.worker_capacity        = GameConstants.COAL_GENERATOR_SLOTS
			new_data.base_production_power  = GameConstants.COAL_POWER_T1
			new_data.power_draw             = 0.0
		"hydro":
			new_data.building_type          = BuildingData.BuildingType.HYDROPONIC_BAY
			new_data.building_name          = "Hydroponic Bay"
			new_data.worker_capacity        = GameConstants.HYDROPONIC_BAY_SLOTS
			new_data.base_production_food   = GameConstants.BASE_FOOD_RATE
			new_data.power_draw             = GameConstants.HYDROPONIC_POWER_DRAW
		"shelter":
			new_data.building_type          = BuildingData.BuildingType.SHELTER_BLOCK
			new_data.building_name          = "Shelter Block"
			new_data.worker_capacity        = GameConstants.SHELTER_BLOCK_SLOTS
			new_data.base_morale_bonus      = 0.0   # Shelter morale is capacity-dependent, handled in ResourceManager
			new_data.power_draw             = GameConstants.SHELTER_POWER_DRAW
		"geothermal":
			new_data.building_type         = BuildingData.BuildingType.GEOTHERMAL_TAP
			new_data.building_name         = "Geothermal Tap"
			new_data.category              = BuildingData.BuildingCategory.POWER
			new_data.worker_capacity       = GameConstants.GEOTHERMAL_WORKER_SLOTS  # 0
			new_data.base_production_power = GameConstants.GEOTHERMAL_POWER_T1
			new_data.power_draw            = 0.0

		"relay":
			new_data.building_type   = BuildingData.BuildingType.RELAY_HUB
			new_data.building_name   = "Relay Hub"
			new_data.category        = BuildingData.BuildingCategory.POWER
			new_data.worker_capacity = GameConstants.RELAY_HUB_SLOTS
			new_data.power_draw      = GameConstants.RELAY_HUB_POWER_DRAW

		"ration":
			new_data.building_type   = BuildingData.BuildingType.RATION_STORE
			new_data.building_name   = "Ration Store"
			new_data.category        = BuildingData.BuildingCategory.SURVIVAL
			new_data.worker_capacity = GameConstants.RATION_STORE_SLOTS  # 0
			new_data.power_draw      = GameConstants.RATION_STORE_POWER_DRAW

		"water":
			new_data.building_type   = BuildingData.BuildingType.WATER_RECYCLER
			new_data.building_name   = "Water Recycler"
			new_data.category        = BuildingData.BuildingCategory.SURVIVAL
			new_data.worker_capacity = GameConstants.WATER_RECYCLER_SLOTS
			new_data.power_draw      = GameConstants.WATER_RECYCLER_POWER_DRAW

		"med":
			new_data.building_type     = BuildingData.BuildingType.MED_CLINIC
			new_data.building_name     = "Med Clinic"
			new_data.category          = BuildingData.BuildingCategory.SURVIVAL
			new_data.worker_capacity   = GameConstants.MED_CLINIC_SLOTS
			new_data.power_draw        = GameConstants.MED_CLINIC_POWER_DRAW
			new_data.base_morale_bonus = GameConstants.MED_CLINIC_MORALE_PASSIVE
			GameManager.med_clinic_built = true  # Narrative flag — Yuna death check needs this

		"archive":
			new_data.building_type         = BuildingData.BuildingType.ARCHIVE_HALL
			new_data.building_name         = "Archive Hall"
			new_data.category              = BuildingData.BuildingCategory.SOCIAL
			new_data.is_unique             = true
			new_data.worker_capacity       = GameConstants.ARCHIVE_HALL_SLOTS
			new_data.power_draw            = GameConstants.ARCHIVE_HALL_POWER_DRAW
			new_data.base_passive_morale   = GameConstants.ARCHIVE_HALL_MORALE_PASSIVE

		"memorial":
			new_data.building_type         = BuildingData.BuildingType.MEMORIAL_WALL
			new_data.building_name         = "Memorial Wall"
			new_data.category              = BuildingData.BuildingCategory.SOCIAL
			new_data.is_unique             = true
			new_data.worker_capacity       = 0
			new_data.power_draw            = 0.0
			new_data.base_passive_morale   = GameConstants.MEMORIAL_WALL_MORALE_DAILY
			
	active_buildings[grid_pos] = new_data
	print("BuildingSystem: Registered [%s] at %s | Slots: %d | Base power: %.1f | Base food: %.1f" \
		% [new_data.building_name, grid_pos, new_data.worker_capacity, new_data.base_production_power, new_data.base_production_food])

func _on_building_removed(grid_pos: Vector2i) -> void:
	if not active_buildings.has(grid_pos):
		return
		
	var b_data: BuildingData = active_buildings[grid_pos]
	
	if b_data.workers_assigned > 0:
		GameManager.available_workers                  += b_data.workers_assigned
		GameManager.population_state.available_workers += b_data.workers_assigned
		workers_changed.emit()
		print("BuildingSystem: Returned %d workers from demolished [%s]" \
			% [b_data.workers_assigned, b_data.building_name])
			
	active_buildings.erase(grid_pos)
	
	if current_selected_grid_pos == grid_pos:
		_on_building_deselected() # Safely clear selection

# ══════════════════════════════════════════════════════════════════════════════
# WORKER ASSIGNMENT
# ══════════════════════════════════════════════════════════════════════════════
func assign_worker() -> void:
	if not active_buildings.has(current_selected_grid_pos):
		return
		
	var b_data: BuildingData = active_buildings[current_selected_grid_pos]
	
	if b_data.workers_assigned >= b_data.worker_capacity:
		print("BuildingSystem: [%s] is fully staffed." % b_data.building_name)
		return
		
	if GameManager.available_workers <= 0:
		print("BuildingSystem: No available workers in pool.")
		return
		
	b_data.workers_assigned                        += 1
	spawn_floating_text(current_selected_grid_pos, "+1 Worker", Color.GREEN)
	GameManager.available_workers                  -= 1
	GameManager.population_state.available_workers -= 1
	
	workers_changed.emit()
	b_data.staffing_changed.emit(b_data.workers_assigned, b_data.worker_capacity) 
	
	print("BuildingSystem: Assigned worker to [%s] | %d/%d | Output: %d%% | Pool left: %d" \
		% [b_data.building_name, b_data.workers_assigned, b_data.worker_capacity, int(b_data.staffing_ratio * 100), GameManager.available_workers])

func remove_worker() -> void:
	if not active_buildings.has(current_selected_grid_pos):
		return
		
	var b_data: BuildingData = active_buildings[current_selected_grid_pos]
	
	if b_data.workers_assigned <= 0:
		print("BuildingSystem: [%s] has no workers to remove." % b_data.building_name)
		return
		
	b_data.workers_assigned                        -= 1
	spawn_floating_text(current_selected_grid_pos, "-1 Worker", Color.RED)
	GameManager.available_workers                  += 1
	GameManager.population_state.available_workers += 1
	
	workers_changed.emit()
	b_data.staffing_changed.emit(b_data.workers_assigned, b_data.worker_capacity) 
	
	print("BuildingSystem: Removed worker from [%s] | %d/%d | Output: %d%% | Pool left: %d" \
		% [b_data.building_name, b_data.workers_assigned, b_data.worker_capacity, int(b_data.staffing_ratio * 100), GameManager.available_workers])

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT QUERY 
# ══════════════════════════════════════════════════════════════════════════════
func get_effective_output(grid_pos: Vector2i) -> Dictionary:
	if not active_buildings.has(grid_pos):
		return {}
		
	var b: BuildingData = active_buildings[grid_pos]
	var result = {
		"power": 0.0,
		"food": 0.0,
		"morale": 0.0
	}
	
	# Base efficiency from staffing
	var efficiency: float = b.staffing_ratio
	
	# Apply GDD Penalties
	if b.is_damaged:
		efficiency *= GameConstants.BUILDING_DAMAGE_OUTPUT
		
	if GameManager.resource_morale.current_value < GameConstants.MORALE_EFFICIENCY_THRESHOLD:
		efficiency *= GameConstants.MORALE_EFFICIENCY_MULTIPLIER
		
	# Buildings must have power (or be a power producer themselves) to operate
	if b.is_powered or b.base_production_power > 0:
		result.power  = b.base_production_power * efficiency
		result.food   = b.base_production_food * efficiency
		result.morale = b.base_morale_bonus * efficiency
		
	return result

func get_all_outputs() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for grid_pos in active_buildings.keys():
		var output := get_effective_output(grid_pos)
		output["grid_pos"] = grid_pos 
		results.append(output)
	return results

# ══════════════════════════════════════════════════════════════════════════════
# QUERY HELPERS — called by ResourceManager and PopulationManager
# ══════════════════════════════════════════════════════════════════════════════

# Returns total housing capacity across all Shelter Blocks
func get_total_shelter_capacity() -> int:
	var total: int = 0
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]
		if b.building_type == BuildingData.BuildingType.SHELTER_BLOCK:
			total += GameConstants.SHELTER_CAPACITY_T2 if b.is_upgraded else GameConstants.SHELTER_CAPACITY_T1
	return total

# Returns 0.0–1.0 staffing ratio of the Med Clinic (0 if none built or unpowered)
func get_med_clinic_staffing_ratio() -> float:
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]
		if b.building_type == BuildingData.BuildingType.MED_CLINIC:
			if b.is_powered and b.worker_capacity > 0:
				return b.staffing_ratio
	return 0.0

# Returns true if at least one Water Recycler has workers assigned and is powered
func is_water_recycler_staffed() -> bool:
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]
		if b.building_type == BuildingData.BuildingType.WATER_RECYCLER:
			if b.workers_assigned > 0 and b.is_powered:
				return true
	return false

# ══════════════════════════════════════════════════════════════════════════════
# VISUAL EFFECTS (FCT)
# ══════════════════════════════════════════════════════════════════════════════
func spawn_floating_text(grid_pos: Vector2i, text: String, color: Color) -> void:
	if floating_text_scene == null or grid_manager == null: return
	
	var fct = floating_text_scene.instantiate()
	
	grid_manager.add_child(fct)
	fct.position = grid_manager.base_grid.map_to_local(grid_pos)
	fct.setup(text, color)

# ══════════════════════════════════════════════════════════════════════════════
# DEBUG / TESTING ONLY — remove in Week 6 when real UI is ready
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	if event.keycode == KEY_EQUAL:   # '+' key
		assign_worker()
	if event.keycode == KEY_MINUS:   # '-' key
		remove_worker()
