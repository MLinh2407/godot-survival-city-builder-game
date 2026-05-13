extends CanvasLayer

var _root:          Control       = null
var _title_lbl:     Label         = null
var _body_lbl:      Label         = null
var _counter_lbl:   Label         = null
var _status_lbl:    Label         = null  # shows trust / no-trust state
var _prev_btn:      Button        = null
var _next_btn:      Button        = null
var _close_btn:     Button        = null
var _scroll:        ScrollContainer = null

var _messages:      Array = []   # filtered messages available today
var _current_index: int   = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 130
	_build_ui()
	visible = false

# ══════════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_left   = 0.5
	_root.anchor_right  = 0.5
	_root.anchor_top    = 0.5
	_root.anchor_bottom = 0.5
	_root.offset_left   = -360.0
	_root.offset_right  =  360.0
	_root.offset_top    = -270.0
	_root.offset_bottom =  270.0
	_root.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dark background with purple Archive Hall border
	var bg := Panel.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color     = Color(0.02, 0.02, 0.07, 0.98)
	bg_s.border_color = Color(0.61, 0.35, 1.0, 0.80)
	bg_s.set_border_width_all(1)
	bg_s.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", bg_s)
	_root.add_child(bg)

	# Thin inner glow line at top 
	var glow_line := ColorRect.new()
	glow_line.color          = Color(0.61, 0.35, 1.0, 0.12)
	glow_line.offset_left    = 1.0
	glow_line.offset_right   = -1.0
	glow_line.offset_top     = 1.0
	glow_line.offset_bottom  = 3.0
	glow_line.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow_line)

	var vb := VBoxContainer.new()
	vb.anchor_right  = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_left   = 20.0
	vb.offset_right  = -20.0
	vb.offset_top    = 14.0
	vb.offset_bottom = -14.0
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vb)

	# ── Header row ───────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(header)

	var sys_lbl := Label.new()
	sys_lbl.text = "◈  MERIDIAN — ARCHIVE HALL TERMINAL"
	sys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_lbl.add_theme_color_override("font_color", Color(0.61, 0.35, 1.0, 1.0))
	sys_lbl.add_theme_font_size_override("font_size", 12)
	sys_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(sys_lbl)

	_close_btn = Button.new()
	_close_btn.text       = "✕"
	_close_btn.flat       = true
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_close_btn.pressed.connect(close_terminal)
	_close_btn.mouse_entered.connect(func():
		if AudioManager: AudioManager.play_ui_sfx("hover"))
	header.add_child(_close_btn)

	# Trust status indicator
	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_status_lbl)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("color", Color(0.61, 0.35, 1.0, 0.35))
	vb.add_child(sep1)

	# ── Message title ────────────────────────────────────────────────────────
	_title_lbl = Label.new()
	_title_lbl.text = ""
	_title_lbl.add_theme_color_override("font_color", Color(0.0, 0.96, 1.0, 0.92))
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_title_lbl)

	# ── Scrollable body ──────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter           = Control.MOUSE_FILTER_PASS
	vb.add_child(_scroll)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD
	_body_lbl.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_body_lbl.add_theme_color_override("font_color", Color(0.80, 0.86, 0.90, 0.90))
	_body_lbl.add_theme_font_size_override("font_size", 11)
	_body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_body_lbl)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.61, 0.35, 1.0, 0.22))
	vb.add_child(sep2)

	# ── Navigation row ───────────────────────────────────────────────────────
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nav)

	_prev_btn = _make_nav_btn("◀  Prev")
	_prev_btn.pressed.connect(_on_prev)
	nav.add_child(_prev_btn)

	_counter_lbl = Label.new()
	_counter_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_counter_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 0.80))
	_counter_lbl.add_theme_font_size_override("font_size", 10)
	_counter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(_counter_lbl)

	_next_btn = _make_nav_btn("Next  ▶")
	_next_btn.pressed.connect(_on_next)
	nav.add_child(_next_btn)

func _make_nav_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text               = txt
	btn.focus_mode         = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(85.0, 32.0)

	var n := StyleBoxFlat.new()
	n.bg_color    = Color(0.05, 0.03, 0.12, 1.0)
	n.border_color = Color(0.61, 0.35, 1.0, 0.50)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color    = Color(0.09, 0.05, 0.20, 1.0)
	h.border_color = Color(0.61, 0.35, 1.0, 0.90)
	h.set_border_width_all(1)
	h.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", h)

	btn.add_theme_color_override("font_color", Color(0.61, 0.35, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 11)
	btn.mouse_entered.connect(func(): if AudioManager: AudioManager.play_ui_sfx("hover"))
	return btn

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

func open_terminal() -> void:
	_load_messages()
	_current_index = 0
	_update_status_label()

	if _messages.is_empty():
		_show_empty_state()
	else:
		_display_current()

	visible = true
	if _root:
		_root.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 1.0, 0.18)

	# Scroll body back to top on every open
	if _scroll:
		_scroll.scroll_vertical = 0

