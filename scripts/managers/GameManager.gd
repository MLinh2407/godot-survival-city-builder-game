extends Node

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════
signal day_advanced(new_day: int)
signal game_over(reason: String) # Triggered by Day 35 storm or 0 Population

# ══════════════════════════════════════════════════════════════════════════════
# GLOBAL GAME STATE
# ══════════════════════════════════════════════════════════════════════════════

var current_day: int = 1

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
	_initialize_resources()
	_load_character_data()

# ══════════════════════════════════════════════════════════════════════════════
# SETUP FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
func _initialize_resources() -> void:
	# 1. Initialize Population Data
	population_state = PopulationStateData.new()
	population_state.current_population = GameConstants.STARTING_POPULATION
	population_state.available_workers = GameConstants.STARTING_WORKERS
	population_state.sick_count = 0
	
	# 2. Initialize Economy Data
	power_data = ResourceData.new()
	power_data.current_value = GameConstants.STARTING_POWER_RESERVE
	
	food_data = ResourceData.new()
	food_data.current_value = GameConstants.STARTING_FOOD
	
	morale_data = ResourceData.new()
	morale_data.current_value = GameConstants.STARTING_MORALE
	
	materials_data = ResourceData.new()
	materials_data.current_value = GameConstants.STARTING_MATERIALS
	
	print("GameManager: All Resources and Population Data Initialized.")

func _load_character_data() -> void:
	# Load the custom resources your team made in Week 4
	# (Update these file paths to match your actual project folders)
	
	# colonist_kael = load("res://data/characters/kael.tres") as ColonistData
	# colonist_yuna = load("res://data/characters/yuna.tres") as ColonistData
	# colonist_rook = load("res://data/characters/rook.tres") as ColonistData
	# colonist_vasquez = load("res://data/characters/vasquez.tres") as ColonistData
	# colonist_meridian = load("res://data/characters/meridian.tres") as ColonistData
	pass

# ══════════════════════════════════════════════════════════════════════════════
# CORE GAMEPLAY LOOPS
# ══════════════════════════════════════════════════════════════════════════════
func advance_to_next_day() -> void:
	current_day += 1
	
	if current_day > GameConstants.TOTAL_DAYS:
		game_over.emit("timeline_complete")
		return
		
	day_advanced.emit(current_day)
	print("GameManager: Day advanced to ", current_day)

func get_survival_rate() -> float:
	# Used by the ending manager on Day 35. Now correctly reads from population_state!
	return float(population_state.current_population) / float(GameConstants.STARTING_POPULATION)