# Represents one of the 10 scripted crisis events
# The CrisisEventSystem loads these and fires them on schedule

class_name CrisisEventData
extends Resource

# Identity 
@export var event_id: String = ""          # Unique key, matches JSON key. e.g. "the_cold_night"
@export var event_name: String = ""        # Display name. e.g. "The Cold Night"
@export var act: int = 1                  

# Trigger
@export var trigger_day: int = 0           # Day this event fires

# Condition checks
@export var requires_morale_below: int = -1  # -1 = no morale condition. e.g. 50 for The Deserters
@export var requires_flag: String = ""       # e.g. "rook_alive" or leave empty if not needed

# State
@export var has_fired: bool = false        # Prevents double firing. Set true after event resolves
@export var player_choice: int = -1        # -1 = not yet chosen. 0 = Option A, 1 = Option B.

# Outcome codes (returned to the CrisisEventSystem after the player chooses)
@export var outcome_code_a: String = ""    # e.g. "cold_night_option_a"
@export var outcome_code_b: String = ""    # e.g. "cold_night_option_b"

# Hope / Order shift 
# Applied to GameManager.hope_order_slider when the choice is made.
@export var hope_shift_a: float = 0.0     # Negative = toward Hope (0)
@export var hope_shift_b: float = 0.0     # Positive = toward Order (100)

# Dialogue reference
# The CrisisEventSystem loads the full text from events.json key at runtime
@export var dialogue_json_key: String = ""  