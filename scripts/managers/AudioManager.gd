extends Node

var critical_warning_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer

var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var is_playing_a: bool = true

var ui_sfx_player_slider: AudioStreamPlayer

var track_1: AudioStream = preload("res://assets/audio/music/Track_1.mp3")
var track_2: AudioStream = preload("res://assets/audio/music/Track_2.mp3")
var track_3: AudioStream = preload("res://assets/audio/music/Track_3.mp3")

# UI SFX Streams (using button_click as placeholder for pause/unpause)
var sfx_hover: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_hover.mp3")
var sfx_click: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_pause: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3") # Placeholder
var sfx_unpause: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3") # Placeholder
var sfx_slider_move: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_slider_move.mp3")
var sfx_build_repair: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_finish.mp3")
var sfx_build_place: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_place.mp3")

var sfx_death_colonist: AudioStream = null   
var sfx_desertion: AudioStream = null       

func play_build_sfx(type: String) -> void:
	match type:
		"repair", "upgrade", "place":
			# Use the place sound for instantaneous feedback on click
			if ui_sfx_player and sfx_build_place:
				ui_sfx_player.stream = sfx_build_place
				ui_sfx_player.play()
				# Stop after 4 seconds to limit playback
				var t = get_tree().create_timer(2.5)
				t.timeout.connect(Callable(ui_sfx_player, "stop"))
		"finish":
			# reserved for finish / completion sound
			if ui_sfx_player and sfx_build_repair:
				ui_sfx_player.stream = sfx_build_repair
				ui_sfx_player.play()
				var t2 = get_tree().create_timer(2.5)
				t2.timeout.connect(Callable(ui_sfx_player, "stop"))
		_:
			return

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep playing when paused
	
	# Critical Warning
	critical_warning_player = AudioStreamPlayer.new()
	critical_warning_player.bus = "SFX"
	var stream = load("res://assets/audio/sfx/warning/alert.mp3")
	if stream:
		critical_warning_player.stream = stream
	else:
		push_warning("Failed to load critical warning sound")
	add_child(critical_warning_player)
	
	# UI SFX
	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.bus = "SFX"
	add_child(ui_sfx_player)

	ui_sfx_player_slider = AudioStreamPlayer.new()
	ui_sfx_player_slider.bus = "SFX"
	add_child(ui_sfx_player_slider)
	
	# Music Players
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = "Music"
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Music"
	add_child(music_player_b)
	
	# Start Background Track 1
	play_music(track_1)

	# Event SFX
	var death_path := "res://assets/audio/sfx/events/sfx_event_death_colonist.mp3"
	var deser_path := "res://assets/audio/sfx/events/sfx_event_desertion.mp3"
	if ResourceLoader.exists(death_path):
		sfx_death_colonist = load(death_path)
	if ResourceLoader.exists(deser_path):
		sfx_desertion = load(deser_path)

func play_critical_warning() -> void:
	if critical_warning_player and critical_warning_player.stream and not critical_warning_player.playing:
		critical_warning_player.play()

func play_ui_sfx(type: String) -> void:
	match type:
		"hover":
			ui_sfx_player.stream = sfx_hover
			ui_sfx_player.play()
		"click":
			ui_sfx_player.stream = sfx_click
			ui_sfx_player.play()
		"pause":
			ui_sfx_player.stream = sfx_pause
			ui_sfx_player.play()
		"unpause":
			ui_sfx_player.stream = sfx_unpause
			ui_sfx_player.play()
		"slider_move":
			ui_sfx_player_slider.stream = sfx_slider_move
			ui_sfx_player_slider.play()
		_:
			return
			
func play_event_sfx(type: String) -> void:
	match type:
		"death_colonist":
			if ui_sfx_player and sfx_death_colonist:
				ui_sfx_player.stream = sfx_death_colonist
				ui_sfx_player.play()
		"desertion":
			if ui_sfx_player and sfx_desertion:
				ui_sfx_player.stream = sfx_desertion
				ui_sfx_player.play()
		_:
			return

func play_music(stream: AudioStream) -> void:
	if is_playing_a:
		music_player_a.stream = stream
		music_player_a.play()
		music_player_a.volume_db = 0.0
	else:
		music_player_b.stream = stream
		music_player_b.play()
		music_player_b.volume_db = 0.0

func crossfade_to(stream: AudioStream, duration: float = 2.0) -> void:
	var tween = create_tween()
	
	if is_playing_a:
		# Fade out A, fade in B
		music_player_b.stream = stream
		music_player_b.play()
		music_player_b.volume_db = -80.0
		
		tween.tween_property(music_player_a, "volume_db", -80.0, duration)
		tween.parallel().tween_property(music_player_b, "volume_db", 0.0, duration)
		tween.tween_callback(music_player_a.stop)
	else:
		# Fade out B, fade in A
		music_player_a.stream = stream
		music_player_a.play()
		music_player_a.volume_db = -80.0
		
		tween.tween_property(music_player_b, "volume_db", -80.0, duration)
		tween.parallel().tween_property(music_player_a, "volume_db", 0.0, duration)
		tween.tween_callback(music_player_b.stop)
		
	is_playing_a = not is_playing_a

func on_crisis_card_opened() -> void:
	crossfade_to(track_2, 1.5)

func on_crisis_card_dismissed() -> void:
	crossfade_to(track_1, 1.5)
