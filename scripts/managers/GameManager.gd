extends Node

signal hope_order_changed(new_value: float)

# ══════════════════════════════════════════════════════════════════════════════
# GLOBAL GAME STATE
# ══════════════════════════════════════════════════════════════════════════════

var current_population: int = GameConstants.STARTING_POPULATION
var available_workers: int  = GameConstants.STARTING_WORKERS
var sick_count: int         = 0
var current_day: int        = 1
var materials: int          = GameConstants.STARTING_MATERIALS

# Float 0-100. Starts at 50 (Neutral)
var _hope_order_slider: float = 50.0
var hope_order_slider: float:
	get:
		return _hope_order_slider
	set(value):
		var next_value = clampf(value, 0.0, 100.0)
		if is_equal_approx(next_value, _hope_order_slider):
			return
		_hope_order_slider = next_value
		hope_order_changed.emit(_hope_order_slider)

# ══════════════════════════════════════════════════════════════════════════════
# CHARACTER ALIVE FLAGS (All true on Day 1)
# ══════════════════════════════════════════════════════════════════════════════

var yuna_alive: bool     = true
var rook_alive: bool     = true
var vasquez_alive: bool  = true
var meridian_alive: bool = true

# ══════════════════════════════════════════════════════════════════════════════
# NARRATIVE STATE FLAGS (set by CrisisEventSystem as story events resolve)
# ══════════════════════════════════════════════════════════════════════════════

var med_clinic_built: bool           = false  # Set TRUE by BuildingSystem on placement
var rook_militia_stopped: bool       = false  # Set TRUE by CrisisEventSystem Day 24 Option B
var rook_militia_sanctioned: bool    = false  # Set TRUE by CrisisEventSystem Day 24 Option A
var rook_reconciliation_taken: bool  = false  # Set TRUE by CrisisEventSystem reconciliation dialogue
var vasquez_trade_accepted: bool     = false  # Set TRUE by CrisisEventSystem on Day 11 Option A
var meridian_trusted: bool           = false  # Set TRUE by CrisisEventSystem Day 21 Option A

# ══════════════════════════════════════════════════════════════════════════════
# DATA CLASS INSTANCES
# ══════════════════════════════════════════════════════════════════════════════

var population_state: PopulationStateData

var resource_power: ResourceData
var resource_food: ResourceData
var resource_morale: ResourceData
var resource_materials: ResourceData

var colonist_kael: ColonistData
var colonist_yuna: ColonistData
var colonist_rook: ColonistData
var colonist_vasquez: ColonistData
var colonist_meridian: ColonistData

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_initialize_data_classes()
	hope_order_slider = GameConstants.SLIDER_STARTING_VALUE

func _initialize_data_classes() -> void:
	# 1. Population State
	population_state                    = PopulationStateData.new()
	population_state.total_population   = current_population
	population_state.available_workers  = available_workers
	population_state.sick_count         = sick_count
	population_state.max_workers        = GameConstants.MAX_WORKERS_LATE_GAME

	# 2. Resource Data
	resource_power                      = ResourceData.new()
	resource_power.res_name             = "Power"
	resource_power.warning_threshold    = GameConstants.WARNING_THRESHOLD
	resource_power.critical_threshold   = GameConstants.CRITICAL_THRESHOLD

	resource_food                       = ResourceData.new()
	resource_food.res_name              = "Food"
	resource_food.current_value         = GameConstants.STARTING_FOOD
	resource_food.max_value             = GameConstants.STARTING_FOOD
	resource_food.warning_threshold     = GameConstants.WARNING_THRESHOLD
	resource_food.critical_threshold    = GameConstants.CRITICAL_THRESHOLD

	resource_morale                     = ResourceData.new()
	resource_morale.res_name            = "Morale"
	resource_morale.current_value       = GameConstants.STARTING_MORALE
	resource_morale.max_value           = 100.0
	resource_morale.warning_threshold   = GameConstants.WARNING_THRESHOLD
	resource_morale.critical_threshold  = GameConstants.CRITICAL_THRESHOLD

	resource_materials                  = ResourceData.new()
	resource_materials.res_name         = "Materials"
	resource_materials.warning_threshold  = 0.0
	resource_materials.critical_threshold = 0.0

	# 3. Colonist Data
	colonist_kael                = ColonistData.new()
	colonist_kael.character_name = "Kael"
	colonist_kael.role           = "Director"
	colonist_kael.is_alive       = true

	colonist_yuna                = ColonistData.new()
	colonist_yuna.character_name = "Yuna"
	colonist_yuna.role           = "Head Medic"
	colonist_yuna.is_alive       = yuna_alive

	colonist_rook                = ColonistData.new()
	colonist_rook.character_name = "Rook"
	colonist_rook.role           = "Scout"
	colonist_rook.is_alive       = rook_alive

	colonist_vasquez                = ColonistData.new()
	colonist_vasquez.character_name = "Vasquez"
	colonist_vasquez.role           = "Grid-9 Director"
	colonist_vasquez.is_alive       = vasquez_alive

	colonist_meridian                = ColonistData.new()
	colonist_meridian.character_name = "MERIDIAN"
	colonist_meridian.role = "Fragmented AI"
	colonist_meridian.is_alive = meridian_alive

func apply_hope_order_delta(delta: float) -> void:
	hope_order_slider = hope_order_slider + delta
