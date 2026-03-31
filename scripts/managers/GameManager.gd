extends Node

# ══════════════════════════════════════════════════════════════════════════════
# GLOBAL GAME STATE
# ══════════════════════════════════════════════════════════════════════════════

var current_population: int = GameConstants.STARTING_POPULATION
var available_workers: int = GameConstants.STARTING_WORKERS
var sick_count: int = 0
var current_day: int = 1
var materials: int = GameConstants.STARTING_MATERIALS

# Float 0-100. Starts at 50 (Neutral)
var hope_order_slider: float = 50.0 

# ══════════════════════════════════════════════════════════════════════════════
# CHARACTER ALIVE FLAGS (All true on Day 1)
# ══════════════════════════════════════════════════════════════════════════════

var yuna_alive: bool = true
var rook_alive: bool = true
var vasquez_alive: bool = true
var meridian_alive: bool = true

# ══════════════════════════════════════════════════════════════════════════════
# DATA CLASS INSTANCES
# ══════════════════════════════════════════════════════════════════════════════
# Note: Assuming these data classes were defined in Week 4. 
# We declare them here so other systems can access them globally.

var population_state: PopulationStateData
var power_data: ResourceData
var food_data: ResourceData
var morale_data: ResourceData
var materials_data: ResourceData

var colonist_kael: ColonistData
var colonist_yuna: ColonistData
var colonist_rook: ColonistData
var colonist_vasquez: ColonistData
var colonist_meridian: ColonistData

func _ready() -> void:
	# We will instantiate the data classes here if needed, 
	# or let their respective managers handle the initialization.
	pass