extends Node

signal resources_changed(power: float, food: float, morale: float, materials: int)
signal threshold_warning(resource: String, is_critical: bool)
signal power_out

# ══════════════════════════════════════════════════════════════════════════════
# REFERENCES
# ══════════════════════════════════════════════════════════════════════════════

# Set by BuildingSystem.register_building_system() on its _ready()
var building_system = null

# ══════════════════════════════════════════════════════════════════════════════
# RESOURCE STATE
# ══════════════════════════════════════════════════════════════════════════════

var power_capacity: float = 0.0
var power_draw: float     = 0.0
var net_power: float      = 0.0

var food: float     = GameConstants.STARTING_FOOD
var max_food: float = GameConstants.STARTING_FOOD   # Increases when Ration Store is built

var morale: float   = GameConstants.STARTING_MORALE

var materials: int  = GameConstants.STARTING_MATERIALS
var days_starving: int = 0

var ration_buffer: float = 0.0
var ration_buffer_max: float = 0.0
var auto_rationing_active: bool = false
var ration_store_exists: bool = false

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.hope_order_changed.connect(_on_slider_changed)
	await get_tree().process_frame
	if TimeManager != null:
		TimeManager.day_changed.connect(_on_day_changed)
	else:
		push_warning("ResourceManager: TimeManager not found.")

	_sync_to_game_manager()
	resources_changed.emit(net_power, food, morale, materials)

func register_building_system(bs) -> void:
	building_system = bs
	print("ResourceManager: BuildingSystem registered.")

# ══════════════════════════════════════════════════════════════════════════════
# DAILY TICK
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(new_day: int) -> void:
	if building_system == null:
		# No buildings yet — still emit so HUD stays updated
		resources_changed.emit(net_power, food, morale, materials)
		return

	_recalculate_power()
	_process_food_tick()
	_process_morale_tick()

	# Materials passive gen
	materials += randi_range(GameConstants.MATERIALS_PASSIVE_MIN, GameConstants.MATERIALS_PASSIVE_MAX)
	# Rook's militia bonus (set by CrisisEventSystem on Day 24 Option A)
	if GameManager.rook_militia_sanctioned:
		materials += GameConstants.MATERIALS_ROOK_MILITIA_BONUS
	GameManager.materials = materials

	# Track Starvation
	if food <= 0.0:
		days_starving += 1
		if days_starving >= GameConstants.FOOD_STARVATION_DELAY:
			# Externally tracked starvation deaths logic can connect to day_changed
			pass
	else:
		days_starving = 0

	# Immediate disease morale drain (extra, separate from _process_morale_tick)
	if GameManager.population_state and GameManager.population_state.outbreak_active:
		morale -= GameConstants.DISEASE_MORALE_DRAIN
		morale = max(0.0, morale)
		print("--- OUTBREAK: Morale drained by ", GameConstants.DISEASE_MORALE_DRAIN)

	_sync_to_game_manager()
	_check_thresholds()
	resources_changed.emit(net_power, food, morale, materials)
	_print_debug(new_day)

# ══════════════════════════════════════════════════════════════════════════════
# 1. POWER
# ══════════════════════════════════════════════════════════════════════════════

func _recalculate_power() -> void:
	power_capacity = 0.0
	power_draw     = 0.0

	var all_buildings = building_system.active_buildings

	# Pass 1 — sum all power producers
	# Generators always produce regardless of is_powered (they ARE the power source)
	for grid_pos in all_buildings:
		var b: BuildingData = all_buildings[grid_pos]
		if b.base_production_power > 0.0:
			var efficiency: float = b.staffing_ratio
			if b.is_damaged:
				efficiency *= GameConstants.BUILDING_DAMAGE_OUTPUT
			power_capacity += b.base_production_power * efficiency

	# Pass 2 — sum all power consumers
	for grid_pos in all_buildings:
		var b: BuildingData = all_buildings[grid_pos]
		if b.base_production_power <= 0.0 and b.power_draw > 0.0:
			power_draw += b.power_draw

	net_power = power_capacity - power_draw

	# Pass 3 — set is_powered flag on every building
	# Simple rule: enough total capacity = everything powered.
	# Priority shutdown system comes in a later pass.
	var grid_has_power: bool = net_power >= 0.0
	for grid_pos in all_buildings:
		var b: BuildingData = all_buildings[grid_pos]
		if b.base_production_power > 0.0:
			b.is_powered = true       # Generators are always "on"
		else:
			b.is_powered = grid_has_power

# ══════════════════════════════════════════════════════════════════════════════
# 2. FOOD
# ══════════════════════════════════════════════════════════════════════════════

