extends PanelContainer

# ══════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ══════════════════════════════════════════════════════════════════════════════
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var worker_label: Label = $VBoxContainer/WorkerLabel
@onready var output_label: Label = $VBoxContainer/OutputLabel
@onready var repair_button: Button = $VBoxContainer/RepairButton
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton

@export var building_system: Node 

# We track the currently selected building so we can disconnect signals when we click away
var current_building: BuildingData = null
var last_selected_grid_pos: Vector2i = Vector2i.ZERO
var has_last_selected_grid_pos: bool = false

func _ready() -> void:
	# Hide the panel by default
	visible = false
	modulate.a = 0.0 # Make it totally transparent for our fade-in effect
	
	if not building_system:
		building_system = _find_building_system()

	if not building_system:
		await get_tree().process_frame
		if typeof(ResourceManager) != TYPE_NIL and ResourceManager.building_system:
			building_system = ResourceManager.building_system

	if building_system:
		building_system.building_selected_data.connect(_on_building_selected)
		print("BuildingInspector: Connected to BuildingSystem at", building_system)
		# Refresh UI when building states change (damaged/upgraded/power)
		if building_system.has_signal("building_state_changed"):
			building_system.building_state_changed.connect(_on_building_state_changed)
			print("BuildingInspector: Connected to building_state_changed signal")
	# Repair button handler
	if repair_button:
		repair_button.pressed.connect(_on_repair_pressed)
		repair_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		push_error("BuildingInspector: BuildingSystem is not assigned in the Inspector!")

	# Upgrade button handler
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		pass

func _find_building_system() -> Node:
	var root = get_tree().get_root()
	return _search_for_building_system(root)


func _search_for_building_system(node: Node) -> Node:
	if node is BuildingSystem:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _search_for_building_system(child)
			if found:
				return found
	return null

# ══════════════════════════════════════════════════════════════════════════════
# SELECTION HANDLING
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_selected(b_data: BuildingData) -> void:
	print("BuildingInspector: _on_building_selected called with", b_data)
	# 1. Disconnect from the old building if we were looking at one
	if current_building != null and current_building.staffing_changed.is_connected(_on_staffing_changed):
		current_building.staffing_changed.disconnect(_on_staffing_changed)
		
	current_building = b_data

	if current_building != null:
		last_selected_grid_pos = current_building.grid_position
		has_last_selected_grid_pos = true
	
	# 2. If we clicked the dirt (deselected), hide the UI
	if current_building == null:
		_hide_panel()
		return
		
	# 3. We clicked a real building! Connect to its specific data signal
	current_building.staffing_changed.connect(_on_staffing_changed)
	
	# 4. Update the text and show the panel
	_refresh_ui_text()
	_show_panel()

# Triggered exactly when you press + or - on the active building
func _on_staffing_changed(_current: int, _capacity: int) -> void:
	_refresh_ui_text()

# ══════════════════════════════════════════════════════════════════════════════
# TEXT FORMATTING
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_ui_text() -> void:
	if current_building == null: return
	
	title_label.text = current_building.building_name
	
	# Format the Worker text
	if current_building.worker_capacity > 0:
		worker_label.text = "Workers: " + str(current_building.workers_assigned) + " / " + str(current_building.worker_capacity)
	else:
		worker_label.text = "Workers: Automated (Passive)"
		
	# Format the Output text using the helper function we wrote in Week 5!
	var output = building_system.get_effective_output(current_building.grid_position)
	
	var output_text = "Daily Output:\n"
	if output.power != 0: output_text += "⚡ Power: " + str(output.power) + " kW\n"
	if output.food != 0:  output_text += "🍲 Food: " + str(output.food) + " rations\n"
	if output.morale != 0: output_text += "😊 Morale: +" + str(output.morale) + "\n"
	
	# If it produces nothing (like a passive building with no output), just say Active
	if output.power == 0 and output.food == 0 and output.morale == 0:
		output_text += "Status: Active"
		
	output_label.text = output_text

	# Repair button visibility / enabled state
	if repair_button:
		if current_building.is_damaged:
			repair_button.visible = true
			repair_button.disabled = GameManager.materials < GameConstants.REPAIR_COST_BASE
		else:
			repair_button.visible = false

	# Upgrade button: show when building exists and is not upgraded
	if upgrade_button:
		if not current_building.is_upgraded:
			upgrade_button.visible = true
			# Determine cost: high-cost critical buildings
			var u_cost = GameConstants.UPGRADE_COST_BASE
			if current_building.building_type == BuildingData.BuildingType.WATER_RECYCLER or current_building.building_type == BuildingData.BuildingType.MED_CLINIC:
				u_cost = GameConstants.UPGRADE_COST_HIGH
			upgrade_button.disabled = GameManager.materials < u_cost
		else:
			upgrade_button.visible = false

