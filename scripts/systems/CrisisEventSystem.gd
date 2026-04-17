extends Node

# Active modifiers for the current run
var active_food_delta: float = 0.0
var active_morale_decay_mult: float = 1.0

# Tracks duration of temporary effects
var _temporary_effects = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		var dialogue_engine = main_node.get_node_or_null("Events/DialogueEngine")
		if dialogue_engine:
			dialogue_engine.choice_made.connect(_on_choice_made)
			
	if TimeManager and TimeManager.current_day == 1:
		_on_day_changed(1)

func _on_day_changed(new_day: int) -> void:
	_process_temporary_effects()
	
	# Fetch building system early in case we need it
	var building_system = null
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		building_system = main_node.get_node_or_null("BuildingSystem")
	
	# Apply active food modifiers
	if active_food_delta != 0.0 and ResourceManager:
		# Modifying the current food directly. Alternatively, if we wanted it to show as a rate, we would need to hook into ResourceManager's daily tick.
		# Since ResourceManager calculates food production itself, we can apply an absolute penalty here every day.
		ResourceManager.food = maxf(0.0, ResourceManager.food + active_food_delta)
		ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
	
	# Check for "Unrest Riot" on Day 10 (Lockdown End)
	if new_day == 10 and GameManager.call("get", "deserters_lockdown_taken") == true:
		if ResourceManager.morale < 30.0:
			_trigger_unrest_riot(building_system)

	# Check for "Vasquez Late Dialogue" on Day 28
	if new_day == 28 and GameManager.call("get", "vasquez_intel_shared") == true:
		if JournalManager:
			var title = "Day 28 — Grid-9 Transmission"
			var body = "Vasquez came over the radio at 1800. He didn't ask for engineers this time. He just wanted to confirm the eastern tunnel routing from the intelligence I gave him. He actually sounded like he respected the data. I'm noting this down because it's the first time someone outside these walls has treated us like an equal player instead of a salvage operation."
			JournalManager.unlock_entry("vasquez_late_dialogue", title, body)

	# Regular event checking
	if main_node and main_node.has_node("Events/DialogueEngine"):
		var de = main_node.get_node("Events/DialogueEngine")
		
		# Day 1 Intros
		if new_day == 1:
			de.show_event("intro_kael")
			# Queue intro_yuna next - handled by a slight delay or chaining. For now, we will connect a one-shot to the dismiss signal.
			de.card_dismissed.connect(_trigger_intro_yuna.bind(de), CONNECT_ONE_SHOT)
			return

		# Day 3
		if new_day == 3:
			de.show_event("cold_night")
		
		# Day 8
		if new_day == 8:
			if ResourceManager.morale < 50.0:
				de.show_event("the_deserters")
				
		# Day 27
		if new_day == 27:
			if GameManager.call("get", "rook_militia_stopped") == true and GameManager.call("get", "rook_reconciliation_taken") == false:
				de.show_event("rook_reconciliation")

func _trigger_intro_yuna(de: Node) -> void:
	de.show_event("intro_yuna")

