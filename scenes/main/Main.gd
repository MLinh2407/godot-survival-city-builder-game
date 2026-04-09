extends Node

@onready var day_label: Label = $UILayer/HUD/DayLabel
@onready var time_label: Label = $UILayer/HUD/TimeLabel
@onready var speed_label: Label = $UILayer/HUD/SpeedLabel

@onready var btn_pause: Button = $UILayer/HUD/SpeedControls/ButtonPause
@onready var btn_1x: Button = $UILayer/HUD/SpeedControls/Button1x
@onready var btn_2x: Button = $UILayer/HUD/SpeedControls/Button2x
@onready var btn_settings: Button = $UILayer/HUD/SpeedControls/ButtonSettings

@onready var power_label: Label = $UILayer/HUD/PowerLabel
@onready var food_label: Label = $UILayer/HUD/FoodLabel
@onready var morale_label: Label = $UILayer/HUD/MoraleLabel
@onready var disease_label: Label = $UILayer/HUD/DiseaseLabel

var was_power_critical: bool = false
var was_food_critical: bool = false
var was_morale_critical: bool = false

var settings_ui: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	settings_ui = preload("res://scenes/main/SettingsUI.tscn").instantiate()
	add_child(settings_ui)
	
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.time_changed.connect(_on_time_changed)
	ResourceManager.resources_changed.connect(_on_resources_changed)
	if PopulationManager != null:
		PopulationManager.population_changed.connect(_on_population_changed)
	
	if day_label:
		day_label.text = "Day " + str(TimeManager.current_day)
	
	# Connect buttons
	if btn_pause: btn_pause.pressed.connect(toggle_pause)
	if btn_1x: btn_1x.pressed.connect(_on_button_1x_pressed)
	if btn_2x: btn_2x.pressed.connect(_on_button_2x_pressed)
	if btn_settings: btn_settings.pressed.connect(_on_button_settings_pressed)
	
	set_speed(TimeManager.GameSpeed.NORMAL, "Speed: 1x")
	
	# init labels manually in case signal fires before Main is fully ready
	if power_label and food_label and morale_label:
		_on_resources_changed(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
	_on_population_changed()

func toggle_pause() -> void:
	if TimeManager.current_speed == TimeManager.GameSpeed.PAUSED:
		get_tree().paused = false
		set_speed(TimeManager.GameSpeed.NORMAL, "Speed: 1x")
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
	set_speed(TimeManager.GameSpeed.NORMAL, "Speed: 1x")

func _on_button_2x_pressed() -> void:
	set_speed(TimeManager.GameSpeed.FAST, "Speed: 2x")

func _on_button_settings_pressed() -> void:
	if settings_ui and settings_ui.has_method("toggle_menu"):
		settings_ui.toggle_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
		elif event.keycode == KEY_1:
			set_speed(TimeManager.GameSpeed.NORMAL, "Speed: 1x")
		elif event.keycode == KEY_2:
			set_speed(TimeManager.GameSpeed.FAST, "Speed: 2x")

func _on_day_changed(new_day: int) -> void:
	if day_label:
		day_label.text = "Day " + str(new_day)

func _on_time_changed(time_string: String) -> void:
	if time_label:
		time_label.text = time_string

func _on_population_changed() -> void:
	if disease_label and GameManager.population_state:
		var sick = GameManager.population_state.sick_count
		disease_label.text = "Sick: " + str(sick)
		if sick > 0:
			disease_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
		else:
			disease_label.remove_theme_color_override("font_color")

func _on_resources_changed(p: float, f: float, m: float, mat: int) -> void:
	if power_label:
		power_label.text = "Power: " + str(p)
		
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
		food_label.text = "Food: " + str(f)
		
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
		morale_label.text = "Morale: " + str(m)
		
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
