extends Node

# Active modifiers for the current run
var active_food_delta: float = 0.0
var active_morale_decay_mult: float = 1.0

# Tracks duration of temporary effects
var _temporary_effects = []

# One-shot guard flags so events don't re-fire on load
var _fired_events: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame

	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)

	var de = _get_dialogue_engine()
	if de:
		de.choice_made.connect(_on_choice_made)

	if TimeManager and TimeManager.current_day == 1:
		_on_day_changed(1)

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _get_dialogue_engine() -> Node:
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("Events/DialogueEngine")
	return null

func _get_building_system() -> Node:
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("BuildingSystem")
	return null

func _fire_event_once(event_id: String) -> void:
	if _fired_events.has(event_id):
		return
	var de = _get_dialogue_engine()
	if de:
		_fired_events[event_id] = true
		de.show_event(event_id)

# func _fire_journal(slug: String, title: String, body: String) -> void:
# 	var journal = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
# 	if journal and journal.has_method("add_entry"):
# 		journal.add_entry(GameManager.current_day, body, 0, title)
# 		if journal.has_signal("journal_new_entry_notified"):
# 			journal.journal_new_entry_notified.emit()

func _fire_journal(slug: String, title: String, body: String) -> void:
	var journal = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
	if journal and journal.has_method("add_entry"):
		var entry_type = preload("res://scripts/data/JournalEntry.gd").EntryType.NARRATIVE
		journal.add_entry(TimeManager.current_day, body, entry_type, title)
	else:
		push_warning("CrisisEventSystem: ColonyJournal not found at Main/UILayer/ColonyJournal")


# ══════════════════════════════════════════════════════════════════════════════
# DAY CHANGED
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(new_day: int) -> void:
	_process_temporary_effects()

	# Apply any persistent daily food modifier from active effects
	if active_food_delta != 0.0 and ResourceManager:
		ResourceManager.food = maxf(0.0, ResourceManager.food + active_food_delta)
		ResourceManager.resources_changed.emit(
			ResourceManager.net_power, ResourceManager.food,
			ResourceManager.morale, ResourceManager.materials
		)

	# ── Day 1: Intro cards ─────────────────────────────────────────────────
	if new_day == 1:
		_fire_event_once("intro_kael")
		var de = _get_dialogue_engine()
		if de and not de.card_dismissed.is_connected(_trigger_intro_yuna):
			de.card_dismissed.connect(_trigger_intro_yuna.bind(de), CONNECT_ONE_SHOT)
		return

	# ── Day 3: The Cold Night ──────────────────────────────────────────────
	if new_day == 3:
		_fire_event_once("cold_night")

	# ── Day 8: The Deserters (condition: Morale < 50) ─────────────────────
	if new_day == 8:
		if ResourceManager and ResourceManager.morale < 50.0:
			_fire_event_once("the_deserters")

	# ── Day 10: Unrest Riot sub-event (lockdown aftermath) ────────────────
	if new_day == 10:
		if GameManager.get("deserters_lockdown_taken") == true:
			if ResourceManager and ResourceManager.morale < 30.0:
				_trigger_unrest_riot()

	# ── Day 11: The Vasquez Offer ─────────────────────────────────────────
	if new_day == 11:
		_fire_event_once("the_vasquez_offer")

	# ── Day 16: The Fever (auto-trigger, no choices) ──────────────────────
	if new_day == 16:
		_handle_the_fever()

	# ── Day 21: MERIDIAN Contact ──────────────────────────────────────────
	if new_day == 21:
		_fire_event_once("meridian_contact")

	# ── Day 24: Rook's Militia ────────────────────────────────────────────
	if new_day == 24:
		_fire_event_once("rooks_militia")

	# ── Day 26: The Storm Warning (auto-trigger, no choices) ─────────────
	if new_day == 26:
		_handle_storm_warning()

	# ── Day 27: Rook Reconciliation (conditional window) ─────────────────
	if new_day == 27:
		if GameManager.rook_militia_stopped and not GameManager.rook_reconciliation_taken:
			_fire_event_once("rook_reconciliation")

	# ── Day 28: The Last Broadcast (auto-trigger, layered outcomes) ───────
	if new_day == 28:
		_handle_last_broadcast()

	# ── Day 28: Vasquez Late Dialogue (if counter-offer intel shared) ─────
	if new_day == 28 and GameManager.vasquez_intel_shared:
		if not _fired_events.has("vasquez_late_dialogue"):
			_fired_events["vasquez_late_dialogue"] = true
			_fire_journal(
				"vasquez_late_dialogue",
				"Day 28 — Grid-9 Transmission",
				"Vasquez came over the radio at 1800. He didn't ask for engineers this time. He just wanted to confirm the eastern tunnel routing from the intelligence I gave him. He actually sounded like he respected the data. I'm noting this down because it's the first time someone outside these walls has treated us like an equal player instead of a salvage operation."
			)

