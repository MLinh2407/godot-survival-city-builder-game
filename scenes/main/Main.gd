extends Node

@onready var day_label: Label = $UILayer/HUD/DayLabel
@onready var time_label: Label = $UILayer/HUD/TimeLabel
@onready var speed_label: Label = $UILayer/HUD/SpeedLabel

@onready var btn_pause: Button = $UILayer/HUD/SpeedControls/ButtonPause
@onready var btn_1x: Button = $UILayer/HUD/SpeedControls/Button1x
@onready var btn_2x: Button = $UILayer/HUD/SpeedControls/Button2x
@onready var btn_settings: Button = $UILayer/HUD/ButtonSettings

@onready var power_label: Label = $UILayer/HUD/PowerLabel
@onready var food_label: Label = $UILayer/HUD/FoodLabel
@onready var morale_label: Label = $UILayer/HUD/MoraleLabel
@onready var power_bar: ProgressBar = $UILayer/HUD/PowerBar
@onready var food_bar: ProgressBar = $UILayer/HUD/FoodBar
@onready var morale_bar: ProgressBar = $UILayer/HUD/MoraleBar
@onready var pop_label: Label = $UILayer/HUD/PopulationLabel
@onready var workers_label: Label = $UILayer/HUD/WorkersLabel
@onready var materials_label: Label = $UILayer/HUD/MaterialsLabel
@onready var power_rate_lbl: Label = $UILayer/HUD/PowerRateLabel
@onready var food_rate_lbl: Label = $UILayer/HUD/FoodRateLabel
@onready var morale_rate_lbl: Label = $UILayer/HUD/MoraleRateLabel
@onready var hope_slider: HSlider = $UILayer/HUD/HopeOrderSlider
@onready var hope_label: Label = $UILayer/HUD/HopeLabel
@onready var order_label: Label = $UILayer/HUD/OrderLabel
@onready var hope_track_border: Panel = $UILayer/HUD/HopeOrderTrackBorder
@onready var hope_track_fill: ColorRect = $UILayer/HUD/HopeOrderTrackFill
@onready var top_strip_panel: Panel = $UILayer/HUD/TopStripPanel
@onready var top_strip_glow: ColorRect = $UILayer/HUD/TopStripGlow
@onready var top_sweep_line: ColorRect = $UILayer/HUD/TopSweepLine
@onready var dialogue_engine = $Events/DialogueEngine
@onready var disease_label: Label = $UILayer/HUD/DiseaseLabel

var was_power_critical: bool = false
var was_food_critical: bool = false
var was_morale_critical: bool = false
var hud_fx_t: float = 0.0
var _last_hope_order_value: float = -1.0
const HOPE_COLOR := Color(0.62, 1.0, 0.78, 1.0)
const ORDER_COLOR := Color(0.94, 0.74, 1.0, 1.0)

