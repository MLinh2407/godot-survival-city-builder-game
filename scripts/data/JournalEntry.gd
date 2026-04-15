# Data container for a single Colony Journal entry
# Created by ColonyJournal.gd and serialised into save files

class_name JournalEntry
extends Resource

enum EntryType {
	NARRATIVE,       # Standard event outcome text
	NAMED_DEATH,     # A named character died
	COLONIST_DEATH,  # Anonymous colonist deaths
	ONBOARDING,      # Day 1-3 in-world nudges
	ARCHIVE,         # archive_entries.json content
}

var day: int = 1
var title: String = ""
var body: String = ""
var entry_type: EntryType = EntryType.NARRATIVE
var read: bool = true