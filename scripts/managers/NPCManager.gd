extends Node

 # Preloaded NPC scenes available for random selection
var npc_scenes = [
	preload("res://scenes/npc/human_1.tscn"),
	preload("res://scenes/npc/human_2.tscn"),
	preload("res://scenes/npc/human_3.tscn"),
	preload("res://scenes/npc/human_4.tscn"),
	preload("res://scenes/npc/human_5.tscn")
]

# Active NPC instances spawned by this manager
var spawned_npcs = []

# Flag indicating whether the spawn coroutine is running
var _is_spawning: bool = false

 # Start NPC spawning when manager is ready
func _ready():
	_start_spawn_loop()

 # Coroutine that periodically spawns NPCs up to the configured maximum
func _start_spawn_loop():
	if _is_spawning: return
	_is_spawning = true

	while true:
		await get_tree().create_timer(GameConstants.NPC_SPAWN_COOLDOWN).timeout

		# Clean up dead references (e.g. going back to main menu)
		spawned_npcs = spawned_npcs.filter(func(n): return is_instance_valid(n))

		if spawned_npcs.size() < GameConstants.NPC_MAX_AMOUNT:
			_spawn_single_npc()

 # Spawn a single NPC near a random active building
func _spawn_single_npc():
	var bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if bs == null or not "active_buildings" in bs:
		return
		
	var buildings = bs.active_buildings.values()
	if buildings.is_empty():
		return
			
	var main_node = get_tree().root.get_node_or_null("Main")
	var parent_node = null
	if main_node:
		parent_node = main_node.get_node_or_null("GameWorld/GridSystem")
		if parent_node == null:
			parent_node = main_node
	else:
		parent_node = self
		
	var b = buildings[randi() % buildings.size()]
	var npc_scene = npc_scenes[randi() % npc_scenes.size()]
	var npc = npc_scene.instantiate()
	parent_node.add_child(npc)
	
	# Offset slightly so they don't all spawn exactly on the same pixel
	var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	
	var spawn_pos = Vector2.ZERO
	if bs.grid_manager and bs.grid_manager.occupied_cells.has(b.grid_position):
		spawn_pos = bs.grid_manager.occupied_cells[b.grid_position].global_position
	elif bs.grid_manager and bs.grid_manager.get("base_grid") != null:
		spawn_pos = bs.grid_manager.base_grid.map_to_local(b.grid_position)
	else:
		spawn_pos = Vector2(b.grid_position.x * 64, b.grid_position.y * 32)
		
	npc.global_position = spawn_pos + offset
	
	# Try to pass a reference to a Node2D so Npc can read global_position later
	if bs.grid_manager and bs.grid_manager.occupied_cells.has(b.grid_position):
		npc.spawn_building = bs.grid_manager.occupied_cells[b.grid_position]
		
	spawned_npcs.append(npc)
