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
@onready var resource_divider_a = $"../ResourceDividerA"
@onready var resource_divider_b = $"../ResourceDividerB"
@onready var resource_divider_c = $"../ResourceDividerC"
@onready var sick_icon = $"../SickIcon"
@onready var disease_label = $"../DiseaseLabel"

var is_panel_visible = true
var panel_elements: Array

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
	sick_icon = false
	disease_label = false

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
	sick_icon = true
	disease_label = true
