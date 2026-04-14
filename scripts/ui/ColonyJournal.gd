extends CanvasLayer
class_name ColonyJournal

const JournalEntryData = preload("res://scripts/data/JournalEntry.gd")
const FONT_BODY = preload("res://assets/ui/fonts/SpecialElite-Regular.ttf")
const FONT_HEADING = preload("res://assets/ui/fonts/Cinzel-VariableFont_wght.ttf")

signal journal_opened
signal journal_closed

@export var debug_fill: bool = true
@export_range(0.18, 1.20, 0.01) var flip_duration: float = 0.36
@export_range(0.00, 0.20, 0.005) var flip_min_width: float = 0.04
@export_range(1.00, 1.10, 0.005) var flip_settle_scale: float = 1.02

const ENTRIES_PER_PAGE: int = 3

const COL_TITLE_DEFAULT := Color(0.42, 0.24, 0.09, 1.0)
const COL_TITLE_DEATH := Color(0.55, 0.16, 0.10, 1.0)
const COL_TITLE_COLONIST := Color(0.60, 0.18, 0.12, 1.0)
const COL_TITLE_ONBOARD := Color(0.31, 0.23, 0.10, 1.0)
const COL_BODY_DEFAULT := Color(0.06, 0.06, 0.06, 1.0)
const COL_BODY_DEATH := Color(0.12, 0.10, 0.09, 1.0)
const COL_SEPARATOR := Color(0.38, 0.28, 0.17, 0.32)

var entries: Array = []
var is_open: bool = false

var _current_spread: int = 0
var _is_flipping: bool = false

var _nudge_1_fired: bool = false
var _nudge_2_fired: bool = false
var _nudge_3_fired: bool = false
var first_unpause_happened: bool = false

@onready var book_root: Control = $BookRoot
@onready var left_page: Panel = $BookRoot/LeftPage
@onready var right_page: Panel = $BookRoot/RightPage
@onready var left_entries: VBoxContainer = $BookRoot/LeftPage/MarginContainer/EntriesLeft
@onready var right_entries: VBoxContainer = $BookRoot/RightPage/MarginContainer/EntriesRight
@onready var page_num_left: Label = $BookRoot/LeftPage/PageNumLeft
@onready var page_num_right: Label = $BookRoot/RightPage/PageNumRight
@onready var prev_btn: Button = $BookRoot/PrevButton
@onready var next_btn: Button = $BookRoot/NextButton
@onready var close_btn: Button = $BookRoot/CloseButton
@onready var empty_label: Label = $BookRoot/EmptyLabel

func _ready() -> void:
	layer = 10
	visible = false

	if prev_btn:
		prev_btn.pressed.connect(_on_prev_pressed)
	if next_btn:
		next_btn.pressed.connect(_on_next_pressed)
	if close_btn:
		close_btn.pressed.connect(close)

	if right_page:
		right_page.pivot_offset = Vector2(0.0, right_page.size.y * 0.5)
	if left_page:
		left_page.pivot_offset = Vector2(left_page.size.x, left_page.size.y * 0.5)

	await get_tree().process_frame

	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
	else:
		push_warning("ColonyJournal: TimeManager not found.")

	if PopulationManager:
		PopulationManager.colonist_died.connect(_on_colonist_died)
		PopulationManager.worker_deserted.connect(_on_worker_deserted)
		PopulationManager.character_died.connect(_on_character_died)
		PopulationManager.starvation_deaths.connect(_on_starvation_deaths)
		PopulationManager.outbreak_started.connect(_on_outbreak_started)
		PopulationManager.outbreak_ended.connect(_on_outbreak_ended)
	else:
		push_warning("ColonyJournal: PopulationManager not found.")

	# Debug: populate with sample entries for page-flip testing
	if debug_fill and entries.is_empty():
		for i in range(1, 11):
			var e := JournalEntryData.new()
			e.day = i
			e.title = "Test Entry %d" % i
			e.body = "This is a sample journal entry number %d. Use this to test the page flipping animation and navigation." % i
			e.entry_type = JournalEntryData.EntryType.NARRATIVE
			entries.append(e)

func add_entry(
		day: int,
		body: String,
		type: int = JournalEntryData.EntryType.NARRATIVE,
		title: String = "") -> void:
	var e := JournalEntryData.new()
	e.day = day
	e.body = body.strip_edges()
	e.entry_type = type
	e.title = title if title != "" else ("Day %d" % day)
	entries.append(e)

	if is_open:
		_current_spread = _max_spread()
		_rebuild_display()

func add_named_death_entry(character_name: String, day: int, body: String) -> void:
	add_entry(day, body, JournalEntryData.EntryType.NAMED_DEATH, character_name.to_upper())

