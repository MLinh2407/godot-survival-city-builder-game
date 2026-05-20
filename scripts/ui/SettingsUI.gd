extends CanvasLayer

signal load_file_selected(path: String)

@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider

var file_dialog: FileDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure menu runs while game is paused
	visible = false

	# Apply neon border and padding to the panel
	var pc := $PanelContainer
	if pc:
		var sb := StyleBoxFlat.new()
		# subtle dark background
		sb.bg_color = Color(0.03, 0.03, 0.06, 0.92)
		# neon cyan border 
		sb.border_color = Color(0.0, 0.75, 0.85, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		# content margin 
		sb.set_content_margin_all(18)
		# horizontal padding 
		pc.add_theme_stylebox_override("panel", sb)
	
	# Initialize sliders to current AudioServer state (assuming GameManager handled defaults)
	_sync_sliders_from_audio_server()
	
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	_setup_tutorial_toggle()
	
	var return_btn = $PanelContainer/VBoxContainer/HBoxContainer/ReturnToMenuButton
	if name == "StandaloneSettingsUI":
		return_btn.hide()

	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.add_filter("*.json")
	# FileDialog needs use_native_dialog = false to exist inside canvas layer on some platforms
	file_dialog.use_native_dialog = false
	file_dialog.size = Vector2i(600, 400)
	file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	file_dialog.title = "Select Save File"
	file_dialog.current_dir = "user://saves"
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle_menu()

func toggle_menu() -> void:
	visible = !visible
	var tree := get_tree()
	if tree:
		tree.paused = visible

func load_settings() -> void:
	# Trigger the FileDialog instead of audio loading
	_check_save_dir()
	file_dialog.current_dir = "user://saves"
	file_dialog.popup_centered()

func _check_save_dir() -> void:
	if not DirAccess.dir_exists_absolute("user://saves"):
		DirAccess.make_dir_absolute("user://saves")

func _on_file_selected(path: String) -> void:
	emit_signal("load_file_selected", path)
	toggle_menu() # hide menu after load

func _on_save_button_pressed() -> void:
	if GameManager:
		# Auto-generate a save name
		var d = TimeManager.current_day if TimeManager else 0
		var dt = Time.get_datetime_dict_from_system()
		var fname = "save_Day%d_%02d%02d%02d.json" % [d, dt.hour, dt.minute, dt.second]
		GameManager.save_game(fname)
		
		var success_lbl = Label.new()
		success_lbl.text = "Game Saved!"
		success_lbl.add_theme_font_size_override("font_size", 28)
		success_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		
		var vp_size = get_viewport().get_visible_rect().size
		success_lbl.position = Vector2(vp_size.x * 0.5 - 80, vp_size.y * 0.5 - 200)
		add_child(success_lbl)
		
		var tween = create_tween()
		tween.tween_property(success_lbl, "position:y", success_lbl.position.y - 50, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(success_lbl, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(success_lbl.queue_free)

func _sync_sliders_from_audio_server() -> void:
	var m = AudioServer.get_bus_index("Master")
	var mu = AudioServer.get_bus_index("Music")
	var s = AudioServer.get_bus_index("SFX")
	
	if m >= 0: master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(m))
	if mu >= 0: music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(mu))
	if s >= 0: sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(s))

func _apply_volume(bus_name: String, value_linear: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if value_linear <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value_linear))

func _on_master_changed(value: float) -> void:
	_apply_volume("Master", value)

func _on_music_changed(value: float) -> void:
	_apply_volume("Music", value)

func _on_sfx_changed(value: float) -> void:
	_apply_volume("SFX", value)

func _on_close_button_pressed() -> void:
	toggle_menu()

func _on_return_to_menu_pressed() -> void:
	toggle_menu()
	var main_scene = get_tree().root.get_node_or_null("Main")
	if not main_scene:
		main_scene = get_tree().root.find_child("Main", true, false)
	
	if main_scene and main_scene.has_method("show_main_menu_from_ending"):
		main_scene.call("show_main_menu_from_ending")
	else:
		get_tree().reload_current_scene()
func _setup_tutorial_toggle() -> void:
	# Create toggle dynamically — adds below the volume sliders
	var container := get_node_or_null("%SFXSlider")
	if not container:
		return
	var parent: Control = container.get_parent()
	if not parent:
		return

	var sep := HSeparator.new()
	parent.add_child(sep)

	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Show Tutorial"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92, 1.0))
	row.add_child(lbl)

	var toggle := CheckButton.new()
	toggle.button_pressed = TutorialManager.tutorial_enabled if TutorialManager else true
	toggle.toggled.connect(func(pressed: bool):
		if TutorialManager:
			TutorialManager.tutorial_enabled = pressed
			TutorialManager.save_config()
	)
	row.add_child(toggle)

	var hint := Label.new()
	hint.text = "Disable to hide all coach marks and tutorial notes.\nStory journal entries still appear normally."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.50, 0.55, 0.60, 0.80))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(hint)