var settings_ui: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	settings_ui = preload("res://scenes/main/SettingsUI.tscn").instantiate()
	add_child(settings_ui)
	
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.time_changed.connect(_on_time_changed)
	ResourceManager.resources_changed.connect(_on_resources_changed)
	PopulationManager.population_changed.connect(_on_population_changed)
	GameManager.hope_order_changed.connect(_on_hope_order_changed)
	
	if day_label:
		day_label.text = "DAY " + str(TimeManager.current_day)
	_update_hope_order_visuals()
	
	# Connect buttons
	if btn_pause: btn_pause.pressed.connect(toggle_pause)
	if btn_1x: btn_1x.pressed.connect(_on_button_1x_pressed)
	if btn_2x: btn_2x.pressed.connect(_on_button_2x_pressed)
	if btn_settings: btn_settings.pressed.connect(_on_button_settings_pressed)
	
	set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
	
	# init labels manually in case signal fires before Main is fully ready
	if power_label and food_label and morale_label:
		_on_resources_changed(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
	_on_population_changed()
	_on_hope_order_changed(GameManager.hope_order_slider)

	if dialogue_engine:
		dialogue_engine.call_deferred("show_event", "cold_night")
	
	if has_node("BuildingSystem"):
		var bs = $BuildingSystem
		if not bs.workers_changed.is_connected(_on_population_changed):
			bs.workers_changed.connect(_on_population_changed)

func _on_population_changed() -> void:
	var p = GameManager.population_state
	if pop_label and p:
		pop_label.text = str(p.total_population)
	if workers_label and p:
		workers_label.text = str(p.available_workers)
	if disease_label and p:
		var sick = p.sick_count
		disease_label.text = str(sick)
		if sick > 0:
			disease_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
		else:
			disease_label.remove_theme_color_override("font_color")

func _process(delta: float) -> void:
	_sync_hope_order_visuals()
	if get_tree() and get_tree().paused:
		return

	hud_fx_t += delta

	if top_strip_glow:
		var glow_alpha: float = 0.28 + 0.32 * (0.5 + 0.5 * sin(hud_fx_t * 2.8))
		top_strip_glow.color = Color(0.42, 0.98, 1.0, glow_alpha)
	if top_sweep_line:
		var beam_width: float = 72.0
		var left_margin: float = 8.0
		var right_margin: float = 8.0
		var start_x: float = 250.0
		var end_x: float = 810.0

		if top_strip_panel:
			start_x = top_strip_panel.offset_left + left_margin
			end_x = top_strip_panel.offset_right - right_margin - beam_width

		if end_x < start_x:
			end_x = start_x

		var range_x: float = maxf(end_x - start_x, 1.0)
		var cycle: float = fmod(hud_fx_t * 280.0, range_x)
		top_sweep_line.offset_left = start_x + cycle
		top_sweep_line.offset_right = top_sweep_line.offset_left + beam_width
		var sweep_alpha: float = 0.26 + 0.46 * (0.5 + 0.5 * sin(hud_fx_t * 5.2))
		top_sweep_line.color = Color(0.58, 1.0, 1.0, sweep_alpha)

func _update_rates() -> void:
	if power_rate_lbl:
		var power_rate = ResourceManager.power_capacity - ResourceManager.power_draw
		var power_rate_i: int = int(round(power_rate))
		if power_rate_i >= 0:
			power_rate_lbl.text = "+" + str(power_rate_i) + "/day"
		else:
			power_rate_lbl.text = str(power_rate_i) + "/day"
		_set_rate_color(power_rate_lbl, power_rate)

	if food_rate_lbl:
		food_rate_lbl.text = "+0/day"
		_set_rate_color(food_rate_lbl, 0.0)

	if morale_rate_lbl:
		morale_rate_lbl.text = "-1/day"
		_set_rate_color(morale_rate_lbl, -1.0)

func _set_rate_color(rate_label: Label, value: float) -> void:
	if value > 0.0:
		rate_label.add_theme_color_override("font_color", Color(0.58, 0.93, 0.64))
	elif value < 0.0:
		rate_label.add_theme_color_override("font_color", Color(1.0, 0.54, 0.54))
	else:
		rate_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))

func toggle_pause() -> void:
	if TimeManager.current_speed == TimeManager.GameSpeed.PAUSED:
		get_tree().paused = false
		set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
	else:
		get_tree().paused = true
		TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)
		if btn_pause:
			btn_pause.text = "Resume"
		if speed_label:
			speed_label.text = "PAUSED"

func set_speed(speed: int, text: String) -> void:
	TimeManager.set_game_speed(speed)
	get_tree().paused = false
	if btn_pause:
		btn_pause.text = "Pause"
	if speed_label:
		speed_label.text = text

func _on_button_1x_pressed() -> void:
	set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")

func _on_button_2x_pressed() -> void:
	set_speed(TimeManager.GameSpeed.FAST, "SPEED 2x")

func _on_button_settings_pressed() -> void:
	if settings_ui and settings_ui.has_method("toggle_menu"):
		settings_ui.toggle_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
		elif event.keycode == KEY_1:
			set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
		elif event.keycode == KEY_2:
			set_speed(TimeManager.GameSpeed.FAST, "SPEED 2x")

func _on_day_changed(new_day: int) -> void:
	if day_label:
		day_label.text = "DAY " + str(new_day)

func _on_time_changed(time_string: String) -> void:
	if time_label:
		time_label.text = "| " + time_string

