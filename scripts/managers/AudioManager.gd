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

# ── UI SFX ───────────────────────────────────────────────────────────────────
var sfx_hover:        AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_hover.mp3")
var sfx_click:        AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_pause:        AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_unpause:      AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_slider_move:  AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_slider_move.mp3")
var sfx_card_open:    AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_open.mp3")
var sfx_card_dismiss: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_dismiss.mp3")

# ── BUILD SFX ────────────────────────────────────────────────────────────────
# sfx_build_place   → place, upgrade, remove, damage, memorial_place, invalid
# sfx_build_finish  → repair, power_online, power_offline
# sfx_build_worker  → worker_assign, worker_remove
# sfx_build_shield  → shield_apply
var sfx_build_place:  AudioStream = preload("res://assets/audio/sfx/build/sfx_build_place.mp3")
var sfx_build_finish: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_finish.mp3")
var sfx_build_worker: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_worker_assign.mp3")
var sfx_build_shield: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_shield_apply.mp3")

# ── EVENT SFX  ────────────────────────────────────────────
var sfx_death_colonist: AudioStream = preload("res://assets/audio/sfx/events/sfx_event_death_colonist.mp3")
var sfx_desertion:      AudioStream = preload("res://assets/audio/sfx/events/sfx_event_desertion.mp3")
func play_build_sfx(type: String) -> void:
	var stream: AudioStream = null
	match type:
		# ── sfx_build_place group ──
		"place", "upgrade", "remove", "damage", "memorial_place", "invalid":
			stream = sfx_build_place
		# ── sfx_build_finish group ──
		"repair", "power_online", "power_offline":
			stream = sfx_build_finish
		# ── sfx_build_worker group ──
		"worker_assign", "worker_remove":
			stream = sfx_build_worker
		# ── sfx_build_shield group ──
		"shield_apply":
			stream = sfx_build_shield
		_:
			return
	if ui_sfx_player and stream:
		ui_sfx_player.stream = stream
		ui_sfx_player.play()

func play_ui_card_sfx(type: String) -> void:
	var stream: AudioStream = null
	match type:
		"open":    stream = sfx_card_open
		"dismiss": stream = sfx_card_dismiss
		_:
			return
	if ui_sfx_player and stream:
		ui_sfx_player.stream = stream
		ui_sfx_player.play()

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
