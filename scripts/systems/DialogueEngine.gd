class_name DialogueEngine
extends Node
signal card_dismissed
signal choice_made(event_id: String, choice_id: String, choice_data: Dictionary)
signal card_opened(event_id: String)

@export var dialogue_root_path: NodePath = NodePath("../../UILayer/DialogueBox")
@export var backdrop_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueBackdrop")
@export var card_panel_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueCard")
@export var text_label_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueText")
@export var choices_box_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueChoices")
@export var portrait_frame_path: NodePath = NodePath("../../UILayer/DialogueBox/DialoguePortraitFrame")
@export var portrait_image_path: NodePath = NodePath("../../UILayer/DialogueBox/DialoguePortraitFrame/DialoguePortraitImage")
@export var portrait_name_label_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueSpeakerName")
@export var portrait_role_label_path: NodePath = NodePath("../../UILayer/DialogueBox/DialogueSpeakerRole")
@export var button_style_source_path: NodePath = NodePath("../../UILayer/HUD/SpeedControls/ButtonPause")

var _events_by_id: Dictionary = {}
var _active_event_id: String = ""
var _was_tree_paused: bool = false
var _previous_speed: int = TimeManager.GameSpeed.NORMAL
var _dialogue_pause_depth: int = 0
var _button_style_normal: StyleBox
var _button_style_hover: StyleBox
var _button_style_pressed: StyleBox
var _button_font_color: Color = Color(0.84, 0.95, 1.0, 1.0)
var _text_default_left: float = 0.0
var _choices_default_left: float = 0.0
var _last_card_shown_time: int = 0

const _PORTRAIT_LAYOUT_SHIFT: float = 200.0
const _SPEAKER_LABEL_LEFT: float = 232.0
const _SPEAKER_LABEL_RIGHT: float = 396.0
const _SPEAKER_NAME_TOP: float = 352.0
const _SPEAKER_NAME_BOTTOM: float = 376.0
const _SPEAKER_ROLE_TOP: float = 376.0
const _SPEAKER_ROLE_BOTTOM: float = 396.0
const _PORTRAIT_TEXTURES_BY_KEY: Dictionary = {
	"kael": "res://assets/characters/Kael.png",
	"yuna": "res://assets/characters/Yuna.png",
	"rook": "res://assets/characters/Rook.png",
	"vasquez": "res://assets/characters/Vasquez.png",
	"meridian": "res://assets/characters/MERDIAN.png"
}
const _PORTRAIT_NAMES_BY_KEY: Dictionary = {
	"kael": "Kael",
	"yuna": "Yuna",
	"rook": "Rook",
	"vasquez": "Vasquez",
	"meridian": "MERIDIAN"
}
const _PORTRAIT_ROLES_BY_KEY: Dictionary = {
	"kael": "Grid-7 Director",
	"yuna": "Head Medic",
	"rook": "Scout",
	"vasquez": "Grid-9 Director",
	"meridian": "AI"
}

@onready var _dialogue_root: Control = get_node(dialogue_root_path)
@onready var _backdrop: ColorRect = get_node(backdrop_path)
@onready var _card_panel: Panel = get_node(card_panel_path)
@onready var _text_label: Label = get_node(text_label_path)
@onready var _choices_box: VBoxContainer = get_node(choices_box_path)
@onready var _portrait_frame: Panel = get_node_or_null(portrait_frame_path)
@onready var _portrait_image: TextureRect = get_node_or_null(portrait_image_path)
@onready var _portrait_name_label: Label = get_node_or_null(portrait_name_label_path)
@onready var _portrait_role_label: Label = get_node_or_null(portrait_role_label_path)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_text_default_left = _text_label.offset_left
	_choices_default_left = _choices_box.offset_left
	_cache_button_styles()
	_load_events()
	_ensure_portrait_labels()
	_set_portrait_for_event({})
	_set_card_visible(false)

