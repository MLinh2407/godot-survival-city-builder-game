extends CanvasLayer

signal build_menu_opened
signal build_menu_closed

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.03, 0.04, 0.10, 0.97)
const C_BORDER  := Color(0.00, 0.96, 1.00, 0.65)
const C_HEADER  := Color(0.00, 0.96, 1.00, 1.00)
const C_TIER    := Color(0.28, 0.60, 0.68, 1.00)
const C_CARD_N  := Color(0.07, 0.09, 0.17, 1.00)
const C_CARD_H  := Color(0.10, 0.20, 0.28, 1.00)
const C_CARD_A  := Color(0.02, 0.26, 0.38, 1.00)
const C_CARD_L  := Color(0.04, 0.04, 0.08, 0.50)
const C_NAME    := Color(0.88, 0.93, 0.96, 1.00)
const C_COST    := Color(0.45, 0.78, 1.00, 0.90)
const C_FREE    := Color(0.40, 0.68, 0.45, 1.00)
const C_WRK     := Color(0.55, 0.78, 0.62, 0.85)
const C_PSV     := Color(0.40, 0.50, 0.55, 0.75)
const C_HINT    := Color(0.40, 0.52, 0.65, 0.80)
const C_WARN    := Color(1.00, 0.72, 0.28, 1.00)
const C_SEP     := Color(0.00, 0.96, 1.00, 0.18)

# ── Sizing ────────────────────────────────────────────────────────────────────
const BAR_FRAC : float = 0.36   # fraction of viewport height the bar occupies
const CARD_W   : float = 88.0
const CARD_H   : float = 98.0
const IMG_H    : float = 50.0
const TIER_W   : float = 46.0
const HEAD_H   : float = 26.0

# ── Sprite paths (T1 images shown in menu) ───────────────────────────────────
const SPRITE_PATHS : Dictionary = {
	"coal"      : "res://assets/buildings/T1_Buildings/Coal_Generator_T1.png",
	"water"     : "res://assets/buildings/T1_Buildings/Water_Recycler_T1.png",
	"hydro"     : "res://assets/buildings/T1_Buildings/Hydroponic_Bay_T1.png",
	"shelter"   : "res://assets/buildings/T1_Buildings/Shelter_Block_T1.png",
	"med"       : "res://assets/buildings/T1_Buildings/Med_Clinic_T1.png",
	"ration"    : "res://assets/buildings/T1_Buildings/Ration_Store_T1.png",
	"relay"     : "res://assets/buildings/T1_Buildings/Relay_Hub_T1.png",
	"geothermal": "res://assets/buildings/T1_Buildings/Geothermal_Tap_T1.png",
	"archive"   : "res://assets/buildings/T1_Buildings/Archive_Hall_T1.png",
	"memorial"  : "res://assets/buildings/T1_Buildings/Memorial_Wall.png",
	"neon_h"   : "res://assets/ui/decorations/deco_neon_h.png",
	"neon_d"   : "res://assets/ui/decorations/deco_neon_d.png",
	"cable_h"  : "res://assets/ui/decorations/deco_cable_h.png",
	"cable_d"  : "res://assets/ui/decorations/deco_cable_d.png",
}

const TIER_LABEL : Dictionary = {
	"first"      : "BUILD\nFIRST",
	"stable"     : "BUILD\nSTABLE",
	"ready"      : "BUILD\nREADY",
	"decoration" : "DECO\nRATION",
}

# ── State ─────────────────────────────────────────────────────────────────────
var _defs         : Array  = []
var is_open       : bool   = false
var _active_type  : String = ""
var _cards        : Dictionary = {}   # b_type → Control (the card panel)
var _root         : Control          = null
var _scroll       : ScrollContainer  = null
var _hint_lbl     : Label            = null
var _grid_manager : Node             = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_init_defs()
	_build_ui()
	visible = false
	call_deferred("_connect_gm")

