# UI panel for shielding buildings ahead of the storm (Day 35 mechanic)
extends CanvasLayer

const C_BG      := Color(0.03, 0.04, 0.10, 0.95)
const C_BORDER  := Color(1.00, 0.55, 0.10, 0.70)
const C_TITLE   := Color(1.00, 0.72, 0.28, 1.00)
const C_SHIELDED := Color(0.35, 0.88, 0.48, 1.00)
const C_SHIELDING := Color(0.30, 0.65, 1.00, 1.00)
const C_EXPOSED  := Color(1.00, 0.45, 0.35, 1.00)
const C_HINT     := Color(0.55, 0.55, 0.60, 0.80)

var _root:       Control = null
var _list_vbox:  VBoxContainer = null
var _bs:         Node = null

# Initialize and connect to TimeManager for storm day updates
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1   
	_build_ui()
	visible = false
	await get_tree().process_frame
	_bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)

# Construct the shield panel UI elements
func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left   = 0.0
	_root.anchor_right  = 0.0
	_root.anchor_top    = 0.0
	_root.anchor_bottom = 0.0  
	_root.offset_left   = 16.0 
	_root.offset_right  = 236.0 
	_root.offset_top    = 120.0 
	_root.offset_bottom = 420.0 
	_root.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.color        = C_BG
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var right_line := ColorRect.new()
	right_line.color         = C_BORDER
	right_line.anchor_left   = 1.0
	right_line.anchor_right  = 1.0
	right_line.anchor_bottom = 1.0
	right_line.offset_left   = -1.0
	right_line.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right_line)

	var outer := VBoxContainer.new()
	outer.anchor_right  = 1.0
	outer.anchor_bottom = 1.0
	outer.offset_left   = 8.0
	outer.offset_right  = -8.0
	outer.offset_top    = 6.0
	outer.offset_bottom = -6.0
	outer.add_theme_constant_override("separation", 4)
	outer.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(outer)

	# Title
	var title := Label.new()
	title.text = "⚡ STORM PREPARATION"
	title.add_theme_color_override("font_color", C_TITLE)
	title.add_theme_font_size_override("font_size", 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(title)

	var hint := Label.new()
	hint.text = "Select a building → Shield it\nbefore Day 35"
	hint.add_theme_color_override("font_color", C_HINT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(hint)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.30))
	outer.add_child(sep)

	# Scroll area for building list
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter           = Control.MOUSE_FILTER_PASS
	outer.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 3)
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list_vbox)

# Called when the day advances to show/hide and refresh the panel
func _on_day_changed(day: int) -> void:
	if day == GameConstants.STORM_START_DAY:
		visible = true
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.35)
	if day >= GameConstants.STORM_START_DAY and day < GameConstants.STORM_HIT_DAY:
		_refresh_list(day)
	if day >= GameConstants.STORM_HIT_DAY:
		visible = false

# Repopulate the building list showing shield status and days remaining
func _refresh_list(current_day: int) -> void:
	if not _list_vbox: return
	for child in _list_vbox.get_children():
		child.queue_free()
	if not _bs: return

	var days_left: int = GameConstants.STORM_HIT_DAY - current_day
	var countdown := Label.new()
	countdown.text = "⚡ Storm in %d day%s" % [days_left, "s" if days_left != 1 else ""]
	countdown.add_theme_color_override("font_color",
		Color(1.0, 0.30, 0.30, 1.0) if days_left <= 3 else C_TITLE)
	countdown.add_theme_font_size_override("font_size", 11)
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_vbox.add_child(countdown)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.35, 0.35, 0.40, 0.35))
	_list_vbox.add_child(sep2)

	for pos in _bs.active_buildings:
		var b: BuildingData = _bs.active_buildings[pos]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list_vbox.add_child(row)

		var icon_lbl := Label.new()
		icon_lbl.add_theme_font_size_override("font_size", 12)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = b.building_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var state_lbl := Label.new()
		state_lbl.add_theme_font_size_override("font_size", 10)
		state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		row.add_child(state_lbl)

		if b.is_shielded:
			icon_lbl.text = "✅"
			name_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.80))
			state_lbl.text = "Shielded"
			state_lbl.add_theme_color_override("font_color", C_SHIELDED)
		elif b.is_shielding:
			icon_lbl.text = "🔷"
			name_lbl.add_theme_color_override("font_color", C_SHIELDING)
			state_lbl.text = "%d/%d" % [b.shield_days_accumulated, GameConstants.STORM_SHIELD_WORKER_DAYS]
			state_lbl.add_theme_color_override("font_color", C_SHIELDING)
		else:
			icon_lbl.text = "⚠"
			name_lbl.add_theme_color_override("font_color", C_EXPOSED)
			state_lbl.text = "Exposed"
			state_lbl.add_theme_color_override("font_color", C_EXPOSED)

# Reset visibility and clear the list for a fresh game
func reset_for_new_game() -> void:
	visible = false
	if _root:
		_root.modulate.a = 0.0
	if _list_vbox:
		for child in _list_vbox.get_children():
			child.queue_free()
