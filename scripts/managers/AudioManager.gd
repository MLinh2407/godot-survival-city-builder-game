extends Node

var critical_warning_player: AudioStreamPlayer

func _ready() -> void:
	critical_warning_player = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/sfx/warning/alert.mp3")
	if stream:
		critical_warning_player.stream = stream
	else:
		push_warning("Failed to load critical warning sound")
	add_child(critical_warning_player)

func play_critical_warning() -> void:
	if critical_warning_player and critical_warning_player.stream and not critical_warning_player.playing:
		critical_warning_player.play()