func _ensure_portrait_labels() -> void:
	if not _dialogue_root:
		return
	if not _portrait_name_label:
		var name_label := Label.new()
		name_label.name = "DialogueSpeakerName"
		name_label.offset_left = _SPEAKER_LABEL_LEFT
		name_label.offset_top = _SPEAKER_NAME_TOP
		name_label.offset_right = _SPEAKER_LABEL_RIGHT
		name_label.offset_bottom = _SPEAKER_NAME_BOTTOM
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.visible = false
		_dialogue_root.add_child(name_label)
		_portrait_name_label = name_label
	if _portrait_name_label:
		# If a portrait frame exists, position the name label just below it to avoid overlap
		if _portrait_frame and _portrait_frame is Control:
			var pl = _portrait_frame.offset_left + 6.0
			var pr = _portrait_frame.offset_right - 6.0
			var nt = _portrait_frame.offset_bottom + 8.0
			_portrait_name_label.offset_left = pl
			_portrait_name_label.offset_right = pr
			_portrait_name_label.offset_top = nt
			_portrait_name_label.offset_bottom = nt + 22.0
		else:
			_portrait_name_label.offset_left = _SPEAKER_LABEL_LEFT
			_portrait_name_label.offset_top = _SPEAKER_NAME_TOP
			_portrait_name_label.offset_right = _SPEAKER_LABEL_RIGHT
			_portrait_name_label.offset_bottom = _SPEAKER_NAME_BOTTOM
		_portrait_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_portrait_name_label.add_theme_font_size_override("font_size", 20)
		_portrait_name_label.add_theme_color_override("font_color", Color(0.25, 0.94, 1.0, 1.0))
		_portrait_name_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.44, 0.86, 0.95))
		_portrait_name_label.add_theme_constant_override("shadow_offset_x", 0)
		_portrait_name_label.add_theme_constant_override("shadow_offset_y", 0)

	if not _portrait_role_label:
		var role_label := Label.new()
		role_label.name = "DialogueSpeakerRole"
		role_label.offset_left = _SPEAKER_LABEL_LEFT
		role_label.offset_top = _SPEAKER_ROLE_TOP
		role_label.offset_right = _SPEAKER_LABEL_RIGHT
		role_label.offset_bottom = _SPEAKER_ROLE_BOTTOM
		role_label.visible = false
		_dialogue_root.add_child(role_label)
		_portrait_role_label = role_label
	if _portrait_role_label:
		# Place role label beneath the name label
		if _portrait_frame and _portrait_frame is Control and _portrait_name_label:
			var rl = _portrait_frame.offset_left + 6.0
			var rr = _portrait_frame.offset_right - 6.0
			var rtop = _portrait_name_label.offset_bottom + 4.0
			_portrait_role_label.offset_left = rl
			_portrait_role_label.offset_right = rr
			_portrait_role_label.offset_top = rtop
			_portrait_role_label.offset_bottom = rtop + 18.0
		else:
			_portrait_role_label.offset_left = _SPEAKER_LABEL_LEFT
			_portrait_role_label.offset_top = _SPEAKER_ROLE_TOP
			_portrait_role_label.offset_right = _SPEAKER_LABEL_RIGHT
			_portrait_role_label.offset_bottom = _SPEAKER_ROLE_BOTTOM
		_portrait_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_portrait_role_label.add_theme_font_size_override("font_size", 12)
		_portrait_role_label.add_theme_color_override("font_color", Color(0.72, 0.75, 0.79, 0.92))

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
	_load_events_from_file("res://data/events.json", "events", false)
	_load_events_from_file("res://data/sub_events.json", "sub_events", true)

func _load_events_from_file(path: String, root_key: String, is_sub_event_file: bool) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("DialogueEngine: Failed to open %s" % path)
		return

	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DialogueEngine: %s has invalid root" % path)
		return

	var entries = parsed.get(root_key, [])
	if typeof(entries) != TYPE_ARRAY:
		push_warning("DialogueEngine: %s %s is not an array" % [path, root_key])
		return

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var event_data: Dictionary = raw_entry
		if is_sub_event_file:
			event_data = _adapt_sub_event_for_dialogue(raw_entry)
			if event_data.is_empty():
				continue

		var event_id = str(event_data.get("event_id", "")).strip_edges()
		if event_id == "":
			continue
		_events_by_id[event_id] = event_data

func _adapt_sub_event_for_dialogue(sub_event: Dictionary) -> Dictionary:
	var event_id = str(sub_event.get("event_id", sub_event.get("sub_event_id", ""))).strip_edges()
	if event_id == "":
		return {}

	var setup_text = str(sub_event.get("setup_text", sub_event.get("prompt_text", ""))).strip_edges()
	var choices: Array = sub_event.get("choices", [])
	if setup_text == "" or typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return {}

	var adapted_choices: Array = []
	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue
		var choice_id = str(choice.get("id", "continue")).strip_edges()
		var choice_text = str(choice.get("text", "Continue"))
		var outcomes: Array = choice.get("outcomes", [])
		if typeof(outcomes) != TYPE_ARRAY:
			outcomes = []
		adapted_choices.append({
			"id": choice_id,
			"text": choice_text,
			"outcomes": outcomes
		})

	if adapted_choices.is_empty():
		return {}

	return {
		"event_id": event_id,
		"setup_text": setup_text,
		"character_portrait": str(sub_event.get("character_portrait", "")),
		"character_name": str(sub_event.get("character_name", "")),
		"character_role": str(sub_event.get("character_role", "")),
		"choices": adapted_choices,
	}

