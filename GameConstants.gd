extends Node

# ══════════════════════════════════════════════════════════════════════════════
# POPULATION
# ══════════════════════════════════════════════════════════════════════════════

const STARTING_POPULATION: int         = 847
const STARTING_WORKERS: int            = 68
const MAX_WORKERS_LATE_GAME: int       = 85   # worker pool grows slowly to this cap


# ══════════════════════════════════════════════════════════════════════════════
# TIME
# ══════════════════════════════════════════════════════════════════════════════

const DAY_LENGTH_SECONDS: float        = 90.0   # real seconds per game day at 1× speed
const DAY_LENGTH_FAST: float           = 45.0   # real seconds per game day at 2× speed
const TOTAL_DAYS: int                  = 35
const STORM_START_DAY: int             = 26     # Storm Warning fires — Act III begins
const STORM_HIT_DAY: int               = 35     # storm lands, game ends


# ══════════════════════════════════════════════════════════════════════════════
# RESOURCE THRESHOLDS
# ══════════════════════════════════════════════════════════════════════════════

const WARNING_THRESHOLD: float         = 0.20   # 20% → yellow HUD, alert SFX
const CRITICAL_THRESHOLD: float        = 0.10   # 10% → red HUD, critical SFX


# ══════════════════════════════════════════════════════════════════════════════
# FOOD
# ══════════════════════════════════════════════════════════════════════════════

const BASE_FOOD_RATE: float            = 8.0    # Hydroponic Bay T1 at full staff/day
const UPGRADED_FOOD_RATE: float        = 14.0   # Hydroponic Bay T2 at full staff/day
const FOOD_STARVATION_DELAY: int       = 2      # consecutive days at Food=0 before deaths
const STARVATION_DEATHS_MIN: int       = 1
const STARVATION_DEATHS_MAX: int       = 3

const RATION_STORE_BUFFER_T1: int      = 50     # days of emergency reserve at T1
const RATION_STORE_BUFFER_T2: int      = 100    # days of emergency reserve at T2
const RATION_AUTO_THRESHOLD: float     = 0.20   # T2 auto-rationing kicks in at 20% reserve


# ══════════════════════════════════════════════════════════════════════════════
# POWER
# ══════════════════════════════════════════════════════════════════════════════

const COAL_POWER_T1: float             = 15.0   # kW produced at T1
const COAL_POWER_T2: float             = 25.0   # kW produced at T2
const COAL_WORKER_SLOTS: int           = 6

const GEOTHERMAL_POWER_T1: float       = 8.0    # kW — passive, no workers required
const GEOTHERMAL_POWER_T2: float       = 14.0
const GEOTHERMAL_WORKER_SLOTS: int     = 0

const RELAY_HUB_POWER_DRAW: float      = 1.0    # kW consumed by each Relay Hub


# ══════════════════════════════════════════════════════════════════════════════
# MORALE
# ══════════════════════════════════════════════════════════════════════════════

const MED_CLINIC_MORALE_PASSIVE: float          = 15.0   # +/day while staffed
const ARCHIVE_HALL_MORALE_PASSIVE: float        = 8.0    # +/day while built
const MEMORIAL_WALL_MORALE_BUILD: float         = 20.0   # one-time bonus on placement
const MEMORIAL_WALL_MORALE_DAILY: float         = 3.0    # +/day permanently after build
const SHELTER_MORALE_AT_CAPACITY_T1: float      = 5.0    # +/day at or below capacity
const SHELTER_MORALE_AT_CAPACITY_T2: float      = 8.0
const SHELTER_MORALE_OVERFLOW_PENALTY: float    = -3.0   # per day when overflow > threshold
const SHELTER_OVERFLOW_THRESHOLD: int           = 100    # overflow headroom before penalty starts

const MORALE_DESERTION_THRESHOLD: float         = 10.0   # Morale below this → passive desertion
const MORALE_DESERTION_WORKERS_MIN: int         = 1
const MORALE_DESERTION_WORKERS_MAX: int         = 2

const MORALE_EFFICIENCY_THRESHOLD: float        = 30.0   # Morale below this → output penalty
const MORALE_EFFICIENCY_MULTIPLIER: float       = 0.80   # all building output × 0.80

const DISEASE_MORALE_DRAIN: float               = 2.0    # Morale lost per day during outbreak


# ══════════════════════════════════════════════════════════════════════════════
# SHELTER
# ══════════════════════════════════════════════════════════════════════════════

const SHELTER_CAPACITY_T1: int                  = 200
const SHELTER_CAPACITY_T2: int                  = 280


# ══════════════════════════════════════════════════════════════════════════════
# DISEASE
# ══════════════════════════════════════════════════════════════════════════════

const DISEASE_SICK_MIN: int                     = 10
const DISEASE_SICK_MAX: int                     = 25
const DISEASE_DEATH_RATE_MIN: int               = 1    # sick die per day if untreated
const DISEASE_DEATH_RATE_MAX: int               = 3
const DISEASE_TREATMENT_RATE: int               = 5    # sick cured per day by staffed Med Clinic
const DISEASE_WATER_DELAY: int                  = 2    # days unstaffed before automatic outbreak
const DISEASE_RESISTANCE_MULTIPLIER: float      = 0.70 # T2 Water Recycler — applied at outbreak start


# ══════════════════════════════════════════════════════════════════════════════
# BUILDING DAMAGE
# ══════════════════════════════════════════════════════════════════════════════

