extends Node
class_name BuildingSystem

signal workers_changed
# signal building_upgraded
# signal building_damaged

# Dictionary mapping Vector2i (grid position) to BuildingData
var active_buildings: Dictionary = {}

const T1_SPRITES = {
	BuildingData.BuildingType.COAL_GENERATOR: preload("res://assets/buildings/T1_Buildings/Coal_Generator_T1.png"),
	BuildingData.BuildingType.HYDROPONIC_BAY: preload("res://assets/buildings/T1_Buildings/Hydroponic_Bay_T1.png"),
	BuildingData.BuildingType.SHELTER_BLOCK: preload("res://assets/buildings/T1_Buildings/Shelter_Block_T1.png"),
	BuildingData.BuildingType.GEOTHERMAL_TAP: preload("res://assets/buildings/T1_Buildings/Geothermal_Tap_T1.png"),
	BuildingData.BuildingType.RATION_STORE: preload("res://assets/buildings/T1_Buildings/Ration_Store_T1.png"),
	BuildingData.BuildingType.WATER_RECYCLER: preload("res://assets/buildings/T1_Buildings/Water_Recycler_T1.png"),
	BuildingData.BuildingType.MED_CLINIC: preload("res://assets/buildings/T1_Buildings/Med_Clinic_T1.png"),
	BuildingData.BuildingType.ARCHIVE_HALL: preload("res://assets/buildings/T1_Buildings/Archive_Hall_T1.png"),
	BuildingData.BuildingType.MEMORIAL_WALL: preload("res://assets/buildings/T1_Buildings/Memorial_Wall.png")
}

const DAMAGED_SPRITES = {
	BuildingData.BuildingType.COAL_GENERATOR: preload("res://assets/buildings/Damaged_Buildings/Coal_Generator_Damaged.png"),
	BuildingData.BuildingType.HYDROPONIC_BAY: preload("res://assets/buildings/Damaged_Buildings/Hydroponic_Bay_Damaged.png"),
	BuildingData.BuildingType.SHELTER_BLOCK: preload("res://assets/buildings/Damaged_Buildings/Shelter_Block_Damaged.png"),
	BuildingData.BuildingType.GEOTHERMAL_TAP: preload("res://assets/buildings/Damaged_Buildings/Geothermal_Tap_Damaged.png"),
	BuildingData.BuildingType.RATION_STORE: preload("res://assets/buildings/Damaged_Buildings/Ration_Store_Damaged.png"),
	BuildingData.BuildingType.WATER_RECYCLER: preload("res://assets/buildings/Damaged_Buildings/Water_Recycler_Damaged.png"),
	BuildingData.BuildingType.MED_CLINIC: preload("res://assets/buildings/Damaged_Buildings/Med_Clinic_Damaged.png"),
	BuildingData.BuildingType.ARCHIVE_HALL: preload("res://assets/buildings/Damaged_Buildings/Archive_Hall_Damaged.png")
}


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

# Call this to change the damaged state of a building and swap its sprite
func set_building_damaged(grid_pos: Vector2i, is_damaged: bool) -> void:
    if not active_buildings.has(grid_pos): return
    var b_data = active_buildings[grid_pos]
    b_data.is_damaged = is_damaged
    
    if not grid_manager: return
    if not grid_manager.occupied_cells.has(grid_pos): return
    
    var building_node = grid_manager.occupied_cells[grid_pos]
    var sprite = building_node.get_node_or_null("Sprite2D")
    if sprite:
        if is_damaged:
            if DAMAGED_SPRITES.has(b_data.building_type):
                sprite.texture = DAMAGED_SPRITES[b_data.building_type]
            else:
                print("BuildingSystem: No damaged sprite available for ", b_data.building_type)
        else:
            if b_data.is_upgraded:
                pass # Later, swap to T2 sprite instead
            elif T1_SPRITES.has(b_data.building_type):
                sprite.texture = T1_SPRITES[b_data.building_type]
    
    print("BuildingSystem: Changed damaged state to ", is_damaged, " at ", grid_pos)