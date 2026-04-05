extends Node
class_name BuildingSystem

signal workers_changed
signal building_selected_data(b_data: BuildingData) 
# signal building_upgraded
# signal building_damaged

var active_buildings: Dictionary = {}
var current_selected_grid_pos: Vector2i = Vector2i(-1, -1) 

@export var grid_manager: Node2D 

func _ready() -> void:
    if grid_manager:
        grid_manager.building_placed.connect(_on_building_placed)
        grid_manager.building_removed.connect(_on_building_removed)
        grid_manager.building_selected.connect(_on_building_selected)
        grid_manager.building_deselected.connect(_on_building_deselected) 
    else:
        push_error("BuildingSystem: GridManager is not assigned!")

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
            new_data.base_morale_bonus      = GameConstants.SHELTER_MORALE_AT_CAPACITY_T1
            new_data.power_draw             = GameConstants.SHELTER_POWER_DRAW
            
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
    GameManager.available_workers                  += 1
    GameManager.population_state.available_workers += 1
    
    workers_changed.emit()
    b_data.staffing_changed.emit(b_data.workers_assigned, b_data.worker_capacity) 
    
    print("BuildingSystem: Removed worker from [%s] | %d/%d | Output: %d%% | Pool left: %d" \
        % [b_data.building_name, b_data.workers_assigned, b_data.worker_capacity, int(b_data.staffing_ratio * 100), GameManager.available_workers])

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT QUERY — used by ResourceManager every day tick (Week 6)
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
# DEBUG / TESTING ONLY — remove in Week 6 when real UI is ready
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed:
        return
        
    if event.keycode == KEY_EQUAL:   # '+' key
        assign_worker()
    if event.keycode == KEY_MINUS:   # '-' key
        remove_worker()