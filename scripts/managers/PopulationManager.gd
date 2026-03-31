extends Node

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════
signal character_died(char_name: String)
signal colonist_died(count: int)

# ══════════════════════════════════════════════════════════════════════════════
# DAILY PROCESSING
# ══════════════════════════════════════════════════════════════════════════════

# This function should be called every time the day_advanced signal fires
func process_daily_population() -> void:
	_process_disease()
	_process_starvation()
	_process_desertion()
	_check_named_character_deaths()

# ══════════════════════════════════════════════════════════════════════════════
# CORE LOGIC STUBS
# ══════════════════════════════════════════════════════════════════════════════

func _process_disease() -> void:
	if GameManager.sick_count <= 0:
		return
		
	# TODO: Check if Med Clinic is staffed.
	# If staffed: GameManager.sick_count -= GameConstants.DISEASE_TREATMENT_RATE (5/day) 
	# If NOT staffed: 1-3 sick colonists die -> reduce total_population and available_workers 
	pass

func _process_starvation() -> void:
	# TODO: Check if Food has been 0 for 2+ days.
	# If true: reduce total_population by STARVATION_DEATHS_MIN to MAX (1-3) 
	# Emit colonist_died signal 
	pass

func _process_desertion() -> void:
	if GameManager.morale_data.current_value >= GameConstants.MORALE_DESERTION_THRESHOLD:
		return
		
	# TODO: If Morale < 10, reduce available_workers by 1-2 
	pass

func _check_named_character_deaths() -> void:
	# TODO: Check conditions for Yuna, Vasquez, etc., based on current day and stats 
	# If condition met, set their alive flag to false in GameManager and emit character_died 
	pass