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
var memorial_panel: Panel

# Worker assignment UI 
var _worker_minus_btn:  Button = null
var _worker_count_lbl:  Label  = null
var _worker_plus_btn:   Button = null
# Remove button and dialog
var _remove_btn:        Button              = null
var _remove_hint_lbl:   Label               = null
var _confirm_dialog:    ConfirmationDialog  = null

var _terminal_btn: Button = null

var _repositioning: bool = false
var _mat_icon_tex: Texture2D = null
var _mat_icon_cache: Dictionary = {}
var _cost_content: Dictionary = {}

# Initialize the building inspector panel.
func _ready() -> void:
	# Hide the panel by default
	visible = false
	modulate.a = 0.0 # Make it totally transparent for our fade-in effect
	z_index = 100
	
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
	
	# Memorial panel
	memorial_panel = get_tree().root.get_node_or_null("Main/UILayer/MemorialPanel")
	if not memorial_panel:
		memorial_panel = get_tree().root.find_child("MemorialPanel", true, false) as Panel

	if shield_button:
		shield_button.pressed.connect(_on_shield_pressed)
		shield_button.mouse_filter = Control.MOUSE_FILTER_STOP

	_cache_material_icon()

 # Build the worker assignment UI row and controls
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

	# "Fill All" button
	var fill_btn := Button.new()
	fill_btn.text = "Fill"
	fill_btn.custom_minimum_size = Vector2(38, 34)
	fill_btn.focus_mode = Control.FOCUS_NONE
	var fs := StyleBoxFlat.new()
	fs.bg_color    = Color(0.04, 0.18, 0.12, 1.0)
	fs.border_color = Color(0.0, 0.75, 0.50, 0.60)
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(4)
	fill_btn.add_theme_stylebox_override("normal", fs)
	var fh := StyleBoxFlat.new()
	fh.bg_color    = Color(0.06, 0.28, 0.18, 1.0)
	fh.border_color = Color(0.0, 0.95, 0.65, 0.90)
	fh.set_border_width_all(1)
	fh.set_corner_radius_all(4)
	fill_btn.add_theme_stylebox_override("hover", fh)
	fill_btn.add_theme_color_override("font_color", Color(0.35, 0.95, 0.60, 1.0))
	fill_btn.add_theme_font_size_override("font_size", 11)
	fill_btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	fill_btn.pressed.connect(_on_fill_workers_pressed)
	row.add_child(fill_btn)

	_setup_terminal_button()

 # Fill all available worker slots for the current building
func _on_fill_workers_pressed() -> void:
	if not building_system or not current_building: return
	var slots_needed: int = current_building.worker_capacity - current_building.workers_assigned
	var can_assign:   int = mini(slots_needed, GameManager.available_workers)
	for i in range(can_assign):
		building_system.assign_worker()
	if can_assign > 0:
		_animate_btn(_worker_plus_btn)
	_refresh_ui_text()

# Create a styled worker control button.
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

# Increase the assigned worker count.
func _on_worker_plus_pressed() -> void:
	if not building_system or not current_building: return
	building_system.assign_worker()
	_animate_btn(_worker_plus_btn)
	_refresh_ui_text()

# Decrease the assigned worker count.
func _on_worker_minus_pressed() -> void:
	if not building_system or not current_building: return
	building_system.remove_worker(current_building.grid_position)
	_animate_btn(_worker_minus_btn)
	_refresh_ui_text()

# Animate a pressed worker button.
func _animate_btn(btn: Button) -> void:
	if not btn: return
	var t := btn.create_tween()
	t.tween_property(btn, "scale", Vector2(1.30, 1.30), 0.07) \
	 .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12) \
	 .set_trans(Tween.TRANS_SINE)

 # Create and wire the remove-building UI and confirmation dialog
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

 # Show confirmation dialog before removing a building
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

# Confirm and execute building removal.
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

# Find the building system node.
func _find_building_system() -> Node:
	var root = get_tree().get_root()
	return _search_for_building_system(root)

# Search the tree for the building system.
func _search_for_building_system(node: Node) -> Node:
	if node != null and node.has_signal("building_selected_data") and node.has_method("get_effective_output"):
		return node
	for child in node.get_children():
		if child is Node:
			var found = _search_for_building_system(child)
			if found:
				return found
	return null