func _init_defs() -> void:
	_defs = [
		["Coal Generator", "coal",       6,  GameConstants.BUILD_COST_COAL_GENERATOR,  "first",      false],
		["Water Recycler", "water",      12, GameConstants.BUILD_COST_WATER_RECYCLER,  "first",      false],
		["Hydroponic Bay", "hydro",      10, GameConstants.BUILD_COST_HYDROPONIC_BAY,  "first",      false],
		["Shelter Block",  "shelter",    0,  GameConstants.BUILD_COST_SHELTER_BLOCK,   "first",      false],
		["Med Clinic",     "med",        14, GameConstants.BUILD_COST_MED_CLINIC,      "stable",     false],
		["Ration Store",   "ration",     0,  GameConstants.BUILD_COST_RATION_STORE,    "stable",     false],
		["Relay Hub",      "relay",      8,  GameConstants.BUILD_COST_RELAY_HUB,       "stable",     false],
		["Geothermal Tap", "geothermal", 0,  GameConstants.BUILD_COST_GEOTHERMAL_TAP,  "stable",     false],
		["Archive Hall",   "archive",    12, GameConstants.BUILD_COST_ARCHIVE_HALL,    "ready",      false],
		["Memorial Wall",  "memorial",   0,  GameConstants.BUILD_COST_MEMORIAL_WALL,   "ready",      false],
		["Neon Inlay H",   "neon_h",     0,  0,                                        "decoration", true],
		["Neon Inlay D",   "neon_d",     0,  0,                                        "decoration", true],
		["Cable Run H",    "cable_h",    0,  0,                                        "decoration", true],
		["Cable Run D",    "cable_d",    0,  0,                                        "decoration", true],
	]

func _connect_gm() -> void:
	_grid_manager = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
	if not _grid_manager:
		push_warning("BuildMenu: GridManager not found at Main/GameWorld/GridSystem")
		return
	if _grid_manager.has_signal("building_placed"):
		_grid_manager.building_placed.connect(
			func(_t: String, _p: Vector2i): _on_placed_externally())
	# Update card affordability whenever materials change
	await get_tree().process_frame
	if ResourceManager:
		ResourceManager.resources_changed.connect(
			func(_p, _f, _m, _mat: int): _refresh_affordability())
	_refresh_affordability()

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BuildMenuRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	_root.anchor_left   = 0.0
	_root.anchor_right  = 1.0
	_root.anchor_top    = 1.0 - BAR_FRAC
	_root.anchor_bottom = 1.0
	_root.offset_left   = 0.0
	_root.offset_right  = 0.0
	_root.offset_top    = 0.0
	_root.offset_bottom = 0.0
	add_child(_root)

	# Dark background
	var bg := ColorRect.new()
	bg.color         = C_BG
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Cyan top border line
	var top_line := ColorRect.new()
	top_line.color        = C_BORDER
	top_line.anchor_right = 1.0
	top_line.offset_bottom = 1.0
	top_line.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_line)

	# Outer VBoxContainer 
	var vbox := VBoxContainer.new()
	vbox.anchor_right   = 1.0
	vbox.anchor_bottom  = 1.0
	vbox.offset_left    = 8.0
	vbox.offset_right   = -8.0
	vbox.offset_top     = 5.0
	vbox.offset_bottom  = -4.0
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vbox)

	# ── Header row ────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, HEAD_H)
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var title := Label.new()
	title.text = "⚙  CONSTRUCT"
	title.add_theme_color_override("font_color", C_HEADER)
	title.add_theme_font_size_override("font_size", 13)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	_hint_lbl = Label.new()
	_hint_lbl.text = "Select a building to place"
	_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_lbl.add_theme_color_override("font_color", C_HINT)
	_hint_lbl.add_theme_font_size_override("font_size", 10)
	_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	header.add_child(_hint_lbl)

	var key_hint := Label.new()
	key_hint.text = "[B] Toggle   [Q] Cancel"
	key_hint.add_theme_color_override("font_color", C_HINT)
	key_hint.add_theme_font_size_override("font_size", 10)
	key_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_hint.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	header.add_child(key_hint)

	var close_btn := Button.new()
	close_btn.text               = "✕"
	close_btn.flat               = true
	close_btn.focus_mode         = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(24.0, 24.0)
	close_btn.add_theme_color_override("font_color", C_HEADER)
	close_btn.pressed.connect(close)
	close_btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx("hover"))
	header.add_child(close_btn)

	# ── Thin separator ────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEP)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# ── Horizontal scroll area ────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter           = Control.MOUSE_FILTER_PASS
	vbox.add_child(_scroll)

	# ── Card row ──────────────────────────────────────────────────────────────
	var row := HBoxContainer.new()
	row.name = "CardRow"
	row.add_theme_constant_override("separation", 3)
	row.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter           = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(row)

	# Add tier headers + cards in order
	var last_tier := ""
	for def in _defs:
		if def[4] != last_tier:
			last_tier = def[4]
			_add_tier_label(row, def[4])
		_add_card(row, def[0], def[1], def[2], def[3], def[5])

	_refresh_memorial()