# ══════════════════════════════════════════════════════════════════════════════
# AUTO-TRIGGER EVENTS (no choice card shown)
# ══════════════════════════════════════════════════════════════════════════════

func _handle_the_fever() -> void:
	if _fired_events.has("the_fever"):
		return
	_fired_events["the_fever"] = true

	# Actual disease outbreak is handled by PopulationManager.process_daily_population_tick
	# on Day 16. We just need to fire the appropriate journal entry here.
	var bs = _get_building_system()
	var clinic_staffed = false
	if bs and bs.has_method("get_workers_for_building_type"):
		clinic_staffed = bs.get_workers_for_building_type(BuildingData.BuildingType.MED_CLINIC) > 0

	var title = "Day 16 — The Fever"
	var body: String
	if clinic_staffed:
		body = "The Fever broke on Day 20. Twenty-one sick at peak. Yuna's staff worked through it. Nobody died. The colony is down workers for a week and morale took the hit but the Med Clinic held. She told me later she was worried we'd run out of antivirals. We didn't. Barely."
	else:
		body = "The Fever is in its fourth day and we have no treatment capacity. People are dying at a rate I cannot stop without a staffed Med Clinic. I made a calculation error somewhere in the first two weeks. I am living in it now."

	_fire_journal("the_fever_day_16", title, body)

func _handle_storm_warning() -> void:
	if _fired_events.has("the_storm_warning"):
		return
	_fired_events["the_storm_warning"] = true

	var source = "MERIDIAN" if GameManager.meridian_trusted else "the Archive Hall weather node"
	var body = "%s detected it first — the data is the same either way: an electromagnetic storm is approaching Grid-7. Impact on Day 35. Unshielded electronics will not survive it. Every production building runs on salvaged electronics. You have nine days. Decide what stays on." % source
	_fire_journal("storm_warning_day_26", "Day 26 — Storm Warning", body)
	# TODO: Hook into Storm Prep UI to allow per-building shielding over Days 26–34.

func _handle_last_broadcast() -> void:
	if _fired_events.has("the_last_broadcast"):
		return
	_fired_events["the_last_broadcast"] = true

	# Outcome 1 — always fires: Morale +8
	if ResourceManager:
		ResourceManager.morale = clampf(ResourceManager.morale + 8.0, 0.0, 100.0)
		ResourceManager.resources_changed.emit(
			ResourceManager.net_power, ResourceManager.food,
			ResourceManager.morale, ResourceManager.materials
		)

	_fire_journal(
		"last_broadcast_day_28",
		"Day 28 — The Last Broadcast",
		"At 1400 the Syndicate emergency broadcast came through. It called us 'undesignated population.' Everyone in the colony heard that phrase at the same time. The anger was immediate and it was clean and it was the most unified I have seen eight hundred people since Day 1. Morale went up. I don't think I've ever written that after something like this."
	)

	# Check Archive Hall for Materials bonus
	var bs = _get_building_system()
	var archive_built = bs != null and bs.has_method("has_building") \
		and bs.has_building(BuildingData.BuildingType.ARCHIVE_HALL)

	if archive_built:
		if ResourceManager:
			ResourceManager.materials += 25
			GameManager.materials = ResourceManager.materials
			ResourceManager.resources_changed.emit(
				ResourceManager.net_power, ResourceManager.food,
				ResourceManager.morale, ResourceManager.materials
			)
		_fire_journal(
			"last_broadcast_cache_day_28",
			"Day 28 — Supply Cache Recovered",
			"MERIDIAN found a secondary data layer in the broadcast — supply cache coordinates for Syndicate emergency stations in the eastern tunnels. We sent a retrieval team. Twenty-five Materials recovered. I don't know whether to be grateful or angry that their infrastructure is still being useful."
		)

	# Check Archive Hall + MERIDIAN trusted for signal seed
	if archive_built and GameManager.meridian_trusted:
		_fire_journal(
			"meridian_signal_detection",
			"Day 28 — Unknown Signal",
			"MERIDIAN flagged something else in the broadcast spectrum. A structured signal — not Syndicate, not noise. From the north. I asked MERIDIAN what it was. It said: 'Unknown. It responded to the broadcast. That means it was listening.' It's in the log. I don't know what to do with it yet."
		)

# ══════════════════════════════════════════════════════════════════════════════
# SUB-EVENT TRIGGERS
# ══════════════════════════════════════════════════════════════════════════════

