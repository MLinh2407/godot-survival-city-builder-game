extends Control

signal start_new_game
signal credits
signal open_settings
signal exit_game

@onready var live_bg: TextureRect = $LiveBackground
@onready var live_bg_node2d: Node2D = $LiveBackgroundNode2D

@onready var title_rect: TextureRect = $LeftColumn/VBox/TitleHolder/Title
@onready var btn_new: Button = $LeftColumn/VBox/ButtonsPanel/Buttons/NewGame
@onready var btn_credits: Button = $LeftColumn/VBox/ButtonsPanel/Buttons/Credits
@onready var btn_settings: Button = $LeftColumn/VBox/ButtonsPanel/Buttons/Settings
@onready var btn_exit: Button = $LeftColumn/VBox/ButtonsPanel/Buttons/Exit
var _buttons: Array[Button] = []
var _button_tweens: Dictionary = {}
var _standalone_load_dialog: FileDialog
var _standalone_credits_screen: Control
var _blur_shader: Shader
var _input_locked_until_msec: int = 0
var initial_input_lock_sec: float = 0.0
var _input_lock_timer: SceneTreeTimer
var _input_lock_retry_timer: SceneTreeTimer
var _credits_roll_active: bool = false

var settings_scene_path: String = "res://scenes/main/SettingsUI.tscn"
var main_scene_path: String = "res://scenes/main/Main.tscn"
var main_scene_packed: PackedScene = preload("res://scenes/main/Main.tscn")
const MENU_CURSOR_PATH: String = "res://assets/ui/main_menu/Hand.png"

func _ready() -> void:
	randomize()
	_setup_custom_cursor()
	_connect_buttons()
	_setup_standalone_load_dialog()
	_setup_background()
	# Menu music (Track_4) plays
	if AudioManager and AudioManager.has_method("crossfade_to") and AudioManager.track_4:
		AudioManager.crossfade_to(AudioManager.track_4, 1.2)
	elif AudioManager and AudioManager.has_method("play_music") and AudioManager.track_4:
		AudioManager.play_music(AudioManager.track_4)
	if live_bg:
		live_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if live_bg_node2d:
		for child in live_bg_node2d.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_buttons = [btn_new, btn_credits, btn_settings, btn_exit]
	for b in _buttons:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.pivot_offset = b.size * 0.5

	if initial_input_lock_sec > 0.0:
		set_input_lock(initial_input_lock_sec)

	_setup_title_outline()
	mouse_filter = Control.MOUSE_FILTER_PASS

var _title_outline_shader: Shader

func _setup_title_outline() -> void:
	if title_rect == null:
		return
	if title_rect.has_node("TitleOutline"):
		return
	if title_rect.texture == null:
		return

	var outline := TextureRect.new()
	outline.name = "TitleOutline"
	outline.texture = title_rect.texture
	outline.stretch_mode = title_rect.stretch_mode
	outline.anchor_left = 0.0
	outline.anchor_top = 0.0
	outline.anchor_right = 1.0
	outline.anchor_bottom = 1.0
	outline.offset_left = -3.0
	outline.offset_top = -3.0
	outline.offset_right = 3.0
	outline.offset_bottom = 3.0
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = -2

	var shader_path := "res://assets/shaders/menu_title_text_outline.gdshader"
	if ResourceLoader.exists(shader_path):
		var sh := ResourceLoader.load(shader_path)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("outline_color", Color(0.88, 0.98, 1.0, 1.0))
		# Thinner border for the title
		mat.set_shader_parameter("outline_size", 1.0)
		mat.set_shader_parameter("outline_strength", 1.0)
		outline.material = mat

	title_rect.add_child(outline)
	title_rect.move_child(outline, 0)

