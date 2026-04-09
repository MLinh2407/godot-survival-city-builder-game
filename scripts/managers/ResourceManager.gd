extends Node

signal resources_changed(power: float, food: float, morale: float, materials: int)
signal threshold_warning(resource: String, is_critical: bool)
signal power_out

# --- Capacities and Totals ---
var power_capacity: float = 0.0
var power_draw: float = 0.0
var net_power: float = 0.0

var food: float = 0.0
var max_food: float = 0.0
var days_starving: int = 0

var materials: int = 0

# Morale goes from 0 to 100
var morale: float = 100.0

func _ready() -> void:
	# Wait one frame to ensure TimeManager autoload is fully initialized
	await get_tree().process_frame
	if TimeManager != null:
		TimeManager.day_changed.connect(_on_day_changed)
	else:
		push_warning("TimeManager not found during ResourceManager init.")
		
	resources_changed.emit(net_power, food, morale, materials)

func calculate_power() -> void:
	net_power = power_capacity - power_draw
	if net_power <= 0.0:
		power_out.emit()
	resources_changed.emit(net_power, food, morale, materials)

func add_materials(amount: int) -> void:
	materials += amount
	resources_changed.emit(net_power, food, morale, materials)

func consume_materials(amount: int) -> bool:
	if materials >= amount:
		materials -= amount
		resources_changed.emit(net_power, food, morale, materials)
		return true
	return false

func _on_day_changed(new_day: int) -> void:
	# Daily Material Passive Gen
	var generated_materials = randi_range(GameConstants.MATERIALS_PASSIVE_MIN, GameConstants.MATERIALS_PASSIVE_MAX)
	materials += generated_materials
	
	# Track Starvation
	if food <= 0.0:
		days_starving += 1
		if days_starving >= GameConstants.FOOD_STARVATION_DELAY:
			# Externally tracked starvation deaths logic can connect to day_changed
			pass
	else:
		days_starving = 0
		
	# Disease Morale Drain
	if GameManager.population_state and GameManager.population_state.outbreak_active:
		morale -= GameConstants.DISEASE_MORALE_DRAIN
		morale = max(0.0, morale)
		print("--- OUTBREAK: Morale drained by ", GameConstants.DISEASE_MORALE_DRAIN)
		
	_check_thresholds()
	
	print("--- Day ", new_day, " ---")
	print("Net Power:  ", net_power, " (Cap: ", power_capacity, " Draw: ", power_draw, ")")
	print("Food:       ", food, " / ", max_food)
	print("Morale:     ", morale)
	print("Materials:  ", materials)
	print("----------------")
	
	resources_changed.emit(net_power, food, morale, materials)

func _check_thresholds() -> void:
	if max_food > 0:
		var food_ratio = food / max_food
		if food_ratio <= GameConstants.CRITICAL_THRESHOLD:
			threshold_warning.emit("Food", true)
		elif food_ratio <= GameConstants.WARNING_THRESHOLD:
			threshold_warning.emit("Food", false)
			
	if morale <= GameConstants.MORALE_DESERTION_THRESHOLD:
		threshold_warning.emit("Morale", true)
	elif morale <= GameConstants.MORALE_EFFICIENCY_THRESHOLD:
		threshold_warning.emit("Morale", false)