# Build the terminal access button.
func _setup_terminal_button() -> void:
	var vbox = $VBoxContainer
	
	_terminal_btn = Button.new()
	_terminal_btn.text = "◈  MERIDIAN Terminal"
	_terminal_btn.focus_mode = Control.FOCUS_NONE
	_terminal_btn.custom_minimum_size = Vector2(0, 36)
	_terminal_btn.visible = false   # only shown for Archive Hall

	var tn := StyleBoxFlat.new()
	tn.bg_color    = Color(0.05, 0.03, 0.12, 0.90)
	tn.border_color = Color(0.61, 0.35, 1.0, 0.60)
	tn.set_border_width_all(1)
	tn.set_corner_radius_all(3)
	_terminal_btn.add_theme_stylebox_override("normal", tn)

	var th := StyleBoxFlat.new()
	th.bg_color    = Color(0.09, 0.05, 0.20, 0.90)
	th.border_color = Color(0.61, 0.35, 1.0, 1.0)
	th.set_border_width_all(1)
	th.set_corner_radius_all(3)
	_terminal_btn.add_theme_stylebox_override("hover", th)

	_terminal_btn.add_theme_color_override("font_color", Color(0.61, 0.35, 1.0, 1.0))
	_terminal_btn.add_theme_font_size_override("font_size", 12)
	_terminal_btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	_terminal_btn.pressed.connect(_on_terminal_pressed)
	_terminal_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_terminal_btn)

# Cache the material icon texture.
func _cache_material_icon() -> void:
	if _mat_icon_tex:
		return
	var icon_node = get_tree().root.get_node_or_null("Main/UILayer/HUD/MaterialsIcon")
	if not icon_node:
		icon_node = get_tree().root.find_child("MaterialsIcon", true, false)
	if icon_node is TextureRect:
		_mat_icon_tex = (icon_node as TextureRect).texture
	elif icon_node is Sprite2D:
		_mat_icon_tex = (icon_node as Sprite2D).texture
	_mat_icon_cache.clear()

# Determine the font size for a button.
func _get_button_font_size(btn: Button) -> int:
	var font_size := btn.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 12
	return font_size

# Return a material icon scaled to height.
func _get_scaled_mat_icon(target_h: int) -> Texture2D:
	if not _mat_icon_tex:
		return null
	var h := clampi(target_h, 10, 20)
	if _mat_icon_cache.has(h):
		return _mat_icon_cache[h]
	var img := _mat_icon_tex.get_image()
	if not img:
		return _mat_icon_tex
	var src_h := img.get_height()
	if src_h <= 0:
		return _mat_icon_tex
	var target_scale := float(h) / float(src_h)
	var w := maxi(1, int(round(img.get_width() * target_scale)))
	var scaled := img.duplicate()
	scaled.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(scaled)
	_mat_icon_cache[h] = tex
	return tex


# Ensure the button has cost content nodes.
func _ensure_cost_content(btn: Button) -> Dictionary:
	if not btn:
		return {}
	if _cost_content.has(btn):
		return _cost_content[btn]

	btn.text = ""

	var row := HBoxContainer.new()
	row.name = "CostContent"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_child(row)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	row.add_child(icon)

	_cost_content[btn] = {"label": lbl, "icon": icon, "row": row}
	_sync_cost_label_style(btn, lbl)
	return _cost_content[btn]

# Sync the cost label style to the button.
func _sync_cost_label_style(btn: Button, lbl: Label) -> void:
	var font_size := _get_button_font_size(btn)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", btn.get_theme_color("font_color"))

# Update the cost button label and icon.
func _set_cost_button_text(btn: Button, text: String, show_icon: bool) -> void:
	if not btn:
		return
	var content: Dictionary = _ensure_cost_content(btn)
	if content.is_empty():
		return
	var lbl: Label = content["label"]
	var icon: TextureRect = content["icon"]
	var row: HBoxContainer = content["row"]
	lbl.text = text
	_sync_cost_label_style(btn, lbl)
	if show_icon and _mat_icon_tex:
		var font_size := _get_button_font_size(btn)
		icon.texture = _get_scaled_mat_icon(int(round(font_size * 0.95)))
		icon.custom_minimum_size = Vector2(font_size, font_size)
		icon.visible = true
	else:
		icon.texture = null
		icon.visible = false
	if row:
		var content_min := row.get_combined_minimum_size()
		var pad := Vector2(16, 10)
		btn.custom_minimum_size = Vector2(
			maxf(btn.custom_minimum_size.x, content_min.x + pad.x),
			maxf(btn.custom_minimum_size.y, content_min.y + pad.y)
		)


