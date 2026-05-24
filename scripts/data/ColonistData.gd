# Represents one of the 5 named characters
# Used by the Memorial Wall system, `EndingManager`, and death prompts

class_name ColonistData
extends Resource

# Identity
@export var character_name: String = ""        # "Yuna Tran", "Rook", "Director Vasquez", "MERIDIAN"
@export var role: String = ""                  # e.g. "Head medic, former Tier-1 hospital doctor"

# Alive flag
# GameManager reads these from an array of ColonistData
@export var alive_flag_key: String = ""        # "yuna_alive", "rook_alive", etc.
@export var is_alive: bool = true              # Initialised TRUE on Day 1 for all characters

# Death State
@export var death_day: int = -1               # -1 = still alive. Set when is_alive flips to false.
@export var death_cause: String = ""          # For Memorial Wall panel display text

# Memorial Wall
# Populated when the character dies. Displayed in the stone plaque UI overlay
@export var memorial_text: String = ""        # Short epitaph line for the Memorial Wall panel