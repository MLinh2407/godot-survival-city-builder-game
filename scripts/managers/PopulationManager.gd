extends Node

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════
signal character_died(char_name: String)
signal colonist_died(count: int, cause: String)
signal worker_deserted(count: int)
signal population_zero() # Triggers Game Over

# ══════════════════════════════════════════════════════════════════════════════
# STATE TRACKING
# ══════════════════════════════════════════════════════════════════════════════
var consecutive_days_starving: int = 0

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TICK (Called by DayNightCycle.gd when a new day starts)
# ══════════════════════════════════════════════════════════════════════════════
func process_daily_population_tick(new_day: int) -> void:
	print("PopulationManager: Processing daily tick for Day ", new_day)
	
	_process_disease_tick()
	_process_starvation_tick()
	_process_desertion_tick()
	_process_character_deaths(new_day)
	
	_sync_game_manager_state()

# ══════════════════════════════════════════════════════════════════════════════
# 1. THE DISEASE TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_disease_tick() -> void:
	if GameManager.sick_count <= 0:
		return # Nobody is sick, skip logic
		
	# TODO: Hook this up to BuildingSystem later to check real staffing
	var is_med_clinic_staffed: bool = false 
	
	if is_med_clinic_staffed:
		# Cure patients
		var cured: int = min(GameConstants.DISEASE_TREATMENT_RATE, GameManager.sick_count)
		GameManager.sick_count -= cured
		GameManager.available_workers += cured # Cured people go back to work
		print("PopulationManager: Med Clinic cured ", cured, " colonists.")
	else:
		# People die from lack of treatment
		var rng = RandomNumberGenerator.new()
		var deaths: int = rng.randi_range(GameConstants.DISEASE_DEATH_RATE_MIN, GameConstants.DISEASE_DEATH_RATE_MAX)
		
		# Don't kill more people than are actually sick
		deaths = min(deaths, GameManager.sick_count)
		
		GameManager.sick_count -= deaths
		_remove_colonists(deaths, "disease")

# ══════════════════════════════════════════════════════════════════════════════
# 2. THE STARVATION TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_starvation_tick() -> void:
	# Assuming ResourceData has a "current_value" property you will add later
	# TODO: Ensure GameManager.resource_food is initialized properly with a current_value
	var current_food: float = 0.0 # Placeholder: Replace with GameManager.resource_food.current_value
	
	if current_food <= 0.0:
		consecutive_days_starving += 1
	else:
		consecutive_days_starving = 0 # Reset if they have food
		
	if consecutive_days_starving >= GameConstants.FOOD_STARVATION_DELAY:
		var rng = RandomNumberGenerator.new()
		var deaths: int = rng.randi_range(GameConstants.STARVATION_DEATHS_MIN, GameConstants.STARVATION_DEATHS_MAX)
		_remove_colonists(deaths, "starvation")

# ══════════════════════════════════════════════════════════════════════════════
# 3. THE DESERTION TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_desertion_tick() -> void:
	var current_morale: float = 50.0 # Placeholder: Replace with GameManager.resource_morale.current_value
	
	if current_morale < GameConstants.MORALE_DESERTION_THRESHOLD:
		var rng = RandomNumberGenerator.new()
		var deserters: int = rng.randi_range(GameConstants.MORALE_DESERTION_WORKERS_MIN, GameConstants.MORALE_DESERTION_WORKERS_MAX)
		
		# Deserters just leave the worker pool and colony, they don't count as "deaths"
		GameManager.available_workers = max(0, GameManager.available_workers - deserters)
		GameManager.current_population = max(0, GameManager.current_population - deserters)
		
		worker_deserted.emit(deserters)
		print("PopulationManager: ", deserters, " workers deserted due to low morale.")

# ══════════════════════════════════════════════════════════════════════════════
# 4. NARRATIVE CHECKS (Named Characters)
# ══════════════════════════════════════════════════════════════════════════════
func _process_character_deaths(day: int) -> void:
	# YUNA'S DEATH CHECK
	if day == GameConstants.YUNA_DEATH_DAY and GameManager.yuna_alive:
		if GameManager.current_population < GameConstants.YUNA_DEATH_POPULATION_THRESHOLD:
			GameManager.yuna_alive = false
			GameManager.colonist_yuna.is_alive = false
			character_died.emit("Yuna")
			
	# VASQUEZ'S DEATH CHECK
	if day == GameConstants.VASQUEZ_DEATH_DAY and GameManager.vasquez_alive:
		var survival_rate = float(GameManager.current_population) / float(GameConstants.STARTING_POPULATION)
		if survival_rate < GameConstants.VASQUEZ_DEATH_SURVIVAL_THRESHOLD:
			GameManager.vasquez_alive = false
			GameManager.colonist_vasquez.is_alive = false
			character_died.emit("Vasquez")

# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
func _remove_colonists(amount: int, cause: String) -> void:
	if amount <= 0: return
	
	# Clamp logic to ensure we never go into negative numbers
	GameManager.current_population = max(0, GameManager.current_population - amount)
	GameManager.available_workers = max(0, GameManager.available_workers - amount)
	
	colonist_died.emit(amount, cause)
	print("PopulationManager: ", amount, " colonists died from ", cause)
	
	if GameManager.current_population == 0:
		population_zero.emit()

# Keeps the data class in GameManager synced with the primitive variables
func _sync_game_manager_state() -> void:
	GameManager.population_state.total_population = GameManager.current_population
	GameManager.population_state.available_workers = GameManager.available_workers
	GameManager.population_state.sick_count = GameManager.sick_count
