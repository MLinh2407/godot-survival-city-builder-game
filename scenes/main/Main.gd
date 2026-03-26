extends Node

@onready var day_label: Label = $UILayer/HUD/DayLabel
@onready var time_label: Label = $UILayer/HUD/TimeLabel

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
	
	# init labels manually in case signal fires before Main is fully ready
	if power_label and food_label and morale_label:
		_on_resources_changed(ResourceManager.power, ResourceManager.food, ResourceManager.morale)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		get_tree().paused = not get_tree().paused

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
