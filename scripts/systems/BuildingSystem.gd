extends Node
class_name BuildingSystem

signal workers_changed
signal building_selected_data(b_data: BuildingData) 
signal building_state_changed(grid_pos: Vector2i)
# signal building_upgraded
# signal building_damaged

var active_buildings: Dictionary = {}
var _prev_powered_states: Dictionary = {}
var _power_sfx_cooldown: float = 0.0
var current_selected_grid_pos: Vector2i = Vector2i.ZERO
var has_selected_building: bool = false

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

const T2_SPRITES = {
	BuildingData.BuildingType.COAL_GENERATOR: preload("res://assets/buildings/T2_Buildings/Coal_Generator_T2.png"),
	BuildingData.BuildingType.HYDROPONIC_BAY: preload("res://assets/buildings/T2_Buildings/Hydroponic_Bay_T2.png"),
	BuildingData.BuildingType.SHELTER_BLOCK: preload("res://assets/buildings/T2_Buildings/Shelter_Block_T2.png"),
	BuildingData.BuildingType.GEOTHERMAL_TAP: preload("res://assets/buildings/T2_Buildings/Geothermal_Tap_T2.png"),
	BuildingData.BuildingType.RATION_STORE: preload("res://assets/buildings/T2_Buildings/Ration_Store_T2.png"),
	BuildingData.BuildingType.WATER_RECYCLER: preload("res://assets/buildings/T2_Buildings/Water_Recycler_T2.png"),
	BuildingData.BuildingType.MED_CLINIC: preload("res://assets/buildings/T2_Buildings/Med_Clinic_T2.png"),
	BuildingData.BuildingType.ARCHIVE_HALL: preload("res://assets/buildings/T2_Buildings/Archive_Hall_T2.png")
}

const JournalEntryData = preload("res://scripts/data/JournalEntry.gd")

# We need to listen to the GridManager's signals
@export var grid_manager: Node2D 

var floating_text_scene = preload("res://scenes/UI/FloatingText.tscn")

func _process(delta: float) -> void:
	if _power_sfx_cooldown > 0.0:
		_power_sfx_cooldown -= delta

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
	
	if GameManager:
		GameManager.named_character_died.connect(_on_named_character_died)

	# React to resource changes so power dimming updates instantly
	if ResourceManager:
		ResourceManager.resources_changed.connect(Callable(self, "_on_resources_changed"))

	# Ensure visuals are correct for any buildings created during load
	# Recalculate power and apply states to any placed buildings
	if ResourceManager:
		if ResourceManager.has_method("calculate_power"):
			ResourceManager.calculate_power()
		else:
			ResourceManager._recalculate_power()

		if grid_manager:
			for pos in active_buildings.keys():
				# If a placed scene node exists, give it its textures and grid pos
				if grid_manager.occupied_cells.has(pos):
					var placed_node = grid_manager.occupied_cells[pos]
					var bdata = active_buildings[pos]
					if placed_node and placed_node.has_method("set_textures"):
						var t1 = T1_SPRITES.get(bdata.building_type, null)
						var t2 = T2_SPRITES.get(bdata.building_type, null)
						var d = DAMAGED_SPRITES.get(bdata.building_type, null)
						placed_node.set_textures(t1, t2, d)
						if placed_node.has_method("set_grid_pos"):
							placed_node.set_grid_pos(pos)
						# Set visual state based on data
						if bdata.is_damaged and placed_node.has_method("set_building_state"):
							placed_node.set_building_state("damaged")
						elif bdata.is_upgraded and placed_node.has_method("set_building_state"):
							placed_node.set_building_state("tier2")
						elif placed_node.has_method("set_building_state"):
							placed_node.set_building_state("tier1")
				# Ensure centralized tint selection is applied
				update_building_visual(pos)

