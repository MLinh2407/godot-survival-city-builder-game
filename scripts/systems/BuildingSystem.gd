extends Node
class_name BuildingSystem

signal workers_changed
# signal building_upgraded
# signal building_damaged

# Dictionary mapping Vector2i (grid position) to BuildingData
var active_buildings: Dictionary = {}

# We need to listen to the GridManager's signals
@export var grid_manager: Node2D 

func _ready() -> void:
    if grid_manager:
        # Connect the signals we created in GridManager earlier
        grid_manager.building_placed.connect(_on_building_placed)
        grid_manager.building_removed.connect(_on_building_removed)
    else:
        push_error("BuildingSystem: GridManager is not assigned!")

# Triggered when GridManager emits 'building_placed'
func _on_building_placed(b_type: String, grid_pos: Vector2i) -> void:
    var new_data: BuildingData = BuildingData.new()
    new_data.grid_position = grid_pos
    
    # Temporary Week 5 setup: configure data based on string type
    # (In Week 6, we will pull exact stats from GameConstants instead of hardcoding)
    if b_type == "coal":
        new_data.building_type = BuildingData.BuildingType.COAL_GENERATOR
        new_data.worker_capacity = 6
    elif b_type == "hydro":
        new_data.building_type = BuildingData.BuildingType.HYDROPONIC_BAY
        new_data.worker_capacity = 10
    elif b_type == "shelter":
        new_data.building_type = BuildingData.BuildingType.SHELTER_BLOCK
        new_data.worker_capacity = 0 # Passive building, no workers needed
        
    active_buildings[grid_pos] = new_data
    print("BuildingSystem: Registered data for ", b_type, " at ", grid_pos)

# Triggered when GridManager emits 'building_removed'
func _on_building_removed(grid_pos: Vector2i) -> void:
    if active_buildings.has(grid_pos):
        var b_data = active_buildings[grid_pos]
        
        # If workers were assigned, return them to the pool before destroying
        if b_data.workers_assigned > 0:
            GameManager.available_workers += b_data.workers_assigned
            
        active_buildings.erase(grid_pos)
        print("BuildingSystem: Removed data at ", grid_pos)
        workers_changed.emit()

# Called by UI +/- buttons to assign a worker
func assign_worker(grid_pos: Vector2i) -> void:
    if not active_buildings.has(grid_pos): return
    var b_data = active_buildings[grid_pos]
    
    # Check if building has empty slots AND we have free workers in GameManager
    if b_data.workers_assigned < b_data.worker_capacity and GameManager.available_workers > 0:
        b_data.workers_assigned += 1
        GameManager.available_workers -= 1
        workers_changed.emit()
        print("Worker assigned. Staffing ratio: ", b_data.staffing_ratio)

# Called by UI +/- buttons to remove a worker
func remove_worker(grid_pos: Vector2i) -> void:
    if not active_buildings.has(grid_pos): return
    var b_data = active_buildings[grid_pos]
    
    if b_data.workers_assigned > 0:
        b_data.workers_assigned -= 1
        GameManager.available_workers += 1
        workers_changed.emit()
        print("Worker removed. Staffing ratio: ", b_data.staffing_ratio)