func _process_food_tick() -> void:
	var food_production: float = 0.0
	for grid_pos in building_system.active_buildings:
		var output = building_system.get_effective_output(grid_pos)
		food_production += output.food

	# Hope/Order modifier on food production
	var slider: float = GameManager.hope_order_slider
	if slider >= GameConstants.SLIDER_ORDER_LOWER:
		food_production *= GameConstants.ORDER_FOOD_PRODUCTION_MODIFIER	  # +15%
	elif slider <= GameConstants.SLIDER_HOPE_UPPER:
		food_production *= GameConstants.HOPE_FOOD_EFFICIENCY_MODIFIER	  # -5%

	# MERIDIAN efficiency boost
	if GameManager.meridian_trusted:
		food_production *= GameConstants.MERIDIAN_EFFICIENCY_BOOST

	# Daily consumption — auto-rationing reduces it when buffer is low (T2 only)
	var consumption: float = GameManager.current_population * GameConstants.FOOD_CONSUMPTION_PER_COLONIST

	if auto_rationing_active:
		consumption *= 0.75  # 25% reduction — extends survival, costs Morale (applied in morale tick)

	var net: float = food_production - consumption
	food += net

	# If food went negative, draw from the Ration Store buffer before starvation counts
	if food < 0.0 and ration_store_exists and ration_buffer > 0.0:
		ration_buffer += food   # food is negative, so buffer decreases
		ration_buffer = maxf(ration_buffer, 0.0)
		food = 0.0

	food = maxf(food, 0.0)

	# Auto-rationing state (T2 Ration Store only — check upgrade flag)
	if ration_store_exists and building_system.is_building_upgraded(BuildingData.BuildingType.RATION_STORE):
		var threshold: float = ration_buffer_max * GameConstants.RATION_AUTO_THRESHOLD
		auto_rationing_active = ration_buffer < threshold and ration_buffer_max > 0.0
	else:
		auto_rationing_active = false

	# Sync ResourceData for HUD and save/load
	GameManager.resource_food.ration_store_buffer  = ration_buffer
	GameManager.resource_food.ration_store_max     = ration_buffer_max
	GameManager.resource_food.auto_rationing_active = auto_rationing_active
	GameManager.resource_food.production_rate  = food_production
	GameManager.resource_food.consumption_rate = consumption

# ══════════════════════════════════════════════════════════════════════════════
# 3. MORALE
# ══════════════════════════════════════════════════════════════════════════════

func _process_morale_tick() -> void:
	var morale_gain: float = 0.0

	for grid_pos in building_system.active_buildings:
		var b: BuildingData = building_system.active_buildings[grid_pos]
		var output = building_system.get_effective_output(grid_pos)

		# Staffing-scaled morale (Med Clinic passive bonus)
		morale_gain += output.morale

		# Passive morale from buildings that just need to exist and have power
		# Archive Hall: +8/day while built and powered
		# Memorial Wall: +3/day permanently (power_draw = 0 so always counts)
		if b.is_powered or b.power_draw == 0.0:
			morale_gain += b.base_passive_morale

	# Shelter capacity check
	var shelter_capacity: int = building_system.get_total_shelter_capacity()
	var pop: int              = GameManager.current_population
	var overflow: int         = pop - shelter_capacity
	var shelter_count: int    = _count_buildings(BuildingData.BuildingType.SHELTER_BLOCK)

	if overflow <= 0 and shelter_count > 0:
		# At or below capacity: each block gives +5 Morale/day
		morale_gain += shelter_count * GameConstants.SHELTER_MORALE_AT_CAPACITY_T1
	elif overflow > GameConstants.SHELTER_OVERFLOW_THRESHOLD:
		# Overcrowded beyond tolerance: flat -3 penalty
		morale_gain += GameConstants.SHELTER_MORALE_OVERFLOW_PENALTY

	# Base passive decay — living underground is hard
	var decay: float = GameConstants.MORALE_BASE_DECAY_PER_DAY

	# Hope/Order modifies decay rate
	var slider: float = GameManager.hope_order_slider
	if slider <= GameConstants.SLIDER_HOPE_UPPER:
		decay *= GameConstants.HOPE_MORALE_DECAY_MODIFIER    # 20% slower
	elif slider >= GameConstants.SLIDER_ORDER_LOWER:
		decay *= GameConstants.ORDER_MORALE_DECAY_MODIFIER   # 20% faster

	# Active disease drains morale
	if GameManager.population_state.outbreak_active:
		decay += GameConstants.DISEASE_MORALE_DRAIN

	# MERIDIAN surveillance unease
	if GameManager.meridian_trusted:
		decay += GameConstants.MERIDIAN_MORALE_DRAIN
	
	# Auto-rationing unease — cuts portions, colony feels it
	if auto_rationing_active:
		decay += absf(GameConstants.RATION_AUTO_MORALE_PENALTY)

	morale = clampf(morale + morale_gain - decay, 0.0, 100.0)

	GameManager.resource_morale.production_rate  = morale_gain
	GameManager.resource_morale.consumption_rate = decay

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _count_buildings(type: BuildingData.BuildingType) -> int:
	var count: int = 0
	for grid_pos in building_system.active_buildings:
		var b: BuildingData = building_system.active_buildings[grid_pos]
		if b.building_type == type:
			count += 1
	return count