# ══════════════════════════════════════════════════════════════════════════════
# DAILY TICK — tracks unstaffed days for damage and Water Recycler disease
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(_day: int) -> void:
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]

		# Only track unstaffed days for buildings that require workers
		if b.worker_capacity == 0:
			continue

		# Track unstaffed days
		if b.workers_assigned == 0:
			b.days_unstaffed += 1

			# Water Recycler: trigger disease after DISEASE_WATER_DELAY consecutive unstaffed days
			if b.building_type == BuildingData.BuildingType.WATER_RECYCLER:
				b.days_unstaffed_for_disease += 1
				if b.days_unstaffed_for_disease >= GameConstants.DISEASE_WATER_DELAY:
					PopulationManager.trigger_outbreak()
					b.days_unstaffed_for_disease = 0   # Reset disease-specific counter so it doesn't fire every day

			# Building damage: any building at 0 workers for BUILDING_DAMAGE_DAYS
			if b.days_unstaffed >= GameConstants.BUILDING_DAMAGE_DAYS and not b.is_damaged:
				# Log resource state and building output before applying damage
				if ResourceManager:
					print("[DBG] Damage BEFORE at %s | net_power=%.2f power_capacity=%.2f power_draw=%.2f materials=%d food=%.2f morale=%.2f" % [str(grid_pos), ResourceManager.net_power, ResourceManager.power_capacity, ResourceManager.power_draw, ResourceManager.materials, ResourceManager.food, ResourceManager.morale])
					var before_out = get_effective_output(grid_pos)
					print("[DBG] Building BEFORE output: %s" % [str(before_out)])

				# Apply damage
				set_building_damaged(grid_pos, true)
				AudioManager.play_build_sfx("damage")
				print("BuildingSystem: [%s] has become damaged from neglect." % b.building_name)
				var journal_node = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
				var entry_text := b.building_name + " has fallen into disrepair. " + "No one has been assigned there in days."
				if journal_node and journal_node.has_method("add_entry"):
					journal_node.add_entry(GameManager.current_day, entry_text, JournalEntryData.EntryType.NARRATIVE)

				# Recalculate resources so post-damage values are accurate for logs
				if ResourceManager:
					if ResourceManager.has_method("_recalculate_power"):
						ResourceManager._recalculate_power()
					elif ResourceManager.has_method("calculate_power"):
						ResourceManager.calculate_power()
					# Emit a resources update to keep HUD in sync
					ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
					print("[DBG] Damage AFTER at %s | net_power=%.2f power_capacity=%.2f power_draw=%.2f materials=%d food=%.2f morale=%.2f" % [str(grid_pos), ResourceManager.net_power, ResourceManager.power_capacity, ResourceManager.power_draw, ResourceManager.materials, ResourceManager.food, ResourceManager.morale])
					var after_out = get_effective_output(grid_pos)
					print("[DBG] Building AFTER output: %s" % [str(after_out)])
		else:
			# Reset counters when staffed
			b.days_unstaffed = 0
			b.days_unstaffed_for_disease = 0

# ══════════════════════════════════════════════════════════════════════════════
# SELECTION
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_selected(grid_pos: Vector2i) -> void:
	if not active_buildings.has(grid_pos):
		return
	has_selected_building = true
	current_selected_grid_pos = grid_pos
	var b: BuildingData = active_buildings[grid_pos]
	building_selected_data.emit(b)
	
	print("BuildingSystem: Selected [%s] | Workers: %d/%d | Output: %d%%" \
		% [b.building_name, b.workers_assigned, b.worker_capacity, int(b.staffing_ratio * 100)])

func _on_building_deselected() -> void:
	has_selected_building = false
	current_selected_grid_pos = Vector2i.ZERO
	building_selected_data.emit(null) # Tells the UI to hide itself

