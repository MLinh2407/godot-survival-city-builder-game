extends Node

var critical_warning_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var is_playing_a: bool = true
var ui_sfx_player_slider: AudioStreamPlayer
var ui_sfx_player_journal: AudioStreamPlayer
var build_sfx_player: AudioStreamPlayer
var _build_sfx_stop_timer: Timer
var rain_player: AudioStreamPlayer
var _rain_active: bool = false


var track_1: AudioStream = preload("res://assets/audio/music/Track_1.mp3")
var track_2: AudioStream = preload("res://assets/audio/music/Track_2.mp3")
var track_3: AudioStream = preload("res://assets/audio/music/Track_3.mp3")
var track_4: AudioStream = preload("res://assets/audio/music/Track_4.mp3")

# ── UI SFX ───────────────────────────────────────────────────────────────────
var sfx_hover:            AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_hover.mp3")
var sfx_click:            AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_pause:            AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_unpause:          AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_button_click.mp3")
var sfx_slider_move:      AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_slider_move.mp3")
var sfx_card_open:        AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_open.wav")
var sfx_card_dismiss:     AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_card_open1.mp3")
var sfx_journal_close:    AudioStream = preload("res://assets/audio/sfx/ui/sfx_journal_close.mp3")
var sfx_journal_open: 	  AudioStream = preload("res://assets/audio/sfx/ui/sfx_journal_open.mp3")
var sfx_ui_journal_entry: AudioStream = preload("res://assets/audio/sfx/ui/sfx_ui_journal_entry.mp3")

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
var sfx_ambient_rain:           AudioStream = preload("res://assets/audio/sfx/ambient/sfx_raining.mp3")

# Dictionary: Vector2i grid_pos → AudioStreamPlayer
# One ambient player per placed building instance on the grid
var _ambient_players: Dictionary = {}
var _startup_music_timer: Timer
var _menu_music_locked: bool = false
var _music_fade_tween: Tween

const STARTUP_MUSIC_DELAY_SEC: float = 2.2

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
		# Use a dedicated player for build SFX so we can limit their playtime
		if build_sfx_player:
			build_sfx_player.stream = stream
			build_sfx_player.play()
			# Schedule a stop for certain build sfx so they don't overlap long with music
			var stop_after: float = 0.0
			match type:
				# limit place-related sounds to 2s
				"place", "upgrade", "remove", "damage", "memorial_place", "invalid":
					stop_after = 2.0
				# limit finish-related sounds to 3s
				"repair", "power_online", "power_offline":
					stop_after = 3.0
				_:
					stop_after = 0.0
			if stop_after > 0.0:
				if _build_sfx_stop_timer:
					_build_sfx_stop_timer.stop()
					_build_sfx_stop_timer.queue_free()
				_build_sfx_stop_timer = Timer.new()
				_build_sfx_stop_timer.wait_time = stop_after
				_build_sfx_stop_timer.one_shot = true
				_build_sfx_stop_timer.autostart = true
				add_child(_build_sfx_stop_timer)
				_build_sfx_stop_timer.timeout.connect(Callable(self, "_on_build_sfx_timeout").bind(build_sfx_player))

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

	ui_sfx_player_journal = AudioStreamPlayer.new()
	ui_sfx_player_journal.bus = "SFX"
	add_child(ui_sfx_player_journal)

	# Build SFX player
	build_sfx_player = AudioStreamPlayer.new()
	build_sfx_player.bus = "SFX"
	add_child(build_sfx_player)

	# Rain ambient loop
	rain_player = AudioStreamPlayer.new()
	rain_player.bus = "SFX"
	rain_player.volume_db = -80.0
	rain_player.stream = sfx_ambient_rain
	rain_player.finished.connect(_on_rain_finished)
	add_child(rain_player)
	
	# Music Players
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = "Music"
	music_player_a.finished.connect(_on_music_player_a_finished)
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Music"
	music_player_b.finished.connect(_on_music_player_b_finished)
	add_child(music_player_b)
	_schedule_startup_music()

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
		"card_open":
			if sfx_card_open:
				ui_sfx_player.stream = sfx_card_open
				ui_sfx_player.play()
		"journal_close":
			if sfx_journal_close:
				ui_sfx_player.stream = sfx_journal_close
				ui_sfx_player.play()
		"journal_open":
			if sfx_journal_open:
				ui_sfx_player.stream = sfx_journal_open
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
		"sfx_ui_journal_entry", "journal_entry":
			if sfx_ui_journal_entry and ui_sfx_player_journal:
				ui_sfx_player_journal.stream = sfx_ui_journal_entry
				ui_sfx_player_journal.play()
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

func start_rain() -> void:
	if _rain_active:
		return
	_rain_active = true
	if not rain_player or not rain_player.stream:
		return
	rain_player.volume_db = -80.0
	rain_player.play()
	var tween := create_tween()
	var target_db: float = linear_to_db(GameConstants.RAIN_VOLUME_RATIO)
	tween.tween_property(rain_player, "volume_db", target_db, GameConstants.AMBIENT_FADE_IN)

