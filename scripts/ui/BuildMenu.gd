extends CanvasLayer

signal build_menu_opened
signal build_menu_closed

# ─────────────────────────────────────────────────────────────────────────────
# COLOURS 
# ─────────────────────────────────────────────────────────────────────────────
const COL_BG:         Color = Color(0.04, 0.04, 0.10, 0.97)
const COL_BORDER:     Color = Color(0.0,  0.96, 1.0,  0.65)
const COL_HEADER:     Color = Color(0.0,  0.96, 1.0,  1.0)
const COL_TIER_LABEL: Color = Color(0.35, 0.72, 0.78, 0.85)
const COL_BTN_NORMAL: Color = Color(0.06, 0.08, 0.14, 1.0)
const COL_BTN_HOVER:  Color = Color(0.08, 0.18, 0.24, 1.0)
const COL_BTN_ACTIVE: Color = Color(0.02, 0.34, 0.40, 1.0)
const COL_BTN_GREY:   Color = Color(0.06, 0.06, 0.09, 0.55)
const COL_NAME:       Color = Color(0.88, 0.93, 0.96, 1.0)
const COL_COST:       Color = Color(0.50, 0.82, 1.0,  0.9)
const COL_FREE:       Color = Color(0.42, 0.68, 0.48, 0.85)
const COL_WORKERS:    Color = Color(0.60, 0.82, 0.65, 0.85)
const COL_PASSIVE:    Color = Color(0.46, 0.58, 0.62, 0.75)
const COL_SEPARATOR:  Color = Color(0.0,  0.96, 1.0,  0.18)

# ─────────────────────────────────────────────────────────────────────────────
# BUILDING DEFINITIONS
# ─────────────────────────────────────────────────────────────────────────────
var _building_defs: Array = []

func _init_building_defs() -> void:
	_building_defs = [
		# ── Build These First ──────────────────────────────────────────────
		["Coal Generator",   "coal",       6,  GameConstants.BUILD_COST_COAL_GENERATOR,  "first",      false],
		["Water Recycler",   "water",      12, GameConstants.BUILD_COST_WATER_RECYCLER,  "first",      false],
		["Hydroponic Bay",   "hydro",      10, GameConstants.BUILD_COST_HYDROPONIC_BAY,  "first",      false],
		["Shelter Block",    "shelter",    0,  GameConstants.BUILD_COST_SHELTER_BLOCK,   "first",      false],
		# ── Build When Stable ──────────────────────────────────────────────
		["Med Clinic",       "med",        14, GameConstants.BUILD_COST_MED_CLINIC,      "stable",     false],
		["Ration Store",     "ration",     0,  GameConstants.BUILD_COST_RATION_STORE,    "stable",     false],
		["Relay Hub",        "relay",      8,  GameConstants.BUILD_COST_RELAY_HUB,       "stable",     false],
		["Geothermal Tap",   "geothermal", 0,  GameConstants.BUILD_COST_GEOTHERMAL_TAP,  "stable",     false],
		# ── Build When Ready ───────────────────────────────────────────────
		["Archive Hall",     "archive",    12, GameConstants.BUILD_COST_ARCHIVE_HALL,    "ready",      false],
		["Memorial Wall",    "memorial",   0,  GameConstants.BUILD_COST_MEMORIAL_WALL,   "ready",      false],
		# ── Decoration ─────────────────────────────────────────────────────
		["Neon Inlay (H)",   "neon_h",     0,  0,                                         "decoration", true],
		["Neon Inlay (D)",   "neon_d",     0,  0,                                         "decoration", true],
		["Cable Run (H)",    "cable_h",    0,  0,                                         "decoration", true],
		["Cable Run (D)",    "cable_d",    0,  0,                                         "decoration", true],
	]

const TIER_HEADERS: Dictionary = {
	"first":      "▸  BUILD THESE FIRST",
	"stable":     "▸  BUILD WHEN STABLE",
	"ready":      "▸  BUILD WHEN READY",
	"decoration": "▸  DECORATION",
}

# ─────────────────────────────────────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────────────────────────────────────
var is_open: bool = false
var _active_type: String = ""
var _buttons: Dictionary = {}          # b_type → Button
var _root_panel: Panel = null
var _grid_manager: Node = null

# ─────────────────────────────────────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 90    

	_init_building_defs()
	_build_ui()
	visible = false

	call_deferred("_connect_grid_manager")

func _connect_grid_manager() -> void:
	_grid_manager = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
	if not _grid_manager:
		push_warning("BuildMenu: GridManager not found at Main/GameWorld/GridSystem.")
		return
	if _grid_manager.has_signal("building_placed"):
		_grid_manager.building_placed.connect(
			func(_type: String, _pos: Vector2i): _on_building_placed_externally()
		)
	print("BuildMenu: Connected to GridManager.")

