extends Panel

@onready var _entry_list: VBoxContainer = %EntryList
@onready var _close_button: Button = %CloseButton

var _is_open: bool = false
var _was_tree_paused: bool = false
var _previous_speed: int = TimeManager.GameSpeed.NORMAL
var _modal_backdrop: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.focus_mode = Control.FOCUS_ALL

	# Create backdrop 
	call_deferred("_ensure_modal_backdrop")

	visible = false
	_is_open = false

func _ensure_modal_backdrop() -> void:
	if _modal_backdrop and is_instance_valid(_modal_backdrop):
		return
	var parent_node := get_parent()
	if parent_node == null:
		return

	_modal_backdrop = ColorRect.new()
	_modal_backdrop.name = "MemorialModalBackdrop"
	_modal_backdrop.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.focus_mode = Control.FOCUS_NONE
	_modal_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_modal_backdrop.visible = false
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.offset_left = 0.0
	_modal_backdrop.offset_top = 0.0
	_modal_backdrop.offset_right = 0.0
	_modal_backdrop.offset_bottom = 0.0
	_modal_backdrop.z_index = max(z_index - 1, 0)

	parent_node.add_child(_modal_backdrop)
	_raise_modal_nodes()

func _raise_modal_nodes() -> void:
	if not _modal_backdrop or not is_instance_valid(_modal_backdrop):
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	# Ensure both blocker and panel are top-most siblings; panel stays above blocker.
	parent_node.move_child(_modal_backdrop, parent_node.get_child_count() - 1)
	parent_node.move_child(self, parent_node.get_child_count() - 1)

## Open the memorial panel and populate it with memorial entries
func open_memorial() -> void:
	if _is_open:
		return
	_ensure_modal_backdrop()
	_raise_modal_nodes()
	
	# Pause systems while this modal is open
	if get_tree():
		_was_tree_paused = get_tree().paused
		_previous_speed = TimeManager.current_speed
		get_tree().paused = true
	TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)
	
	# Clear existing entries
	for child in _entry_list.get_children():
		child.queue_free()
	
	# Populate with current memorial entries
	_refresh_entries()

	_is_open = true
	if _modal_backdrop:
		_modal_backdrop.visible = true
	visible = true
	
	_close_button.grab_focus()

## Close the memorial panel
func close_memorial() -> void:
	if not _is_open and not visible:
		return

	_is_open = false
	if _modal_backdrop:
		_modal_backdrop.visible = false
	visible = false

	# Restore pre pause/speed state
	if get_tree():
		if _was_tree_paused or _previous_speed == TimeManager.GameSpeed.PAUSED:
			get_tree().paused = true
			TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)
		else:
			get_tree().paused = false
			TimeManager.set_game_speed(_previous_speed)

## Refresh the memorial entries list
func _refresh_entries() -> void:
	# Get memorial entries from GameManager
	var entries = GameManager.get_memorial_entries()
	
	# Populate the list
	for entry in entries:
		_add_entry_display(entry)

## Add a single memorial entry to the display
func _add_entry_display(entry: Dictionary) -> void:
	var entry_node = Label.new()
	entry_node.text = "%s - Day %d" % [entry.get("name", "Unknown"), entry.get("day", 0)]
	entry_node.custom_minimum_size = Vector2(0, 40)
	entry_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_node.add_theme_font_size_override("font_size", 18)
	entry_node.modulate = Color.WHITE
	_entry_list.add_child(entry_node)

## Signal handlers
func _on_close_pressed() -> void:
	close_memorial()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	
	# ESC key to close
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_memorial()

func is_open() -> bool:
	return _is_open