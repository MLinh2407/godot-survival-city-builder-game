extends Node

# TimeManager signals for day, time, speed, and storm events.
signal day_changed(new_day: int)
# Emitted when the in-game clock minute string changes ("HH:MM")
signal time_changed(time_string: String)
# Emitted when the game speed changes (old_speed, new_speed)
signal speed_changed(old_speed: int, new_speed: int)
signal storm_warning_issued
signal storm_hit

# Game speed enum and the current selected speed.
enum GameSpeed { PAUSED, NORMAL, FAST }
# Current selected game speed.
var current_speed: GameSpeed = GameSpeed.NORMAL

# Current day number and accumulated seconds within the day.
var current_day: int = 1
var time_elapsed: float = 0.0

# Cached last emitted time string to avoid duplicate signals.
var _last_time_str: String = ""

# Flag set when the game has ended to stop time progression.
var game_ended: bool = false

# Initialize TimeManager and enable processing.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Reset time state for a new game.
func reset_for_new_game() -> void:
	current_day = 1
	time_elapsed = 0.0
	_last_time_str = ""
	game_ended = false
	current_speed = GameSpeed.PAUSED
	day_changed.emit(current_day)
	time_changed.emit("00:00")

# Change game speed and preserve the current time fraction.
func set_game_speed(speed: GameSpeed) -> void:
	if current_speed == speed:
		return

	var old_length = get_current_day_length()
	var fraction = float(time_elapsed) / float(old_length) if old_length > 0 else 0.0

	var previous_speed := current_speed
	if speed == GameSpeed.PAUSED:
		AudioManager.play_ui_sfx("pause")
	elif previous_speed == GameSpeed.PAUSED:
		AudioManager.play_ui_sfx("unpause")
	
	current_speed = speed

	var new_length = get_current_day_length()
	time_elapsed = fraction * new_length

	speed_changed.emit(previous_speed, current_speed)

# Return the current day's length in seconds for the active speed.
func get_current_day_length() -> float:
	match current_speed:
		GameSpeed.FAST:
			return GameConstants.DAY_LENGTH_FAST
		_:
			return GameConstants.DAY_LENGTH_SECONDS

# Advance in-game time and emit day/time/storm milestones.
func _process(delta: float) -> void:
	if game_ended:
		return
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

	var fraction_elapsed = clamp(float(time_elapsed) / float(current_day_length), 0.0, 1.0)
	var total_ingame_minutes = int(fraction_elapsed * 24.0 * 60.0)
	var h: int = int(total_ingame_minutes / 60.0)
	var m: int = total_ingame_minutes % 60
	var time_str = "%02d:%02d" % [h, m]

	if time_str != _last_time_str:
		_last_time_str = time_str
		time_changed.emit(time_str)