func close_terminal() -> void:
	if _root:
		var t := create_tween()
		t.tween_property(_root, "modulate:a", 0.0, 0.14)
		t.tween_callback(func(): visible = false)

# ══════════════════════════════════════════════════════════════════════════════
# MESSAGE LOADING — filters by current day range and trust status
# ══════════════════════════════════════════════════════════════════════════════

func _load_messages() -> void:
	_messages.clear()

	var file := FileAccess.open("res://data/meridian_messages.json", FileAccess.READ)
	if not file:
		push_warning("MeridianTerminal: Could not open res://data/meridian_messages.json")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MeridianTerminal: meridian_messages.json has invalid root type")
		return

	var current_day: int   = TimeManager.current_day if TimeManager else 1
	var trusted: bool      = GameManager.meridian_trusted if GameManager else false

	# Pre-trust messages — always loaded (shown before Day 21, or always if refused)
	var pre_data: Dictionary = parsed.get("pre_trust", {})
	for msg in pre_data.get("messages", []):
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		if _is_in_day_range(msg, current_day):
			_messages.append(msg)

	# Post-trust messages — only if MERIDIAN was trusted on Day 21 Option A
	if trusted:
		var post_data: Dictionary = parsed.get("post_trust", {})
		for msg in post_data.get("messages", []):
			if typeof(msg) != TYPE_DICTIONARY:
				continue
			if _is_in_day_range(msg, current_day):
				_messages.append(msg)

	# Sort chronologically by the start of each message's day range
	_messages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_range: Array = a.get("display_day_range", [1, 35])
		var b_range: Array = b.get("display_day_range", [1, 35])
		return int(a_range[0]) < int(b_range[0])
	)

func _is_in_day_range(msg: Dictionary, current_day: int) -> bool:
	var day_range: Array = msg.get("display_day_range", [1, 35])
	if day_range.size() < 2:
		return true
	return current_day >= int(day_range[0]) and current_day <= int(day_range[1])

# ══════════════════════════════════════════════════════════════════════════════
# DISPLAY
# ══════════════════════════════════════════════════════════════════════════════

func _display_current() -> void:
	if _messages.is_empty():
		_show_empty_state()
		return

	_current_index = clampi(_current_index, 0, _messages.size() - 1)
	var msg: Dictionary = _messages[_current_index]

	_title_lbl.text   = str(msg.get("title", "MERIDIAN TERMINAL"))
	_body_lbl.text    = str(msg.get("body",  ""))
	_counter_lbl.text = "Message %d of %d" % [_current_index + 1, _messages.size()]

	_prev_btn.disabled = (_current_index <= 0)
	_next_btn.disabled = (_current_index >= _messages.size() - 1)

	# Scroll to top on message switch
	if _scroll:
		_scroll.scroll_vertical = 0

func _show_empty_state() -> void:
	var trusted: bool = GameManager.meridian_trusted if GameManager else false
	_title_lbl.text = "TERMINAL — NO TRANSMISSIONS AVAILABLE"

	if not trusted:
		_body_lbl.text = (
			"MERIDIAN has not yet been granted biometric access.\n\n"
			+ "Transmissions are visible but limited. "
			+ "Trust MERIDIAN (Day 21, Option A) to unlock full message history.\n\n"
			+ "Return later — new messages appear as the days progress."
		)
	else:
		_body_lbl.text = (
			"No transmissions logged for the current period.\n\n"
			+ "MERIDIAN sends messages every few days when the Archive Hall is built. "
			+ "Return as the days advance."
		)

	_counter_lbl.text = "— / —"
	if _prev_btn: _prev_btn.disabled = true
	if _next_btn: _next_btn.disabled = true

func _update_status_label() -> void:
	if not _status_lbl:
		return
	var trusted: bool = GameManager.meridian_trusted if GameManager else false
	if trusted:
		_status_lbl.text = "ACCESS LEVEL: FULL — biometric integration active"
		_status_lbl.add_theme_color_override("font_color", Color(0.35, 0.88, 0.48, 0.85))
	else:
		_status_lbl.text = "ACCESS LEVEL: LIMITED — biometric access not granted"
		_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62, 0.70))

# ══════════════════════════════════════════════════════════════════════════════
# NAVIGATION
# ══════════════════════════════════════════════════════════════════════════════

func _on_prev() -> void:
	if _current_index > 0:
		_current_index -= 1
		_display_current()
		if AudioManager: AudioManager.play_ui_sfx("click")

func _on_next() -> void:
	if _current_index < _messages.size() - 1:
		_current_index += 1
		_display_current()
		if AudioManager: AudioManager.play_ui_sfx("click")