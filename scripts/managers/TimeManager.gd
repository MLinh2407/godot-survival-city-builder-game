extends Node

signal day_changed(new_day: int)
signal time_changed(time_string: String)
signal speed_changed(old_speed: int, new_speed: int)
signal storm_warning_issued
signal storm_hit

enum GameSpeed { PAUSED, NORMAL, FAST }
var current_speed: GameSpeed = GameSpeed.NORMAL

var current_day: int = 1
var time_elapsed: float = 0.0

var _last_time_str: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset_for_new_game() -> void:
	current_day = 1
	time_elapsed = 0.0
	_last_time_str = ""
	current_speed = GameSpeed.PAUSED
	day_changed.emit(current_day)
	time_changed.emit("00:00")

func set_game_speed(speed: GameSpeed) -> void:
	if current_speed == speed:
		return
	var previous_speed := current_speed
	if speed == GameSpeed.PAUSED:
		AudioManager.play_ui_sfx("pause")
	elif previous_speed == GameSpeed.PAUSED:
		AudioManager.play_ui_sfx("unpause")
	current_speed = speed
	speed_changed.emit(previous_speed, current_speed)

func get_current_day_length() -> float:
	match current_speed:
		GameSpeed.FAST:
			return GameConstants.DAY_LENGTH_FAST
		_:
			return GameConstants.DAY_LENGTH_SECONDS

func _process(delta: float) -> void:
	if current_speed == GameSpeed.PAUSED:
		return
		
	var current_day_length = get_current_day_length()
	
	time_elapsed += delta
	
	if time_elapsed >= current_day_length:
		time_elapsed -= current_day_length
		current_day += 1
		day_changed.emit(current_day)
		
		# Signal Milestones
		if current_day == GameConstants.STORM_START_DAY:
			storm_warning_issued.emit()
		elif current_day == GameConstants.STORM_HIT_DAY:
			storm_hit.emit()
		
	var fraction_elapsed = clamp(time_elapsed / current_day_length, 0.0, 1.0)
	var total_ingame_minutes = int(fraction_elapsed * 24.0 * 60.0)
	var h = total_ingame_minutes / 60
	var m = total_ingame_minutes % 60
	var time_str = "%02d:%02d" % [h, m]
	
	if time_str != _last_time_str:
		_last_time_str = time_str
		time_changed.emit(time_str)