func _trigger_intro_yuna(de: Node) -> void:
	de.show_event("intro_yuna")

func _trigger_unrest_riot() -> void:
	if _fired_events.has("unrest_riot"):
		return
	_fired_events["unrest_riot"] = true

	_fire_journal(
		"unrest_riot_day_10",
		"Day 10 — Unrest in the West Corridor",
		"The lockdown ended at 0600 and by 0800 there was a disturbance in the west corridor. Nobody was killed. Two security personnel injured. One building took damage — equipment pulled from its housing, fixtures broken. The people who did it are back in their section now.\n\nI could write this up in a way that makes it sound more contained than it was. What it was: people who were told they couldn't leave, in a place where the conditions that made them want to leave haven't changed, expressing that in the only way left available to them. The lockdown held the numbers. It did not hold the tension. The tension found its exit anyway.\n\nThe damaged building needs Materials to repair. Morale dropped further. I kept everyone here. I'm not sure everyone being here is the same as everyone being fine."
	)

	if ResourceManager:
		ResourceManager.morale = maxf(0.0, ResourceManager.morale - 5.0)
		ResourceManager.resources_changed.emit(
			ResourceManager.net_power, ResourceManager.food,
			ResourceManager.morale, ResourceManager.materials
		)

	var bs = _get_building_system()
	if bs and bs.has_method("set_building_damaged_randomly"):
		bs.set_building_damaged_randomly()

func _trigger_rook_injury() -> void:
	if _fired_events.has("rook_injury"):
		return
	_fired_events["rook_injury"] = true

	# -2 available workers for 3 days
	if GameManager:
		GameManager.population_state.available_workers = maxi(
			0, GameManager.population_state.available_workers - 2
		)
		GameManager.available_workers = GameManager.population_state.available_workers
		if PopulationManager:
			PopulationManager.population_changed.emit()

	_add_temporary_effect("workers_restored", 2.0, 3)

	_fire_journal(
		"rook_injury_event",
		"Rook's Militia — Injury Report",
		"Two of Rook's team took structural injuries in the collapsed section — one a fractured radius, one a concussion from a debris fall. They're off rotation. Rook filed the report himself. He didn't ask me to reconsider anything. The operation continues with the ten that are healthy."
	)

# ══════════════════════════════════════════════════════════════════════════════
# CHOICE HANDLER
# ══════════════════════════════════════════════════════════════════════════════

func _on_choice_made(event_id: String, choice_id: String, choice_data: Dictionary) -> void:
	var outcomes: Array = choice_data.get("outcomes", [])
	for outcome in outcomes:
		var type = outcome.get("type", "")
		if type == "narrative":
			_handle_narrative_outcome(event_id, outcome)
		elif type == "resource":
			_handle_resource_outcome(event_id, choice_id, outcome)

func _handle_narrative_outcome(event_id: String, outcome: Dictionary) -> void:
	var raw_body = outcome.get("journal_entry", "")
	if typeof(raw_body) != TYPE_STRING or raw_body.is_empty():
		return
	var day_str = "Day %d" % TimeManager.current_day
	var title = "%s — %s" % [day_str, _event_display_name(event_id)]
	var slug = "%s_%s" % [event_id, str(TimeManager.current_day)]
	_fire_journal(slug, title, raw_body)

func _event_display_name(event_id: String) -> String:
	match event_id:
		"cold_night":         return "The Cold Night"
		"the_deserters":      return "The Deserters"
		"the_vasquez_offer":  return "The Vasquez Offer"
		"meridian_contact":   return "MERIDIAN Contact"
		"rooks_militia":      return "Rook's Militia"
		"rook_reconciliation":return "Rook Reconciliation"
		_:                    return event_id.replace("_", " ").capitalize()

