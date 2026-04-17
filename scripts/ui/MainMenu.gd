extends Control

signal start_new_game
signal load_game
signal open_settings
signal exit_game

@onready var live_bg: TextureRect = $LiveBackground
@onready var live_bg_node2d: Node2D = $LiveBackgroundNode2D

@onready var title_rect: TextureRect = $LeftColumn/VBox/Title
@onready var btn_new: TextureButton = $LeftColumn/VBox/Buttons/NewGame
@onready var btn_load: TextureButton = $LeftColumn/VBox/Buttons/LoadGame
@onready var btn_settings: TextureButton = $LeftColumn/VBox/Buttons/Settings
@onready var btn_exit: TextureButton = $LeftColumn/VBox/Buttons/Exit
var _buttons: Array[TextureButton] = []
var _button_tweens: Dictionary = {}
var _button_blurs: Dictionary = {}
var _standalone_load_dialog: FileDialog
var _blur_shader: Shader

var settings_scene_path: String = "res://scenes/main/SettingsUI.tscn"
var main_scene_path: String = "res://scenes/main/Main.tscn"
var main_scene_packed: PackedScene = preload("res://scenes/main/Main.tscn")

func _ready() -> void:
	randomize()
	_connect_buttons()
	_setup_standalone_load_dialog()
	_setup_background()
	btn_new.grab_focus()
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

	_buttons = [btn_new, btn_load, btn_settings, btn_exit]
	for b in _buttons:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.pivot_offset = b.size * 0.5
			_get_or_create_button_blur(b)
			if b.texture_normal:
				b.texture_hover = b.texture_normal
				b.texture_pressed = b.texture_normal

	_setup_title_blur()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _input(_event: InputEvent) -> void:
	pass

func _connect_buttons() -> void:
	if btn_new:
		btn_new.pressed.connect(Callable(self, "_on_new_game_pressed"))
		btn_new.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("NewGame", btn_new))
		btn_new.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("NewGame", btn_new))
	if btn_load:
		btn_load.pressed.connect(Callable(self, "_on_load_game_pressed"))
		btn_load.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("LoadGame", btn_load))
		btn_load.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("LoadGame", btn_load))
	if btn_settings:
		btn_settings.pressed.connect(Callable(self, "_on_settings_pressed"))
		btn_settings.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("Settings", btn_settings))
		btn_settings.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("Settings", btn_settings))
	if btn_exit:
		btn_exit.pressed.connect(Callable(self, "_on_exit_pressed"))
		btn_exit.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind("Exit", btn_exit))
		btn_exit.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind("Exit", btn_exit))

func _on_button_mouse_entered(button_id: String, button: TextureButton) -> void:
	_animate_button_hover(button, true)
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("hover")

func _on_button_mouse_exited(button_id: String, button: TextureButton) -> void:
	_animate_button_hover(button, false)

func _animate_button_hover(button: TextureButton, is_hovered: bool) -> void:
	if button == null:
		return
	var tween_key: String = str(button.get_instance_id())
	if _button_tweens.has(tween_key):
		var old_tween: Tween = _button_tweens[tween_key]
		if old_tween:
			old_tween.kill()

	var target_scale: Vector2 = Vector2.ONE
	var target_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
	var target_blur_alpha: float = 0.42
	if is_hovered:
		target_scale = Vector2(1.04, 1.04)
		target_modulate = Color(1.0, 0.97, 0.9, 1.0)
		target_blur_alpha = 0.66

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)
	tween.parallel().tween_property(button, "modulate", target_modulate, 0.12)
	var blur := _get_or_create_button_blur(button)
	if blur:
		tween.parallel().tween_property(blur, "modulate:a", target_blur_alpha, 0.12)
	_button_tweens[tween_key] = tween

func _get_or_create_button_blur(button: TextureButton) -> TextureRect:
	if button == null:
		return null
	var key := str(button.get_instance_id())
	if _button_blurs.has(key):
		return _button_blurs[key]

	if button.texture_normal == null:
		return null

	var blur := TextureRect.new()
	blur.name = "BlurSilhouette"
	blur.texture = button.texture_normal
	blur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blur.anchor_left = 0.0
	blur.anchor_top = 0.0
	blur.anchor_right = 1.0
	blur.anchor_bottom = 1.0
	blur.offset_left = -16.0
	blur.offset_top = -10.0
	blur.offset_right = 16.0
	blur.offset_bottom = 10.0
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.material = _make_blur_material()
	blur.modulate = Color(1.0, 1.0, 1.0, 0.42)
	blur.z_index = -1
	button.add_child(blur)
	button.move_child(blur, 0)
	_button_blurs[key] = blur
	return blur

func _setup_title_blur() -> void:
	if title_rect == null:
		return
	if title_rect.has_node("TitleBlur"):
		return
	if title_rect.texture == null:
		return

	var blur := TextureRect.new()
	blur.name = "TitleBlur"
	blur.texture = title_rect.texture
	blur.stretch_mode = title_rect.stretch_mode
	blur.anchor_left = 0.0
	blur.anchor_top = 0.0
	blur.anchor_right = 1.0
	blur.anchor_bottom = 1.0
	blur.offset_left = -18.0
	blur.offset_top = -12.0
	blur.offset_right = 18.0
	blur.offset_bottom = 12.0
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.material = _make_blur_material(2.0, Color(0.6, 0.9, 1.0, 0.95))
	blur.modulate = Color(1.0, 1.0, 1.0, 0.58)
	blur.z_index = -1
	title_rect.add_child(blur)
	title_rect.move_child(blur, 0)

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

func _on_load_game_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("load_game")
	if _get_signal_listener_count("load_game") == 0:
		if _standalone_load_dialog:
			if not DirAccess.dir_exists_absolute("user://saves"):
				DirAccess.make_dir_absolute("user://saves")
			_standalone_load_dialog.current_dir = "user://saves"
			_standalone_load_dialog.popup_centered()
		else:
			push_warning("MainMenu: standalone load dialog is unavailable")

func _on_standalone_load_file_selected(path: String) -> void:
	if main_scene_packed == null:
		push_warning("MainMenu: main scene not found at %s" % main_scene_path)
		return
	get_tree().set_meta("launch_load_game_path", path)
	get_tree().change_scene_to_packed(main_scene_packed)

func _on_settings_pressed() -> void:
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
	if AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("click")
	emit_signal("exit_game")
	if _get_signal_listener_count("exit_game") == 0:
		get_tree().quit()

func _get_signal_listener_count(signal_name: StringName) -> int:
	if not has_signal(signal_name):
		return 0
	return get_signal_connection_list(signal_name).size()