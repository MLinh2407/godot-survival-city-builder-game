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
signal starvation_deaths(count: int)
signal population_zero() # Triggers Game Over

var consecutive_days_starving: int = 0
var consecutive_days_water_unstaffed: int = 0

# ══════════════════════════════════════════════════════════════════════════════
# INITIALISATION
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var pop_data = GameManager.population_state
	pop_data.total_population  = GameConstants.STARTING_POPULATION
	pop_data.available_workers = GameConstants.STARTING_WORKERS
	pop_data.sick_count        = 0
	print("PopulationManager ready | Pop: %d | Workers: %d" \
		% [pop_data.total_population, pop_data.available_workers])

	# Wire daily tick — this is what was missing
	await get_tree().process_frame
	TimeManager.day_changed.connect(process_daily_population_tick)

# Called by BuildingSystem registration 
var building_system = null
func register_building_system(bs) -> void:
	building_system = bs
	print("PopulationManager: BuildingSystem registered.")

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TICK (Called by DayNightCycle.gd when a new day starts)
# ══════════════════════════════════════════════════════════════════════════════
func process_daily_population_tick(new_day: int) -> void:
	print("\n--- PopulationManager: Processing Day ", new_day, " ---")
	
	var pop_data = GameManager.population_state
	
	# Scripted Day 16 Event
	if new_day == 16 and not pop_data.outbreak_active:
		trigger_outbreak()
		
	# Water Recycler auto-outbreak
	var building_sys = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if building_sys:
		if building_sys.has_building(BuildingData.BuildingType.WATER_RECYCLER):
			if building_sys.get_workers_for_building_type(BuildingData.BuildingType.WATER_RECYCLER) == 0:
				consecutive_days_water_unstaffed += 1
			else:
				consecutive_days_water_unstaffed = 0
		else:
			consecutive_days_water_unstaffed += 1
	else:
		consecutive_days_water_unstaffed += 1
		
	if consecutive_days_water_unstaffed >= GameConstants.DISEASE_WATER_DELAY and not pop_data.outbreak_active:
		trigger_outbreak()
	
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
	var building_sys = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if building_sys and building_sys.is_building_upgraded(BuildingData.BuildingType.WATER_RECYCLER):
		pop_data.disease_resistance_active = true
	else:
		pop_data.disease_resistance_active = false
		
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
	AudioManager.play_event_sfx("disease_start")
	print("🚨 OUTBREAK STARTED: ", actual_sick, " workers fell ill.")

func _process_disease_tick(pop_data: PopulationStateData) -> void:
	if pop_data.sick_count <= 0:
		pop_data.outbreak_active = false
		return 
		
	var is_med_clinic_staffed: bool = false
	if building_system != null:
		if building_system.has_method("get_med_clinic_staffing_ratio"):
			var med_ratio: float = building_system.get_med_clinic_staffing_ratio()
			is_med_clinic_staffed = med_ratio >= 0.5
		else:
			var building_sys = get_tree().root.get_node_or_null("Main/BuildingSystem")
			if building_sys and building_sys.get_workers_for_building_type(BuildingData.BuildingType.MED_CLINIC) > 0:
				is_med_clinic_staffed = true
	
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
		AudioManager.play_event_sfx("death_colonist")
		
		# GAME OVER CATCH
		if pop_data.total_population == 0:
			population_zero.emit()
		
	if pop_data.sick_count <= 0:
		pop_data.sick_count = 0
		pop_data.outbreak_active = false
		outbreak_ended.emit()
		AudioManager.play_event_sfx("disease_end")
		print("✅ OUTBREAK RESOLVED.")

# ══════════════════════════════════════════════════════════════════════════════
# 2. THE STARVATION TICK
# ══════════════════════════════════════════════════════════════════════════════
func _process_starvation_tick(pop_data: PopulationStateData) -> void:
	var current_food: float = GameManager.resource_food.current_value
	var buffer: float       = GameManager.resource_food.ration_store_buffer

	# Starvation only counts when BOTH main food and buffer are exhausted
	var truly_starving: bool = current_food <= 0.0 and buffer <= 0.0

	if truly_starving:
		consecutive_days_starving += 1
	else:
		consecutive_days_starving = 0

	if consecutive_days_starving >= GameConstants.FOOD_STARVATION_DELAY:
		var deaths: int = randi_range(GameConstants.STARVATION_DEATHS_MIN, GameConstants.STARVATION_DEATHS_MAX)
		_remove_colonists(pop_data, deaths, "Starvation")
		starvation_deaths.emit(deaths)

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
			AudioManager.play_event_sfx("desertion")

			if pop_data.total_population == 0:
				population_zero.emit()

# ══════════════════════════════════════════════════════════════════════════════
# 4. NARRATIVE CHECKS (Named Characters)
# ══════════════════════════════════════════════════════════════════════════════
func _process_character_deaths(day: int, pop_data: PopulationStateData) -> void:
	# YUNA'S DEATH CHECK
	if day == GameConstants.YUNA_DEATH_DAY and GameManager.colonist_yuna.is_alive:
		var pop_too_low = pop_data.total_population < GameConstants.YUNA_DEATH_POPULATION_THRESHOLD
		var no_clinic = not GameManager.med_clinic_built or not GameManager.med_clinic_upgraded_to_tier_2
		
		if pop_too_low and no_clinic:
			GameManager.colonist_yuna.is_alive = false
			GameManager.yuna_alive = false 
			character_died.emit("Yuna")
			GameManager.named_character_died.emit("yuna")  # For BuildingSystem morale bonus removal
			AudioManager.play_event_sfx("death_named")
			
	# VASQUEZ'S DEATH CHECK
	if day == GameConstants.VASQUEZ_DEATH_DAY and GameManager.colonist_vasquez.is_alive:
		if GameManager.vasquez_trade_accepted:
			var survival_rate = float(pop_data.total_population) / float(GameConstants.STARTING_POPULATION)
			if survival_rate < GameConstants.VASQUEZ_DEATH_SURVIVAL_THRESHOLD:
				GameManager.colonist_vasquez.is_alive = false
				GameManager.vasquez_alive = false
				character_died.emit("Vasquez")
				GameManager.named_character_died.emit("vasquez")  # Reserved for future BuildingSystem effects
				AudioManager.play_event_sfx("death_named")
			
	# ROOK'S DEATH CHECK
	if day == GameConstants.ROOK_RECONCILIATION_DEADLINE and GameManager.colonist_rook.is_alive:
		if GameManager.rook_militia_stopped and not GameManager.rook_reconciliation_taken:
			GameManager.colonist_rook.is_alive = false
			GameManager.rook_alive = false
			character_died.emit("Rook")
			GameManager.named_character_died.emit("rook")  # Reserved for future BuildingSystem effects
			AudioManager.play_event_sfx("death_named")

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
	AudioManager.play_event_sfx("death_colonist")

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
