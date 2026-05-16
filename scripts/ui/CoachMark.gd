extends CanvasLayer

signal coach_mark_dismissed(mark_id: String)

# ── Configuration ─────────────────────────────────────────────────────────────
const AUTO_DISMISS_SEC:  float = 8.0
const BUBBLE_MIN_WIDTH:  float = 260.0
const PADDING:           float = 12.0
const HIGHLIGHT_EXPAND:  float = 5.0
const ARROW_GAP:         float = 10.0
const BLUR_FADE_IN_SEC:  float = 0.30
const BLUR_FADE_OUT_SEC: float = 0.20

const C_BORDER := Color(0.0,  0.96, 1.0,  1.00)
const C_GLOW   := Color(0.0,  0.75, 1.0,  0.25)
const C_BG     := Color(0.03, 0.04, 0.10, 1.00)
const C_SHADOW := Color(0.0,  0.0,  0.0,  0.75)
const C_TEXT   := Color(0.92, 0.96, 1.00, 1.00)
const C_HINT   := Color(0.45, 0.55, 0.62, 0.90)

# ── State ─────────────────────────────────────────────────────────────────────
var mark_id:        String  = ""
var _direction:     String  = "below"
var _target:        Control = null
var _is_dismissing: bool    = false

# ── Blur overlay  ─────────────────────────────────────────────────────────────
var _blur_layer: CanvasLayer = null
var _blur_rect:  ColorRect   = null

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _root:      Control
var _shadow:    Panel
var _glow:      Panel
var _highlight: Panel
var _bubble:    Panel
var _vbox:      VBoxContainer
var _text_lbl:  Label
var _hint_lbl:  Label
var _arrow_lbl: Label
var _timer:     Timer
var _pulse_tw:  Tween

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 175
	_build_nodes()
	_build_blur_overlay()

# ── Node construction ─────────────────────────────────────────────────────────

func _build_nodes() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter  = Control.MOUSE_FILTER_PASS
	_root.process_mode  = Node.PROCESS_MODE_ALWAYS
	_root.gui_input.connect(_on_root_input)
	add_child(_root)

	# Pulsing highlight ring around the target Control
	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.process_mode = Node.PROCESS_MODE_ALWAYS
	_highlight.visible = false
	var hs := StyleBoxFlat.new()
	hs.bg_color     = Color(0.0, 0.96, 1.0, 0.07)
	hs.border_color = C_BORDER
	hs.set_border_width_all(2)
	hs.set_corner_radius_all(4)
	_highlight.add_theme_stylebox_override("panel", hs)
	_root.add_child(_highlight)

	# Drop shadow — rendered behind everything else so it must be added first
	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.process_mode = Node.PROCESS_MODE_ALWAYS
	var ss := StyleBoxFlat.new()
	ss.bg_color = C_SHADOW
	ss.set_corner_radius_all(6)
	_shadow.add_theme_stylebox_override("panel", ss)
	_root.add_child(_shadow)

	# Soft glow ring behind the bubble border
	_glow = Panel.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.process_mode = Node.PROCESS_MODE_ALWAYS
	var gs := StyleBoxFlat.new()
	gs.bg_color     = Color.TRANSPARENT
	gs.border_color = C_GLOW
	gs.set_border_width_all(4)
	gs.set_corner_radius_all(7)
	_glow.add_theme_stylebox_override("panel", gs)
	_root.add_child(_glow)

	# Arrow pointer
	_arrow_lbl = Label.new()
	_arrow_lbl.add_theme_color_override("font_color", C_BORDER)
	_arrow_lbl.add_theme_font_size_override("font_size", 16)
	_arrow_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_arrow_lbl.add_theme_constant_override("outline_size", 3)
	_arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_arrow_lbl)

	# Main bubble  
	_bubble = Panel.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.process_mode = Node.PROCESS_MODE_ALWAYS
	var bs := StyleBoxFlat.new()
	bs.bg_color     = C_BG
	bs.border_color = C_BORDER
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(5)
	_bubble.add_theme_stylebox_override("panel", bs)
	_bubble.gui_input.connect(_on_bubble_input)
	_root.add_child(_bubble)

	# Layout inside bubble
	_vbox = VBoxContainer.new()
	_vbox.offset_left   = PADDING
	_vbox.offset_top    = PADDING
	_vbox.offset_right  = -PADDING
	_vbox.offset_bottom = -PADDING
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_vbox.process_mode  = Node.PROCESS_MODE_ALWAYS
	_bubble.add_child(_vbox)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_lbl.custom_minimum_size = Vector2(BUBBLE_MIN_WIDTH - PADDING * 2, 0)
	_text_lbl.add_theme_color_override("font_color", C_TEXT)
	_text_lbl.add_theme_font_size_override("font_size", 12)
	_text_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_text_lbl.add_theme_constant_override("outline_size", 4)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_text_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.96, 1.0, 0.20))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(sep)

	_hint_lbl = Label.new()
	_hint_lbl.text = "Click anywhere  •  ESC to dismiss"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_lbl.add_theme_color_override("font_color", C_HINT)
	_hint_lbl.add_theme_font_size_override("font_size", 9)
	_hint_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_lbl.add_theme_constant_override("outline_size", 2)
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_hint_lbl)

	_timer = Timer.new()
	_timer.wait_time    = AUTO_DISMISS_SEC
	_timer.one_shot     = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(dismiss)
	add_child(_timer)

