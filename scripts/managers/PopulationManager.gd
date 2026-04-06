extends Node

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════
signal population_changed
signal outbreak_started(sick_count: int)
signal outbreak_ended()
signal character_died(char_name: String)
signal colonist_died(count: int, cause: String)
signal worker_deserted(count: int)
signal population_zero() # Triggers Game Over

var consecutive_days_starving: int = 0

# ══════════════════════════════════════════════════════════════════════════════
# INITIALISATION
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Ensure starting state is perfectly synced on boot
	var pop_data = GameManager.population_state
	pop_data.total_population  = GameConstants.STARTING_POPULATION
	pop_data.available_workers = GameConstants.STARTING_WORKERS
	pop_data.sick_count        = 0
	print("PopulationManager ready | Pop: %d | Workers: %d" % [pop_data.total_population, pop_data.available_workers])

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TICK (Called by DayNightCycle.gd when a new day starts)
# ══════════════════════════════════════════════════════════════════════════════
func process_daily_population_tick(new_day: int) -> void:
	print("\n--- PopulationManager: Processing Day ", new_day, " ---")
	
	var pop_data = GameManager.population_state
	
	_process_disease_tick(pop_data)
	_process_starvation_tick(pop_data)
	_process_desertion_tick(pop_data)
	_process_character_deaths(new_day, pop_data)
	
	_recalculate_workers(pop_data)
	population_changed.emit()
	
	print("END OF DAY | Pop: ", pop_data.total_population, " | Workers: ", pop_data.available_workers, " | Sick: ", pop_data.sick_count)

# ══════════════════════════════════════════════════════════════════════════════
# 1. THE DISEASE TICK & TRIGGER
# ══════════════════════════════════════════════════════════════════════════════
func trigger_outbreak() -> void:
	var pop_data = GameManager.population_state
	if pop_data.sick_count > 0:
		return # Already in an outbreak
		
	var new_sick: int = randi_range(GameConstants.DISEASE_SICK_MIN, GameConstants.DISEASE_SICK_MAX)
	
	# Apply T2 Water Recycler resistance (30% reduction) if active
	if pop_data.disease_resistance_active:
		new_sick = int(float(new_sick) * GameConstants.DISEASE_RESISTANCE_MULTIPLIER)
		
	var actual_sick: int = mini(new_sick, pop_data.available_workers)
	
	# Move from worker pool to sick pool
	pop_data.available_workers -= actual_sick
	pop_data.sick_count += actual_sick
	pop_data.outbreak_active = true
	
	# Sync primitive vars
	GameManager.available_workers = pop_data.available_workers
	GameManager.sick_count = pop_data.sick_count
	
	outbreak_started.emit(actual_sick)
	print("🚨 OUTBREAK STARTED: ", actual_sick, " workers fell ill.")

func _process_disease_tick(pop_data: PopulationStateData) -> void:
	if pop_data.sick_count <= 0:
		pop_data.outbreak_active = false
		return 
		
	# TODO: Hook this up to BuildingSystem later to check real staffing
	var is_med_clinic_staffed: bool = randf() > 0.5 
	
	if is_med_clinic_staffed:
		var cured: int = mini(GameConstants.DISEASE_TREATMENT_RATE, pop_data.sick_count)
		pop_data.sick_count -= cured
		pop_data.available_workers += cured  
		print("🏥 TREATMENT: Med Clinic cured ", cured, " colonists.")
	else:
		var deaths: int = randi_range(GameConstants.DISEASE_DEATH_RATE_MIN, GameConstants.DISEASE_DEATH_RATE_MAX)
		deaths = mini(deaths, pop_data.sick_count)
		
		pop_data.sick_count -= deaths
		pop_data.total_population = maxi(0, pop_data.total_population - deaths)
		colonist_died.emit(deaths, "Disease")
		print("💀 DEATH: ", deaths, " colonists died from Disease.")
		
		# GAME OVER CATCH
		if pop_data.total_population == 0:
			population_zero.emit()
		
	if pop_data.sick_count <= 0:
		pop_data.sick_count = 0
		pop_data.outbreak_active = false
		outbreak_ended.emit()
		print("✅ OUTBREAK RESOLVED.")

# ══════════════════════════════════════════════════════════════════════════════
# 2. THE STARVATION TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_starvation_tick(pop_data: PopulationStateData) -> void:
	var current_food: float = GameManager.resource_food.current_value
	
	if current_food <= 0.0:
		consecutive_days_starving += 1
	else:
		consecutive_days_starving = 0 
		
	if consecutive_days_starving >= GameConstants.FOOD_STARVATION_DELAY:
		var deaths: int = randi_range(GameConstants.STARVATION_DEATHS_MIN, GameConstants.STARVATION_DEATHS_MAX)
		_remove_colonists(pop_data, deaths, "Starvation")

