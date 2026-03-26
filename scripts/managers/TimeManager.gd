extends Node

signal day_changed(new_day: int)
signal time_changed(time_string: String)

var current_day: int = 1
var day_length_seconds: float = 60.0 
var time_elapsed: float = 0.0

var _last_time_str: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	time_elapsed += delta
	
	if time_elapsed >= day_length_seconds:
		time_elapsed -= day_length_seconds
		current_day += 1
		day_changed.emit(current_day)
		
	var fraction_left = clamp(1.0 - (time_elapsed / day_length_seconds), 0.0, 1.0)
	var total_ingame_minutes = int(fraction_left * 24.0 * 60.0)
	var h = total_ingame_minutes / 60
	var m = total_ingame_minutes % 60
	var time_str = "%02d:%02d" % [h, m]
	
	if time_str != _last_time_str:
		_last_time_str = time_str
		time_changed.emit(time_str)