func _sync_to_game_manager() -> void:
	GameManager.resource_food.current_value   = food
	GameManager.resource_food.max_value       = max_food
	GameManager.resource_morale.current_value = morale
	GameManager.resource_power.current_value  = net_power

func _check_thresholds() -> void:
	if max_food > 0.0:
		var food_ratio: float = food / max_food
		if food_ratio <= GameConstants.CRITICAL_THRESHOLD:
			threshold_warning.emit("Food", true)
		elif food_ratio <= GameConstants.WARNING_THRESHOLD:
			threshold_warning.emit("Food", false)

	var morale_ratio: float = morale / 100.0
	if morale_ratio <= GameConstants.CRITICAL_THRESHOLD:
		threshold_warning.emit("Morale", true)
	elif morale_ratio <= GameConstants.WARNING_THRESHOLD:
		threshold_warning.emit("Morale", false)

func _print_debug(day: int) -> void:
	print("--- Day %d | Power: %.1f (Cap:%.1f / Draw:%.1f) | Food: %.0f | Morale: %.1f | Mat: %d" \
		% [day, net_power, power_capacity, power_draw, food, morale, materials])

	# Hope/Order slider verification — prints modifier state every day
	var slider: float = GameManager.hope_order_slider
	if slider <= GameConstants.SLIDER_HOPE_UPPER:
		print("    [SLIDER] Hope zone (%.1f) | Morale decay ×%.2f | Food efficiency ×%.2f" \
			% [slider, GameConstants.HOPE_MORALE_DECAY_MODIFIER, GameConstants.HOPE_FOOD_EFFICIENCY_MODIFIER])
	elif slider >= GameConstants.SLIDER_ORDER_LOWER:
		print("    [SLIDER] Order zone (%.1f) | Morale decay ×%.2f | Food production ×%.2f" \
			% [slider, GameConstants.ORDER_MORALE_DECAY_MODIFIER, GameConstants.ORDER_FOOD_PRODUCTION_MODIFIER])
	else:
		print("    [SLIDER] Neutral zone (%.1f) | No passive modifiers active" % slider)

	# Ration Store buffer state
	if ration_store_exists:
		print("    [RATION] Buffer: %.0f / %.0f | Auto-rationing: %s" \
			% [ration_buffer, ration_buffer_max, str(auto_rationing_active)])

func on_ration_store_built(is_upgraded: bool) -> void:
	ration_store_exists = true

	# Compute buffer capacity: T1 = 50 days, T2 = 100 days of full-colony consumption
	var days: int = GameConstants.RATION_STORE_BUFFER_T2 if is_upgraded else GameConstants.RATION_STORE_BUFFER_T1
	ration_buffer_max = days * GameConstants.STARTING_POPULATION * GameConstants.FOOD_CONSUMPTION_PER_COLONIST

	# Buffer starts full on placement — represents pre-existing colony reserves
	if ration_buffer == 0.0:
		ration_buffer = ration_buffer_max

	# Sync to ResourceData so save/load and HUD can read it
	GameManager.resource_food.ration_store_buffer = ration_buffer
	GameManager.resource_food.ration_store_max    = ration_buffer_max

	resources_changed.emit(net_power, food, morale, materials)
	print("RationStore built | buffer: %.0f / %.0f | auto-ration threshold: %.0f" \
		% [ration_buffer, ration_buffer_max, ration_buffer_max * GameConstants.RATION_AUTO_THRESHOLD])

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — called externally by events and building upgrades
# ══════════════════════════════════════════════════════════════════════════════

func calculate_power() -> void:
	if building_system:
		_recalculate_power()
	resources_changed.emit(net_power, food, morale, materials)

func add_food(amount: float) -> void:
	food = minf(food + amount, max_food)
	resources_changed.emit(net_power, food, morale, materials)

func add_morale(amount: float) -> void:
	morale = clampf(morale + amount, 0.0, 100.0)
	if net_power <= 0.0:
		power_out.emit()
	resources_changed.emit(net_power, food, morale, materials)

func add_materials(amount: int) -> void:
	materials += amount
	GameManager.materials = materials
	resources_changed.emit(net_power, food, morale, materials)

func consume_materials(amount: int) -> bool:
	if materials >= amount:
		materials -= amount
		GameManager.materials = materials
		resources_changed.emit(net_power, food, morale, materials)
		return true
	return false

func _on_slider_changed(_new_value: float) -> void:
	if building_system == null:
		return
	_recalculate_power()
	_process_food_tick()
	_process_morale_tick()
	_sync_to_game_manager()
	resources_changed.emit(net_power, food, morale, materials)