# ══════════════════════════════════════════════════════════════════════════════
# 3. THE DESERTION TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_desertion_tick(pop_data: PopulationStateData) -> void:
	var current_morale: float = GameManager.resource_morale.current_value
	
	if current_morale < GameConstants.MORALE_DESERTION_THRESHOLD:
		var deserters: int = randi_range(GameConstants.MORALE_DESERTION_WORKERS_MIN, GameConstants.MORALE_DESERTION_WORKERS_MAX)
		deserters = mini(deserters, pop_data.available_workers)
		
		if deserters > 0:
			pop_data.available_workers = maxi(0, pop_data.available_workers - deserters)
			pop_data.total_population = maxi(0, pop_data.total_population - deserters)
			worker_deserted.emit(deserters)
			print("🏃 DESERTION: ", deserters, " workers deserted due to low morale.")
			
			if pop_data.total_population == 0:
				population_zero.emit()

# ══════════════════════════════════════════════════════════════════════════════
# 4. NARRATIVE CHECKS (Named Characters)
# ══════════════════════════════════════════════════════════════════════════════
func _process_character_deaths(day: int, pop_data: PopulationStateData) -> void:
	# YUNA'S DEATH CHECK
	if day == GameConstants.YUNA_DEATH_DAY and GameManager.colonist_yuna.is_alive:
		var pop_too_low = pop_data.total_population < GameConstants.YUNA_DEATH_POPULATION_THRESHOLD
		var no_clinic = not GameManager.med_clinic_built
		
		if pop_too_low and no_clinic:
			GameManager.colonist_yuna.is_alive = false
			GameManager.yuna_alive = false 
			character_died.emit("Yuna")
			
	# VASQUEZ'S DEATH CHECK
	if day == GameConstants.VASQUEZ_DEATH_DAY and GameManager.colonist_vasquez.is_alive:
		if GameManager.vasquez_trade_accepted:
			var survival_rate = float(pop_data.total_population) / float(GameConstants.STARTING_POPULATION)
			if survival_rate < GameConstants.VASQUEZ_DEATH_SURVIVAL_THRESHOLD:
				GameManager.colonist_vasquez.is_alive = false
				GameManager.vasquez_alive = false
				character_died.emit("Vasquez")
			
	# ROOK'S DEATH CHECK
	if day == GameConstants.ROOK_RECONCILIATION_DEADLINE and GameManager.colonist_rook.is_alive:
		if GameManager.rook_militia_stopped and not GameManager.rook_reconciliation_taken:
			GameManager.colonist_rook.is_alive = false
			GameManager.rook_alive = false
			character_died.emit("Rook")

# ══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
func _remove_colonists(pop_data: PopulationStateData, amount: int, cause: String) -> void:
	if amount <= 0: return
	
	pop_data.total_population = maxi(0, pop_data.total_population - amount)
	
	var worker_deaths = mini(amount, pop_data.available_workers)
	pop_data.available_workers = maxi(0, pop_data.available_workers - worker_deaths)
	
	colonist_died.emit(amount, cause)
	print("💀 DEATH: ", amount, " colonists died from ", cause)
	
	if pop_data.total_population == 0:
		population_zero.emit()

func _recalculate_workers(pop_data: PopulationStateData) -> void:
	var healthy_pop = pop_data.total_population - pop_data.sick_count
	var absolute_max = mini(healthy_pop, GameConstants.MAX_WORKERS_LATE_GAME)
	
	pop_data.available_workers = mini(pop_data.available_workers, absolute_max)
	
	# Sync primitive vars back to GameManager
	GameManager.current_population = pop_data.total_population
	GameManager.available_workers = pop_data.available_workers
	GameManager.sick_count = pop_data.sick_count

# ══════════════════════════════════════════════════════════════════════════════
# DEBUG / TESTING ONLY 
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			print("\n--- DEBUG: FORCING NEXT DAY ---")
			GameManager.current_day += 1
			process_daily_population_tick(GameManager.current_day)
		
		if event.keycode == KEY_O:
			trigger_outbreak()
			
		if event.keycode == KEY_F:
			GameManager.resource_food.current_value = 0.0
			print("TEST: Food artificially set to 0.0")
			
		if event.keycode == KEY_M:
			GameManager.resource_morale.current_value = 5.0
			print("TEST: Morale artificially set to 5.0")