func show_event(event_id: String) -> void:
	if not _events_by_id.has(event_id):
		push_warning("DialogueEngine: Unknown event_id: %s" % event_id)
		return
	_active_event_id = event_id
	_build_card(_events_by_id[event_id])

func has_event(event_id: String) -> bool:
	return _events_by_id.has(event_id)

func reset_for_new_game() -> void:
	_active_event_id = ""
	_was_tree_paused = false
	_previous_speed = TimeManager.GameSpeed.NORMAL
	_dialogue_pause_depth = 0
	_last_card_shown_time = 0
	_set_portrait_for_event({})
	_clear_choices()
	_set_card_visible(false)
	if _dialogue_root:
		_dialogue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop:
		_backdrop.visible = false
	if _card_panel:
		_card_panel.visible = false
	if _text_label:
		_text_label.visible = false
	if _choices_box:
		_choices_box.visible = false

func is_intro_card_active() -> bool:
	if not _dialogue_root:
		return false
	if not _dialogue_root.visible:
		return false
	if typeof(_active_event_id) != TYPE_STRING:
		return false
	return str(_active_event_id).begins_with("intro_")

func _build_card(event_data: Dictionary) -> void:
	_pause_game()
	var setup_text = str(event_data.get("setup_text", ""))
	_text_label.text = setup_text
	_set_portrait_for_event(event_data)
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
	# Allow one frame for the label and buttons to update their sizes
	await get_tree().process_frame
	# Compute minimal heights for text and choices so the card can shrink-wrap
	var text_min_h: float = 0.0
	var choices_min_h: float = 0.0
	if _text_label:
		text_min_h = _text_label.get_minimum_size().y
	if _choices_box:
		choices_min_h = _choices_box.get_minimum_size().y
	var portrait_bottom: float = 0.0
	if _portrait_frame and _portrait_frame.visible:
		portrait_bottom = _portrait_frame.offset_bottom
	var content_bottom: float = max(_text_label.offset_top + text_min_h, portrait_bottom)
	# Place choices under the content with a gap
	var choices_count = 0
	if typeof(choices) == TYPE_ARRAY:
		choices_count = choices.size()
	var extra_gap: float = 12.0
	if choices_count > 1:
		extra_gap = 54.0
	var choices_top_target: float = content_bottom + extra_gap
	if _choices_box:
		_choices_box.offset_top = choices_top_target
	# Compute desired bottom edge for the card (choices bottom + padding)
	var bottom_padding: float = 32.0
	var desired_bottom: float = choices_top_target + choices_min_h + bottom_padding
	if _card_panel:
		# Keep a minimum size so the card doesn't collapse too small
		var min_bottom = _card_panel.offset_top + 240.0
		_card_panel.offset_bottom = max(desired_bottom, min_bottom)
	_set_card_visible(true)
	card_opened.emit(_active_event_id)
	_last_card_shown_time = Time.get_ticks_msec()
	AudioManager.play_ui_card_sfx("open")
	AudioManager.on_crisis_card_opened()
	_play_event_specific_sfx(_active_event_id)

func _set_portrait_for_event(event_data: Dictionary) -> void:
	if not _portrait_frame or not _portrait_image:
		_apply_portrait_layout(false)
		return

	var portrait_key = str(event_data.get("character_portrait", "")).to_lower()
	var display_data = _resolve_character_display(event_data, portrait_key)
	var character_name = str(display_data.get("name", ""))
	var character_role = str(display_data.get("role", ""))
	if portrait_key == "" or not _PORTRAIT_TEXTURES_BY_KEY.has(portrait_key):
		_portrait_image.texture = null
		_portrait_frame.visible = false
		_portrait_image.visible = false
		_set_portrait_identity("", "")
		_apply_portrait_layout(false)
		return

	var texture_path = str(_PORTRAIT_TEXTURES_BY_KEY[portrait_key])
	var portrait_texture := load(texture_path) as Texture2D
	if portrait_texture == null:
		push_warning("DialogueEngine: Missing portrait texture at %s" % texture_path)
		_portrait_image.texture = null
		_portrait_frame.visible = false
		_portrait_image.visible = false
		_set_portrait_identity("", "")
		_apply_portrait_layout(false)
		return

	_portrait_image.texture = portrait_texture
	_portrait_frame.visible = true
	_portrait_image.visible = true
	_set_portrait_identity(character_name, character_role)
	_apply_portrait_layout(true)