# ─────────────────────────────────────────────────────────────────────────────
# UI CONSTRUCTION  
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# ── Root panel — anchored to the right edge of the screen ────────────────
	_root_panel = Panel.new()
	_root_panel.name = "BuildMenuPanel"

	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	bg.border_color = COL_BORDER
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.content_margin_left   = 10.0
	bg.content_margin_right  = 10.0
	bg.content_margin_top    = 8.0
	bg.content_margin_bottom = 8.0
	_root_panel.add_theme_stylebox_override("panel", bg)

	# Position: right side, below the HUD strip (offset_top = 70)
	_root_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -252.0)
	_root_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0,   -8.0)
	_root_panel.set_anchor_and_offset(SIDE_TOP,    0.0,   70.0)
	_root_panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0,   -8.0)
	add_child(_root_panel)

	# ── Outer VBox ────────────────────────────────────────────────────────────
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 0)
	outer.add_theme_constant_override("separation", 4)
	_root_panel.add_child(outer)

	# ── Header row ────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)

	var title := Label.new()
	title.text = "CONSTRUCT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", COL_HEADER)
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "[B]"
	hint.add_theme_color_override("font_color", Color(0.4, 0.55, 0.6, 0.7))
	hint.add_theme_font_size_override("font_size", 11)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(hint)

	var close_btn := Button.new()
	close_btn.text        = "✕"
	close_btn.flat        = true
	close_btn.focus_mode  = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.add_theme_color_override("font_color", COL_HEADER)
	close_btn.pressed.connect(close)
	close_btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	header.add_child(close_btn)

	# ── Top separator ─────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", COL_SEPARATOR)
	outer.add_child(sep)

	# ── Scroll container for building buttons ─────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical                = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode            = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode              = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "ContentBox"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	scroll.add_child(content)

	# ── Build sections tier order ──────────────────────────────────────
	_build_tier_section(content, "first")
	_build_tier_section(content, "stable")
	_build_tier_section(content, "ready")
	_build_tier_section(content, "decoration")

func _build_tier_section(parent: VBoxContainer, tier: String) -> void:
	# Spacer before each tier (except the first)
	if tier != "first":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 5)
		parent.add_child(spacer)

	# Tier label
	var tier_lbl := Label.new()
	tier_lbl.text = TIER_HEADERS.get(tier, tier.to_upper())
	tier_lbl.add_theme_color_override("font_color", COL_TIER_LABEL)
	tier_lbl.add_theme_font_size_override("font_size", 10)
	parent.add_child(tier_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", COL_SEPARATOR)
	parent.add_child(sep)

	# Building buttons for this tier
	for def in _building_defs:
		if def[4] != tier:
			continue
		var btn := _create_building_button(def[0], def[1], def[2], def[3], def[4], def[5])
		parent.add_child(btn)
		_buttons[def[1]] = btn

func _create_building_button(
		display_name:  String,
		b_type:        String,
		worker_slots:  int,
		cost:          int,
		_tier:         String,
		is_decoration: bool) -> Button:

	var btn := Button.new()
	btn.flat                  = true
	btn.focus_mode            = Control.FOCUS_NONE
	btn.mouse_filter          = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size   = Vector2(0, 44)

	# Styles
	btn.add_theme_stylebox_override("normal",  _make_btn_style(COL_BTN_NORMAL, 0))
	btn.add_theme_stylebox_override("hover",   _make_btn_style(COL_BTN_HOVER,  1))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(COL_BTN_ACTIVE, 1))

	# Content row (name left, stats right)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text                    = display_name
	name_lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COL_NAME)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.mouse_filter            = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 1)
	stats.alignment    = BoxContainer.ALIGNMENT_CENTER
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(stats)

	# Cost label
	var cost_lbl := Label.new()
	if cost == 0:
		cost_lbl.text = "Free"
		cost_lbl.add_theme_color_override("font_color", COL_FREE)
	else:
		cost_lbl.text = "%d mat" % cost
		cost_lbl.add_theme_color_override("font_color", COL_COST)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	stats.add_child(cost_lbl)

	# Worker slot label (not shown for decoration tiles)
	if not is_decoration:
		var wk_lbl := Label.new()
		if worker_slots > 0:
			wk_lbl.text = "%d slots" % worker_slots
			wk_lbl.add_theme_color_override("font_color", COL_WORKERS)
		else:
			wk_lbl.text = "passive"
			wk_lbl.add_theme_color_override("font_color", COL_PASSIVE)
		wk_lbl.add_theme_font_size_override("font_size", 10)
		wk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		wk_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		stats.add_child(wk_lbl)

	# Signals
	btn.pressed.connect(
		Callable(self, "_on_building_button_pressed").bind(b_type, is_decoration)
	)
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))

	# Initial greyed state for Memorial Wall
	if b_type == "memorial":
		_apply_greyed_style(btn)

	return btn

