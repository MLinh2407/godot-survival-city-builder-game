extends CanvasLayer

signal load_file_selected(path: String)

@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider

var file_dialog: FileDialog

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS # Ensure menu runs while game is paused
    visible = false
    
    # Initialize sliders to current AudioServer state (assuming GameManager handled defaults)
    _sync_sliders_from_audio_server()
    
    master_slider.value_changed.connect(_on_master_changed)
    music_slider.value_changed.connect(_on_music_changed)
    sfx_slider.value_changed.connect(_on_sfx_changed)
    
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
    get_tree().paused = visible

func load_settings() -> void:
    # Trigger the FileDialog instead of audio loading
    _check_save_dir()
    file_dialog.current_dir = "user://saves"
    file_dialog.popup_centered()

func _check_save_dir() -> void:
    if not DirAccess.dir_exists_absolute("user://saves"):
        DirAccess.make_dir_absolute("user://saves")

func _on_file_selected(path: String) -> void:
    if GameManager:
        GameManager.load_game(path)
    emit_signal("load_file_selected", path)
    toggle_menu() # hide menu after load

func _on_save_button_pressed() -> void:
    if GameManager:
        # Auto-generate a save name
        var d = TimeManager.current_day if TimeManager else 0
        var dt = Time.get_datetime_dict_from_system()
        var fname = "save_Day%d_%02d%02d%02d.json" % [d, dt.hour, dt.minute, dt.second]
        GameManager.save_game(fname)

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