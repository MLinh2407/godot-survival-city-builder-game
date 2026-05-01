extends Control

const ENDING_VIDEO_PREFIX := {
	EndingManager.ENDING_THE_SIGNAL: "signal",
	EndingManager.ENDING_THE_QUIET: "quiet",
	EndingManager.ENDING_THE_TORCH: "torch",
	EndingManager.ENDING_THE_NECESSARY_EVIL: "evil",
}

const SKIP_DELAY_SEC: float = 5.0
const DEFAULT_VIDEO_SIZE: Vector2 = Vector2(1934.0, 1080.0)

@onready var video_player: VideoStreamPlayer = $EndingVideo
@onready var skip_prompt: Label = $SkipPrompt
@onready var end_card: Control = $EndCard
@onready var end_card_text: Label = $EndCard/EndCardText
@onready var continue_button: Button = $EndCard/ContinueButton
@onready var credits_roll: Control = $CreditsRoll

var _elapsed: float = 0.0
var _skip_enabled: bool = false
var _ending_key: String = ""
var _rook_alive: bool = false
var _was_paused: bool = false
var _previous_speed: int = TimeManager.GameSpeed.NORMAL
var _skip_tween: Tween
var _continue_hover_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	visible = false
	end_card.visible = false
	skip_prompt.visible = false
	if credits_roll:
		credits_roll.visible = false
	if continue_button:
		continue_button.visible = false
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
		if not continue_button.mouse_entered.is_connected(_on_continue_mouse_entered):
			continue_button.mouse_entered.connect(_on_continue_mouse_entered)
		if not continue_button.mouse_exited.is_connected(_on_continue_mouse_exited):
			continue_button.mouse_exited.connect(_on_continue_mouse_exited)

	if EndingManager and not EndingManager.ending_determined.is_connected(_on_ending_determined):
		EndingManager.ending_determined.connect(_on_ending_determined)

	if video_player and not video_player.finished.is_connected(_on_video_finished):
		video_player.process_mode = Node.PROCESS_MODE_ALWAYS
		video_player.finished.connect(_on_video_finished)
	if get_viewport() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(delta: float) -> void:
	if not visible or end_card.visible or (credits_roll and credits_roll.visible):
		return
	_elapsed += delta
	if not _skip_enabled and _elapsed >= SKIP_DELAY_SEC:
		_skip_enabled = true
		skip_prompt.visible = true
		_start_skip_prompt_fx()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or end_card.visible or (credits_roll and credits_roll.visible):
		return
	if not _skip_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_show_end_card()

func _on_ending_determined(ending_key: String, rook_alive: bool) -> void:
	_ending_key = ending_key
	_rook_alive = rook_alive
	_start_ending()

func _start_ending() -> void:
	visible = true
	end_card.visible = false
	skip_prompt.visible = false
	if credits_roll:
		credits_roll.visible = false
	if continue_button:
		continue_button.visible = false
	_elapsed = 0.0
	_skip_enabled = false
	_stop_skip_prompt_fx()

	_was_paused = get_tree().paused
	get_tree().paused = true
	if TimeManager:
		_previous_speed = TimeManager.current_speed
		TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)

	if AudioManager and AudioManager.has_method("fade_out_music"):
		AudioManager.fade_out_music(1.5)

	var video_path := _get_video_path(_ending_key, _rook_alive)
	var stream := load(video_path)
	if not stream:
		push_warning("EndingScreen: Missing video stream at %s" % video_path)
		_show_end_card()
		return

	video_player.stream = stream
	video_player.play()
	await get_tree().process_frame
	_fit_video_to_viewport()

func _on_video_finished() -> void:
	_show_end_card()

func _show_end_card() -> void:
	if end_card.visible:
		return
	if video_player and video_player.is_playing():
		video_player.stop()
	end_card.visible = true
	skip_prompt.visible = false
	_stop_skip_prompt_fx()
	_set_end_card_text()
	if continue_button:
		continue_button.visible = true
		_start_continue_idle_fx()

