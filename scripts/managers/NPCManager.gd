extends Node

var npc_scenes = [
	preload("res://scenes/npc/human_1.tscn"),
	preload("res://scenes/npc/human_2.tscn"),
	preload("res://scenes/npc/human_3.tscn"),
	preload("res://scenes/npc/human_4.tscn"),
	preload("res://scenes/npc/human_5.tscn")
]
var spawned_npcs = []

func _ready():
	# Wait for Main and BuildingSystem to be ready and buildings to be placed
	await get_tree().create_timer(1.5).timeout
	spawn_initial_npcs()

func spawn_initial_npcs():
	var bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if bs == null or not "active_buildings" in bs:
		return
		
	var buildings = bs.active_buildings.values()
	if buildings.is_empty():
		# Try again in a bit if no buildings yet
		await get_tree().create_timer(2.0).timeout
		buildings = bs.active_buildings.values()
		if buildings.is_empty():
			return
			
	var main_node = get_tree().root.get_node_or_null("Main")
	var parent_node = null
	if main_node:
		parent_node = main_node.get_node_or_null("GameWorld/GridManager")
		if parent_node == null:
			parent_node = main_node
	else:
		parent_node = self
		
	for i in range(GameConstants.NPC_MAX_AMOUNT):
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
		
		# Cooldown before spawning the next NPC
		await get_tree().create_timer(GameConstants.NPC_SPAWN_COOLDOWN).timeout