func stop_rain() -> void:
	if not _rain_active:
		return
	_rain_active = false
	if not rain_player:
		return
	var tween := create_tween()
	tween.tween_property(rain_player, "volume_db", -80.0, GameConstants.AMBIENT_FADE_OUT)
	tween.tween_callback(rain_player.stop)

func _on_rain_finished() -> void:
	if _rain_active and rain_player:
		rain_player.play()

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
	_kill_music_fade_tween()
	# Stop the other player to prevent overlapping audio
	if is_playing_a:
		if music_player_b and music_player_b.playing:
			music_player_b.stop()
		music_player_a.stream = stream
		music_player_a.play()
		music_player_a.volume_db = 0.0
	else:
		if music_player_a and music_player_a.playing:
			music_player_a.stop()
		music_player_b.stream = stream
		music_player_b.play()
		music_player_b.volume_db = 0.0

func _is_any_music_playing() -> bool:
	return (music_player_a and music_player_a.playing) or (music_player_b and music_player_b.playing)

func _is_track_currently_playing(track: AudioStream) -> bool:
	if not track:
		return false
	if music_player_a and music_player_a.playing and music_player_a.stream == track:
		return true
	if music_player_b and music_player_b.playing and music_player_b.stream == track:
		return true
	return false

func _schedule_startup_music() -> void:
	_cancel_startup_music_timer()
	_startup_music_timer = Timer.new()
	_startup_music_timer.wait_time = STARTUP_MUSIC_DELAY_SEC
	_startup_music_timer.one_shot = true
	_startup_music_timer.autostart = true
	add_child(_startup_music_timer)
	_startup_music_timer.timeout.connect(_on_startup_music_timer_timeout)

func _cancel_startup_music_timer() -> void:
	if _startup_music_timer:
		_startup_music_timer.stop()
		_startup_music_timer.queue_free()
		_startup_music_timer = null

func _on_startup_music_timer_timeout() -> void:
	_startup_music_timer = null
	if _menu_music_locked:
		return
	if _is_any_music_playing():
		return
	play_music(track_1)

func set_menu_music_locked(locked: bool) -> void:
	_menu_music_locked = locked

func fade_out_music(duration: float = 1.5) -> void:
	if not _is_any_music_playing():
		return
	_kill_music_fade_tween()
	var tween = create_tween()
	_music_fade_tween = tween
	if music_player_a and music_player_a.playing:
		tween.tween_property(music_player_a, "volume_db", -80.0, duration)
		tween.tween_callback(music_player_a.stop)
	if music_player_b and music_player_b.playing:
		tween.parallel().tween_property(music_player_b, "volume_db", -80.0, duration)
		tween.parallel().tween_callback(music_player_b.stop)
func silence_music(fade_duration: float = 0.35) -> void:
	fade_duration = maxf(fade_duration, 0.0)
	if fade_duration <= 0.0:
		_kill_music_fade_tween()
		_stop_and_reset_music_player(music_player_a)
		_stop_and_reset_music_player(music_player_b)
		return

	_kill_music_fade_tween()
	_fade_out_and_stop_player(music_player_a, fade_duration)
	_fade_out_and_stop_player(music_player_b, fade_duration)

func _fade_out_and_stop_player(player: AudioStreamPlayer, fade_duration: float) -> void:
	if player == null:
		return
	if not player.playing:
		_stop_and_reset_music_player(player)
		return

	var tween = create_tween()
	tween.tween_property(player, "volume_db", -40.0, fade_duration)
	tween.tween_callback(Callable(self, "_stop_and_reset_music_player").bind(player))

func _stop_and_reset_music_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.volume_db = 0.0

func crossfade_to(stream: AudioStream, duration: float = 2.0) -> void:
	_kill_music_fade_tween()
	var tween = create_tween()
	_music_fade_tween = tween
	
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

func _kill_music_fade_tween() -> void:
	if _music_fade_tween:
		_music_fade_tween.kill()
		_music_fade_tween = null

func on_crisis_card_opened() -> void:
	if _menu_music_locked:
		return
	_cancel_startup_music_timer()
	if _is_track_currently_playing(track_2):
		return
	if _is_any_music_playing():
		crossfade_to(track_2, 1.5)
	else:
		play_music(track_2)

func on_crisis_card_dismissed() -> void:
	if _menu_music_locked:
		return
	if _is_any_music_playing():
		crossfade_to(track_1, 1.5)
	else:
		play_music(track_1)

func _on_build_sfx_timeout(player: AudioStreamPlayer) -> void:
	if player and player.playing:
		player.stop()
	if _build_sfx_stop_timer:
		_build_sfx_stop_timer.queue_free()
		_build_sfx_stop_timer = null

func _on_storm_warning() -> void:
	play_event_sfx("storm_warning")

func _on_storm_hit() -> void:
	play_event_sfx("storm_hit")
	if _menu_music_locked:
		return
	crossfade_to(track_1, 1.5)

func _on_music_player_a_finished() -> void:
	# Loops at the stream level, restart on finish to guarantee looping
	if music_player_a and music_player_a.stream:
		music_player_a.play()

func _on_music_player_b_finished() -> void:
	if music_player_b and music_player_b.stream:
		music_player_b.play()
