extends PanelContainer

# ══════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ══════════════════════════════════════════════════════════════════════════════
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var worker_label: Label = $VBoxContainer/WorkerLabel
@onready var output_label: Label = $VBoxContainer/OutputLabel
@onready var repair_button: Button = $VBoxContainer/RepairButton
@onready var upgrade_button: Button = $VBoxContainer/UpgradeButton
@onready var shield_button: Button = $VBoxContainer/ShieldButton

@export var building_system: Node 

# We track the currently selected building so we can disconnect signals when we click away
var current_building: BuildingData = null
var last_selected_grid_pos: Vector2i = Vector2i.ZERO
var has_last_selected_grid_pos: bool = false

# Worker assignment UI 
var _worker_minus_btn:  Button = null
var _worker_count_lbl:  Label  = null
var _worker_plus_btn:   Button = null
# Remove button and dialog
var _remove_btn:        Button              = null
var _remove_hint_lbl:   Label               = null
var _confirm_dialog:    ConfirmationDialog  = null

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

	_setup_worker_ui()
	_setup_remove_button()

	# Upgrade button handler
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
		upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		pass

	if shield_button:
		shield_button.pressed.connect(_on_shield_pressed)
		shield_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_worker_ui() -> void:
	var vbox = $VBoxContainer

	if worker_label:
		worker_label.visible = false

	# Worker assignment row
	var row := HBoxContainer.new()
	row.name = "WorkerAssignRow"
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	vbox.move_child(row, worker_label.get_index() + 1)

	var assign_lbl := Label.new()
	assign_lbl.text = "Workers"
	assign_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88, 1.0))
	assign_lbl.add_theme_font_size_override("font_size", 12)
	assign_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(assign_lbl)

	_worker_minus_btn = _make_worker_btn("−")
	_worker_minus_btn.pressed.connect(_on_worker_minus_pressed)
	row.add_child(_worker_minus_btn)

	_worker_count_lbl = Label.new()
	_worker_count_lbl.custom_minimum_size = Vector2(52, 0)
	_worker_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_worker_count_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.96, 1.0))
	_worker_count_lbl.add_theme_font_size_override("font_size", 13)
	_worker_count_lbl.text = "—"
	row.add_child(_worker_count_lbl)

	_worker_plus_btn = _make_worker_btn("+")
	_worker_plus_btn.pressed.connect(_on_worker_plus_pressed)
	row.add_child(_worker_plus_btn)

func _make_worker_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(34, 34)
	btn.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	n.bg_color    = Color(0.07, 0.12, 0.18, 1.0)
	n.border_color = Color(0.0, 0.75, 0.85, 0.55)
	n.set_border_width_all(1)
	n.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color     = Color(0.10, 0.22, 0.30, 1.0)
	h.border_color = Color(0.0, 0.96, 1.0, 0.9)
	h.set_border_width_all(1)
	h.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color(0.0, 0.96, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 17)
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	return btn

func _on_worker_plus_pressed() -> void:
	if not building_system or not current_building: return
	building_system.assign_worker()
	_animate_btn(_worker_plus_btn)
	_refresh_ui_text()

func _on_worker_minus_pressed() -> void:
	if not building_system or not current_building: return
	building_system.remove_worker(current_building.grid_position)
	_animate_btn(_worker_minus_btn)
	_refresh_ui_text()

func _animate_btn(btn: Button) -> void:
	if not btn: return
	var t := btn.create_tween()
	t.tween_property(btn, "scale", Vector2(1.30, 1.30), 0.07) \
	 .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12) \
	 .set_trans(Tween.TRANS_SINE)

func _setup_remove_button() -> void:
	var vbox = $VBoxContainer

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	# Instruction label
	_remove_hint_lbl = Label.new()
	_remove_hint_lbl.text = "⟵ Hold Right-Click on building to remove"
	_remove_hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48, 0.65))
	_remove_hint_lbl.add_theme_font_size_override("font_size", 9)
	_remove_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remove_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_remove_hint_lbl.visible = false
	vbox.add_child(_remove_hint_lbl)

	# Remove button
	_remove_btn = Button.new()
	_remove_btn.text = "⚠  Remove Building"
	_remove_btn.focus_mode = Control.FOCUS_NONE
	_remove_btn.custom_minimum_size = Vector2(0, 36)
	_remove_btn.visible = false
	var dn := StyleBoxFlat.new()
	dn.bg_color    = Color(0.18, 0.04, 0.04, 0.90)
	dn.border_color = Color(0.75, 0.12, 0.12, 0.70)
	dn.set_border_width_all(1)
	dn.set_corner_radius_all(3)
	_remove_btn.add_theme_stylebox_override("normal", dn)
	var dh := StyleBoxFlat.new()
	dh.bg_color    = Color(0.30, 0.05, 0.05, 0.90)
	dh.border_color = Color(0.92, 0.18, 0.18, 1.0)
	dh.set_border_width_all(1)
	dh.set_corner_radius_all(3)
	_remove_btn.add_theme_stylebox_override("hover", dh)
	_remove_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	_remove_btn.add_theme_font_size_override("font_size", 12)
	_remove_btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	_remove_btn.pressed.connect(_on_remove_pressed)
	vbox.add_child(_remove_btn)

	# Confirmation dialog
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Remove Building"
	_confirm_dialog.ok_button_text     = "Yes, Remove It"
	_confirm_dialog.cancel_button_text = "Cancel"
	_confirm_dialog.confirmed.connect(_on_removal_confirmed)
	add_child(_confirm_dialog)