func _on_building_state_changed(grid_pos: Vector2i) -> void:
	# If the changed building is the current selection, refresh the UI so Repair appears
	if current_building and current_building.grid_position == grid_pos:
		_refresh_ui_text()

# ══════════════════════════════════════════════════════════════════════════════
# UX JUICE (Animations)
# ══════════════════════════════════════════════════════════════════════════════
func _show_panel() -> void:
	visible = true
	# A tiny Tween makes the UI fade in smoothly instead of snapping aggressively
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _hide_panel() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false) # Hide it fully after the fade finishes

func _on_repair_pressed() -> void:
	print("BuildingInspector: Repair button pressed for", current_building)

	var target_building: BuildingData = current_building
	var gm = building_system
	if (target_building == null or gm == null) and gm != null:
		# Fallback: use the BuildingSystem's current selected grid pos to find the building
		var sel_pos: Vector2i = gm.current_selected_grid_pos
		if gm.has_selected_building and gm.active_buildings.has(sel_pos):
			target_building = gm.active_buildings[sel_pos]
			print("BuildingInspector: Fallback found building at", sel_pos, "->", target_building)

	if target_building == null and gm != null and has_last_selected_grid_pos:
		# Use the last selected pos if current selection cleared due to input ordering
		if gm.active_buildings.has(last_selected_grid_pos):
			target_building = gm.active_buildings[last_selected_grid_pos]
			print("BuildingInspector: Using last_selected_grid_pos fallback ->", last_selected_grid_pos)

	if target_building == null or not gm:
		print("BuildingInspector: No current building or building_system")
		if gm:
			print("BuildingInspector: current_selected_grid_pos", gm.current_selected_grid_pos)
			print("BuildingInspector: active_buildings keys", gm.active_buildings.keys())
			if gm.grid_manager:
				print("BuildingInspector: occupied_cells keys", gm.grid_manager.occupied_cells.keys())
		return

	# Find the placed scene node for this building
	if not gm.grid_manager:
		push_warning("BuildingInspector: No grid_manager available to perform repair.")
		return

	var node = gm.grid_manager.occupied_cells.get(target_building.grid_position, null)
	print("BuildingInspector: Found node:", node, "for building data:", target_building)
	if node:
		print("BuildingInspector: node class:", node.get_class(), "script:", node.get_script(), "has_method(repair):", node.has_method("repair"))
		# Prefer calling repair() synchronously
		if node.has_method("repair"):
			print("BuildingInspector: Calling repair() for grid", target_building.grid_position)
			# Play place SFX for user feedback
			if AudioManager and AudioManager.has_method("play_build_sfx"):
				AudioManager.play_build_sfx("place")
			var ok: bool = false
			# Call directly to obtain success/failure
			ok = node.repair()
			if ok:
				print("BuildingInspector: Repair succeeded for", target_building.grid_position)
				_refresh_ui_text()
			else:
				push_warning("BuildingInspector: Repair failed or insufficient materials")
		else:
			var found_child: bool = false
			for child in node.get_children():
				if child.has_method("repair"):
					found_child = true
					print("BuildingInspector: Calling repair() on child", child)
					if AudioManager and AudioManager.has_method("play_build_sfx"):
						AudioManager.play_build_sfx("repair")
					var child_ok: bool = child.repair()
					if child_ok:
						_refresh_ui_text()
					else:
						push_warning("BuildingInspector: Repair failed on child or insufficient materials")
					break
			if not found_child:
				push_warning("BuildingInspector: Selected building instance has no repair() method.")
	else:
		push_warning("BuildingInspector: Selected building instance has no repair() method.")

	if node and not node.has_method("repair"):
		var cost:int = GameConstants.REPAIR_COST_BASE
		print("BuildingInspector: Fallback repair for", target_building, "cost", cost, "materials", ResourceManager.materials)
		if AudioManager and AudioManager.has_method("play_build_sfx"):
			AudioManager.play_build_sfx("repair")

		# Use ResourceManager.consume_materials so HUD updates
		if not ResourceManager.consume_materials(cost):
			push_warning("Repair failed: insufficient materials")
			return
		print("BuildingInspector: Materials after spending", ResourceManager.materials)
		# Notify building system to clear damaged
		if building_system and building_system.has_method("set_building_damaged"):
			building_system.set_building_damaged(target_building.grid_position, false)
			_refresh_ui_text()
			building_system.update_building_visual(target_building.grid_position)
		else:
			push_warning("BuildingInspector: cannot notify BuildingSystem to clear damaged")

