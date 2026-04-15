extends Node

# ══════════════════════════════════════════════════════════════════════════════
# ENDING MANAGER
# Called once on Day 35 when the storm hits.
# This is the only place in the codebase where ending selection happens.
# ══════════════════════════════════════════════════════════════════════════════

signal ending_determined(ending_key: String, rook_alive: bool)

# Ending keys — match endings.json
const ENDING_THE_SIGNAL        := "the_signal"
const ENDING_THE_TORCH         := "the_torch"
const ENDING_THE_NECESSARY_EVIL := "the_necessary_evil"
const ENDING_THE_QUIET         := "the_quiet"

var _ending_fired: bool = false

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	if TimeManager:
		TimeManager.storm_hit.connect(_on_storm_hit)
	print("EndingManager ready — listening for storm_hit signal.")

# ══════════════════════════════════════════════════════════════════════════════
# STORM HIT — Day 35 trigger
# ══════════════════════════════════════════════════════════════════════════════

func _on_storm_hit() -> void:
	if _ending_fired:
		return
	_ending_fired = true
	determine_ending()

# ══════════════════════════════════════════════════════════════════════════════
# ENDING DETERMINATION
# ══════════════════════════════════════════════════════════════════════════════

func determine_ending() -> void:
	var survival_rate: float  = float(GameManager.current_population) / 847.0
	var slider_value: float   = GameManager.hope_order_slider
	var rook_alive: bool      = GameManager.rook_alive
	var yuna_alive: bool      = GameManager.yuna_alive
	var vasquez_alive: bool   = GameManager.vasquez_alive
	var meridian_alive: bool  = GameManager.meridian_alive
	var all_alive: bool       = rook_alive and yuna_alive and vasquez_alive and meridian_alive

	print("══════════════════════════════════════════════════════")
	print(" ENDING DETERMINATION — Day 35")
	print("══════════════════════════════════════════════════════")
	print(" Survival rate : %.1f%% (%d / 847)" % [survival_rate * 100.0, GameManager.current_population])
	print(" Slider value  : %.1f" % slider_value)
	print(" Yuna alive    : %s" % str(yuna_alive))
	print(" Rook alive    : %s" % str(rook_alive))
	print(" Vasquez alive : %s" % str(vasquez_alive))
	print(" MERIDIAN alive: %s" % str(meridian_alive))
	print(" All alive     : %s" % str(all_alive))
	print("──────────────────────────────────────────────────────")

	var ending_key: String

	# Step 0 — Secret ending check (highest priority)
	if all_alive and survival_rate >= GameConstants.ENDING_SIGNAL_RATE:
		ending_key = ENDING_THE_SIGNAL
		print(" STEP 0: The Signal conditions met → firing secret ending")
		_play_ending(ending_key, rook_alive)
		return

	# Step 1 — Primary gate: survival rate
	if survival_rate < GameConstants.ENDING_QUIET_RATE:
		ending_key = ENDING_THE_QUIET
		print(" STEP 1: Survival rate %.1f%% below %.1f%% threshold → The Quiet" \
			% [survival_rate * 100.0, GameConstants.ENDING_QUIET_RATE * 100.0])
		_play_ending(ending_key, rook_alive)
		return

	# Step 2 — Secondary gate: Hope/Order slider
	if slider_value < GameConstants.ENDING_SLIDER_MID:
		ending_key = ENDING_THE_TORCH
		print(" STEP 2: Slider %.1f below %.1f → The Torch" \
			% [slider_value, GameConstants.ENDING_SLIDER_MID])
	else:
		ending_key = ENDING_THE_NECESSARY_EVIL
		print(" STEP 2: Slider %.1f at or above %.1f → The Necessary Evil" \
			% [slider_value, GameConstants.ENDING_SLIDER_MID])

	_play_ending(ending_key, rook_alive)

# ══════════════════════════════════════════════════════════════════════════════
# PLAY ENDING
# Loads text from endings.json, emits signal, displays ending screen
# ══════════════════════════════════════════════════════════════════════════════

func _play_ending(key: String, rook_modifier: bool) -> void:
	var variant_key: String = key + ("_rook_alive" if rook_modifier else "_rook_dead")

	print("──────────────────────────────────────────────────────")
	print(" ENDING FIRED: %s | Rook modifier: %s" % [key, str(rook_modifier)])
	print(" Variant key : %s" % variant_key)
	print("══════════════════════════════════════════════════════")

	# Load ending text from endings.json
	var ending_data: Dictionary = _load_ending_data(key, rook_modifier)

	# Emit signal — EndingScreen UI listens and displays
	ending_determined.emit(key, rook_modifier)

	# Log ending final line to journal
	var ending_text: String = ending_data.get("final_line", "")
	
	if ending_text != "":
		JournalManager.add_entry(ending_text, JournalManager.TYPE_SYSTEM)

	# Play ending music
	if AudioManager:
		AudioManager.crossfade_to(AudioManager.track_3, 2.0)

func _load_ending_data(key: String, rook_alive: bool) -> Dictionary:
	var file = FileAccess.open("res://data/endings.json", FileAccess.READ)
	if not file:
		push_warning("EndingManager: Could not open endings.json")
		return {}

	var content = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EndingManager: endings.json has invalid root")
		return {}

	# endings is an ARRAY — iterate to find the matching ending_id
	var endings: Array = parsed.get("endings", [])
	var ending_entry: Dictionary = {}

	for e in endings:
		if typeof(e) == TYPE_DICTIONARY and e.get("ending_id", "") == key:
			ending_entry = e
			break

	if ending_entry.is_empty():
		push_warning("EndingManager: No ending found for key '%s'" % key)
		return {}

	# variants is an ARRAY — find the correct rook variant
	var variants: Array = ending_entry.get("variants", [])
	for v in variants:
		if typeof(v) == TYPE_DICTIONARY and v.get("rook_alive", true) == rook_alive:
			return v

	# Fallback — return first variant if no exact rook match found
	if not variants.is_empty():
		push_warning("EndingManager: No exact rook variant for '%s' rook_alive=%s — using first variant" \
			% [key, str(rook_alive)])
		return variants[0]

	return {}

# ══════════════════════════════════════════════════════════════════════════════
# DEBUG — force-fire a specific ending for testing without playing 35 days
# Call from the Godot debugger: EndingManager.debug_force_ending("the_torch", true)
# ══════════════════════════════════════════════════════════════════════════════

func debug_force_ending(key: String, rook_alive: bool) -> void:
	print("EndingManager: DEBUG — force firing ending '%s' rook_alive=%s" % [key, str(rook_alive)])
	_ending_fired = false   # Reset so it can fire again
	_play_ending(key, rook_alive)