# Open the building terminal panel.
func _on_terminal_pressed() -> void:
	var terminal = get_tree().root.get_node_or_null("Main/MeridianTerminal")
	if terminal and terminal.has_method("open_terminal"):
		terminal.open_terminal()
	else:
		push_warning("BuildingInspector: MeridianTerminal not found at Main/MeridianTerminal")

# Reposition the panel to fit the content.
func _reposition_for_content() -> void:
	if _repositioning or not visible:
		return
	_repositioning = true
	await get_tree().process_frame
	_repositioning = false

	var vp_size: Vector2  = get_viewport_rect().size
	var panel_h: float    = size.y if size.y > 20.0 else get_combined_minimum_size().y
	var panel_w: float    = size.x if size.x > 20.0 else get_combined_minimum_size().x

	if global_position.y + panel_h > vp_size.y - 8.0:
		global_position.y = maxf(8.0, vp_size.y - panel_h - 8.0)

	if global_position.y < 8.0:
		global_position.y = 8.0

	if global_position.x + panel_w > vp_size.x - 8.0:
		global_position.x = maxf(8.0, vp_size.x - panel_w - 8.0)

# ══════════════════════════════════════════════════════════════════════════════
# SELECTION HANDLING
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_selected(b_data: BuildingData) -> void:
	print("BuildingInspector: _on_building_selected called with", b_data)
	# Disconnect from the old building
	if current_building != null and current_building.staffing_changed.is_connected(_on_staffing_changed):
		current_building.staffing_changed.disconnect(_on_staffing_changed)
		
	current_building = b_data

	if current_building != null:
		last_selected_grid_pos = current_building.grid_position
		has_last_selected_grid_pos = true
	
	# If click the deselected, hide the UI
	if current_building == null:
		_hide_panel()
		return
	
	# Open the memorial panel 
	if current_building.building_type == BuildingData.BuildingType.MEMORIAL_WALL:
		if not memorial_panel:
			memorial_panel = get_tree().root.get_node_or_null("Main/UILayer/MemorialPanel")
			if not memorial_panel:
				memorial_panel = get_tree().root.find_child("MemorialPanel", true, false) as Panel
		if memorial_panel and memorial_panel.has_method("open_memorial"):
			memorial_panel.open_memorial()
		_hide_panel()
		return
		
	# Connect to its specific data signal
	current_building.staffing_changed.connect(_on_staffing_changed)
	
	# Update the text and show the panel
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
			if _mat_icon_tex:
				_set_cost_button_text(shield_button, "Shield Building %d" % GameConstants.STORM_SHIELD_COST, true)
			else:
				_set_cost_button_text(shield_button, "Shield Building (%d mat)" % GameConstants.STORM_SHIELD_COST, false)
			shield_button.disabled = GameManager.materials < GameConstants.STORM_SHIELD_COST
		elif in_storm_window and current_building.is_shielding:
			shield_button.visible = true
			_set_cost_button_text(shield_button,
				"Shielding... (%d/%d days)" \
				% [current_building.shield_days_accumulated, GameConstants.STORM_SHIELD_WORKER_DAYS],
				false)
			shield_button.disabled = true
		elif in_storm_window and current_building.is_shielded:
			shield_button.visible = true
			_set_cost_button_text(shield_button, "✓ Shielded", false)
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
	
	# ── Live output display ────────────────────────────────────────────────────
	if output_label and current_building and building_system:
		var out = building_system.get_effective_output(current_building.grid_position)
		var lines: Array[String] = ["Live Output:"]
		if out.get("power", 0.0) != 0.0:
			lines.append("  ⚡ Power: %+.0f kW" % out["power"])
		if out.get("food", 0.0) != 0.0:
			lines.append("  🍲 Food: %+.0f/day" % out["food"])
		if out.get("morale", 0.0) != 0.0:
			lines.append("  ✦ Morale: %+.0f/day" % out["morale"])
		if current_building.base_passive_morale > 0.0:
			lines.append("  ✦ Passive: %+.0f/day" % current_building.base_passive_morale)
		if lines.size() == 1:
			lines.append("  Status: Active")
		# Append damage/power warning
		if current_building.is_damaged:
			lines.append("  ⚠ DAMAGED — 30% output")
		if not current_building.is_powered and current_building.power_draw > 0.0:
			lines.append("  ⚫ UNPOWERED — offline")
		output_label.text = "\n".join(lines)

	# Morale efficiency penalty warning
	if ResourceManager \
			and ResourceManager.morale < GameConstants.MORALE_EFFICIENCY_THRESHOLD \
			and output_label:
		output_label.text += "\n  ⚠ LOW MORALE — all output ×80%"
		output_label.add_theme_color_override("font_color",
			GameConstants.UI_COLOR_WARNING)

	# ── Upgrade button: show materials availability ────────────────────────────
	if upgrade_button and not current_building.is_upgraded:
		var u_cost := GameConstants.UPGRADE_COST_BASE
		if current_building.building_type == BuildingData.BuildingType.WATER_RECYCLER \
				or current_building.building_type == BuildingData.BuildingType.MED_CLINIC:
			u_cost = GameConstants.UPGRADE_COST_HIGH
		var mat: int = GameManager.materials
		if mat >= u_cost:
			upgrade_button.add_theme_color_override("font_color", Color(0.0, 0.95, 0.70, 1.0))
			if _mat_icon_tex:
				_set_cost_button_text(upgrade_button, "Upgrade %d" % u_cost, true)
			else:
				_set_cost_button_text(upgrade_button, "Upgrade  (%d mat)" % u_cost, false)
		else:
			upgrade_button.add_theme_color_override("font_color", Color(0.80, 0.40, 0.40, 1.0))
			if _mat_icon_tex:
				_set_cost_button_text(upgrade_button,
					"Upgrade %d — need %d more" % [u_cost, u_cost - mat],
					true)
			else:
				_set_cost_button_text(upgrade_button,
					"Upgrade  (%d mat — need %d more)" % [u_cost, u_cost - mat],
					false)

	# ── Remove button visibility ───────────────────────────────────────────────
	var show_remove := current_building != null
	if _remove_btn:       _remove_btn.visible      = show_remove
	if _remove_hint_lbl:  _remove_hint_lbl.visible = show_remove

	# Days until damage countdown
	if current_building.workers_assigned == 0 \
			and current_building.worker_capacity > 0 \
			and not current_building.is_damaged:
		var days_left: int = GameConstants.BUILDING_DAMAGE_DAYS \
			- current_building.days_unstaffed
		if days_left > 0 and output_label:
			output_label.text += "\n  ⚠ Damages in %d day%s if unstaffed" \
				% [days_left, "s" if days_left != 1 else ""]
			output_label.add_theme_color_override("font_color",
				GameConstants.UI_COLOR_WARNING)

	# Terminal button — only visible for Archive Hall
	if _terminal_btn:
		var is_archive: bool = (
			current_building != null
			and current_building.building_type == BuildingData.BuildingType.ARCHIVE_HALL
		)
		_terminal_btn.visible = is_archive
		if is_archive:
			var trusted: bool = GameManager.meridian_trusted
			_terminal_btn.text = "◈  MERIDIAN Terminal" if trusted \
				else "◈  MERIDIAN Terminal  [limited]"

	call_deferred("_reposition_for_content")

# Update the inspector when a building state changes.
func _on_building_state_changed(grid_pos: Vector2i) -> void:
	# If the changed building is the current selection, refresh the UI so Repair appears
	if current_building and current_building.grid_position == grid_pos:
		_refresh_ui_text()

# ══════════════════════════════════════════════════════════════════════════════
# UX JUICE (Animations)
# ══════════════════════════════════════════════════════════════════════════════
func _show_panel() -> void:
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	call_deferred("_reposition_for_content")

# Hide the inspector panel.
func _hide_panel() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): visible = false) # Hide it fully after the fade finishes

# Start a building repair action.
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
				pass
	else:
		pass

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

# Start a building upgrade action.
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

# Toggle the building shield state.
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