func fire_day1_nudge() -> void:
	if _nudge_1_fired:
		return
	_nudge_1_fired = true
	add_entry(
		1,
		"The heating relay in Sector C needs attention. Without it, the temperature drops below survival threshold after dark.",
		JournalEntryData.EntryType.ONBOARDING
	)

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func _process(delta: float) -> void:
	# Allow flipping with Left/Right even if GUI elements have focus.
	if not is_open:
		return
	if Input.is_action_just_pressed("ui_left"):
		_on_prev_pressed()
	elif Input.is_action_just_pressed("ui_right"):
		_on_next_pressed()

func open() -> void:
	is_open = true
	visible = true
	_current_spread = _max_spread()
	_rebuild_display()
	_play_open_animation()
	journal_opened.emit()

func close() -> void:
	is_open = false
	_play_close_animation()
	journal_closed.emit()

func _on_prev_pressed() -> void:
	if _current_spread <= 0 or _is_flipping:
		return
	_flip_to(_current_spread - 1, false)

func _on_next_pressed() -> void:
	if _current_spread >= _max_spread() or _is_flipping:
		return
	_flip_to(_current_spread + 1, true)

func _max_spread() -> int:
	if entries.is_empty():
		return 0
	var entries_per_spread: int = ENTRIES_PER_PAGE * 2
	return maxi(0, ceili(float(entries.size()) / float(entries_per_spread)) - 1)

func _update_nav_buttons() -> void:
	if prev_btn:
		prev_btn.disabled = (_current_spread <= 0)
	if next_btn:
		next_btn.disabled = (_current_spread >= _max_spread())

func _rebuild_display() -> void:
	_populate_spread(_current_spread)
	_update_nav_buttons()
	if empty_label:
		empty_label.visible = entries.is_empty()

func _populate_spread(spread_index: int) -> void:
	var left_page_index: int = spread_index * 2
	var right_page_index: int = spread_index * 2 + 1
	_populate_page(left_entries, left_page_index, page_num_left)
	_populate_page(right_entries, right_page_index, page_num_right)

func _populate_page(container: VBoxContainer, page_index: int, num_label: Label) -> void:
	for child in container.get_children():
		child.queue_free()

	var start: int = page_index * ENTRIES_PER_PAGE
	var end: int = mini(start + ENTRIES_PER_PAGE, entries.size())

	if start >= entries.size():
		if num_label:
			num_label.text = ""
		return

	for i in range(start, end):
		var node := _build_entry_node(entries[i])
		container.add_child(node)

	if num_label:
		num_label.text = str(page_index + 1)

func _build_entry_node(e) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", COL_SEPARATOR)
	container.add_child(sep)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", FONT_HEADING)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.clip_text = false
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	match e.entry_type:
		JournalEntryData.EntryType.NAMED_DEATH:
			title_lbl.text = e.title
			title_lbl.add_theme_color_override("font_color", COL_TITLE_DEATH)
			title_lbl.add_theme_font_size_override("font_size", 14)
		JournalEntryData.EntryType.COLONIST_DEATH:
			title_lbl.text = "Day %d -" % e.day
			title_lbl.add_theme_color_override("font_color", COL_TITLE_COLONIST)
		JournalEntryData.EntryType.ONBOARDING:
			title_lbl.text = "Day %d -" % e.day
			title_lbl.add_theme_color_override("font_color", COL_TITLE_ONBOARD)
		_:
			title_lbl.text = "Day %d -" % e.day
			title_lbl.add_theme_color_override("font_color", COL_TITLE_DEFAULT)

	container.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = e.body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_lbl.add_theme_font_override("font", FONT_BODY)
	body_lbl.add_theme_font_size_override("font_size", 12)

	if e.entry_type == JournalEntryData.EntryType.NAMED_DEATH:
		body_lbl.add_theme_color_override("font_color", COL_BODY_DEATH)
	else:
		body_lbl.add_theme_color_override("font_color", COL_BODY_DEFAULT)

	container.add_child(body_lbl)

	container.modulate.a = 0.0
	var tween := container.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)

	return container

