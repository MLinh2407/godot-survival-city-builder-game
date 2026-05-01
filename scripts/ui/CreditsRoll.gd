extends Control

@export var scroll_speed: float = 50.0
@export var speed_multiplier: float = 5.0
@export var credits_path: String = "res://data/credits.txt"

@onready var credits_text: Label = $CreditsText
@onready var speed_hint: Label = $SpeedHint

const FALLBACK_CREDITS := "LOOK FOR THE LIGHT\n\nA Game By\nTeam03\n"

var _scrolling: bool = false
var _end_y: float = 0.0
var _hint_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_credits_text()
	if speed_hint:
		speed_hint.visible = false
	if resized.is_connected(_on_resized) == false:
		resized.connect(_on_resized)

func start_roll() -> void:
	visible = true
	_scrolling = true
	call_deferred("_reset_scroll")

func _process(delta: float) -> void:
	if not _scrolling:
		return
	if not credits_text:
		return
	var speed := scroll_speed
	if Input.is_key_pressed(KEY_SPACE):
		speed *= speed_multiplier
	credits_text.position.y -= speed * delta
	if credits_text.position.y <= _end_y:
		_finish_roll()

func _reset_scroll() -> void:
	_layout_text(true)
	_start_hint_fx()

func _layout_text(reset_position: bool) -> void:
	if not credits_text:
		return
	var max_width := size.x * 0.75
	if max_width <= 0.0:
		return
	credits_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	credits_text.size = Vector2(max_width, credits_text.get_minimum_size().y)
	if reset_position:
		credits_text.position = Vector2((size.x - credits_text.size.x) * 0.5, size.y + 20.0)
	_end_y = -credits_text.size.y - 20.0

func _load_credits_text() -> void:
	var text := FALLBACK_CREDITS
	if FileAccess.file_exists(credits_path):
		var file := FileAccess.open(credits_path, FileAccess.READ)
		if file:
			text = file.get_as_text()
			file.close()
	if credits_text:
		credits_text.text = text.strip_edges()

func _finish_roll() -> void:
	_scrolling = false
	if speed_hint:
		speed_hint.visible = false
	_stop_hint_fx()

func _start_hint_fx() -> void:
	if not speed_hint:
		return
	_stop_hint_fx()
	speed_hint.visible = true
	speed_hint.modulate.a = 0.2
	_hint_tween = create_tween()
	_hint_tween.set_loops(-1)
	_hint_tween.tween_property(speed_hint, "modulate:a", 1.0, 0.6)
	_hint_tween.tween_property(speed_hint, "modulate:a", 0.2, 0.6)

func _stop_hint_fx() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	if speed_hint:
		speed_hint.modulate.a = 1.0

func _on_resized() -> void:
	if not visible:
		return
	_layout_text(false)