func _resolve_character_display(event_data: Dictionary, portrait_key: String) -> Dictionary:
	var explicit_name = str(event_data.get("character_name", "")).strip_edges()
	var explicit_role = str(event_data.get("character_role", "")).strip_edges()
	var resolved_name = explicit_name
	if resolved_name == "" and _PORTRAIT_NAMES_BY_KEY.has(portrait_key):
		resolved_name = str(_PORTRAIT_NAMES_BY_KEY[portrait_key])
	var resolved_role = explicit_role
	if resolved_role == "" and _PORTRAIT_ROLES_BY_KEY.has(portrait_key):
		resolved_role = str(_PORTRAIT_ROLES_BY_KEY[portrait_key])
	return {
		"name": resolved_name,
		"role": resolved_role,
	}

func _set_portrait_identity(name_text: String, role_text: String) -> void:
	if not _portrait_name_label:
		return
	var has_name = name_text.strip_edges() != ""
	_portrait_name_label.text = name_text
	_portrait_name_label.visible = has_name
	if _portrait_role_label:
		var has_role = role_text.strip_edges() != "" and has_name
		_portrait_role_label.text = role_text
		_portrait_role_label.visible = has_role

func _apply_portrait_layout(has_portrait: bool) -> void:
	if not _text_label or not _choices_box:
		return
	if has_portrait:
		_text_label.offset_left = _text_default_left + _PORTRAIT_LAYOUT_SHIFT
		_choices_box.offset_left = _choices_default_left + _PORTRAIT_LAYOUT_SHIFT
	else:
		_text_label.offset_left = _text_default_left
		_choices_box.offset_left = _choices_default_left

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
	if get_tree() and get_tree().has_meta("input_lock_until_msec"):
		var until = int(get_tree().get_meta("input_lock_until_msec"))
		if Time.get_ticks_msec() < until:
			print("DialogueEngine: Ignoring input due to global input lock")
			return

	if Time.get_ticks_msec() - _last_card_shown_time < 200:
		print("DialogueEngine: Ignoring rapid choice activation")
		return
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

func _recursive_find(node: Node, target_name: String):
	if not node:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		if child is Node:
			var res = _recursive_find(child, target_name)
			if res:
				return res
	return null

func _dismiss_card() -> void:
	var should_force_unpause := _active_event_id.begins_with("intro_")
	_set_portrait_for_event({})
	_set_card_visible(false)
	_clear_choices()
	AudioManager.play_ui_card_sfx("dismiss")
	card_dismissed.emit()
	await get_tree().process_frame
	_resume_game()
	
	if should_force_unpause and not is_intro_card_active():
		get_tree().paused = false
		TimeManager.set_game_speed(TimeManager.GameSpeed.NORMAL)
	if _dialogue_root and _dialogue_root.visible:
		return
	AudioManager.on_crisis_card_dismissed()

func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()

func _pause_game() -> void:
	if not get_tree():
		return
	if _dialogue_pause_depth == 0:
		_was_tree_paused = get_tree().paused
		_previous_speed = TimeManager.current_speed
	_dialogue_pause_depth += 1
	get_tree().paused = true
	TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)

func _resume_game() -> void:
	if not get_tree():
		return
	if _dialogue_pause_depth > 0:
		_dialogue_pause_depth -= 1
	if _dialogue_pause_depth > 0:
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
		if _card_panel and _card_panel.focus_mode != Control.FOCUS_NONE:
			_card_panel.grab_focus()
			if _choices_box and _choices_box.get_child_count() > 0:
				var first_btn = _choices_box.get_child(0)
				if first_btn and first_btn.has_method("grab_focus") \
						and first_btn.focus_mode != Control.FOCUS_NONE:
					first_btn.grab_focus()

func _play_event_specific_sfx(event_id: String) -> void:
	match event_id:
		"the_vasquez_offer":
			AudioManager.play_event_sfx("radio_vasquez")
		"meridian_contact":
			AudioManager.play_event_sfx("meridian_contact")
		_:
			return

func show_death_card(portrait_key: String, char_name: String, char_role: String, prompt_text: String) -> void:
	var event_data: Dictionary = {
		"setup_text": prompt_text,
		"character_portrait": portrait_key,
		"character_name": char_name,
		"character_role": char_role,
		"choices": [
			{"id": "acknowledge", "text": "Acknowledge", "outcomes": []}
		]
	}
	
	# Use a special ID for death cards
	_active_event_id = "death_card_" + portrait_key
	
	# Build and show the card
	_build_card(event_data)