func _trigger_unrest_riot(building_system: Node) -> void:
	if JournalManager:
		var title = "Day 10 — Unrest in the West Corridor"
		var body = "The lockdown ended at 0600 and by 0800 there was a disturbance in the west corridor. Nobody was killed. Two security personnel injured. One building took damage — equipment pulled from its housing, fixtures broken. The people who did it are back in their section now.\n\nI could write this up in a way that makes it sound more contained than it was. What it was: people who were told they couldn't leave, in a place where the conditions that made them want to leave haven't changed, expressing that in the only way left available to them. The lockdown held the numbers. It did not hold the tension. The tension found its exit anyway.\n\nThe damaged building needs Materials to repair. Morale dropped further. I kept everyone here. I'm not sure everyone being here is the same as everyone being fine."
		JournalManager.unlock_entry("unrest_riot_day_10", title, body)
	ResourceManager.morale = maxf(0.0, ResourceManager.morale - 5.0)
	ResourceManager.resources_changed.emit(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
	
	if building_system and building_system.has_method("set_building_damaged_randomly"):
		building_system.set_building_damaged_randomly()

func _on_choice_made(event_id: String, choice_id: String, choice_data: Dictionary) -> void:
	var outcomes = choice_data.get("outcomes", [])
	for outcome in outcomes:
		var type = outcome.get("type", "")
		if type == "narrative":
			_handle_narrative_outcome(outcome)
		elif type == "resource":
			_handle_resource_outcome(event_id, choice_id, outcome)

func _handle_narrative_outcome(outcome: Dictionary) -> void:
	if outcome.has("journal_entry") and typeof(outcome["journal_entry"]) == TYPE_STRING:
		var title = "Journal Entry"
		if "name was Amos" in outcome["journal_entry"] or "name is Lira" in outcome["journal_entry"]:
			title = "Day " + str(TimeManager.current_day) + " — The Cold Night"
		elif "Forty-three people" in outcome["journal_entry"] or "The gate stays closed" in outcome["journal_entry"]:
			title = "Day " + str(TimeManager.current_day) + " — The Deserters"

		if JournalManager:
			var id_slug = title.to_lower().replace(" ", "_").replace("—", "").replace("-", "_") + str(TimeManager.current_day)
			JournalManager.unlock_entry(id_slug, title, outcome["journal_entry"])

func _handle_resource_outcome(event_id: String, choice_id: String, outcome: Dictionary) -> void:
	# Check specific flags
	if event_id == "the_deserters" and choice_id == "option_b":
		GameManager.set("deserters_lockdown_taken", true)
		
	if outcome.has("vasquez_late_dialogue_unlocked"):
		GameManager.set("vasquez_intel_shared", outcome["vasquez_late_dialogue_unlocked"])
	if outcome.has("reconciliation_window_open"):
		GameManager.set("rook_militia_stopped", outcome["reconciliation_window_open"])
	if outcome.has("rook_reconciliation_taken"):
		GameManager.set("rook_reconciliation_taken", outcome["rook_reconciliation_taken"])
		
	# Food Modifiers
	if outcome.has("food_rate_delta_per_day"):
		var delta = float(outcome.get("food_rate_delta_per_day", 0.0))
		var duration = int(outcome.get("food_rate_duration_days", 0))
		if duration > 0:
			_add_temporary_effect("food", delta, duration)
	
	# Population logic
	if outcome.has("population_delta"):
		var p_delta = int(outcome["population_delta"])
		if p_delta < 0 and PopulationManager:
			PopulationManager.call("_remove_colonists", GameManager.population_state, abs(p_delta), "Event Outcome")
			
	# Available workers logic 
	if outcome.has("available_workers_delta"):
		var w_delta = int(outcome["available_workers_delta"])
		if w_delta < 0:
			GameManager.population_state.available_workers = maxi(0, GameManager.population_state.available_workers - abs(w_delta))
			GameManager.available_workers = GameManager.population_state.available_workers
			if PopulationManager:
				PopulationManager.population_changed.emit()

	# Morale Modifiers
	if outcome.has("morale_delta"):
		var m_delta = float(outcome["morale_delta"])
		if ResourceManager:
			ResourceManager.morale = clampf(ResourceManager.morale + m_delta, 0.0, 100.0)
			
	if outcome.has("morale_decay_multiplier"):
		var mult = float(outcome.get("morale_decay_multiplier", 1.0))
		var duration = int(outcome.get("morale_decay_duration_days", 0))
		if duration > 0:
			_add_temporary_effect("morale_decay", mult, duration)

func _add_temporary_effect(target: String, value: float, duration_days: int) -> void:
	_temporary_effects.append({
		"target": target,
		"value": value,
		"days_remaining": duration_days
	})
	_recalc_active_modifiers()

func _process_temporary_effects() -> void:
	var to_remove = []
	for effect in _temporary_effects:
		effect["days_remaining"] -= 1
		if effect["days_remaining"] <= 0:
			to_remove.append(effect)
	
	for r in to_remove:
		_temporary_effects.erase(r)
		
	_recalc_active_modifiers()

func _recalc_active_modifiers() -> void:
	active_food_delta = 0.0
	active_morale_decay_mult = 1.0
	
	for effect in _temporary_effects:
		if effect["target"] == "food":
			active_food_delta += effect["value"]
		elif effect["target"] == "morale_decay":
			# Just taking max multiplier for now if multiple exist
			active_morale_decay_mult = maxf(active_morale_decay_mult, effect["value"])
