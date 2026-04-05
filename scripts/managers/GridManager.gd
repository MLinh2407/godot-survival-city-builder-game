extends Node2D

signal building_placed(type: String, grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)

const GRID_BOUNDS_MIN = Vector2i(-5, -5)
const GRID_BOUNDS_MAX = Vector2i(5, 5)

# Maps Vector2i grid coordinates to the instantiated Node representing the building
var occupied_cells: Dictionary = {}

@onready var base_grid: TileMapLayer = $BaseGrid
@onready var cursor: Sprite2D = $PlacementCursor
@onready var ghost_sprite: Sprite2D = $GhostSprite

# NEW: The container where building scenes will be spawned (must have Y-sort enabled)
@export var building_container: Node2D 

# NEW: Assign your 3 test building PackedScenes in the Inspector here
@export var building_scenes: Dictionary = {}

var current_build_type: String = ""
var current_build_scene: PackedScene = null

func _ready() -> void:
    cursor.visible = false # Hide until a building is selected

# Called by UI (or our debug inputs) to start placing a specific building
func enter_build_mode(b_type: String) -> void:
    if building_scenes.has(b_type):
        current_build_type = b_type
        current_build_scene = building_scenes[b_type]
        cursor.visible = true

        # Temporarily instantiate the scene to steal its visual data
        var temp_building = current_build_scene.instantiate()
        
        var b_sprite = temp_building.get_node_or_null("Sprite2D")
        if b_sprite:
            ghost_sprite.texture = b_sprite.texture
            ghost_sprite.offset = b_sprite.offset
            ghost_sprite.visible = true
            
        # Delete the temporary building from memory instantly
        temp_building.queue_free()

func exit_build_mode() -> void:
    current_build_type = ""
    current_build_scene = null
    cursor.visible = false
    cursor.modulate = Color.WHITE

    ghost_sprite.visible = false
    ghost_sprite.texture = null

func _process(_delta: float) -> void:
    # Only run placement logic if we are actively holding a building
    if not cursor.visible: return

    var local_mouse = get_local_mouse_position()
    var map_pos = base_grid.local_to_map(local_mouse)
    cursor.position = base_grid.map_to_local(map_pos)

    ghost_sprite.position = cursor.position
    
    # Valid/Invalid zone highlight (green/red)
    if is_valid_placement(map_pos):
        var valid_color = Color(0.2, 3.0, 0.2, 0.5) 
        cursor.modulate = valid_color
        ghost_sprite.modulate = valid_color
    else:
        var invalid_color = Color(3.0, 0.2, 0.2, 0.5) 
        cursor.modulate = invalid_color
        ghost_sprite.modulate = invalid_color 

func is_valid_placement(cell: Vector2i) -> bool:
    if cell.x < GRID_BOUNDS_MIN.x or cell.x > GRID_BOUNDS_MAX.x or cell.y < GRID_BOUNDS_MIN.y or cell.y > GRID_BOUNDS_MAX.y:
        return false
    if occupied_cells.has(cell):
        return false
    return true

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var map_pos = base_grid.local_to_map(get_local_mouse_position())
        
        # LEFT CLICK: Place Building
        if event.button_index == MOUSE_BUTTON_LEFT and current_build_scene != null:
            if is_valid_placement(map_pos):
                place_building(map_pos)
                
        # RIGHT CLICK: Remove Building or Cancel Placement
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if occupied_cells.has(map_pos):
                remove_building(map_pos)
            else:
                # If clicking empty space, cancel the current build mode
                exit_build_mode()

    # DEBUG: Temporary keys to test the "3 different buildings" requirement
    if event is InputEventKey and event.pressed:
        var keys = building_scenes.keys()
        if event.keycode == KEY_1 and keys.size() > 0: enter_build_mode(keys[0])
        if event.keycode == KEY_2 and keys.size() > 1: enter_build_mode(keys[1])
        if event.keycode == KEY_3 and keys.size() > 2: enter_build_mode(keys[2])

func place_building(map_pos: Vector2i) -> void:
    # Instantiate the scene
    var new_building = current_build_scene.instantiate()
    
    # Add to the Y-sorted container
    building_container.add_child(new_building)
    
    # Convert map coordinates to local pixel coordinates
    new_building.position = base_grid.map_to_local(map_pos)
    
    # Store the node reference so we can easily delete it later
    occupied_cells[map_pos] = new_building
    building_placed.emit(current_build_type, map_pos)
    print("GridManager: Placed ", current_build_type, " at ", map_pos)

func remove_building(map_pos: Vector2i) -> void:
    # Grab the node reference
    var building = occupied_cells[map_pos]
    
    # Destroy the scene
    building.queue_free()
    
    # Free up the tile
    occupied_cells.erase(map_pos)
    building_removed.emit(map_pos)
    print("GridManager: Removed at ", map_pos)