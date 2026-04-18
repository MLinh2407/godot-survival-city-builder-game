extends Node2D

signal building_placed(type: String, grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)
signal building_selected(grid_pos: Vector2i)
signal building_deselected() 

const GRID_BOUNDS_MIN = Vector2i(-5, -5)
const GRID_BOUNDS_MAX = Vector2i(5, 5)

var occupied_cells: Dictionary = {}

@onready var base_grid: TileMapLayer = $BaseGrid
@onready var ghost_sprite: Sprite2D = $GhostSprite 
@onready var hover_cursor: Sprite2D = $HoverCursor 


@export var building_container: Node2D 
@export var building_scenes: Dictionary = {}

var current_build_type: String = ""
var current_build_scene: PackedScene = null

func _ready() -> void:
	ghost_sprite.visible = false 
	hover_cursor.visible = false
	ghost_sprite.z_index = 100

# ══════════════════════════════════════════════════════════════════════════════
# BUILD MODE ENTER / EXIT
# ══════════════════════════════════════════════════════════════════════════════
func enter_build_mode(b_type: String) -> void:
	if building_scenes.has(b_type):
		current_build_type = b_type
		current_build_scene = building_scenes[b_type]

		# Temporarily instantiate the scene to steal its visual data
		var temp_building = current_build_scene.instantiate()
		var b_sprite = temp_building.get_node_or_null("Sprite2D")
		
		if b_sprite:
			ghost_sprite.texture = b_sprite.texture
			ghost_sprite.offset = b_sprite.offset
			
			# AUTOMATIC SCALING: 64px Tile / 256px Sprite = 0.25 Scale
			var scale_factor = float(GameConstants.TILE_SIZE) / float(GameConstants.BUILDING_SPRITE_SIZE)
			ghost_sprite.scale = Vector2(scale_factor, scale_factor)
			
			ghost_sprite.visible = true
			
		# Delete the temporary building from memory instantly
		temp_building.queue_free()

func exit_build_mode() -> void:
	current_build_type = ""
	current_build_scene = null
	
	ghost_sprite.visible = false
	ghost_sprite.texture = null
	ghost_sprite.modulate = Color.WHITE

# ══════════════════════════════════════════════════════════════════════════════
# VISUAL PROCESSING (Tracking the Mouse)
# ══════════════════════════════════════════════════════════════════════════════
func _process(_delta: float) -> void:
	var local_mouse = get_local_mouse_position()
	var map_pos = base_grid.local_to_map(local_mouse)
	
	# STATE 1: BUILD MODE (Holding a building tool)
	if current_build_scene != null:
		hover_cursor.visible = false 
		ghost_sprite.visible = true
		
		# Snap ghost to grid
		ghost_sprite.position = base_grid.map_to_local(map_pos)
		
		# Valid/Invalid zone highlight applied directly to the building sprite
		if is_valid_placement(map_pos):
			ghost_sprite.modulate = Color(0.2, 3.0, 0.2, 0.6) # Translucent Green
		else:
			ghost_sprite.modulate = Color(3.0, 0.2, 0.2, 0.6) # Translucent Red

	# STATE 2: SELECTION MODE (Empty hands)
	else:
		ghost_sprite.visible = false
		
		if occupied_cells.has(map_pos):
			hover_cursor.position = base_grid.map_to_local(map_pos)
			hover_cursor.visible = true
		else:
			hover_cursor.visible = false

# ══════════════════════════════════════════════════════════════════════════════
# PLACEMENT LOGIC & INPUT
# ══════════════════════════════════════════════════════════════════════════════
func is_valid_placement(cell: Vector2i) -> bool:
	if cell.x < GRID_BOUNDS_MIN.x or cell.x > GRID_BOUNDS_MAX.x or cell.y < GRID_BOUNDS_MIN.y or cell.y > GRID_BOUNDS_MAX.y:
		return false
	if occupied_cells.has(cell):
		return false
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var map_pos = base_grid.local_to_map(get_local_mouse_position())
		
		# LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_build_scene != null:
				if is_valid_placement(map_pos):
					place_building(map_pos)
				else:
					AudioManager.play_build_sfx("invalid")
			else:
				if occupied_cells.has(map_pos):
					building_selected.emit(map_pos)
				else:
					building_deselected.emit()
					
		# RIGHT CLICK
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_build_scene != null:
				exit_build_mode()
			elif occupied_cells.has(map_pos):
				remove_building(map_pos)

	# DEBUG KEYS
	if event is InputEventKey and event.pressed:
		var keys = building_scenes.keys()
		if event.keycode == KEY_1 and keys.size() > 0: enter_build_mode(keys[0])
		if event.keycode == KEY_2 and keys.size() > 1: enter_build_mode(keys[1])
		if event.keycode == KEY_3 and keys.size() > 2: enter_build_mode(keys[2])
		if event.keycode == KEY_4 and keys.size() > 3: enter_build_mode(keys[3])
		if event.keycode == KEY_5 and keys.size() > 4: enter_build_mode(keys[4])
		if event.keycode == KEY_6 and keys.size() > 5: enter_build_mode(keys[5])
		if event.keycode == KEY_7 and keys.size() > 6: enter_build_mode(keys[6])
		if event.keycode == KEY_8 and keys.size() > 7: enter_build_mode(keys[7])
		if event.keycode == KEY_9 and keys.size() > 8: enter_build_mode(keys[8])

func place_building(map_pos: Vector2i) -> void:
	var new_building = current_build_scene.instantiate()
	
	# Apply the same automatic scaling to the final placed building!
	var scale_factor = float(GameConstants.TILE_SIZE) / float(GameConstants.BUILDING_SPRITE_SIZE)
	new_building.scale = Vector2(scale_factor, scale_factor)
	
	building_container.add_child(new_building)
	new_building.position = base_grid.map_to_local(map_pos)
	
	occupied_cells[map_pos] = new_building
	building_placed.emit(current_build_type, map_pos)

func remove_building(map_pos: Vector2i) -> void:
	var building = occupied_cells[map_pos]
	building.queue_free()
	occupied_cells.erase(map_pos)
	building_removed.emit(map_pos)
	print("GridManager: Removed at ", map_pos)

func clear_grid() -> void:
	var keys = occupied_cells.keys()
	for pos in keys:
		remove_building(pos)

func spawn_building_from_save(b_type: String, map_pos: Vector2i) -> void:
	if not building_scenes.has(b_type):
		push_error("GridManager: Cannot spawn unknown building type ", b_type)
		return
		
	var saved_build_scene = building_scenes[b_type]
	var new_building = saved_build_scene.instantiate()
	
	building_container.add_child(new_building)
	new_building.position = base_grid.map_to_local(map_pos)
	occupied_cells[map_pos] = new_building
	building_placed.emit(b_type, map_pos)
	print("GridManager: Spawning from save ", b_type, " at ", map_pos)
