# Small helper panel showing keyboard/mouse shortcuts
extends CanvasLayer

var _root: Control = null

# Shortcut label definitions used to populate the UI
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

# Initialize panel nodes and hide
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	visible = false

# Build the UI layout for the shortcuts list
func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left   = 0.5
	_root.anchor_right  = 0.5
	_root.anchor_top    = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left   = -160.0
	_root.offset_right  =  160.0
	_root.offset_top    = -160.0
	_root.offset_bottom =  160.0
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
	s.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", s)
	_root.add_child(bg)

	var vb := VBoxContainer.new()
	vb.anchor_right  = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left   = 14.0
	vb.offset_right  = -14.0
	vb.offset_top    = 12.0
	vb.offset_bottom = -12.0
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vb)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(content)

	var title := Label.new()
	title.text = "Keyboard Shortcuts"
	title.add_theme_color_override("font_color", Color(0.0, 0.96, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.96, 1.0, 0.20))
	content.add_child(sep)

	for entry in SHORTCUTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(row)

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

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 0)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(footer)

	var close_btn := Button.new()
	close_btn.text        = "Close"
	close_btn.focus_mode  = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(64, 24)
	close_btn.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(0.0, 0.96, 1.0, 1.0))
	close_btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.95, 1.0, 1.0))

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.07, 0.10, 0.18, 0.98)
	btn_normal.border_color = Color(0.0, 0.96, 1.0, 0.55)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn_normal.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.09, 0.14, 0.24, 1.0)
	btn_hover.border_color = Color(0.0, 0.96, 1.0, 0.85)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.05, 0.08, 0.14, 1.0)
	btn_pressed.border_color = Color(0.0, 0.96, 1.0, 1.0)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(4)
	btn_pressed.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("pressed", btn_pressed)
	close_btn.add_theme_stylebox_override("focus", btn_hover)
	close_btn.pressed.connect(hide_panel)
	footer.add_child(close_btn)

# Show the shortcuts overlay with fade-in
func show_panel() -> void:
	visible = true
	if _root:
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.14)

# Hide the shortcuts overlay with fade-out
func hide_panel() -> void:
	if _root:
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 0.0, 0.10)
		t.tween_callback(func(): visible = false)

# Toggle visibility of the panel
func toggle() -> void:
	if visible: hide_panel()
	else:        show_panel()