# ══════════════════════════════════════════════════════════════════════════════
# PLACEMENT & REMOVAL
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_placed(b_type: String, grid_pos: Vector2i) -> void:
	var new_data: BuildingData = BuildingData.new()
	new_data.grid_position = grid_pos
	
	# Memorial Wall can only be placed after at least one named character has died
	if b_type == "memorial":
		var any_dead: bool = (not GameManager.yuna_alive) or \
							 (not GameManager.rook_alive) or \
							 (not GameManager.vasquez_alive) or \
							 (not GameManager.meridian_alive)
		if not any_dead:
			# Undo the GridManager placement immediately
			if grid_manager:
				grid_manager.remove_building(grid_pos)
			print("BuildingSystem: Memorial Wall cannot be placed — no named character has died yet.")
			return
	
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
			ResourceManager.on_ration_store_built(false) 

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
			if GameManager.yuna_alive:
				new_data.base_morale_bonus = GameConstants.MED_CLINIC_MORALE_PASSIVE
			else:
				new_data.base_morale_bonus = 0.0
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
			AudioManager.play_build_sfx("memorial_place")
			
	active_buildings[grid_pos] = new_data
	new_data.footprint_size = grid_manager.BUILDING_FOOTPRINTS.get(b_type, Vector2i(1, 1))
	# Connect staffing_changed for this instance so visuals update on worker assignment
	new_data.staffing_changed.connect(Callable(self, "_on_staffing_changed").bind(grid_pos))
	print("BuildingSystem: Registered [%s] at %s | Slots: %d | Base power: %.1f | Base food: %.1f" \
		% [new_data.building_name, grid_pos, new_data.worker_capacity, new_data.base_production_power, new_data.base_production_food])

	# Ensure visuals are correct on placement
	update_building_visual(grid_pos)

	# Recalculate power so `is_powered` flags are up-to-date and visuals reflect power state
	if ResourceManager:
		ResourceManager.calculate_power()

	if grid_manager and grid_manager.occupied_cells.has(grid_pos):
		var placed_node = grid_manager.occupied_cells[grid_pos]
		if placed_node and placed_node.has_method("set_textures"):
			var t1 = T1_SPRITES.get(new_data.building_type, null)
			var t2 = T2_SPRITES.get(new_data.building_type, null)
			var d = DAMAGED_SPRITES.get(new_data.building_type, null)
			placed_node.set_textures(t1, t2, d)
			if placed_node.has_method("set_grid_pos"):
				placed_node.set_grid_pos(grid_pos)
			# Set initial visual state based on data
			if new_data.is_damaged and placed_node.has_method("set_building_state"):
				placed_node.set_building_state("damaged")
			elif new_data.is_upgraded and placed_node.has_method("set_building_state"):
				placed_node.set_building_state("tier2")
			elif placed_node.has_method("set_building_state"):
				placed_node.set_building_state("tier1")

	if b_type != "memorial":
		AudioManager.play_build_sfx("place")

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
			
	AudioManager.play_build_sfx("remove")
	AudioManager.remove_ambient(grid_pos)
	active_buildings.erase(grid_pos)
	
	if current_selected_grid_pos == grid_pos:
		_on_building_deselected() # Safely clear selection

# ══════════════════════════════════════════════════════════════════════════════
# WORKER ASSIGNMENT
# ══════════════════════════════════════════════════════════════════════════════
func assign_worker() -> void:
	if not has_selected_building:
		return
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
	AudioManager.play_build_sfx("worker_assign")
	GameManager.available_workers                  -= 1
	GameManager.population_state.available_workers -= 1
	
	workers_changed.emit()
	b_data.staffing_changed.emit(b_data.workers_assigned, b_data.worker_capacity) 
	
	print("BuildingSystem: Assigned worker to [%s] | %d/%d | Output: %d%% | Pool left: %d" \
		% [b_data.building_name, b_data.workers_assigned, b_data.worker_capacity, int(b_data.staffing_ratio * 100), GameManager.available_workers])

