class_name DialogueEngine
extends Node
signal card_dismissed
signal choice_made(event_id: String, choice_id: String, choice_data: Dictionary)

@export var dialogue_root_path: NodePath = NodePath("../../UILayer/DialogueBox")
@export var backdrop_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueBackdrop")
@export var card_panel_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueCard")
@export var text_label_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueText")
@export var choices_box_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueChoices")
@export var button_style_source_path: NodePath = NodePath("../../UILayer/HUD/SpeedControls/ButtonPause")

var _events_by_id: Dictionary = {}
var _active_event_id: String = ""
var _was_tree_paused: bool = false
var _previous_speed: int = TimeManager.GameSpeed.NORMAL
var _button_style_normal: StyleBox
var _button_style_hover: StyleBox
var _button_style_pressed: StyleBox
var _button_font_color: Color = Color(0.84, 0.95, 1.0, 1.0)

@onready var _dialogue_root: Control = get_node(dialogue_root_path)
@onready var _backdrop: ColorRect = get_node(backdrop_path)
@onready var _card_panel: Panel = get_node(card_panel_path)
@onready var _text_label: Label = get_node(text_label_path)
@onready var _choices_box: VBoxContainer = get_node(choices_box_path)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_button_styles()
	_load_events()
	_set_card_visible(false)

func _cache_button_styles() -> void:
	if not button_style_source_path:
		return
	var source_button: Button = get_node_or_null(button_style_source_path)
	if not source_button:
		return
	_button_style_normal = source_button.get_theme_stylebox("normal")
	_button_style_hover = source_button.get_theme_stylebox("hover")
	_button_style_pressed = source_button.get_theme_stylebox("pressed")
	if source_button.has_theme_color_override("font_color"):
		_button_font_color = source_button.get_theme_color("font_color")

func _load_events() -> void:
	_events_by_id.clear()
	var file = FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		push_warning("DialogueEngine: Failed to open events.json")
		return
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DialogueEngine: events.json has invalid root")
		return
	var events = parsed.get("events", [])
	if typeof(events) != TYPE_ARRAY:
		push_warning("DialogueEngine: events.json events is not an array")
		return
	for event_data in events:
		if typeof(event_data) != TYPE_DICTIONARY:
			continue
		var event_id = str(event_data.get("event_id", ""))
		if event_id == "":
			continue
		_events_by_id[event_id] = event_data

func show_event(event_id: String) -> void:
	if not _events_by_id.has(event_id):
		push_warning("DialogueEngine: Unknown event_id: %s" % event_id)
		return
	_active_event_id = event_id
	_build_card(_events_by_id[event_id])

func _build_card(event_data: Dictionary) -> void:
	var setup_text = str(event_data.get("setup_text", ""))
	_text_label.text = setup_text
	_clear_choices()
	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		choices = [ {"id": "continue", "text": "Continue", "outcomes": []}]
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_id = str(choice.get("id", "continue"))
		var choice_text = str(choice.get("text", "Continue"))
		var button = _create_choice_button(choice_text)
		button.pressed.connect(_on_choice_pressed.bind(_active_event_id, choice_id, choice))
		_choices_box.add_child(button)
	_pause_game()
	_set_card_visible(true)

func _create_choice_button(choice_text: String) -> Button:
	var button = Button.new()
	button.text = choice_text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _button_style_normal:
		button.add_theme_stylebox_override("normal", _button_style_normal)
	if _button_style_hover:
		button.add_theme_stylebox_override("hover", _button_style_hover)
	if _button_style_pressed:
		button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_color_override("font_color", _button_font_color)
	button.set_script(load("res://scripts/ui/UI_Button.gd"))
	return button

func _on_choice_pressed(event_id: String, choice_id: String, choice_data: Dictionary) -> void:
	var delta = _extract_hope_order_delta(choice_data)
	GameManager.apply_hope_order_delta(delta)
	print("%s/%s" % [event_id, choice_id])
	choice_made.emit(event_id, choice_id, choice_data)
	_dismiss_card()

func _extract_hope_order_delta(choice_data: Dictionary) -> float:
	var outcomes: Array = choice_data.get("outcomes", [])
	for outcome in outcomes:
		if typeof(outcome) != TYPE_DICTIONARY:
			continue
		if outcome.has("hope_order_delta") and outcome["hope_order_delta"] != null:
			return float(outcome["hope_order_delta"])
	return 0.0

func _dismiss_card() -> void:
	_set_card_visible(false)
	_clear_choices()
	_resume_game()
	card_dismissed.emit()

func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()

func _pause_game() -> void:
	if not get_tree():
		return
	_was_tree_paused = get_tree().paused
	_previous_speed = TimeManager.current_speed
	get_tree().paused = true
	TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)

func _resume_game() -> void:
	if not get_tree():
		return
	if _was_tree_paused or _previous_speed == TimeManager.GameSpeed.PAUSED:
		get_tree().paused = true
		TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)
	else:
		get_tree().paused = false
		TimeManager.set_game_speed(_previous_speed)

func _set_card_visible(is_visible: bool) -> void:
	if _dialogue_root:
		_dialogue_root.visible = is_visible
		_dialogue_root.process_mode = Node.PROCESS_MODE_ALWAYS
		if is_visible:
			_dialogue_root.mouse_filter = Control.MOUSE_FILTER_STOP
			var _p = _dialogue_root.get_parent()
			if _p:
				_p.move_child(_dialogue_root, max(0, _p.get_child_count() - 1))
		else:
			_dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop:
		_backdrop.visible = is_visible
		if is_visible:
			_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _card_panel:
		_card_panel.visible = is_visible
	if _text_label:
		_text_label.visible = is_visible
	if _choices_box:
		_choices_box.visible = is_visible
	# When visible, ensure the card grabs focus so keyboard and input target the card
	if is_visible:
		if _card_panel:
			_card_panel.grab_focus()
			# Prefer focusing the first choice button
			if _choices_box and _choices_box.get_child_count() > 0:
				var first_btn = _choices_box.get_child(0)
				if first_btn and first_btn.has_method("grab_focus"):
					first_btn.grab_focus()