func set_input_lock(duration_sec: float) -> void:
	if duration_sec <= 0.0:
		_input_locked_until_msec = 0
		_set_buttons_enabled(true)
		return
	_input_locked_until_msec = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	_set_buttons_enabled(false)
	if _input_lock_timer:
		_input_lock_timer.timeout.disconnect(_on_input_lock_timeout)
		_input_lock_timer = null
	_input_lock_timer = get_tree().create_timer(duration_sec, true)
	_input_lock_timer.timeout.connect(_on_input_lock_timeout)

func _can_accept_input() -> bool:
	if _input_locked_until_msec == 0:
		return true
	if Time.get_ticks_msec() >= _input_locked_until_msec:
		_input_locked_until_msec = 0
		_set_buttons_enabled(true)
		return true
	return false

func _on_input_lock_timeout() -> void:
	_attempt_unlock()

func _attempt_unlock() -> void:
	if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_SPACE):
		_schedule_unlock_retry()
		return
	_input_locked_until_msec = 0
	_set_buttons_enabled(true)
	for b in _buttons:
		if b:
			b.release_focus()

func _schedule_unlock_retry() -> void:
	if _input_lock_retry_timer:
		_input_lock_retry_timer.timeout.disconnect(_on_unlock_retry_timeout)
		_input_lock_retry_timer = null
	_input_lock_retry_timer = get_tree().create_timer(0.1, true)
	_input_lock_retry_timer.timeout.connect(_on_unlock_retry_timeout)

func _on_unlock_retry_timeout() -> void:
	_attempt_unlock()

func _set_buttons_enabled(enabled: bool) -> void:
	for b in _buttons:
		if b:
			b.disabled = not enabled

func _connect_buttons() -> void:
	if btn_new:
		btn_new.pressed.connect(Callable(self, "_on_new_game_pressed"))
		btn_new.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("NewGame", btn_new))
		btn_new.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("NewGame", btn_new))
	if btn_credits:
		btn_credits.pressed.connect(Callable(self, "_on_credits_pressed"))
		btn_credits.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("Credits", btn_credits))
		btn_credits.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("Credits", btn_credits))
	if btn_settings:
		btn_settings.pressed.connect(Callable(self, "_on_settings_pressed"))
		btn_settings.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("Settings", btn_settings))
		btn_settings.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("Settings", btn_settings))
	if btn_exit:
		btn_exit.pressed.connect(Callable(self, "_on_exit_pressed"))
		btn_exit.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("Exit", btn_exit))
		btn_exit.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("Exit", btn_exit))

func _on_button_mouse_entered(button_id: String, button: Button) -> void:
	_animate_button_hover(button, true)
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("hover")

func _on_button_mouse_exited(button_id: String, button: Button) -> void:
	_animate_button_hover(button, false)

func _animate_button_hover(button: Button, is_hovered: bool) -> void:
	if button == null:
		return
	var tween_key: String = str(button.get_instance_id())
	if _button_tweens.has(tween_key):
		var old_tween: Tween = _button_tweens[tween_key]
		if old_tween:
			old_tween.kill()

	var target_scale: Vector2 = Vector2.ONE
	var target_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
	if is_hovered:
		target_scale = Vector2(1.04, 1.04)
		target_modulate = Color(1.0, 0.97, 0.9, 1.0)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)
	tween.parallel().tween_property(button, "modulate", target_modulate, 0.12)
	_button_tweens[tween_key] = tween

func _setup_custom_cursor() -> void:
	if not ResourceLoader.exists(MENU_CURSOR_PATH):
		push_warning("MainMenu: cursor not found at %s" % MENU_CURSOR_PATH)
		return
	var cursor_texture := ResourceLoader.load(MENU_CURSOR_PATH) as Texture2D
	if cursor_texture == null:
		push_warning("MainMenu: failed to load cursor texture at %s" % MENU_CURSOR_PATH)
		return
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_POINTING_HAND)

