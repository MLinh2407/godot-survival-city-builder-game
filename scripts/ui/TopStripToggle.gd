class_name TopStripToggle
extends Node

@onready var hide_button = $HideUIButton
@onready var show_button = $ShowUIButton
@onready var top_strip_panel = $"../TopStripPanel"
@onready var top_strip_glow = $"../TopStripGlow"
@onready var top_sweep_line = $"../TopSweepLine"
@onready var power_marker = $"../PowerMarker"
@onready var food_marker = $"../FoodMarker"
@onready var morale_marker = $"../MoraleMarker"
@onready var power_label = $"../PowerLabel"
@onready var power_bar = $"../PowerBar"
@onready var power_rate_label = $"../PowerRateLabel"
@onready var food_label = $"../FoodLabel"
@onready var food_bar = $"../FoodBar"
@onready var food_rate_label = $"../FoodRateLabel"
@onready var morale_label = $"../MoraleLabel"
@onready var morale_bar = $"../MoraleBar"
@onready var morale_rate_label = $"../MoraleRateLabel"
@onready var materials_icon = $"../MaterialsIcon"
@onready var materials_label = $"../MaterialsLabel"
@onready var population_icon = $"../PopulationIcon"
@onready var population_label = $"../PopulationLabel"
@onready var workers_icon = $"../WorkersIcon"
@onready var workers_label = $"../WorkersLabel"
@onready var settings_button = $"../ButtonSettings"
@onready var resource_divider_a = $"../ResourceDividerA"
@onready var resource_divider_b = $"../ResourceDividerB"
@onready var resource_divider_c = $"../ResourceDividerC"
@onready var sick_icon = $"../SickIcon"
@onready var disease_label = $"../DiseaseLabel"

var is_panel_visible = true
var panel_elements: Array
var tooltip_panel: Panel
var tooltip_label: Label
var last_hover_icon: Control
var _tooltip_padding: Vector2 = Vector2(8, 4)
var _tooltip_max_width: int = 220
var _tooltip_max_chars: int = 28

const ANIMATION_DURATION = 0.15

func _ready() -> void:
	# Collect all panel elements for animation
	panel_elements = [
		top_strip_panel, top_strip_glow, top_sweep_line,
		power_marker, food_marker, morale_marker,
		power_label, power_bar, power_rate_label,
		food_label, food_bar, food_rate_label,
		morale_label, morale_bar, morale_rate_label,
		materials_icon, materials_label,
		population_icon, population_label,
		workers_icon, workers_label,
		resource_divider_a, resource_divider_b, resource_divider_c, 
		sick_icon, disease_label
	]
	
	hide_button.pressed.connect(_on_hide_ui_pressed)
	show_button.pressed.connect(_on_show_ui_pressed)
	show_button.visible = false

	# Create tooltip panel + label for icon hover hints
	tooltip_panel = Panel.new()
	tooltip_panel.name = "HoverTooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tooltip_label = Label.new()
	tooltip_label.name = "HoverTooltip"
	tooltip_label.horizontal_alignment = 1 as HorizontalAlignment
	tooltip_label.vertical_alignment = 1 as VerticalAlignment
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	tooltip_panel.add_child(tooltip_label)
	tooltip_label.position = _tooltip_padding

	get_parent().call_deferred("add_child", tooltip_panel)
	tooltip_panel.z_index = 1000

	# Connect hover signals for icons (show a tooltip and scale icon)
	if materials_icon:
		materials_icon.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Materials", materials_icon))
		materials_icon.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(materials_icon))
	if population_icon:
		population_icon.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Population", population_icon))
		population_icon.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(population_icon))
	if workers_icon:
		workers_icon.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Workers", workers_icon))
		workers_icon.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(workers_icon))
	if sick_icon:
		sick_icon.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Sick pool", sick_icon))
		sick_icon.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(sick_icon))

	# Tooltips for hide/show/settings buttons
	if hide_button:
		hide_button.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Hide", hide_button))
		hide_button.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(hide_button))
	if show_button:
		show_button.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Show", show_button))
		show_button.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(show_button))
	if settings_button:
		settings_button.mouse_entered.connect(Callable(self, "_on_icon_mouse_entered").bind("Settings", settings_button))
		settings_button.mouse_exited.connect(Callable(self, "_on_icon_mouse_exited").bind(settings_button))

func _on_hide_ui_pressed() -> void:
	_animate_hide_resources_panel()
	hide_button.visible = false
	show_button.visible = true
	is_panel_visible = false

func _on_show_ui_pressed() -> void:
	_animate_show_resources_panel()
	show_button.visible = false
	hide_button.visible = true
	is_panel_visible = true

func _animate_hide_resources_panel() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	
	# Set pivot to right side for left-to-right collapse effect
	for element in panel_elements:
		element.pivot_offset = Vector2(element.size.x, element.size.y / 2)
	
	# Scale down and fade out all panel elements simultaneously
	for element in panel_elements:
		tween.tween_property(element, "scale", Vector2(0.8, 0.8), ANIMATION_DURATION)
		tween.tween_property(element, "modulate:a", 0.0, ANIMATION_DURATION)
	
	# Hide after animation completes
	await tween.finished
	_hide_resources_panel()