# ── Blur overlay ──────────────────────────────────────────────────────────────

func _build_blur_overlay() -> void:
	_blur_layer = CanvasLayer.new()
	_blur_layer.layer        = 174
	_blur_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_blur_layer)

	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_blur_rect.modulate.a   = 0.0  
	_blur_rect.color        = Color.WHITE  

	# Inline shader 
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_strength  : hint_range(0.0, 8.0) = 3.0;
uniform float darken_amount  : hint_range(0.0, 0.8) = 0.40;

void fragment() {
	vec2 pixel_size = blur_strength / vec2(textureSize(screen_texture, 0));
	vec4 col        = vec4(0.0);

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			col += texture(
				screen_texture,
				SCREEN_UV + vec2(float(x), float(y)) * pixel_size
			);
		}
	}

	col      /= 25.0;
	col.rgb  *= (1.0 - darken_amount);
	COLOR     = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blur_strength", 3.0)
	mat.set_shader_parameter("darken_amount", 0.40)
	_blur_rect.material = mat

	_blur_layer.add_child(_blur_rect)

func _fade_in_blur() -> void:
	if not _blur_rect or not is_instance_valid(_blur_rect):
		return
	var t := _blur_rect.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(_blur_rect, "modulate:a", 1.0, BLUR_FADE_IN_SEC)

func _fade_out_and_free_blur() -> void:
	if not _blur_rect or not is_instance_valid(_blur_rect):
		return
	var t := _blur_rect.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(_blur_rect, "modulate:a", 0.0, BLUR_FADE_OUT_SEC)
	t.tween_callback(func():
		if _blur_layer and is_instance_valid(_blur_layer):
			_blur_layer.queue_free()
		_blur_layer = null
		_blur_rect  = null
	)

# ── Public API ────────────────────────────────────────────────────────────────

func show_for_target(id: String, target: Control, text: String,
		direction: String = "below") -> void:
	mark_id            = id
	_target            = target
	_direction         = direction
	_text_lbl.text     = text
	_highlight.visible = true
	call_deferred("_do_layout")

func show_floating(id: String, screen_pos: Vector2, text: String) -> void:
	mark_id            = id
	_target            = null
	_highlight.visible = false
	_arrow_lbl.text    = "▲"
	_text_lbl.text     = text
	call_deferred("_place_bubble_at", screen_pos)

func dismiss() -> void:
	if _is_dismissing:
		return
	_is_dismissing = true

	if _pulse_tw:
		_pulse_tw.kill()
	_timer.stop()

	# Blur fades out in parallel with the mark
	_fade_out_and_free_blur()

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		coach_mark_dismissed.emit(mark_id)
		queue_free()
	)

# ── Input handling ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _is_dismissing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			dismiss()

func _on_root_input(event: InputEvent) -> void:
	if _is_dismissing:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

func _on_bubble_input(event: InputEvent) -> void:
	if _is_dismissing:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

# ── Layout ────────────────────────────────────────────────────────────────────

