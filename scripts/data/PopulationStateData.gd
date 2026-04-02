# Tracks the three population numbers for the 847 colonist mass

class_name PopulationStateData
extends Resource

# Population Manager
@export var total_population: int = 847   
@export var available_workers: int = 68  
@export var sick_count: int = 0           # Colonists alive but unable to work (Sick pool)
@export var max_workers: int = 0

# Outbreak state
@export var outbreak_active: bool = false  # True when sick_count > 0 and event has fired

# Disease resistance (from Water Recycler upgrade)
# When true, initial sick_count on any outbreak is multiplied by 0.70 
@export var disease_resistance_active: bool = false

# Population Caps
const STARTING_POPULATION: int = 847
const STARTING_WORKERS: int = 68
const MAX_WORKERS_LATE_GAME: int = 85   

# Survival rate (used by ending_manager.gd)
var survival_rate: float:
    get: return float(total_population) / float(STARTING_POPULATION)