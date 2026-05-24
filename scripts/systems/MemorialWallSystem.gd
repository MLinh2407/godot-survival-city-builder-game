extends Node

signal death_prompt_shown(character_id: String)

var _dialogue_engine: Node
var _game_manager: Node
var _grid_manager: Node

# Resolve runtime dependencies and wire death/dialogue callbacks.
func _ready() -> void:
	_game_manager = GameManager
	_dialogue_engine = get_tree().root.get_node_or_null("Main/Events/DialogueEngine")
	_grid_manager = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
	if not _dialogue_engine:
		_dialogue_engine = get_tree().root.find_child("DialogueEngine", true, false)
	if not _grid_manager:
		_grid_manager = get_tree().root.find_child("GridSystem", true, false)
	
	if _game_manager:
		_game_manager.named_character_died.connect(_on_character_died)
	else:
		push_error("MemorialWallSystem: GameManager not found!")

	if _dialogue_engine and _dialogue_engine.has_signal("choice_made"):
		if not _dialogue_engine.choice_made.is_connected(_on_dialogue_choice_made):
			_dialogue_engine.choice_made.connect(_on_dialogue_choice_made)

# Triggered when any named character dies.
func _on_character_died(character_id: String) -> void:
	# Not show prompt if wall already built
	if GameManager.memorial_wall_built:
		return
	
	_show_death_prompt(character_id)

# Show the memorial prompt card for the fallen character.
func _show_death_prompt(character_id: String) -> void:
	if not _dialogue_engine:
		_dialogue_engine = get_tree().root.get_node_or_null("Main/Events/DialogueEngine")
		if not _dialogue_engine:
			_dialogue_engine = get_tree().root.find_child("DialogueEngine", true, false)
		if not _dialogue_engine:
			push_error("MemorialWallSystem: DialogueEngine not found!")
			return
	
	var lower_id = character_id.to_lower()
	var char_metadata = GameManager.CHARACTER_METADATA.get(lower_id)
	
	if not char_metadata:
		push_error("MemorialWallSystem: Unknown character ID: ", character_id)
		return
	
	var char_name = char_metadata.get("name", "")
	var char_role = char_metadata.get("role", "")
	var portrait_key = lower_id
	
	# Build the prompt text
	var prompt_text = "Build the Memorial Wall to honour the fallen"
	
	# Show the death card with portrait, name, role and text
	if _dialogue_engine.has_method("show_death_card"):
		_dialogue_engine.show_death_card(portrait_key, char_name, char_role, prompt_text)
	else:
		push_error("MemorialWallSystem: DialogueEngine is missing show_death_card().")
		return
	
	death_prompt_shown.emit(lower_id)

# React to the acknowledgement choice by entering memorial build mode.
func _on_dialogue_choice_made(event_id: String, choice_id: String, _choice_data: Dictionary) -> void:
	if not event_id.begins_with("death_card_"):
		return
	if choice_id != "acknowledge":
		return
	if GameManager.memorial_wall_built:
		return
	if not _grid_manager:
		_grid_manager = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
		if not _grid_manager:
			_grid_manager = get_tree().root.find_child("GridSystem", true, false)
	if _grid_manager and _grid_manager.has_method("enter_build_mode"):
		_grid_manager.enter_build_mode("memorial")

# Mark the memorial wall as built so the prompt will not reappear.
func mark_memorial_built() -> void:
	GameManager.memorial_wall_built = true