func _flip_to(new_spread: int, forward: bool) -> void:
	if _is_flipping:
		return
	_is_flipping = true

	var anim_page: Panel = right_page if forward else left_page
	var close_time := flip_duration * 0.5
	var open_time := flip_duration * 0.35
	var settle_time := flip_duration * 0.15

	var tween1 := create_tween()
	tween1.tween_property(anim_page, "scale:x", flip_min_width, close_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await tween1.finished

	_current_spread = new_spread
	_populate_spread(_current_spread)
	_update_nav_buttons()

	var tween2 := create_tween()
	tween2.tween_property(anim_page, "scale:x", flip_settle_scale, open_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween2.tween_property(anim_page, "scale:x", 1.0, settle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tween2.finished
	anim_page.scale.x = 1.0
	_is_flipping = false

func _play_open_animation() -> void:
	book_root.scale = Vector2(0.88, 0.88)
	book_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(book_root, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(book_root, "modulate:a", 1.0, 0.18)

func _play_close_animation() -> void:
	var tween := create_tween()
	tween.tween_property(book_root, "scale", Vector2(0.88, 0.88), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(book_root, "modulate:a", 0.0, 0.14)
	tween.tween_callback(func(): visible = false)

func _on_day_changed(new_day: int) -> void:
	if new_day == 2 and not _nudge_2_fired:
		if not _is_building_built(BuildingData.BuildingType.WATER_RECYCLER):
			_nudge_2_fired = true
			add_entry(
				2,
				"Yuna flagged a water contamination concern. We are still filtering manually but it will not hold long.",
				JournalEntryData.EntryType.ONBOARDING
			)

	if new_day == 3 and not _nudge_3_fired:
		if not _is_building_built(BuildingData.BuildingType.HYDROPONIC_BAY):
			_nudge_3_fired = true
			add_entry(
				3,
				"Current food reserves will last approximately 27 more days at current consumption. That is the runway we have.",
				JournalEntryData.EntryType.ONBOARDING
			)

func _is_building_built(type: BuildingData.BuildingType) -> bool:
	var bs := get_tree().root.get_node_or_null("Main/BuildingSystem")
	if bs and bs.has_method("has_building"):
		return bs.has_building(type)
	return false

func _on_colonist_died(count: int, cause: String) -> void:
	var noun := "colonist" if count == 1 else "colonists"
	var text := "%d %s lost to %s." % [count, noun, cause.to_lower()]
	add_entry(GameManager.current_day, text, JournalEntryData.EntryType.COLONIST_DEATH)

func _on_starvation_deaths(count: int) -> void:
	_on_colonist_died(count, "Starvation")

func _on_worker_deserted(count: int) -> void:
	var noun := "worker" if count == 1 else "workers"
	var text := "%d %s left the colony. Morale has dropped below the point where orders hold." % [count, noun]
	add_entry(GameManager.current_day, text, JournalEntryData.EntryType.COLONIST_DEATH)

func _on_outbreak_started(sick_count: int) -> void:
	var text := "Disease outbreak. %d colonists moved to the Sick pool and cannot work. The Med Clinic is the only way to bring them back." % sick_count
	add_entry(GameManager.current_day, text, JournalEntryData.EntryType.NARRATIVE)

func _on_outbreak_ended() -> void:
	add_entry(
		GameManager.current_day,
		"The outbreak has been resolved. Sick colonists have returned to the worker pool.",
		JournalEntryData.EntryType.NARRATIVE
	)

func _on_character_died(char_name: String) -> void:
	var body_text := _load_death_text_from_json(char_name)
	add_named_death_entry(char_name, GameManager.current_day, body_text)

func _load_death_text_from_json(char_name: String) -> String:
	var file := FileAccess.open("res://data/character_deaths.json", FileAccess.READ)
	if not file:
		push_warning("ColonyJournal: Could not open character_deaths.json")
		return "%s is gone." % char_name

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ColonyJournal: character_deaths.json parse failed")
		return "%s is gone." % char_name

	for death in parsed.get("deaths", []):
		if typeof(death) != TYPE_DICTIONARY:
			continue
		if death.get("display_name", "").begins_with(char_name) \
		or death.get("character_id", "") == char_name.to_lower().replace(" ", "_"):
			var journal_entry = death.get("journal_entry", {})
			return journal_entry.get("body", "%s is gone." % char_name)

	return "%s is gone." % char_name

func serialise() -> Array:
	var out: Array = []
	for e in entries:
		out.append({
			"day": e.day,
			"title": e.title,
			"body": e.body,
			"type": e.entry_type,
		})
	return out

func deserialise(data: Array) -> void:
	entries.clear()
	_nudge_1_fired = false
	_nudge_2_fired = false
	_nudge_3_fired = false
	first_unpause_happened = false

	for d in data:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var e := JournalEntryData.new()
		e.day = int(d.get("day", 1))
		e.title = str(d.get("title", ""))
		e.body = str(d.get("body", ""))
		e.entry_type = int(d.get("type", JournalEntryData.EntryType.NARRATIVE))
		entries.append(e)

		if e.entry_type == JournalEntryData.EntryType.ONBOARDING:
			if e.day == 1:
				_nudge_1_fired = true
				first_unpause_happened = true
			elif e.day == 2:
				_nudge_2_fired = true
			elif e.day == 3:
				_nudge_3_fired = true

	_current_spread = _max_spread()
	if is_open:
		_rebuild_display()
