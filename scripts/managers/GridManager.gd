extends Node2D

signal building_placed(type: String, grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)

const SOURCE_ID = 3
const TILE_COORDS = Vector2i(0, 0)

const GRID_BOUNDS_MIN = Vector2i(-5, -5)
const GRID_BOUNDS_MAX = Vector2i(5, 5)

var occupied_cells: Dictionary = {}

# We now grab references to our specific child nodes
@onready var base_grid: TileMapLayer = $BaseGrid
@onready var cursor: Sprite2D = $PlacementCursor

func _process(_delta: float) -> void:
	var local_mouse = get_local_mouse_position()
	
	# Ask the base_grid to calculate the map coordinates
	var map_pos = base_grid.local_to_map(local_mouse)
	
	# Ask the base_grid to calculate the pixel position for the cursor
	cursor.position = base_grid.map_to_local(map_pos)
	
	if is_valid_placement(map_pos):
		cursor.modulate = Color(0.2, 3.0, 0.2, 0.5) 
	else:
		cursor.modulate = Color(3.0, 0.2, 0.2, 0.5) 

func is_valid_placement(cell: Vector2i) -> bool:
	if cell.x < GRID_BOUNDS_MIN.x or cell.x > GRID_BOUNDS_MAX.x or cell.y < GRID_BOUNDS_MIN.y or cell.y > GRID_BOUNDS_MAX.y:
		return false
	if occupied_cells.has(cell):
		return false
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var map_pos = base_grid.local_to_map(get_local_mouse_position())
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_valid_placement(map_pos):
				occupied_cells[map_pos] = true
				
				# Tell the base_grid to draw the tile
				base_grid.set_cell(map_pos, SOURCE_ID, TILE_COORDS) 
				
				building_placed.emit("placeholder_type", map_pos)
				print("GridManager: Placed at ", map_pos)
			else:
				print("GridManager: Invalid placement at ", map_pos)
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if occupied_cells.has(map_pos):
				occupied_cells.erase(map_pos)
				
				# Tell the base_grid to erase the tile
				base_grid.set_cell(map_pos, -1) 
				
				building_removed.emit(map_pos)
				print("GridManager: Removed at ", map_pos)
				
func is_cell_free(cell: Vector2i) -> bool:
	return not occupied_cells.has(cell)