func _make_blur_material(blur_radius: float = 1.6, tint: Color = Color(0.55, 0.88, 1.0, 0.9)) -> ShaderMaterial:
	if _blur_shader == null:
		var shader_path := "res://assets/shaders/menu_blur.gdshader"
		if ResourceLoader.exists(shader_path):
			_blur_shader = ResourceLoader.load(shader_path)
		else:
			push_warning("MainMenu: shader not found at %s" % shader_path)

	var material := ShaderMaterial.new()
	if _blur_shader:
		material.shader = _blur_shader
		material.set_shader_parameter("blur_radius", blur_radius)
		material.set_shader_parameter("tint", tint)
	return material

func _setup_standalone_load_dialog() -> void:
	if _standalone_load_dialog:
		return
	_standalone_load_dialog = FileDialog.new()
	_standalone_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_standalone_load_dialog.access = FileDialog.ACCESS_USERDATA
	_standalone_load_dialog.add_filter("*.json")
	_standalone_load_dialog.use_native_dialog = false
	_standalone_load_dialog.size = Vector2i(640, 420)
	_standalone_load_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_standalone_load_dialog.title = "Select Save File"
	_standalone_load_dialog.current_dir = "user://saves"
	_standalone_load_dialog.file_selected.connect(_on_standalone_load_file_selected)
	add_child(_standalone_load_dialog)

