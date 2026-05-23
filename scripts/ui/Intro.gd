extends Control

signal intro_finished

@export var video_path: String = "res://assets/ui/main_menu/intro_video.ogv"
@export var video_start_delay_sec: float = 0.2
@onready var vp: VideoStreamPlayer = $VideoPlayer
@onready var continue_prompt: Label = $ContinuePrompt
var _preloaded_stream: VideoStream
var _is_finishing: bool = false
var _prompt_t: float = 0.0

func set_preloaded_stream(stream: VideoStream) -> void:
    _preloaded_stream = stream

func _ready() -> void:
    set_process(true)

func start_intro() -> void:
    await get_tree().create_timer(maxf(video_start_delay_sec, 0.0)).timeout
    _play_video()

func _play_video() -> void:
    var stream: VideoStream = _preloaded_stream
    if stream == null and ResourceLoader.exists(video_path):
        stream = ResourceLoader.load(video_path) as VideoStream

    if stream != null:
        vp.stream = stream
        vp.play()
        vp.finished.connect(_on_video_finished)
    else:
        _finish_intro()

func _on_video_finished() -> void:
    _finish_intro()

func _process(delta: float) -> void:
    if continue_prompt == null:
        return
    _prompt_t += delta
    var flicker: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_prompt_t * 7.8))
    continue_prompt.modulate.a = clampf(flicker, 0.35, 1.0)

func _unhandled_input(event) -> void:
    if (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE) \
    or event.is_action_pressed("ui_accept") \
    or (event is InputEventMouseButton and event.pressed):
        get_viewport().set_input_as_handled()
        _finish_intro()

func _finish_intro() -> void:
    if _is_finishing:
        return
    _is_finishing = true
    emit_signal("intro_finished")
    queue_free()