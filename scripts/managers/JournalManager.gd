extends Node

signal journal_updated

var unlocked_entries: Array[Dictionary] = []

func _ready() -> void:
	print("--- JournalManager Initialized ---")

func unlock_entry(id: String, title: String, body: String) -> void:
	# Check if it already exists
	for entry in unlocked_entries:
		if entry.get("id") == id:
			return
			
	var new_entry = {
		"id": id,
		"title": title,
		"body": body,
		"day_unlocked": TimeManager.current_day if typeof(TimeManager) != TYPE_NIL else 1
	}
	
	unlocked_entries.append(new_entry)
	journal_updated.emit()
	print("JournalManager: Unlocked entry '", title, "'")

# Note: Could add save/load here if required by requirements,
# but for now we'll keep it simple to support the Yuna collapse requirement.