func _set_end_card_text() -> void:
	var ending_number := _get_ending_number(_ending_key, _rook_alive)
	end_card_text.text = "You have unlocked Ending %d out of 7 endings" % ending_number

func _on_continue_pressed() -> void:
	if not end_card.visible:
		return
	end_card.visible = false
	if continue_button:
		continue_button.visible = false
		_stop_continue_idle_fx()
	if credits_roll and credits_roll.has_method("start_roll"):
		credits_roll.visible = true
		credits_roll.call("start_roll")
	if AudioManager and AudioManager.track_3:
		AudioManager.play_music(AudioManager.track_3)

func _get_video_path(ending_key: String, rook_alive: bool) -> String:
	var prefix: String = ENDING_VIDEO_PREFIX.get(ending_key, "")
	if prefix == "signal":
		return "res://assets/ending_videos/signal.ogv"
	if prefix.is_empty():
		return ""
	var suffix := "rookalive" if rook_alive else "rookdead"
	return "res://assets/ending_videos/%s_%s.ogv" % [prefix, suffix]

func _get_ending_number(ending_key: String, rook_alive: bool) -> int:
	match ending_key:
		EndingManager.ENDING_THE_QUIET:
			return 1 if rook_alive else 2
		EndingManager.ENDING_THE_TORCH:
			return 3 if rook_alive else 4
		EndingManager.ENDING_THE_NECESSARY_EVIL:
			return 5 if rook_alive else 6
		EndingManager.ENDING_THE_SIGNAL:
			return 7
		_:
			return 0

func _on_viewport_size_changed() -> void:
	if visible and not end_card.visible:
		_fit_video_to_viewport()

func _fit_video_to_viewport() -> void:
	if not video_player:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var video_size := DEFAULT_VIDEO_SIZE
	if video_player.get_video_texture():
		video_size = video_player.get_video_texture().get_size()
	if video_size == Vector2.ZERO:
		return
	# Scale to fit inside the viewport without cropping
	var scale_factor: float = min(viewport_size.x / video_size.x, viewport_size.y / video_size.y)
	var scaled_size: Vector2 = video_size * scale_factor
	video_player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	video_player.size = video_size
	video_player.scale = Vector2(scale_factor, scale_factor)
	video_player.position = (viewport_size - scaled_size) * 0.5

func _start_skip_prompt_fx() -> void:
	if not skip_prompt:
		return
	_stop_skip_prompt_fx()
	skip_prompt.modulate.a = 0.2
	_skip_tween = create_tween()
	_skip_tween.set_loops(-1)
	_skip_tween.tween_property(skip_prompt, "modulate:a", 1.0, 0.6)
	_skip_tween.tween_property(skip_prompt, "modulate:a", 0.2, 0.6)

func _stop_skip_prompt_fx() -> void:
	if _skip_tween:
		_skip_tween.kill()
		_skip_tween = null
	if skip_prompt:
		skip_prompt.modulate.a = 1.0

func _on_continue_mouse_entered() -> void:
	_stop_continue_idle_fx()
	if continue_button:
		continue_button.modulate.a = 1.0

func _on_continue_mouse_exited() -> void:
	_start_continue_idle_fx()

func _start_continue_idle_fx() -> void:
	if not continue_button:
		return
	_stop_continue_idle_fx()
	continue_button.modulate.a = 0.7
	_continue_hover_tween = create_tween()
	_continue_hover_tween.set_loops(-1)
	_continue_hover_tween.tween_property(continue_button, "modulate:a", 1.0, 0.6)
	_continue_hover_tween.tween_property(continue_button, "modulate:a", 0.7, 0.6)

func _stop_continue_idle_fx() -> void:
	if _continue_hover_tween:
		_continue_hover_tween.kill()
		_continue_hover_tween = null
	if continue_button:
		continue_button.modulate.a = 1.0