func _do_layout() -> void:
	if not _target or not _target.is_inside_tree():
		_highlight.visible = false
		_place_bubble_at(get_viewport().get_visible_rect().size * 0.5)
		return

	# Frame 1 — let the target compute its global rect
	await get_tree().process_frame

	var tr: Rect2  = _target.get_global_rect()
	_highlight.position = tr.position - Vector2(HIGHLIGHT_EXPAND, HIGHLIGHT_EXPAND)
	_highlight.size     = tr.size     + Vector2(HIGHLIGHT_EXPAND * 2, HIGHLIGHT_EXPAND * 2)

	var bw: float   = BUBBLE_MIN_WIDTH
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cx: float   = tr.position.x + tr.size.x * 0.5
	var cy: float   = tr.position.y + tr.size.y * 0.5

	# Constrain bubble width so Godot can calculate the wrapped text height
	_bubble.custom_minimum_size = Vector2(bw, 0.0)

	# Frame 2 — let the bubble measure its minimum height from the wrapped text
	await get_tree().process_frame

	var bh: float = maxf(_bubble.get_combined_minimum_size().y, 70.0)

	var bpos:  Vector2
	var apos:  Vector2
	var achar: String

	match _direction:
		"below":
			achar = "▲"
			apos  = Vector2(cx - 8.0, tr.position.y + tr.size.y + ARROW_GAP)
			bpos  = Vector2(
				clampf(cx - bw * 0.5, 8.0, vp.x - bw - 8.0),
				apos.y + 22.0
			)
		"above":
			achar = "▼"
			bpos  = Vector2(
				clampf(cx - bw * 0.5, 8.0, vp.x - bw - 8.0),
				tr.position.y - bh - 26.0 - ARROW_GAP
			)
			apos  = Vector2(cx - 8.0, bpos.y + bh + 4.0)
		"right":
			achar = "◀"
			apos  = Vector2(tr.position.x + tr.size.x + ARROW_GAP, cy - 12.0)
			bpos  = Vector2(
				apos.x + 20.0,
				clampf(cy - bh * 0.5, 8.0, vp.y - bh - 8.0)
			)
		"left":
			achar = "▶"
			bpos  = Vector2(
				tr.position.x - bw - 24.0 - ARROW_GAP,
				clampf(cy - bh * 0.5, 8.0, vp.y - bh - 8.0)
			)
			apos  = Vector2(bpos.x + bw + 4.0, cy - 12.0)
		_:
			achar = ""
			bpos  = Vector2(
				clampf(cx - bw * 0.5, 8.0, vp.x - bw - 8.0),
				tr.position.y + tr.size.y + ARROW_GAP
			)

	_arrow_lbl.text     = achar
	_arrow_lbl.position = apos
	_bubble.position    = bpos

	# Frames 3 & 4 — wait for the bubble to fully render at its final position.
	await get_tree().process_frame
	await get_tree().process_frame

	_apply_shadow_and_glow(bpos, bw)
	_fade_in()
	_fade_in_blur()
	_start_pulse()
	_timer.start()

func _place_bubble_at(screen_pos: Vector2) -> void:
	var bw: float = BUBBLE_MIN_WIDTH
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_bubble.custom_minimum_size = Vector2(bw, 0.0)

	await get_tree().process_frame

	var bh: float = maxf(_bubble.get_combined_minimum_size().y, 70.0)
	var bpos := Vector2(
		clampf(screen_pos.x - bw * 0.5, 8.0, vp.x - bw - 8.0),
		clampf(screen_pos.y - bh - 30.0, 8.0, vp.y - bh - 8.0)
	)
	_arrow_lbl.position = Vector2(screen_pos.x - 8.0, screen_pos.y - 24.0)
	_bubble.position    = bpos

	await get_tree().process_frame
	await get_tree().process_frame

	_apply_shadow_and_glow(bpos, bw)
	_fade_in()
	_fade_in_blur()
	_timer.start()

# ── Shadow and glow — sized from actual rendered bubble height ────────────────

func _apply_shadow_and_glow(bpos: Vector2, bw: float) -> void:
	var actual: Vector2 = _bubble.size
	if actual.y < 10.0:
		actual = Vector2(bw, _bubble.get_combined_minimum_size().y)

	# Shadow: offset 3px right and 4px down, same size as the bubble
	_shadow.position = bpos + Vector2(3.0, 4.0)
	_shadow.size     = actual

	# Glow: 4px larger on every side, centred behind the bubble
	_glow.position = bpos - Vector2(4.0, 4.0)
	_glow.size     = actual + Vector2(8.0, 8.0)

# ── Animations ────────────────────────────────────────────────────────────────

func _fade_in() -> void:
	_root.modulate.a = 0.0
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(_root, "modulate:a", 1.0, 0.22)

func _start_pulse() -> void:
	if _pulse_tw:
		_pulse_tw.kill()
	_pulse_tw = create_tween()
	_pulse_tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pulse_tw.set_loops(-1)
	_pulse_tw.tween_property(_highlight, "modulate:a", 0.30, 0.90).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(_highlight, "modulate:a", 1.00, 0.90).set_trans(Tween.TRANS_SINE)