const BUILDING_DAMAGE_DAYS: int                 = 3    # consecutive days at 0 workers → damaged
const BUILDING_DAMAGE_OUTPUT: float             = 0.30 # damaged output even when re-staffed until repaired


# ══════════════════════════════════════════════════════════════════════════════
# HOPE / ORDER SLIDER
# ══════════════════════════════════════════════════════════════════════════════

const SLIDER_HOPE_UPPER: float                  = 30.0  # 0–30 = Hope zone
const SLIDER_ORDER_LOWER: float                 = 70.0  # 70–100 = Order zone

# Hope zone passive effects
const HOPE_MORALE_DECAY_MODIFIER: float         = 0.80  # Morale decays 20% slower
const HOPE_FOOD_EFFICIENCY_MODIFIER: float      = 0.95  # food distribution −5%

# Order zone passive effects
const ORDER_FOOD_PRODUCTION_MODIFIER: float     = 1.15  # food production +15%
const ORDER_MORALE_DECAY_MODIFIER: float        = 1.20  # Morale decays 20% faster


# ══════════════════════════════════════════════════════════════════════════════
# MERIDIAN
# ══════════════════════════════════════════════════════════════════════════════

const MERIDIAN_EFFICIENCY_BOOST: float          = 1.20  # all production × 1.20 if MERIDIAN trusted
const MERIDIAN_MORALE_DRAIN: float              = 1.0   # −Morale/day ongoing


# ══════════════════════════════════════════════════════════════════════════════
# BUILDING WORKER SLOTS (total across all 10 buildings = 62 slots)
# ══════════════════════════════════════════════════════════════════════════════

const COAL_GENERATOR_SLOTS: int                 = 6
const GEOTHERMAL_TAP_SLOTS: int                 = 0    # passive
const RELAY_HUB_SLOTS: int                      = 2
const HYDROPONIC_BAY_SLOTS: int                 = 10
const RATION_STORE_SLOTS: int                   = 0    # passive
const WATER_RECYCLER_SLOTS: int                 = 4
const MED_CLINIC_SLOTS: int                     = 6
const SHELTER_BLOCK_SLOTS: int                  = 0    # no worker assignment
const ARCHIVE_HALL_SLOTS: int                   = 4
const MEMORIAL_WALL_SLOTS: int                  = 0    # permanent passive


# ══════════════════════════════════════════════════════════════════════════════
# MATERIALS
# ══════════════════════════════════════════════════════════════════════════════

const MATERIALS_PASSIVE_MIN: int                = 1
const MATERIALS_PASSIVE_MAX: int                = 2
const MATERIALS_ROOK_MILITIA_BONUS: int         = 3   # extra/day if militia sanctioned Day 24


# ══════════════════════════════════════════════════════════════════════════════
# ENDING GATES  (read only by ending_manager.gd on Day 35)
# ══════════════════════════════════════════════════════════════════════════════

const ENDING_SIGNAL_RATE: float                 = 0.85  # The Signal — min survival rate
const ENDING_QUIET_RATE: float                  = 0.65  # below this → The Quiet
const ENDING_SLIDER_MID: float                  = 50.0  # Torch vs Necessary Evil gate


# ══════════════════════════════════════════════════════════════════════════════
# CHARACTER DEATH CONDITIONS
# ══════════════════════════════════════════════════════════════════════════════

const YUNA_DEATH_DAY: int                       = 20
const YUNA_DEATH_POPULATION_THRESHOLD: int      = 600
const VASQUEZ_DEATH_DAY: int                    = 30
const VASQUEZ_DEATH_SURVIVAL_THRESHOLD: float   = 0.50
const ROOK_RECONCILIATION_DEADLINE: int         = 33


# ══════════════════════════════════════════════════════════════════════════════
# SPRITE / ASSET SIZES
# ══════════════════════════════════════════════════════════════════════════════

const BUILDING_SPRITE_SIZE: int                 = 256   # px — all building sprites
const CHARACTER_PORTRAIT_SIZE: int              = 64    # px — source size
const CHARACTER_PORTRAIT_DISPLAY_SCALE: int     = 2     # displayed at 2× in dialogue cards
const TILE_SIZE: int                            = 64    # px — isometric tile


# ══════════════════════════════════════════════════════════════════════════════
# UI / ANIMATION TIMING
# ══════════════════════════════════════════════════════════════════════════════

const INTRO_ANIMATION_DURATION: float           = 30.0  # seconds — Sumi-e intro
const TOOLTIP_AUTODISMISS_SECONDS: float        = 6.0
const TOOLTIP_FADE_IN_SECONDS: float            = 0.3
const FLICKER_TWEEN_DURATION: float             = 0.8   # Press Space To Continue alpha pulse
const FLICKER_ALPHA_MIN: float                  = 0.15
const BUILDING_UPGRADE_PARTICLE_DURATION: float = 1.5   # smoke burst before sprite swap
const AMBIENT_FADE_IN: float                    = 0.5   # AudioManager ambient loop fade-in
const AMBIENT_FADE_OUT: float                   = 1.0   # AudioManager ambient loop fade-out
const AMBIENT_VOLUME_RATIO: float               = 0.50  # ambient at 50% of music track volume


# ══════════════════════════════════════════════════════════════════════════════
# WEEKLY SUMMARY DAYS
# ══════════════════════════════════════════════════════════════════════════════

const WEEKLY_SUMMARY_DAYS: Array[int]           = [7, 14, 21, 28, 35]