# Called by UI +/- buttons to remove a worker
func remove_worker(grid_pos: Vector2i) -> void:
	if not has_selected_building:
		return
	if not active_buildings.has(grid_pos): return
	var b_data = active_buildings[grid_pos]
	
	if b_data.workers_assigned <= 0:
		print("BuildingSystem: [%s] has no workers to remove." % b_data.building_name)
		return
	
	b_data.workers_assigned                        -= 1
	spawn_floating_text(grid_pos, "-1 Worker", Color.RED)
	AudioManager.play_build_sfx("worker_remove")
	GameManager.available_workers                  += 1
	GameManager.population_state.available_workers += 1
	
	workers_changed.emit()
	b_data.staffing_changed.emit(b_data.workers_assigned, b_data.worker_capacity) 
	
	print("BuildingSystem: Removed worker from [%s] | %d/%d | Output: %d%% | Pool left: %d" \
		% [b_data.building_name, b_data.workers_assigned, b_data.worker_capacity, int(b_data.staffing_ratio * 100), GameManager.available_workers])

# Call this to change the damaged state of a building and swap its sprite
func set_building_damaged(grid_pos: Vector2i, is_damaged: bool) -> void:
	if not active_buildings.has(grid_pos): return
	var b_data = active_buildings[grid_pos]
	b_data.is_damaged = is_damaged
	# Inform scene instance to update its visual
	if grid_manager and grid_manager.occupied_cells.has(grid_pos):
		var node = grid_manager.occupied_cells[grid_pos]
		if node and node.has_method("set_building_state"):
			if is_damaged:
				node.set_building_state("damaged")
			else:
				# restore to upgraded state if applicable
				var b = active_buildings[grid_pos]
				if b.is_upgraded:
					node.set_building_state("tier2")
				else:
					node.set_building_state("tier1")

	# Centralized visual refresh handles tinting
	update_building_visual(grid_pos)

	# After repair, reset unstaffed counters so the building
	# doesn't enter the damage path on the next day tick
	if not is_damaged:
		b_data.days_unstaffed = 0
		b_data.days_unstaffed_for_disease = 0
		print("BuildingSystem: Cleared damage at", grid_pos, "— reset days_unstaffed counters")

		# Recalculate power so `is_powered` flags reflect restored output
		if ResourceManager:
			if ResourceManager.has_method("_recalculate_power"):
				ResourceManager._recalculate_power()
			elif ResourceManager.has_method("calculate_power"):
				ResourceManager.calculate_power()
			ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)

	# Notify listeners that this building's visual state changed
	emit_signal("building_state_changed", grid_pos)

	print("BuildingSystem: Changed damaged state to ", is_damaged, " at ", grid_pos)
	
func set_building_damaged_randomly() -> void:
	if active_buildings.is_empty(): return
	var keys = active_buildings.keys()
	# Fisher-Yates or simple random choice, we can just grab an array since Dictionary keys is an array in GDScript 4
	var target_pos = keys[randi() % keys.size()]
	set_building_damaged(target_pos, true)

func get_med_clinic_count() -> int:
	var count: int = 0
	for pos in active_buildings:
		if active_buildings[pos].building_type == BuildingData.BuildingType.MED_CLINIC:
			count += 1
	return count

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
# VISUAL UPDATE: centralised sprite selection and tinting
func update_building_visual(grid_pos: Vector2i) -> void:
	if not active_buildings.has(grid_pos): return
	var b = active_buildings[grid_pos]
	if not grid_manager: return
	if not grid_manager.occupied_cells.has(grid_pos): return

	var node = grid_manager.occupied_cells[grid_pos]
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if not sprite:
		return

	# Texture selection
	var chosen_texture: Texture2D = null
	if b.is_damaged and DAMAGED_SPRITES.has(b.building_type):
		chosen_texture = DAMAGED_SPRITES[b.building_type]
	elif b.is_upgraded and T2_SPRITES.has(b.building_type):
		chosen_texture = T2_SPRITES[b.building_type]
	elif T1_SPRITES.has(b.building_type):
		chosen_texture = T1_SPRITES[b.building_type]
	if chosen_texture != null:
		sprite.texture = chosen_texture

	# Power-based dimming
	var unpowered_color: Color = Color(0.45, 0.45, 0.45, 1.0)
	var normal_color: Color = Color(1, 1, 1, 1)
	var power_ok: bool = b.is_powered or b.base_production_power > 0.0
	var power_color: Color = normal_color if power_ok else unpowered_color

	# Staffing tint: subtle boost when well-staffed
	var s := clampf(b.staffing_ratio, 0.0, 1.0)
	var staff_color: Color = Color(1.0 - 0.08 * (1.0 - s), 1.0 - 0.05 * (1.0 - s), 1.0, 1.0)

	# Final modulate mixes power and staff influence
	var t := s * 0.5
	sprite.modulate = Color(
		power_color.r + (staff_color.r - power_color.r) * t,
		power_color.g + (staff_color.g - power_color.g) * t,
		power_color.b + (staff_color.b - power_color.b) * t,
		power_color.a + (staff_color.a - power_color.a) * t
	)

