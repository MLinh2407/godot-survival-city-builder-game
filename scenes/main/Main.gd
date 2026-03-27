extends Node

@onready var day_label: Label = $UILayer/HUD/DayLabel
@onready var time_label: Label = $UILayer/HUD/TimeLabel
@onready var speed_label: Label = $UILayer/HUD/SpeedLabel

@onready var btn_pause: Button = $UILayer/HUD/SpeedControls/ButtonPause
@onready var btn_1x: Button = $UILayer/HUD/SpeedControls/Button1x
@onready var btn_2x: Button = $UILayer/HUD/SpeedControls/Button2x

@onready var power_label: Label = $UILayer/HUD/PowerLabel
@onready var food_label: Label = $UILayer/HUD/FoodLabel
@onready var morale_label: Label = $UILayer/HUD/MoraleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.time_changed.connect(_on_time_changed)
	ResourceManager.resources_changed.connect(_on_resources_changed)
	
	if day_label:
		day_label.text = "Day " + str(TimeManager.current_day)
	
	# Connect buttons
	if btn_pause: btn_pause.pressed.connect(toggle_pause)
	if btn_1x: btn_1x.pressed.connect(_on_button_1x_pressed)
	if btn_2x: btn_2x.pressed.connect(_on_button_2x_pressed)
	
	set_speed(1.0, "Speed: 1x")
	
	# init labels manually in case signal fires before Main is fully ready
	if power_label and food_label and morale_label:
		_on_resources_changed(ResourceManager.power, ResourceManager.food, ResourceManager.morale)

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	if btn_pause:
		btn_pause.text = "Resume" if get_tree().paused else "Pause"

func set_speed(multiplier: float, text: String) -> void:
	Engine.time_scale = multiplier
	if speed_label:
		speed_label.text = text

func _on_button_1x_pressed() -> void:
	set_speed(1.0, "Speed: 1x")

func _on_button_2x_pressed() -> void:
	set_speed(2.0, "Speed: 2x")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_pause()
		elif event.keycode == KEY_1:
			set_speed(1.0, "Speed: 1x")
		elif event.keycode == KEY_2:
			set_speed(2.0, "Speed: 2x")

func _on_day_changed(new_day: int) -> void:
	if day_label:
		day_label.text = "Day " + str(new_day)

func _on_time_changed(time_string: String) -> void:
	if time_label:
		time_label.text = time_string

func _on_resources_changed(p: int, f: int, m: int) -> void:
	if power_label:
		power_label.text = "Power: " + str(p)
	if food_label:
		food_label.text = "Food: " + str(f)
	if morale_label:
		morale_label.text = "Morale: " + str(m)