# ── Tier separator label ──────────────────────────────────────────────────────
func _add_tier_label(parent: HBoxContainer, tier: String) -> void:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(TIER_W, CARD_H)
	p.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(C_TIER.r, C_TIER.g, C_TIER.b, 0.07)
	s.border_color = Color(C_TIER.r, C_TIER.g, C_TIER.b, 0.25)
	s.border_width_right = 1
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)

	var lbl := Label.new()
	lbl.text = TIER_LABEL.get(tier, tier.to_upper())
	lbl.add_theme_color_override("font_color", C_TIER)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.anchor_right         = 1.0
	lbl.anchor_bottom        = 1.0
	lbl.offset_left          = 2.0
	lbl.offset_right         = -2.0
	p.add_child(lbl)

# ── Individual building card ──────────────────────────────────────────────────
func _add_card(parent: HBoxContainer, display_name: String, b_type: String,
		slots: int, cost: int, is_deco: bool) -> void:

	var card := Panel.new()
	card.name                 = "Card_%s" % b_type
	card.custom_minimum_size  = Vector2(CARD_W, CARD_H)
	card.mouse_filter         = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_N, Color.TRANSPARENT, 0))
	_cards[b_type] = card
	parent.add_child(card)

	var vb := VBoxContainer.new()
	vb.anchor_right  = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left   = 3.0
	vb.offset_right  = -3.0
	vb.offset_top    = 3.0
	vb.offset_bottom = -3.0
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	# Image
	var img_holder := Control.new()
	img_holder.custom_minimum_size   = Vector2(0.0, IMG_H)
	img_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_holder.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vb.add_child(img_holder)

	var sprite_path : String = SPRITE_PATHS.get(b_type, "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex := load(sprite_path) as Texture2D
		if tex:
			var tex_rect := TextureRect.new()
			tex_rect.texture      = tex
			tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.anchor_right  = 1.0
			tex_rect.anchor_bottom = 1.0
			tex_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
			img_holder.add_child(tex_rect)
	else:
		var icon := Label.new()
		icon.text = "◇" if is_deco else "□"
		icon.add_theme_color_override("font_color", Color(0.0, 0.75, 0.85, 0.55))
		icon.add_theme_font_size_override("font_size", 24)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		icon.anchor_right  = 1.0
		icon.anchor_bottom = 1.0
		icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		img_holder.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text               = display_name
	name_lbl.add_theme_color_override("font_color", C_NAME)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
	name_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	# Cost
	var cost_lbl := Label.new()
	cost_lbl.text = "Free" if cost == 0 else ("%d mat" % cost)
	cost_lbl.add_theme_color_override("font_color", C_FREE if cost == 0 else C_COST)
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_lbl)

	# Workers / Passive
	if not is_deco:
		var wk := Label.new()
		wk.text = ("%d slots" % slots) if slots > 0 else "passive"
		wk.add_theme_color_override("font_color", C_WRK if slots > 0 else C_PSV)
		wk.add_theme_font_size_override("font_size", 9)
		wk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wk.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		vb.add_child(wk)

	# Input
	card.gui_input.connect(func(ev: InputEvent): _on_card_input(ev, b_type, is_deco))
	card.mouse_entered.connect(func(): _on_card_hover(b_type, true))
	card.mouse_exited.connect(func():  _on_card_hover(b_type, false))

func _card_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(4)
	s.set_border_width_all(bw)
	s.border_color = border
	return s