# ══════════════════════════════════════════════════════════════════════════════
# UPGRADE VISUAL: dual-path sync guaranteeing T2 sprite appears
# ══════════════════════════════════════════════════════════════════════════════
func apply_upgrade_visual(grid_pos: Vector2i) -> void:
	if not active_buildings.has(grid_pos):
		return
	var b: BuildingData = active_buildings[grid_pos]
	if not b.is_upgraded:
		return

	if grid_manager and grid_manager.occupied_cells.has(grid_pos):
		var node: Node2D = grid_manager.occupied_cells.get(grid_pos, null)
		if node and node.has_method("set_building_state"):
			node.set_building_state("tier2")
		var sprite: Sprite2D = node.get_node_or_null("Sprite2D") if node else null
		if sprite and T2_SPRITES.has(b.building_type):
			sprite.texture = T2_SPRITES[b.building_type]

	update_building_visual(grid_pos)

	print("BuildingSystem: apply_upgrade_visual complete at %s | building: %s" \
		% [str(grid_pos), b.building_name])

func _on_resources_changed(_power: float, _food: float, _morale: float, _materials: int) -> void:
	for pos in active_buildings.keys():
		var b: BuildingData = active_buildings[pos]
		var power_ok: bool = b.is_powered or b.base_production_power > 0.0

		# Detect power state flip and play SFX once per change cycle
		if _prev_powered_states.has(pos) and _power_sfx_cooldown <= 0.0:
			var was_powered: bool = _prev_powered_states[pos]
			if power_ok and not was_powered:
				AudioManager.play_build_sfx("power_online")
				_power_sfx_cooldown = 0.5
			elif not power_ok and was_powered:
				AudioManager.play_build_sfx("power_offline")
				_power_sfx_cooldown = 0.5

		_prev_powered_states[pos] = power_ok

		AudioManager.update_ambient(pos, b.building_type, _should_ambient_play(b))

		update_building_visual(pos)

func _on_staffing_changed(grid_pos: Vector2i, _current: int, _capacity: int) -> void:
	if not active_buildings.has(grid_pos):
		return
	var b: BuildingData = active_buildings[grid_pos]
	AudioManager.update_ambient(grid_pos, b.building_type, _should_ambient_play(b))
	update_building_visual(grid_pos)

func _on_named_character_died(char_name: String) -> void:
	if char_name == "yuna":
		var changed = false
		for pos in active_buildings.keys():
			var b = active_buildings[pos]
			if b.building_type == BuildingData.BuildingType.MED_CLINIC:
				b.base_morale_bonus = 0.0
				changed = true
		if changed and ResourceManager:
			if ResourceManager.has_method("_recalculate_power"):
				ResourceManager._recalculate_power()
			elif ResourceManager.has_method("calculate_power"):
				ResourceManager.calculate_power()
			ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)

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

func get_workers_for_building_type(type: BuildingData.BuildingType) -> int:
	var total: int = 0
	for pos in active_buildings:
		if active_buildings[pos].building_type == type:
			total += active_buildings[pos].workers_assigned
	return total

func has_building(type: BuildingData.BuildingType) -> bool:
	for pos in active_buildings:
		if active_buildings[pos].building_type == type:
			return true
	return false

func is_building_upgraded(type: BuildingData.BuildingType) -> bool:
	for pos in active_buildings:
		if active_buildings[pos].building_type == type and active_buildings[pos].is_upgraded:
			return true
	return false

