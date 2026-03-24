# Represents one node in a dialogue tree loaded from JSON
# The NarrativeEngine builds an array of these from events.json / endings.json
# Used for: crisis event dialogue, choice moments, ending screens, MERIDIAN terminal

class_name DialogueNodeData
extends Resource

# Identity
@export var node_id: String = ""           # Unique within its dialogue tree. e.g. "cold_night_01"
@export var speaker: String = ""           # "SYSTEM", "YUNA", "ROOK", "MERIDIAN", "VASQUEZ"
                                    
# Text displayed in the dialogue box
@export var dialogue_text: String = ""     

# Navigation 
@export var next_node_id: String = ""      # ID of the next node for linear dialogue.
                                            # Empty string = this node ends the sequence.

# --- Choices ---
# Present when this node branches. Empty array = no choices (just "Press Space to Continue")
@export var choices: Array[Dictionary] = []
# Each Dictionary in the array has this shape:
# {
#   "label": String,          # Button text shown to player. e.g. "Reassign workers to heating"
#   "next_node_id": String,   # Node to jump to on selection
#   "outcome_code": String    # Returned to CrisisEventSystem. e.g. "cold_night_option_a"
# }

# --- Blocking ---
# When true, game time is paused and the "Press Space To Continue" label is shown 
@export var is_blocking: bool = true       # Almost always true for story dialogue