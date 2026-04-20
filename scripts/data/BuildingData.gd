# Represents a single placed building instance on the isometric grid
# The BuildingSystem creates one BuildingData per placed building

class_name BuildingData
extends Resource

signal staffing_changed(current: int, capacity: int)

# Building type enum (10 building types)
enum BuildingType {
    COAL_GENERATOR,
    GEOTHERMAL_TAP,
    RELAY_HUB,
    HYDROPONIC_BAY,
    RATION_STORE,
    WATER_RECYCLER,
    MED_CLINIC,
    SHELTER_BLOCK,
    ARCHIVE_HALL,
    MEMORIAL_WALL
}

# Category enum (for build menu tier grouping)
enum BuildingCategory {
    POWER,      # Tier 1 in build menu
    SURVIVAL,   # Tier 2 in build menu
    SOCIAL      # Tier 3 in build menu
}

@export var footprint_size: Vector2i = Vector2i(1, 1)

# Identity
@export var building_type: BuildingType = BuildingType.COAL_GENERATOR
@export var building_name: String = ""
@export var category: BuildingCategory = BuildingCategory.POWER

# Grid position
@export var grid_position: Vector2i = Vector2i.ZERO  

# Archive Hall and Memorial Wall (limited to 1 per colony)
@export var is_unique: bool = false      

# --- Power ---
@export var power_draw: float = 0.0       # kW consumed per day (negative = producer)
@export var is_powered: bool = false      # Set by ResourceManager each tick

# --- Workers ---
@export var worker_capacity: int = 0      # Max workers this building accepts
@export var workers_assigned: int = 0     # Current workers assigned by player

# Output scales proportionally with staffing
var staffing_ratio: float:
    get:
        var ratio: float = 1.0
        if worker_capacity > 0:
            ratio = float(workers_assigned) / float(worker_capacity)
            
        if ResourceManager.morale < GameConstants.MORALE_EFFICIENCY_THRESHOLD:
            ratio *= GameConstants.MORALE_EFFICIENCY_MULTIPLIER
            
        return ratio

# --- Upgrade state ---
@export var is_upgraded: bool = false

# --- Storm damage state ---
# Shielded buildings survive Day 35. Unshielded go offline
@export var is_shielded: bool = false
@export var is_damaged: bool = false     

# --- Resource Production (base values, before staffing ratio) ---
# Populated by BuildingSystem from GameConstants.gd.
@export var base_production_power: float = 0.0   
@export var base_production_food: float = 0.0    
@export var base_morale_bonus: float = 0.0      

# --- Consecutive unstaffed days ---
# Used by BuildingSystem to trigger:
#   - Building damage (any building at 0 workers for BUILDING_DAMAGE_DAYS consecutive days)
#   - Disease outbreak (Water Recycler at 0 workers for DISEASE_WATER_DELAY consecutive days)
@export var days_unstaffed: int = 0
@export var days_unstaffed_for_disease: int = 0

# base_passive_morale:
#   Applied REGARDLESS of staffing — just from the building existing and being powered.
#   Use for Archive Hall (+8/day while built) and Memorial Wall (+3/day permanently).
#   ResourceManager reads this separately from base_morale_bonus.
@export var base_passive_morale: float = 0.0