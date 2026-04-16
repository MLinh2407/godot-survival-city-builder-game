extends Control

@onready var close_button = $Panel/VBoxContainer/TitleBox/CloseButton
@onready var entry_list = $Panel/VBoxContainer/ScrollContainer/EntryList

func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)
	# Safely connect if it exists in the autoloads
	if typeof(JournalManager) != TYPE_NIL:
		JournalManager.journal_updated.connect(_refresh_entries)

func _on_close_pressed() -> void:
	hide()

func toggle_journal() -> void:
	visible = not visible
	if visible:
		_refresh_entries()

func show_journal() -> void:
	show()
	_refresh_entries()

func _refresh_entries() -> void:
	for child in entry_list.get_children():
		child.queue_free()

	if typeof(JournalManager) == TYPE_NIL: return

	var reverse_entries = JournalManager.unlocked_entries.duplicate()
	reverse_entries.reverse()

	for entry in reverse_entries:
		var panel = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		panel.add_child(margin)

		var vbox = VBoxContainer.new()
		margin.add_child(vbox)

		var title = Label.new()
		title.text = entry.title
		title.add_theme_font_size_override("font_size", 20)
		vbox.add_child(title)

		var sep = HSeparator.new()
		vbox.add_child(sep)

		var body = Label.new()
		body.text = entry.body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(body)

		entry_list.add_child(panel)