func _on_upgrade_pressed() -> void:
	print("BuildingInspector: Upgrade pressed for", current_building)

	var target_building: BuildingData = current_building
	var gm = building_system
	if (target_building == null or gm == null) and gm != null:
		var sel_pos: Vector2i = gm.current_selected_grid_pos
		if gm.has_selected_building and gm.active_buildings.has(sel_pos):
			target_building = gm.active_buildings[sel_pos]

	if target_building == null and gm != null and has_last_selected_grid_pos:
		if gm.active_buildings.has(last_selected_grid_pos):
			target_building = gm.active_buildings[last_selected_grid_pos]

	if target_building == null or not gm:
		push_warning("BuildingInspector: No building available to upgrade")
		return

	if target_building.is_upgraded:
		push_warning("BuildingInspector: Building already upgraded")
		return

	# Determine upgrade cost
	var cost:int = GameConstants.UPGRADE_COST_BASE
	if target_building.building_type == BuildingData.BuildingType.WATER_RECYCLER or target_building.building_type == BuildingData.BuildingType.MED_CLINIC:
		cost = GameConstants.UPGRADE_COST_HIGH

	print("BuildingInspector: Upgrade cost", cost, "materials", ResourceManager.materials)
	if ResourceManager:
		print("[DEBUG] Before upgrade - power_capacity:", ResourceManager.power_capacity, "power_draw:", ResourceManager.power_draw, "net_power:", ResourceManager.net_power)
		if building_system:
			for pos in building_system.active_buildings.keys():
				var b = building_system.active_buildings[pos]
				print("[DEBUG] Building", b.building_name, "pos", pos, "base_power", b.base_production_power, "is_upgraded", b.is_upgraded, "workers", b.workers_assigned)

	# Play SFX for user feedback
	if AudioManager and AudioManager.has_method("play_build_sfx"):
		AudioManager.play_build_sfx("upgrade")

	if not ResourceManager.consume_materials(cost):
		push_warning("Upgrade failed: insufficient materials")
		return

	# Apply upgrade flag and update visuals/outputs
	target_building.is_upgraded = true

	# Adjust base production where applicable
	match target_building.building_type:
		BuildingData.BuildingType.COAL_GENERATOR:
			target_building.base_production_power = GameConstants.COAL_POWER_T2
		BuildingData.BuildingType.GEOTHERMAL_TAP:
			target_building.base_production_power = GameConstants.GEOTHERMAL_POWER_T2
		BuildingData.BuildingType.HYDROPONIC_BAY:
			target_building.base_production_food = GameConstants.UPGRADED_FOOD_RATE
		BuildingData.BuildingType.SHELTER_BLOCK:
			# capacity handled by BuildingSystem getters via is_upgraded flag
			pass
		BuildingData.BuildingType.RATION_STORE:
			ResourceManager.on_ration_store_built(true)
		_:
			pass
	
	# Set narrative upgrade flags
	if target_building.building_type == BuildingData.BuildingType.MED_CLINIC:
		GameManager.med_clinic_upgraded = true

	# Spawn particles first — visual swap waits for the burst to complete
	if gm and gm.has_method("spawn_upgrade_particles"):
		gm.spawn_upgrade_particles(target_building.grid_position, target_building.building_type)

	# Wait for particle duration before swapping the sprite
	await get_tree().create_timer(GameConstants.BUILDING_UPGRADE_PARTICLE_DURATION).timeout

	if gm and gm.has_method("apply_upgrade_visual"):
		gm.apply_upgrade_visual(target_building.grid_position)
	elif gm and gm.has_method("update_building_visual"):
		gm.update_building_visual(target_building.grid_position)

	if ResourceManager and ResourceManager.has_method("calculate_power"):
		ResourceManager.calculate_power()

	if ResourceManager:
		print("[DEBUG] After upgrade - power_capacity:", ResourceManager.power_capacity, "power_draw:", ResourceManager.power_draw, "net_power:", ResourceManager.net_power)
		if building_system:
			for pos in building_system.active_buildings.keys():
				var b2 = building_system.active_buildings[pos]
				print("[DEBUG] Building", b2.building_name, "pos", pos, "base_power", b2.base_production_power, "is_upgraded", b2.is_upgraded, "workers", b2.workers_assigned)

	_refresh_ui_text()
	print("BuildingInspector: Upgrade applied to", target_building)