# ── Input handling ────────────────────────────────────────────────────────────
func _on_card_input(ev: InputEvent, b_type: String, is_deco: bool) -> void:
	if not (ev is InputEventMouseButton and ev.pressed
			and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if b_type == "memorial" and not _memorial_available():
		_flash_locked(b_type)
		return
	AudioManager.play_ui_sfx("click")
	if _active_type == b_type:
		_deactivate()
		return
	_deactivate()
	_active_type = b_type
	_apply_active(b_type)
	_set_hint(b_type, is_deco)
	if not _grid_manager:
		return
	if is_deco:
		_grid_manager.enter_decoration_mode(b_type)
	else:
		_grid_manager.enter_build_mode(b_type)

func _on_card_hover(b_type: String, entering: bool) -> void:
	if b_type == _active_type:
		return
	if entering:
		if _cards.has(b_type):
			_cards[b_type].add_theme_stylebox_override(
				"panel", _card_style(C_CARD_H, C_BORDER, 1))
		AudioManager.play_ui_sfx("hover")
	else:
		_restore_card(b_type)

func _on_placed_externally() -> void:
	if _active_type == "":
		return
	_restore_card(_active_type)
	_active_type = ""
	if _hint_lbl:
		_hint_lbl.text = "Select a building to place"

func _deactivate() -> void:
	if _active_type == "":
		return
	_restore_card(_active_type)
	if _hint_lbl:
		_hint_lbl.text = "Select a building to place"
	if _grid_manager:
		if _grid_manager.current_build_scene != null:
			_grid_manager.exit_build_mode()
		if _grid_manager.current_decoration_type != "":
			_grid_manager.exit_decoration_mode()
	_active_type = ""

func _set_hint(_b_type: String, is_deco: bool) -> void:
	if not _hint_lbl:
		return
	if is_deco:
		_hint_lbl.text = "Left-click: place tile   Right-click: erase   [Q]: cancel"
		_hint_lbl.add_theme_color_override("font_color", C_HINT)
	else:
		_hint_lbl.text = "Left-click: place   Right-click / [Q]: cancel building mode"
		_hint_lbl.add_theme_color_override("font_color", C_WARN)

# ── Style helpers ─────────────────────────────────────────────────────────────
func _apply_active(b_type: String) -> void:
	if not _cards.has(b_type): return
	_cards[b_type].add_theme_stylebox_override(
		"panel", _card_style(C_CARD_A, C_BORDER, 1))

func _restore_card(b_type: String) -> void:
	if not _cards.has(b_type): return
	if b_type == "memorial" and not _memorial_available():
		_cards[b_type].modulate = Color(0.48, 0.48, 0.52, 0.55)
		_cards[b_type].add_theme_stylebox_override(
			"panel", _card_style(C_CARD_L, Color.TRANSPARENT, 0))
	else:
		_cards[b_type].modulate = Color.WHITE
		_cards[b_type].add_theme_stylebox_override(
			"panel", _card_style(C_CARD_N, Color.TRANSPARENT, 0))

func _flash_locked(b_type: String) -> void:
	AudioManager.play_build_sfx("invalid")
	if _hint_lbl:
		_hint_lbl.text = "Memorial Wall requires a named character to have died first."
		_hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	if _cards.has(b_type):
		_cards[b_type].add_theme_stylebox_override(
			"panel", _card_style(Color(0.22, 0.03, 0.03, 0.9),
			Color(0.75, 0.10, 0.10, 1.0), 1))
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func():
		_restore_card(b_type)
		if _hint_lbl:
			_hint_lbl.text = "Select a building to place"
			_hint_lbl.add_theme_color_override("font_color", C_HINT))

# ── Scroll capture: prevents mouse wheel from zooming while menu is open ──────
func _input(event: InputEvent) -> void:
	if not is_open or not _root or not _root.visible:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_WHEEL_UP \
			and event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	# Only intercept when the cursor is physically over the menu bar
	var mp  : Vector2 = get_viewport().get_mouse_position()
	var rc  : Rect2   = _root.get_global_rect()
	if not rc.has_point(mp):
		return
	get_viewport().set_input_as_handled()

# ── Memorial availability ─────────────────────────────────────────────────────
func _memorial_available() -> bool:
	return (not GameManager.yuna_alive)    or \
		   (not GameManager.rook_alive)    or \
		   (not GameManager.vasquez_alive) or \
		   (not GameManager.meridian_alive)

func _refresh_memorial() -> void:
	_restore_card("memorial")

func refresh_memorial_button() -> void:
	_refresh_memorial()

# ── Affordability ─────────────────────────────────────────────────────────────
# Called every time materials change. Dims cards the player cannot afford.
func _refresh_affordability() -> void:
	var current_mat: int = GameManager.materials
	for def in _defs:
		var b_type : String = def[1]
		var cost   : int    = def[3]
		var is_deco: bool   = def[5]
		if not _cards.has(b_type):
			continue
		if b_type == _active_type:
			continue   # never dim the one being actively placed
		if b_type == "memorial":
			continue   # memorial has its own locked logic
		if is_deco or cost == 0:
			_cards[b_type].modulate = Color.WHITE
			continue
		if current_mat < cost:
			# Cannot afford — dim to 55% and tint slightly red
			_cards[b_type].modulate = Color(0.90, 0.65, 0.65, 0.55)
		else:
			_cards[b_type].modulate = Color.WHITE

# ── Open / Close / Toggle ─────────────────────────────────────────────────────
func open() -> void:
	if is_open: return
	is_open = true
	visible = true
	_refresh_memorial()
	build_menu_opened.emit()
	if _root:
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.14)

func close() -> void:
	if not is_open: return
	is_open = false
	_deactivate()
	build_menu_closed.emit()
	if _root:
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 0.0, 0.12)
		t.tween_callback(func(): visible = false)

func toggle() -> void:
	if is_open: close()
	else:        open()