func _animate_show_resources_panel() -> void:
	# Make elements visible with starting scale and alpha
	for element in panel_elements:
		element.visible = true
		element.scale = Vector2(0.8, 0.8)
		element.modulate.a = 0.0
		# Set pivot to left side for right-to-left expand effect
		element.pivot_offset = Vector2(0, element.size.y / 2)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	# Scale up and fade in all panel elements simultaneously
	for element in panel_elements:
		tween.tween_property(element, "scale", Vector2(1.0, 1.0), ANIMATION_DURATION)
		tween.tween_property(element, "modulate:a", 1.0, ANIMATION_DURATION)

func _hide_resources_panel() -> void:
	top_strip_panel.visible = false
	top_strip_glow.visible = false
	top_sweep_line.visible = false
	power_marker.visible = false
	food_marker.visible = false
	morale_marker.visible = false
	power_label.visible = false
	power_bar.visible = false
	power_rate_label.visible = false
	food_label.visible = false
	food_bar.visible = false
	food_rate_label.visible = false
	morale_label.visible = false
	morale_bar.visible = false
	morale_rate_label.visible = false
	materials_icon.visible = false
	materials_label.visible = false
	population_icon.visible = false
	population_label.visible = false
	workers_icon.visible = false
	workers_label.visible = false
	resource_divider_a.visible = false
	resource_divider_b.visible = false
	resource_divider_c.visible = false
	sick_icon.visible = false
	disease_label.visible = false

func _show_resources_panel() -> void:
	top_strip_panel.visible = true
	top_strip_glow.visible = true
	top_sweep_line.visible = true
	power_marker.visible = true
	food_marker.visible = true
	morale_marker.visible = true
	power_label.visible = true
	power_bar.visible = true
	power_rate_label.visible = true
	food_label.visible = true
	food_bar.visible = true
	food_rate_label.visible = true
	morale_label.visible = true
	morale_bar.visible = true
	morale_rate_label.visible = true
	materials_icon.visible = true
	materials_label.visible = true
	population_icon.visible = true
	population_label.visible = true
	workers_icon.visible = true
	workers_label.visible = true
	resource_divider_a.visible = true
	resource_divider_b.visible = true
	resource_divider_c.visible = true
	sick_icon.visible = true
	disease_label.visible = true

func _on_icon_mouse_entered(text: String, icon: Control) -> void:
	if tooltip_panel and tooltip_label:
		tooltip_label.text = _wrap_tooltip_text(text, _tooltip_max_chars)
		tooltip_panel.visible = true
		last_hover_icon = icon
		# defer size computation after text update
		call_deferred("_update_tooltip_size")
		call_deferred("_position_tooltip_at_mouse")
	icon.scale = Vector2(1.08, 1.08)


func _on_icon_mouse_exited(icon: Control) -> void:
	if tooltip_panel:
		tooltip_panel.visible = false
	icon.scale = Vector2(1, 1)
	last_hover_icon = null


func _process(_delta: float) -> void:
	if tooltip_panel and tooltip_panel.visible:
		_position_tooltip_at_mouse()


func _position_tooltip_at_mouse() -> void:
	if not tooltip_panel:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	var label_min: Vector2 = tooltip_label.get_minimum_size()
	var tp_size: Vector2 = Vector2(min(label_min.x + _tooltip_padding.x * 2, _tooltip_max_width), label_min.y + _tooltip_padding.y * 2)
	tooltip_panel.custom_minimum_size = tp_size

	var desired: Vector2

	if last_hover_icon and last_hover_icon.is_inside_tree():
		var icon_rect: Rect2 = last_hover_icon.get_global_rect()
		var icon_pos: Vector2 = icon_rect.position
		var icon_size: Vector2 = icon_rect.size
		# Default: center tooltip above the icon
		desired = Vector2(icon_pos.x + icon_size.x * 0.5 - tp_size.x * 0.5, icon_pos.y - tp_size.y - 6)
		# For the left-side show/hide/settings buttons, anchor tooltip nearer the control's right edge
		if last_hover_icon == hide_button or last_hover_icon == show_button or last_hover_icon == settings_button:
			desired.x = icon_pos.x + icon_size.x - tp_size.x - 8
	else:
		desired = mouse_pos + Vector2(12, -6)
	# flip horizontally if overflowing right
	if desired.x + tp_size.x > vp_rect.size.x - 4:
		desired.x = mouse_pos.x - tp_size.x - 12
	# clamp left
	desired.x = clamp(desired.x, 4, max(4, vp_rect.size.x - tp_size.x - 4))
	# flip vertically if overflowing bottom
	if desired.y + tp_size.y > vp_rect.size.y - 4:
		desired.y = mouse_pos.y - tp_size.y - 12
	# clamp top
	desired.y = clamp(desired.y, 4, max(4, vp_rect.size.y - tp_size.y - 4))

	tooltip_panel.global_position = desired

func _update_tooltip_size() -> void:
	if not tooltip_label or not tooltip_panel:
		return
	# constrain label width so autowrap takes effect, then measure
	var label_min: Vector2 = tooltip_label.get_minimum_size()
	var tp_size: Vector2 = Vector2(min(label_min.x + _tooltip_padding.x * 2, _tooltip_max_width), label_min.y + _tooltip_padding.y * 2)
	tooltip_panel.custom_minimum_size = tp_size

func _wrap_tooltip_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	var words := text.split(" ")
	var lines := []
	var current := ""
	for w in words:
		if current == "":
			current = w
		elif current.length() + 1 + w.length() <= max_chars:
			current += " " + w
		else:
			lines.append(current)
			current = w
	if current != "":
		lines.append(current)
	return String("\n").join(lines)