func _handle_resource_outcome(event_id: String, choice_id: String, outcome: Dictionary) -> void:
	# ── Flag: Lockdown taken (Deserters B) ──────────────────────────────
	if event_id == "the_deserters" and choice_id == "option_b":
		GameManager.set("deserters_lockdown_taken", true)

	# ── Flag: Vasquez trade accepted ─────────────────────────────────────
	if outcome.has("vasquez_trade_accepted_flag"):
		GameManager.vasquez_trade_accepted = bool(outcome["vasquez_trade_accepted_flag"])

	# ── Flag: Vasquez late dialogue (counter-offer C) ────────────────────
	if outcome.get("vasquez_late_dialogue_unlocked", false):
		GameManager.vasquez_intel_shared = true

	# ── Flag: MERIDIAN trusted ────────────────────────────────────────────
	if outcome.has("meridian_trusted_flag"):
		GameManager.meridian_trusted = bool(outcome["meridian_trusted_flag"])
		if GameManager.meridian_trusted:
			GameManager.meridian_alive = true
			GameManager.colonist_meridian.is_alive = true

	# ── Flag: Rook militia sanctioned (Option A) ──────────────────────────
	if outcome.get("rook_injury_risk_flag", false):
		GameManager.rook_militia_sanctioned = true
		# Schedule injury check — fires if Med Clinic not upgraded before Day 33
		# We'll check this on a deferred day-tick via the permanent effect tracker
		_add_temporary_effect("check_rook_injury", 1.0, 9) # Check around Day 33

	# ── Flag: Rook militia stopped (Option B) ────────────────────────────
	if outcome.get("reconciliation_window_open", false):
		GameManager.rook_militia_stopped = true

	# ── Flag: Rook reconciliation taken ──────────────────────────────────
	if outcome.get("rook_reconciliation_taken", false):
		GameManager.rook_reconciliation_taken = true

	# ── Population delta ─────────────────────────────────────────────────
	if outcome.has("population_delta"):
		var p_delta = int(outcome["population_delta"])
		if p_delta < 0 and PopulationManager:
			PopulationManager.call(
				"_remove_colonists",
				GameManager.population_state,
				abs(p_delta),
				"Event Outcome"
			)

	# ── Available workers delta ───────────────────────────────────────────
	if outcome.has("available_workers_delta"):
		var w_delta = int(outcome["available_workers_delta"])
		if w_delta < 0:
			GameManager.population_state.available_workers = maxi(
				0, GameManager.population_state.available_workers - abs(w_delta)
			)
			GameManager.available_workers = GameManager.population_state.available_workers
			if PopulationManager:
				PopulationManager.population_changed.emit()

	# ── Immediate morale delta ────────────────────────────────────────────
	if outcome.has("morale_delta") and ResourceManager:
		ResourceManager.morale = clampf(
			ResourceManager.morale + float(outcome["morale_delta"]), 0.0, 100.0
		)

	# ── Temporary morale decay multiplier ────────────────────────────────
	if outcome.has("morale_decay_multiplier"):
		var mult = float(outcome.get("morale_decay_multiplier", 1.0))
		var dur  = int(outcome.get("morale_decay_duration_days", 0))
		if dur > 0:
			_add_temporary_effect("morale_decay", mult, dur)

	# ── Temporary food rate delta ─────────────────────────────────────────
	if outcome.has("food_rate_delta_per_day"):
		var delta = float(outcome["food_rate_delta_per_day"])
		var dur   = int(outcome.get("food_rate_duration_days", 0))
		if dur > 0:
			_add_temporary_effect("food", delta, dur)

	# ── Sync ResourceManager after flag/resource changes ─────────────────
	if ResourceManager:
		ResourceManager.resources_changed.emit(
			ResourceManager.net_power, ResourceManager.food,
			ResourceManager.morale, ResourceManager.materials
		)

# ══════════════════════════════════════════════════════════════════════════════
# TEMPORARY EFFECT SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _add_temporary_effect(target: String, value: float, duration_days: int) -> void:
	_temporary_effects.append({
		"target": target,
		"value": value,
		"days_remaining": duration_days
	})
	_recalc_active_modifiers()

func _process_temporary_effects() -> void:
	var current_day = TimeManager.current_day if TimeManager else 0
	var to_remove = []

	for effect in _temporary_effects:
		effect["days_remaining"] -= 1

		# Special: Rook injury check fires near Day 33
		if effect["target"] == "check_rook_injury" and effect["days_remaining"] <= 0:
			if GameManager.rook_militia_sanctioned:
				var bs = _get_building_system()
				var clinic_upgraded = GameManager.med_clinic_upgraded_to_tier_2
				var clinic_doubled = bs != null and bs.has_method("get_med_clinic_count") \
					and bs.get_med_clinic_count() >= 2
				if not clinic_upgraded and not clinic_doubled:
					_trigger_rook_injury()
			to_remove.append(effect)

		# Special: Restore workers after Rook injury
		elif effect["target"] == "workers_restored" and effect["days_remaining"] <= 0:
			GameManager.population_state.available_workers = mini(
				GameManager.population_state.available_workers + int(effect["value"]),
				GameManager.population_state.total_population - GameManager.population_state.sick_count
			)
			GameManager.available_workers = GameManager.population_state.available_workers
			if PopulationManager:
				PopulationManager.population_changed.emit()
			to_remove.append(effect)

		elif effect["days_remaining"] <= 0:
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
			active_morale_decay_mult = maxf(active_morale_decay_mult, effect["value"])
