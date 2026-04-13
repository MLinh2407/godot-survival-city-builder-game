extends Node

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════

signal entry_added(entry: Dictionary)

# ══════════════════════════════════════════════════════════════════════════════
# STORAGE
# Each entry is a Dictionary:
# {
#   "day":  int,
#   "text": String,
#   "type": String   # see type constants below
# }
# ══════════════════════════════════════════════════════════════════════════════

const TYPE_SYSTEM        := "system"            # generic game events
const TYPE_ONBOARDING    := "onboarding"        # Day 1–3 in-world nudges
const TYPE_DEATH_COLONIST:= "death_colonist"    # unnamed colonist deaths
const TYPE_DEATH_NAMED   := "death_named"       # named character deaths
const TYPE_DESERTION     := "desertion"         # workers leaving from low Morale
const TYPE_DAMAGE        := "damage"            # building gone damaged

var entries: Array[Dictionary] = []

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to TimeManager for onboarding nudges and future daily hooks
	await get_tree().process_frame
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
	print("JournalManager ready.")

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

func add_entry(text: String, type: String = TYPE_SYSTEM) -> void:
	var day: int = TimeManager.current_day if TimeManager else 1
	var entry: Dictionary = {
		"day":  day,
		"text": text,
		"type": type
	}
	entries.append(entry)
	entry_added.emit(entry)
	print("📓 JOURNAL [Day %d] [%s]: %s" % [day, type, text])

func get_all_entries() -> Array[Dictionary]:
	return entries

func clear() -> void:
	entries.clear()

# ══════════════════════════════════════════════════════════════════════════════
# DAY 1–3 ONBOARDING NUDGES
# Fires once per day, in-world voice, never blocks screen
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(new_day: int) -> void:
	match new_day:
		1:
			add_entry(
				"The heating relay in Sector C needs attention. " +
				"Without it, the temperature drops below survival threshold after dark.",
				TYPE_ONBOARDING
			)
		2:
			# Only fires if Water Recycler not yet built
			var bs := _get_building_system()
			if bs and not bs.has_building(BuildingData.BuildingType.WATER_RECYCLER):
				add_entry(
					"Yuna flagged a water contamination concern. " +
					"We are still filtering manually but it will not hold long.",
					TYPE_ONBOARDING
				)
		3:
			# Only fires if Hydroponic Bay not yet built
			var bs := _get_building_system()
			if bs and not bs.has_building(BuildingData.BuildingType.HYDROPONIC_BAY):
				add_entry(
					"Current food reserves will last approximately 27 more days " +
					"at current consumption. That is the runway we have.",
					TYPE_ONBOARDING
				)

func _get_building_system() -> Node:
	return get_tree().root.get_node_or_null("Main/BuildingSystem")