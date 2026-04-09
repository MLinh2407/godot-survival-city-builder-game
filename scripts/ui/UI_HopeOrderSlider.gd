extends ProgressBar

# ══════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ══════════════════════════════════════════════════════════════════════════════

@onready var hope_label: Label  = $"../HopeLabel"
@onready var order_label: Label = $"../OrderLabel"

# ══════════════════════════════════════════════════════════════════════════════
# COLORS
# ══════════════════════════════════════════════════════════════════════════════

const COLOR_HOPE:    Color = Color("#00F5FF")   # Neon cyan
const COLOR_ORDER:   Color = Color("#FF9500")   # Amber
const COLOR_NEUTRAL: Color = Color("#9B59FF")   # Purple

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	GameManager.slider_changed.connect(_on_slider_changed)
	# Defer one frame so ProgressBar size is valid before we read it
	await get_tree().process_frame
	_refresh_display(GameManager.hope_order_slider)

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLER
# ══════════════════════════════════════════════════════════════════════════════

func _on_slider_changed(new_value: float) -> void:
	_animate_to(new_value)
	_update_fill_color(GameManager.get_slider_zone())
	AudioManager.play_ui_sfx("slider_move")

# ══════════════════════════════════════════════════════════════════════════════
# DISPLAY
# ══════════════════════════════════════════════════════════════════════════════

func _refresh_display(new_value: float) -> void:
	# Called once on ready — no animation, just snap to current value
	self.value = new_value
	_update_fill_color(GameManager.get_slider_zone())

func _animate_to(new_value: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "value", new_value, 0.5) \
		 .set_ease(Tween.EASE_OUT) \
		 .set_trans(Tween.TRANS_CUBIC)

func _update_fill_color(zone: String) -> void:
	# Duplicate the stylebox so we don't modify the shared theme resource
	var style: StyleBoxFlat = get_theme_stylebox("fill").duplicate()
	match zone:
		"Hope":
			style.bg_color = COLOR_HOPE
			hope_label.add_theme_color_override("font_color", COLOR_HOPE)
			order_label.remove_theme_color_override("font_color")
		"Order":
			style.bg_color = COLOR_ORDER
			order_label.add_theme_color_override("font_color", COLOR_ORDER)
			hope_label.remove_theme_color_override("font_color")
		"Neutral":
			style.bg_color = COLOR_NEUTRAL
			hope_label.remove_theme_color_override("font_color")
			order_label.remove_theme_color_override("font_color")
	add_theme_stylebox_override("fill", style)