func _on_resources_changed(p: float, f: float, m: float, _mat: int) -> void:
	if power_label:
		var power_i: int = int(round(p))
		var power_cap_i: int = maxi(int(round(ResourceManager.power_capacity)), 0)
		power_label.text = "POWER " + str(power_i) + "/" + str(power_cap_i)

	if power_bar:
		if ResourceManager.power_capacity > 0:
			power_bar.value = clamp((p / ResourceManager.power_capacity) * 100.0, 0.0, 100.0)
		else:
			power_bar.value = 0.0
		
		var power_is_critical = ResourceManager.power_capacity > 0 and ResourceManager.power_capacity < ResourceManager.power_draw
		var power_is_warning = ResourceManager.power_capacity > 0 and (p / ResourceManager.power_capacity) <= GameConstants.WARNING_THRESHOLD and not power_is_critical
		
		if power_is_critical:
			power_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_power_critical:
				AudioManager.play_critical_warning()
				was_power_critical = true
		elif power_is_warning:
			power_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_power_critical = false
		else:
			power_label.remove_theme_color_override("font_color")
			was_power_critical = false

	if food_label:
		var food_i: int = int(round(f))
		var max_food_i: int = maxi(int(round(ResourceManager.max_food)), 0)
		food_label.text = "FOOD " + str(food_i) + "/" + str(max_food_i)

	if food_bar:
		if ResourceManager.max_food > 0:
			food_bar.value = clamp((f / ResourceManager.max_food) * 100.0, 0.0, 100.0)
		else:
			food_bar.value = 0.0
		
		var food_ratio = 0.0
		if ResourceManager.max_food > 0:
			food_ratio = f / ResourceManager.max_food
			
		var food_is_critical = ResourceManager.max_food > 0 and food_ratio <= GameConstants.CRITICAL_THRESHOLD
		var food_is_warning = ResourceManager.max_food > 0 and food_ratio <= GameConstants.WARNING_THRESHOLD and not food_is_critical
		
		if food_is_critical:
			food_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_food_critical:
				AudioManager.play_critical_warning()
				was_food_critical = true
		elif food_is_warning:
			food_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_food_critical = false
		else:
			food_label.remove_theme_color_override("font_color")
			was_food_critical = false

	if morale_label:
		var morale_i: int = int(round(m))
		morale_label.text = "MORALE " + str(morale_i) + "/100"

	if morale_bar:
		morale_bar.value = clamp(m, 0.0, 100.0)
		
		var morale_ratio = m / 100.0
		var morale_is_critical = morale_ratio <= GameConstants.CRITICAL_THRESHOLD
		var morale_is_warning = morale_ratio <= GameConstants.WARNING_THRESHOLD and not morale_is_critical
		
		if morale_is_critical:
			morale_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_morale_critical:
				AudioManager.play_critical_warning()
				was_morale_critical = true
		elif morale_is_warning:
			morale_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_morale_critical = false
		else:
			morale_label.remove_theme_color_override("font_color")
			was_morale_critical = false

	if materials_label:
		materials_label.text = str(_mat)

	if hope_slider:
		hope_slider.value = GameManager.hope_order_slider
		_update_hope_order_visuals()

	_update_rates()

func _on_hope_order_changed(new_value: float) -> void:
	_last_hope_order_value = new_value
	if hope_slider:
		hope_slider.value = new_value
		_update_hope_order_visuals()
		AudioManager.play_ui_sfx("slider_move")

func _sync_hope_order_visuals() -> void:
	var current_value: float = GameManager.hope_order_slider
	if is_equal_approx(current_value, _last_hope_order_value):
		return
	_last_hope_order_value = current_value
	_update_hope_order_visuals()

func _update_hope_order_visuals() -> void:
	if not hope_slider:
		return

	var slider_value: float = clampf(GameManager.hope_order_slider, 0.0, 100.0)
	hope_slider.value = slider_value

	var hope_upper: float = GameConstants.SLIDER_HOPE_UPPER
	var order_lower: float = GameConstants.SLIDER_ORDER_LOWER

	# Color interpolation parameter (for choosing Hope / Order / Neutral)
	var t_color: float
	if slider_value <= hope_upper:
		t_color = 0.0
	elif slider_value >= order_lower:
		t_color = 1.0
	else:
		t_color = (slider_value - hope_upper) / maxf(order_lower - hope_upper, 1.0)

	# Color choice: neutral in middle band, otherwise explicit Hope/Order
	var NEUTRAL_COLOR: Color = Color(0.85, 0.85, 0.85, 1.0)
	var slider_color: Color
	if slider_value > hope_upper and slider_value < order_lower:
		slider_color = NEUTRAL_COLOR
	elif t_color <= 0.0:
		slider_color = HOPE_COLOR
	else:
		slider_color = ORDER_COLOR
	hope_slider.modulate = slider_color

	# Fill position uses full 0..100 proportion so 1 unit = 1% of track width
	var t_fill: float = slider_value / 100.0

	if hope_track_border and hope_track_fill:
		var inset: float = 2.0
		var inner_left: float = hope_track_border.offset_left + inset
		var inner_right: float = hope_track_border.offset_right - inset
		var inner_top: float = hope_track_border.offset_top + inset
		var inner_bottom: float = hope_track_border.offset_bottom - inset
		var inner_width: float = maxf(inner_right - inner_left, 1.0)
		var fill_right: float = inner_left + inner_width * t_fill

		hope_track_fill.offset_left = inner_left
		hope_track_fill.offset_top = inner_top
		hope_track_fill.offset_right = fill_right
		hope_track_fill.offset_bottom = inner_bottom
		hope_track_fill.color = Color(slider_color.r, slider_color.g, slider_color.b, 0.95)

	if hope_label:
		hope_label.add_theme_color_override("font_color", HOPE_COLOR)
	if order_label:
		order_label.add_theme_color_override("font_color", ORDER_COLOR)