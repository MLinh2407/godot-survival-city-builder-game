extends CanvasLayer

var _root: Control = null

const SHORTCUTS: Array = [
	["SPACE",      "Pause / Unpause"],
	["1",          "Normal speed (1×)"],
	["2",          "Fast speed (2×)"],
	["B",          "Open / close Build Menu"],
	["J",          "Open / close Colony Journal"],
	["Q",          "Cancel building placement"],
	["ESC",        "Cancel / close current panel"],
	["+ / −",      "Assign / remove worker"],
	["Scroll",     "Zoom in / out"],
	["Mid-drag",   "Pan the map"],
	["Left-click", "Place building / select"],
	["Right-click","Cancel placement / remove (hold)"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left   = 0.5
	_root.anchor_right  = 0.5
	_root.anchor_top    = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left   = -160.0
	_root.offset_right  =  160.0
	_root.offset_top    = -200.0
	_root.offset_bottom =  200.0
	_root.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := Panel.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.03, 0.04, 0.10, 0.98)
	s.border_color = Color(0.0, 0.96, 1.0, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", s)
	_root.add_child(bg)

	var vb := VBoxContainer.new()
	vb.anchor_right  = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left   = 14.0
	vb.offset_right  = -14.0
	vb.offset_top    = 10.0
	vb.offset_bottom = -10.0
	vb.add_theme_constant_override("separation", 5)
	vb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vb)

	var title := Label.new()
	title.text = "Keyboard Shortcuts"
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.96, 1.0, 0.20))
	vb.add_child(sep)

	for entry in SHORTCUTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)

		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % entry[0]
		key_lbl.custom_minimum_size = Vector2(90, 0)
		key_lbl.add_theme_color_override("font_color", Color(0.0, 0.96, 1.0, 0.85))
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(key_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry[1]
		desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92, 0.90))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(desc_lbl)

	var close_btn := Button.new()
	close_btn.text        = "Close"
	close_btn.focus_mode  = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_panel)
	vb.add_child(close_btn)

func show_panel() -> void:
	visible = true
	if _root:
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.14)

func hide_panel() -> void:
	if _root:
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 0.0, 0.10)
		t.tween_callback(func(): visible = false)

func toggle() -> void:
	if visible: hide_panel()
	else:        show_panel()