func _setup_background() -> void:
	var folder := "res://assets/ui/live_background"
	var dir = DirAccess.open(folder)
	if dir == null:
		push_warning("MainMenu: live_background folder not found: %s" % folder)
		return

	var candidates: Array = []
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var file_ext = fname.get_extension().to_lower()
			if file_ext in ["png","jpg","jpeg","webp","bmp","tga","gif","ogv","webm","mp4","mkv"]:
				candidates.append(folder + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()

	if candidates.is_empty():
		push_warning("MainMenu: no background files in %s" % folder)
		return

	var pick = candidates[randi() % candidates.size()]
	var res = ResourceLoader.load(pick)
	if res == null:
		var video_stream = ResourceLoader.load(pick)
		res = video_stream
	var ext = pick.get_extension().to_lower()
	var video_exts := ["ogv","webm","mp4","mkv"]

	if res == null:
		push_warning("MainMenu: failed to load background: %s" % pick)
		return

	if ext in video_exts or res is VideoStream:
		var vp := VideoStreamPlayer.new()
		vp.anchor_left = 0.0
		vp.anchor_top = 0.0
		vp.anchor_right = 1.0
		vp.anchor_bottom = 1.0
		vp.expand = true
		vp.loop = true
		vp.z_index = -101
		vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp.stream = res
		vp.volume_db = -80.0
		add_child(vp)
		live_bg.visible = false
		vp.play()
	elif res is SpriteFrames:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = res
		var anim_names: PackedStringArray = res.get_animation_names()
		if not anim_names.is_empty():
			anim.animation = anim_names[0]
		anim.play()
		var vp_rect = get_viewport_rect()
		var frame_tex: Texture2D = res.get_frame(anim.animation, 0)
		if frame_tex != null:
			var sx = vp_rect.size.x / float(frame_tex.get_width())
			var sy = vp_rect.size.y / float(frame_tex.get_height())
			var s = max(sx, sy)
			anim.scale = Vector2(s, s)
			anim.position = vp_rect.size * 0.5
		live_bg_node2d.add_child(anim)
	elif res is Texture2D:
		live_bg.texture = res
	else:
		var tex = res as Texture2D
		if tex:
			live_bg.texture = tex
		else:
			push_warning("MainMenu: unsupported background resource type for %s" % pick)

func _on_new_game_pressed() -> void:
	if not _can_accept_input():
		return
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("start_new_game")
	if _get_signal_listener_count("start_new_game") == 0:
		if main_scene_packed:
			get_tree().set_meta("launch_new_game_flow", true)
			get_tree().set_meta("play_intro_on_new_game", true)
			get_tree().change_scene_to_packed(main_scene_packed)
		else:
			push_warning("MainMenu: main scene not found at %s" % main_scene_path)

func _on_credits_pressed() -> void:
	if not _can_accept_input():
		return
	if _credits_roll_active:
		return
	_credits_roll_active = true
	_set_buttons_enabled(false)
	if btn_credits:
		btn_credits.release_focus()
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("credits")
	if _get_signal_listener_count("credits") == 0:
		var main := get_tree().root.get_node_or_null("Main")
		if not main:
			main = get_tree().root.find_child("Main", true, false)
		if main and main.has_method("show_credits_roll_from_menu"):
			main.call("show_credits_roll_from_menu")
		else:
			_open_standalone_credits_roll()

func _open_standalone_credits_roll() -> void:
	if _standalone_credits_screen and is_instance_valid(_standalone_credits_screen):
		if _standalone_credits_screen.has_method("start_credits_roll"):
			_standalone_credits_screen.call("start_credits_roll", false)
			return
	var credits_scene_path := "res://scenes/UI/EndingScreen.tscn"
	if not ResourceLoader.exists(credits_scene_path):
		push_warning("MainMenu: credits scene not found at %s" % credits_scene_path)
		return
	var credits_scene := load(credits_scene_path) as PackedScene
	if credits_scene == null:
		push_warning("MainMenu: credits scene failed to load")
		return
	_standalone_credits_screen = credits_scene.instantiate()
	if _standalone_credits_screen == null:
		push_warning("MainMenu: credits scene failed to instantiate")
		return
	_standalone_credits_screen.name = "StandaloneCreditsScreen"
	if _standalone_credits_screen.has_signal("credits_finished") and not _standalone_credits_screen.is_connected("credits_finished", Callable(self, "_on_standalone_credits_finished")):
		_standalone_credits_screen.connect("credits_finished", Callable(self, "_on_standalone_credits_finished"))
	add_child(_standalone_credits_screen)
	if _standalone_credits_screen.has_method("start_credits_roll"):
		_standalone_credits_screen.call("start_credits_roll", false)

func _on_standalone_credits_finished() -> void:
	if _standalone_credits_screen and is_instance_valid(_standalone_credits_screen):
		_standalone_credits_screen.queue_free()
		_standalone_credits_screen = null
	resume_after_credits()

func resume_after_credits() -> void:
	_credits_roll_active = false
	_set_buttons_enabled(true)
	if AudioManager and AudioManager.has_method("set_menu_music_locked"):
		AudioManager.set_menu_music_locked(true)
	if AudioManager and AudioManager.track_4:
		if AudioManager.has_method("crossfade_to"):
			AudioManager.crossfade_to(AudioManager.track_4, 1.0)
		elif AudioManager.has_method("play_music"):
			AudioManager.play_music(AudioManager.track_4)

func _on_standalone_load_file_selected(path: String) -> void:
	if main_scene_packed == null:
		push_warning("MainMenu: main scene not found at %s" % main_scene_path)
		return
	get_tree().set_meta("launch_load_game_path", path)
	get_tree().change_scene_to_packed(main_scene_packed)

func _on_settings_pressed() -> void:
	if not _can_accept_input():
		return
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("open_settings")
	if _get_signal_listener_count("open_settings") == 0:
		if has_node("StandaloneSettingsUI"):
			var existing = get_node("StandaloneSettingsUI")
			if existing and existing.has_method("toggle_menu"):
				existing.toggle_menu()
			return
		if ResourceLoader.exists(settings_scene_path):
			var settings = load(settings_scene_path).instantiate()
			settings.name = "StandaloneSettingsUI"
			if settings is CanvasLayer:
				settings.layer = 300
			add_child(settings)
			if settings.has_method("toggle_menu"):
				settings.toggle_menu()
		else:
			push_warning("MainMenu: settings scene not found at %s" % settings_scene_path)

func _on_exit_pressed() -> void:
	if not _can_accept_input():
		return
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("exit_game")
	if _get_signal_listener_count("exit_game") == 0:
		get_tree().quit()

func _get_signal_listener_count(signal_name: StringName) -> int:
	if not has_signal(signal_name):
		return 0
	return get_signal_connection_list(signal_name).size()