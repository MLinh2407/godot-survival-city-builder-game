extends Node

signal resources_changed(power: int, food: int, morale: int)

var power: int = 50
var food: int = 100
var morale: int = 100

func _ready() -> void:
	# Wait one frame to ensure TimeManager autoload is fully initialized
	await get_tree().process_frame
	if TimeManager != null:
		TimeManager.day_changed.connect(_on_day_changed)
	else:
		push_warning("TimeManager not found during ResourceManager init.")
		
	resources_changed.emit(power, food, morale)

func _on_day_changed(new_day: int) -> void:
	print("--- Day ", new_day, " ---")
	print("Power:  ", power)
	print("Food:   ", food)
	print("Morale: ", morale)
	print("----------------")
	resources_changed.emit(power, food, morale)