# Returns true if at least one Water Recycler has workers assigned and is powered
func is_water_recycler_staffed() -> bool:
	for grid_pos in active_buildings:
		var b: BuildingData = active_buildings[grid_pos]
		if b.building_type == BuildingData.BuildingType.WATER_RECYCLER:
			if b.workers_assigned > 0 and b.is_powered:
				return true
	return false

# Returns true if this building's ambient loop should currently be playing.
func _should_ambient_play(b: BuildingData) -> bool:
	match b.building_type:
		BuildingData.BuildingType.COAL_GENERATOR:
			# Needs both power and at least one worker
			return b.is_powered and b.workers_assigned > 0
		BuildingData.BuildingType.GEOTHERMAL_TAP:
			# Passive — only needs power
			return b.is_powered
		BuildingData.BuildingType.WATER_RECYCLER:
			# Ambient represents active filtration — needs staff
			return b.workers_assigned > 0
		BuildingData.BuildingType.MED_CLINIC:
			# Ambient represents active clinic — needs staff
			return b.workers_assigned > 0
		BuildingData.BuildingType.ARCHIVE_HALL:
			# Ambient represents humming servers — needs power
			return b.is_powered
		BuildingData.BuildingType.SHELTER_BLOCK:
			# Ambient represents occupied housing — needs power
			return b.is_powered
		_:
			# Relay Hub, Ration Store, Memorial Wall — no ambient loop
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

func spawn_upgrade_particles(grid_pos: Vector2i, building_type: BuildingData.BuildingType) -> void:
	if not grid_manager:
		return

	# Choose particle colour to match the building's neon palette 
	var particle_color: Color
	match building_type:
		BuildingData.BuildingType.COAL_GENERATOR, \
		BuildingData.BuildingType.GEOTHERMAL_TAP:
			particle_color = Color(1.0, 0.58, 0.0, 0.9)   # amber — power buildings
		BuildingData.BuildingType.ARCHIVE_HALL, \
		BuildingData.BuildingType.MEMORIAL_WALL:
			particle_color = Color(0.61, 0.35, 1.0, 0.9)  # purple — social buildings
		_:
			particle_color = Color(0.0, 0.96, 1.0, 0.9)   # cyan — default

	# Build the particle material programmatically
	var material := ParticleProcessMaterial.new()
	material.direction            = Vector3(0.0, -1.0, 0.0)
	material.spread               = 50.0
	material.initial_velocity_min = 35.0
	material.initial_velocity_max = 75.0
	material.gravity              = Vector3(0.0, 30.0, 0.0)
	material.scale_min            = 3.0
	material.scale_max            = 6.0
	material.color                = particle_color

	# Build the GPUParticles2D node
	var particles := GPUParticles2D.new()
	particles.process_material  = material
	particles.amount            = 40
	particles.lifetime          = 1.0
	particles.one_shot          = true
	particles.explosiveness     = 0.85   # burst all at once
	particles.z_index           = 200    # above buildings, below HUD

	# Place it at the building's world position and emit
	grid_manager.add_child(particles)
	particles.position = grid_manager.base_grid.map_to_local(grid_pos)
	particles.emitting = true

	# Auto-cleanup after the full particle duration from GameConstants
	var cleanup_timer := particles.get_tree().create_timer(
		GameConstants.BUILDING_UPGRADE_PARTICLE_DURATION + 0.5
	)
	cleanup_timer.timeout.connect(particles.queue_free)

	print("BuildingSystem: Upgrade particles spawned at %s | color: %s" \
		% [str(grid_pos), str(particle_color)])

# ══════════════════════════════════════════════════════════════════════════════
# DEBUG / TESTING ONLY — remove in Week 6 when real UI is ready
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	if event.keycode == KEY_EQUAL:   # '+' key
		assign_worker()
	if event.keycode == KEY_MINUS:   # '-' key
		remove_worker(current_selected_grid_pos)