func _make_btn_style(bg_color: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_corner_radius_all(3)
	s.set_border_width_all(border_width)
	if border_width > 0:
		s.border_color = Color(0.0, 0.65, 0.76, 0.55)
	return s

# ─────────────────────────────────────────────────────────────────────────────
# BUTTON INTERACTION
# ─────────────────────────────────────────────────────────────────────────────
func _on_building_button_pressed(b_type: String, is_decoration: bool) -> void:
	if not _grid_manager:
		push_warning("BuildMenu: GridManager not available.")
		return

	# Memorial Wall is locked until at least one named character has died
	if b_type == "memorial" and not _is_memorial_available():
		_flash_unavailable(b_type)
		return

	AudioManager.play_ui_sfx("click")

	# Clicking the already-active type cancels it
	if _active_type == b_type:
		_deactivate()
		return

	_deactivate()
	_active_type = b_type
	_apply_active_style(b_type)

	if is_decoration:
		_grid_manager.enter_decoration_mode(b_type)
	else:
		_grid_manager.enter_build_mode(b_type)

func _on_building_placed_externally() -> void:
	# Called after the player successfully places a building from the grid.
	# Reset the active button so the menu reflects the idle state.
	if _active_type != "":
		_restore_normal_style(_active_type)
		_active_type = ""

func _deactivate() -> void:
	if _active_type == "":
		return
	_restore_normal_style(_active_type)
	# Exit whichever mode is active in GridManager
	if _grid_manager:
		if _grid_manager.current_build_scene != null:
			_grid_manager.exit_build_mode()
		if _grid_manager.current_decoration_type != "":
			_grid_manager.exit_decoration_mode()
	_active_type = ""

# ─────────────────────────────────────────────────────────────────────────────
# STYLE HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _apply_active_style(b_type: String) -> void:
	if not _buttons.has(b_type):
		return
	var s := StyleBoxFlat.new()
	s.bg_color = COL_BTN_ACTIVE
	s.set_corner_radius_all(3)
	s.border_color = COL_BORDER
	s.set_border_width_all(1)
	_buttons[b_type].add_theme_stylebox_override("normal", s)

func _restore_normal_style(b_type: String) -> void:
	if not _buttons.has(b_type):
		return
	if b_type == "memorial" and not _is_memorial_available():
		_apply_greyed_style(_buttons[b_type])
		return
	_buttons[b_type].add_theme_stylebox_override("normal",
		_make_btn_style(COL_BTN_NORMAL, 0))

func _apply_greyed_style(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = COL_BTN_GREY
	s.set_corner_radius_all(3)
	s.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", s)
	btn.modulate = Color(0.55, 0.55, 0.58, 0.65)

func _flash_unavailable(b_type: String) -> void:
	if not _buttons.has(b_type):
		return
	AudioManager.play_build_sfx("invalid")
	var btn: Button = _buttons[b_type]
	var flash_s := StyleBoxFlat.new()
	flash_s.bg_color = Color(0.32, 0.04, 0.04, 0.9)
	flash_s.border_color = Color(0.75, 0.12, 0.12, 1.0)
	flash_s.set_border_width_all(1)
	flash_s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", flash_s)
	var tween := create_tween()
	tween.tween_interval(0.32)
	tween.tween_callback(func(): _apply_greyed_style(btn))

# ─────────────────────────────────────────────────────────────────────────────
# MEMORIAL WALL AVAILABILITY
# ─────────────────────────────────────────────────────────────────────────────
func _is_memorial_available() -> bool:
	return (not GameManager.yuna_alive)   or \
		   (not GameManager.rook_alive)   or \
		   (not GameManager.vasquez_alive) or \
		   (not GameManager.meridian_alive)

# Called from Main.gd when a named character dies, to update the button state.
func refresh_memorial_button() -> void:
	if not _buttons.has("memorial"):
		return
	var btn: Button = _buttons["memorial"]
	if _is_memorial_available():
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		btn.add_theme_stylebox_override("normal", _make_btn_style(COL_BTN_NORMAL, 0))
	else:
		_apply_greyed_style(btn)

# ─────────────────────────────────────────────────────────────────────────────
# OPEN / CLOSE / TOGGLE
# ─────────────────────────────────────────────────────────────────────────────
func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	refresh_memorial_button()
	build_menu_opened.emit()
	_root_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root_panel, "modulate:a", 1.0, 0.14)

func close() -> void:
	if not is_open:
		return
	is_open = false
	_deactivate()
	build_menu_closed.emit()
	var tween := create_tween()
	tween.tween_property(_root_panel, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): visible = false)

func toggle() -> void:
	if is_open: close()
	else:        open()