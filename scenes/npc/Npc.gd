extends CharacterBody2D

enum State { WANDER, IDLE, GO_TO_BUILDING }
var current_state: State = State.WANDER
var spawn_building: Node2D
var target_position: Vector2
var behavior_timer: Timer

@onready var animated_sprite = $AnimatedSprite2D

var idle_anim = "idle"
var move_anim = "moving"

func _ready():
	z_index = 100 # Ensure NPCs overlay the buildings
	target_position = global_position
	
	if animated_sprite and animated_sprite.sprite_frames:
		for anim in animated_sprite.sprite_frames.get_animation_names():
			if "idle" in anim.to_lower():
				idle_anim = anim
			elif "moving" in anim.to_lower() or anim == "new_animation":
				move_anim = anim
				
	behavior_timer = Timer.new()
	behavior_timer.wait_time = GameConstants.NPC_BEHAVIOR_CHANGE_TIME
	behavior_timer.autostart = true
	behavior_timer.timeout.connect(_on_behavior_timer_timeout)
	add_child(behavior_timer)
	
	_on_behavior_timer_timeout()

func _on_behavior_timer_timeout():
	var choices = [State.WANDER, State.IDLE, State.GO_TO_BUILDING]
	current_state = choices[randi() % choices.size()]
	
	match current_state:
		State.WANDER:
			var rand_x = randf_range(-GameConstants.NPC_WANDER_RADIUS, GameConstants.NPC_WANDER_RADIUS)
			var rand_y = randf_range(-GameConstants.NPC_WANDER_RADIUS, GameConstants.NPC_WANDER_RADIUS)
			target_position = global_position + Vector2(rand_x, rand_y)
		State.IDLE:
			target_position = global_position
		State.GO_TO_BUILDING:
			if spawn_building != null and is_instance_valid(spawn_building):
				target_position = spawn_building.global_position
			else:
				var bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
				if bs != null and bs.active_buildings.size() > 0:
					var buildings = bs.active_buildings.values()
					var b = buildings[randi() % buildings.size()]
					
					if bs.grid_manager and bs.grid_manager.occupied_cells.has(b.grid_position):
						var building_node = bs.grid_manager.occupied_cells[b.grid_position]
						target_position = building_node.global_position
					elif bs.grid_manager and bs.grid_manager.get("base_grid") != null:
						target_position = bs.grid_manager.base_grid.map_to_local(b.grid_position)
					else:
						target_position = global_position

func _physics_process(_delta):
	if current_state == State.WANDER or current_state == State.GO_TO_BUILDING:
		if global_position.distance_to(target_position) > 5.0:
			var dir = global_position.direction_to(target_position)
			velocity = dir * GameConstants.NPC_WALK_SPEED
			
			if dir.x != 0:
				animated_sprite.flip_h = dir.x > 0 # Assuming sprite faces left by default
				# Wait, usually flip_h = true means flipped horizontally.
				# We will just flip based on movement.
			
			animated_sprite.play(move_anim)
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			animated_sprite.play(idle_anim)
			if current_state == State.GO_TO_BUILDING:
				queue_free()
	else:
		velocity = Vector2.ZERO
		animated_sprite.play(idle_anim)
