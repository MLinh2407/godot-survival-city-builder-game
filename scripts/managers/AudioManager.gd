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
var sfx_card_open:    AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_open1.mp3")
var sfx_card_dismiss: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_open1.mp3")

# ── BUILD SFX ────────────────────────────────────────────────────────────────
# sfx_build_place   → place, upgrade, remove, damage, memorial_place, invalid
# sfx_build_finish  → repair, power_online, power_offline
# sfx_build_worker  → worker_assign, worker_remove
# sfx_build_shield  → shield_apply
var sfx_build_place:  AudioStream = preload("res://assets/audio/sfx/build/sfx_build_place.mp3")
var sfx_build_finish: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_finish.mp3")
var sfx_build_worker: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_worker_assign.mp3")
var sfx_build_shield: AudioStream = preload("res://assets/audio/sfx/build/sfx_build_shield_apply.mp3")

# ── EVENT SFX ────────────────────────────────────────────────────────────────
var sfx_death_colonist:       AudioStream = preload("res://assets/audio/sfx/event/sfx_event_death_colonist.mp3")
var sfx_desertion:            AudioStream = preload("res://assets/audio/sfx/event/sfx_event_desertion.mp3")
var sfx_crisis_fire:          AudioStream = preload("res://assets/audio/sfx/event/sfx_event_crisis_fire.mp3")
var sfx_death_named:          AudioStream = preload("res://assets/audio/sfx/event/sfx_event_death_named.mp3")
var sfx_disease_start:        AudioStream = preload("res://assets/audio/sfx/event/sfx_event_disease_start.mp3")
var sfx_disease_end:          AudioStream = preload("res://assets/audio/sfx/event/sfx_event_disease_end.mp3")
var sfx_unrest_riot:          AudioStream = preload("res://assets/audio/sfx/event/sfx_event_unrest_riot.mp3")
var sfx_storm_warning:        AudioStream = preload("res://assets/audio/sfx/event/sfx_event_storm_warning.mp3")
var sfx_storm_hit:            AudioStream = preload("res://assets/audio/sfx/event/sfx_event_storm_hit.mp3")
var sfx_radio_vasquez:        AudioStream = preload("res://assets/audio/sfx/event/sfx_event_radio_vasquez.mp3")
var sfx_meridian_contact:     AudioStream = preload("res://assets/audio/sfx/event/sfx_event_meridian_contact.mp3")

# ── AMBIENT LOOPS ────────────────────────────────────────────────────────────
var sfx_ambient_generator:      AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_generator.mp3")
var sfx_ambient_geothermal:     AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_geothermal.mp3")
var sfx_ambient_water_recycler: AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_water_recycler.mp3")
var sfx_ambient_med_clinic:     AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_med_clinic.mp3")
var sfx_ambient_archive:        AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_archive.mp3")
var sfx_ambient_shelter:        AudioStream = preload("res://assets/audio/sfx/ambient/sfx_ambient_shelter.mp3")

# Dictionary: Vector2i grid_pos → AudioStreamPlayer
# One ambient player per placed building instance on the grid
var _ambient_players: Dictionary = {}

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

	# Connect storm signals from TimeManager
	await get_tree().process_frame
	if TimeManager:
		TimeManager.storm_warning_issued.connect(_on_storm_warning)
		TimeManager.storm_hit.connect(_on_storm_hit)

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
	var stream: AudioStream = null
	match type:
		"crisis_fire":       stream = sfx_crisis_fire
		"death_colonist":    stream = sfx_death_colonist
		"death_named":       stream = sfx_death_named
		"disease_start":     stream = sfx_disease_start
		"disease_end":       stream = sfx_disease_end
		"desertion":         stream = sfx_desertion
		"unrest_riot":       stream = sfx_unrest_riot
		"storm_warning":     stream = sfx_storm_warning
		"storm_hit":         stream = sfx_storm_hit
		"radio_vasquez":     stream = sfx_radio_vasquez
		"meridian_contact":  stream = sfx_meridian_contact
		_:
			return
	if ui_sfx_player and stream:
		ui_sfx_player.stream = stream
		ui_sfx_player.play()

func _get_ambient_stream(building_type: BuildingData.BuildingType) -> AudioStream:
	match building_type:
		BuildingData.BuildingType.COAL_GENERATOR:   return sfx_ambient_generator
		BuildingData.BuildingType.GEOTHERMAL_TAP:   return sfx_ambient_geothermal
		BuildingData.BuildingType.WATER_RECYCLER:   return sfx_ambient_water_recycler
		BuildingData.BuildingType.MED_CLINIC:       return sfx_ambient_med_clinic
		BuildingData.BuildingType.ARCHIVE_HALL:     return sfx_ambient_archive
		BuildingData.BuildingType.SHELTER_BLOCK:    return sfx_ambient_shelter
		_:
			return null

# Start ambient loop for a building at grid_pos. Fades in over AMBIENT_FADE_IN seconds.
func start_ambient(grid_pos: Vector2i, building_type: BuildingData.BuildingType) -> void:
	var stream: AudioStream = _get_ambient_stream(building_type)
	if stream == null:
		return

	# Already playing — do nothing
	if _ambient_players.has(grid_pos):
		var existing: AudioStreamPlayer = _ambient_players[grid_pos]
		if existing and existing.playing:
			return

	# Create a new player if none exists for this grid position
	if not _ambient_players.has(grid_pos):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -80.0
		add_child(player)
		_ambient_players[grid_pos] = player

	var p: AudioStreamPlayer = _ambient_players[grid_pos]
	p.stream = stream
	p.volume_db = -80.0
	p.play()

	# Fade in
	var tween := create_tween()
	var target_db: float = linear_to_db(GameConstants.AMBIENT_VOLUME_RATIO)
	tween.tween_property(p, "volume_db", target_db, GameConstants.AMBIENT_FADE_IN)

# Stop ambient loop for a building at grid_pos. Fades out over AMBIENT_FADE_OUT seconds.
func stop_ambient(grid_pos: Vector2i) -> void:
	if not _ambient_players.has(grid_pos):
		return
	var p: AudioStreamPlayer = _ambient_players[grid_pos]
	if not p or not p.playing:
		return

	# Fade out then stop — do not destroy the player, it may restart
	var tween := create_tween()
	tween.tween_property(p, "volume_db", -80.0, GameConstants.AMBIENT_FADE_OUT)
	tween.tween_callback(p.stop)

# Called when a building is permanently removed from the grid.
func remove_ambient(grid_pos: Vector2i) -> void:
	if not _ambient_players.has(grid_pos):
		return
	var p: AudioStreamPlayer = _ambient_players[grid_pos]
	if not p:
		_ambient_players.erase(grid_pos)
		return

	var tween := create_tween()
	tween.tween_property(p, "volume_db", -80.0, GameConstants.AMBIENT_FADE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(p):
			p.queue_free()
		_ambient_players.erase(grid_pos)
	)

func update_ambient(grid_pos: Vector2i, building_type: BuildingData.BuildingType, should_play: bool) -> void:
	if should_play:
		start_ambient(grid_pos, building_type)
	else:
		stop_ambient(grid_pos)

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

func _on_storm_warning() -> void:
	play_event_sfx("storm_warning")

func _on_storm_hit() -> void:
	play_event_sfx("storm_hit")