func _on_remove_pressed() -> void:
	if not current_building: return
	_confirm_dialog.dialog_text = (
		"Remove %s?\n\n" % current_building.building_name +
		"• Assigned workers will be returned to the pool\n" +
		"• Materials spent are NOT refunded\n" +
		"• This action cannot be undone\n\n" +
		"Are you sure you want to remove this building?"
	)
	_confirm_dialog.popup_centered()

func _on_removal_confirmed() -> void:
	if not current_building: return
	var gm = building_system.grid_manager if building_system else null
	if not gm or not gm.has_method("arm_demolish"):
		push_warning("BuildingInspector: Cannot find arm_demolish on GridManager")
		return

	var pos := current_building.grid_position
	gm.arm_demolish(pos)

	# Change the remove button to show the instruction
	if _remove_btn:
		_remove_btn.text     = "Hold right-click on building to confirm"
		_remove_btn.disabled = true

	# Reset button after 12 seconds if the player doesn't follow through
	var t := create_tween()
	t.tween_interval(12.0)
	t.tween_callback(func():
		if _remove_btn:
			_remove_btn.text     = "⚠  Remove Building"
			_remove_btn.disabled = false
	)

func _find_building_system() -> Node:
	var root = get_tree().get_root()
	return _search_for_building_system(root)


func _search_for_building_system(node: Node) -> Node:
	if node != null and node.has_signal("building_selected_data") and node.has_method("get_effective_output"):
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

	# Shield button: show only during storm prep window and when not yet shielded
	if shield_button:
		var current_day: int = TimeManager.current_day if TimeManager else 0
		var in_storm_window: bool = current_day >= GameConstants.STORM_START_DAY \
			and current_day < GameConstants.STORM_HIT_DAY
		
		if in_storm_window and not current_building.is_shielded and not current_building.is_shielding:
			shield_button.visible = true
			shield_button.text = "Shield Building (%d mat)" % GameConstants.STORM_SHIELD_COST
			shield_button.disabled = GameManager.materials < GameConstants.STORM_SHIELD_COST
		elif in_storm_window and current_building.is_shielding:
			shield_button.visible = true
			shield_button.text = "Shielding... (%d/%d days)" \
				% [current_building.shield_days_accumulated, GameConstants.STORM_SHIELD_WORKER_DAYS]
			shield_button.disabled = true
		elif in_storm_window and current_building.is_shielded:
			shield_button.visible = true
			shield_button.text = "✓ Shielded"
			shield_button.disabled = true
		else:
			shield_button.visible = false

	# ── Worker assignment buttons ──────────────────────────────────────────────
	if _worker_count_lbl and current_building:
		if current_building.worker_capacity > 0:
			_worker_count_lbl.text = "%d / %d" % [
				current_building.workers_assigned,
				current_building.worker_capacity
			]
			if _worker_plus_btn:
				_worker_plus_btn.disabled = (
					current_building.workers_assigned >= current_building.worker_capacity
					or GameManager.available_workers <= 0
				)
			if _worker_minus_btn:
				_worker_minus_btn.disabled = (current_building.workers_assigned <= 0)
		else:
			_worker_count_lbl.text = "Passive"
			if _worker_plus_btn:  _worker_plus_btn.disabled  = true
			if _worker_minus_btn: _worker_minus_btn.disabled = true

	# ── Remove button visibility ───────────────────────────────────────────────
	var show_remove := current_building != null
	if _remove_btn:       _remove_btn.visible      = show_remove
	if _remove_hint_lbl:  _remove_hint_lbl.visible = show_remove

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

	if target_building.building_type == BuildingData.BuildingType.MED_CLINIC:
		if GameManager:
			GameManager.med_clinic_upgraded_to_tier_2 = true

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
		GameManager.med_clinic_upgraded_to_tier_2 = true

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

func _on_shield_pressed() -> void:
	var target_building: BuildingData = current_building
	var gm = building_system
	
	if target_building == null and gm != null and has_last_selected_grid_pos:
		if gm.active_buildings.has(last_selected_grid_pos):
			target_building = gm.active_buildings[last_selected_grid_pos]
	
	if target_building == null or not gm:
		push_warning("BuildingInspector: No building available to shield")
		return
	
	var ok: bool = gm.begin_shield(target_building.grid_position)
	if ok:
		_refresh_ui_text()
	else:
		push_warning("BuildingInspector: Shield failed — check materials or building state")
