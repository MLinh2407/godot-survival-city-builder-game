extends Node

@onready var day_label: Label = $UILayer/HUD/DayLabel
@onready var time_label: Label = $UILayer/HUD/TimeLabel
@onready var speed_label: Label = $UILayer/HUD/SpeedLabel

@onready var btn_pause: Button = $UILayer/HUD/SpeedControls/ButtonPause
@onready var btn_1x: Button = $UILayer/HUD/SpeedControls/Button1x
@onready var btn_2x: Button = $UILayer/HUD/SpeedControls/Button2x
@onready var btn_settings: Button = $UILayer/HUD/ButtonSettings
@onready var btn_journal: Button = $UILayer/HUD/ButtonJournal
@onready var colony_journal: CanvasLayer = $UILayer/ColonyJournal
@onready var journal_unread_badge: Panel = $UILayer/HUD/ButtonJournal/JournalUnreadBadge
@onready var journal_unread_badge_text: Label = $UILayer/HUD/ButtonJournal/JournalUnreadBadge/BadgeText
@onready var journal_write_prompt: Control = $UILayer/HUD/JournalWritePrompt
@onready var journal_prompt_text: Label = $UILayer/HUD/JournalWritePrompt/PromptText
@onready var journal_prompt_gif: AnimatedSprite2D = $UILayer/HUD/JournalWritePrompt/PromptWritingGif

@onready var power_label: Label = $UILayer/HUD/PowerLabel
@onready var food_label: Label = $UILayer/HUD/FoodLabel
@onready var morale_label: Label = $UILayer/HUD/MoraleLabel
@onready var power_bar: ProgressBar = $UILayer/HUD/PowerBar
@onready var food_bar: ProgressBar = $UILayer/HUD/FoodBar
@onready var morale_bar: ProgressBar = $UILayer/HUD/MoraleBar
@onready var pop_label: Label = $UILayer/HUD/PopulationLabel
@onready var workers_label: Label = $UILayer/HUD/WorkersLabel
@onready var materials_label: Label = $UILayer/HUD/MaterialsLabel
@onready var power_rate_lbl: Label = $UILayer/HUD/PowerRateLabel
@onready var food_rate_lbl: Label = $UILayer/HUD/FoodRateLabel
@onready var morale_rate_lbl: Label = $UILayer/HUD/MoraleRateLabel
@onready var storm_countdown_label: Label = $UILayer/HUD/StormCountdownLabel
@onready var hope_slider: HSlider = $UILayer/HUD/HopeOrderSlider
@onready var hope_label: Label = $UILayer/HUD/HopeLabel
@onready var order_label: Label = $UILayer/HUD/OrderLabel
@onready var hope_track_border: Panel = $UILayer/HUD/HopeOrderTrackBorder
@onready var hope_track_fill: ColorRect = $UILayer/HUD/HopeOrderTrackFill
@onready var top_strip_panel: Panel = $UILayer/HUD/TopStripPanel
@onready var top_strip_glow: ColorRect = $UILayer/HUD/TopStripGlow
@onready var top_sweep_line: ColorRect = $UILayer/HUD/TopSweepLine
@onready var dialogue_engine = $Events/DialogueEngine
@onready var disease_label: Label = $UILayer/HUD/DiseaseLabel
@onready var _camera: Camera2D = $GameWorld/Camera2D  

@export var use_journal_unread_count: bool = true
@export var journal_prompt_gif_path: String = "res://assets/ui/hud/gifs/writing_gif.gif"

var was_power_critical: bool = false
var was_food_critical: bool = false
var was_morale_critical: bool = false
var hud_fx_t: float = 0.0
var _last_hope_order_value: float = -1.0
const HOPE_COLOR := Color(0.62, 1.0, 0.78, 1.0)
const ORDER_COLOR := Color(0.94, 0.74, 1.0, 1.0)

var _ration_buffer_bar: ProgressBar = null
var settings_ui: CanvasLayer
var _journal_prompt_serial: int = 0
var _last_journal_prompt_msec: int = -10000
var _journal_badge_tween: Tween
var _journal_prompt_dot_timer: float = 0.0
var _journal_prompt_dot_count: int = 1
var _power_bar_tween: Tween
var _food_bar_tween: Tween
var _morale_bar_tween: Tween
var _hope_slider_tween: Tween

const UI_BAR_TWEEN_DURATION: float = 0.6
const UI_SLIDER_TWEEN_DURATION: float = 0.45
const JOURNAL_PROMPT_DURATION_SEC: float = 3.2
const JOURNAL_PROMPT_BURST_WINDOW_MSEC: int = 1400
const JOURNAL_PROMPT_DOT_INTERVAL_SEC: float = 0.30
const JOURNAL_PROMPT_BASE_TEXT: String = "The pages feel heavier"

# ── Zoom configuration ───────────────────────────────────────────────────────
const ZOOM_STEPS:     Array[float] = [0.75, 1.0, 1.5, 2.0, 3.0]
const ZOOM_DEFAULT:   int          = 1    
const ZOOM_LERP_SPEED: float       = 10.0  

var _zoom_index:  int   = ZOOM_DEFAULT
var _zoom_target: float = ZOOM_STEPS[ZOOM_DEFAULT]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	settings_ui = preload("res://scenes/main/SettingsUI.tscn").instantiate()
	add_child(settings_ui)
	
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.speed_changed.connect(_on_time_speed_changed)
	ResourceManager.resources_changed.connect(_on_resources_changed)
	PopulationManager.population_changed.connect(_on_population_changed)
	GameManager.hope_order_changed.connect(_on_hope_order_changed)
	
	if day_label:
		day_label.text = "DAY " + str(TimeManager.current_day)
	_update_hope_order_visuals()
	
	# Connect buttons
	if btn_pause: btn_pause.pressed.connect(toggle_pause)
	if btn_1x: btn_1x.pressed.connect(_on_button_1x_pressed)
	if btn_2x: btn_2x.pressed.connect(_on_button_2x_pressed)
	if btn_settings:
		btn_settings.focus_mode = Control.FOCUS_NONE
		if btn_settings.has_signal("gui_input"):
			btn_settings.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_button_settings_pressed()
			)
	if btn_journal and colony_journal:
		btn_journal.focus_mode = Control.FOCUS_NONE
		if btn_journal.has_signal("gui_input"):
			btn_journal.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					colony_journal.toggle()
			)

	if colony_journal and colony_journal.has_signal("unread_state_changed"):
		colony_journal.unread_state_changed.connect(_on_journal_unread_state_changed)
	if colony_journal and colony_journal.has_signal("journal_new_entry_notified"):
		colony_journal.journal_new_entry_notified.connect(_on_journal_new_entry_notified)
	if colony_journal and colony_journal.has_signal("journal_opened"):
		colony_journal.journal_opened.connect(_on_journal_opened)

	if journal_write_prompt:
		journal_write_prompt.visible = false
	if journal_prompt_text:
		journal_prompt_text.text = JOURNAL_PROMPT_BASE_TEXT + "."
	if journal_prompt_gif:
		if ResourceLoader.exists(journal_prompt_gif_path):
			var gif_resource := load(journal_prompt_gif_path)
			if gif_resource is SpriteFrames:
				journal_prompt_gif.sprite_frames = gif_resource
				var anim_names: PackedStringArray = journal_prompt_gif.sprite_frames.get_animation_names()
				if not anim_names.is_empty():
					journal_prompt_gif.animation = anim_names[0]
				journal_prompt_gif.visible = true
				journal_prompt_gif.play()
			else:
				journal_prompt_gif.visible = false
				push_warning("Main: expected SpriteFrames for gif path %s" % journal_prompt_gif_path)
		else:
			journal_prompt_gif.visible = false
			push_warning("Main: journal prompt gif not found at %s" % journal_prompt_gif_path)

	if colony_journal and colony_journal.has_method("has_unread_entries"):
		_on_journal_unread_state_changed(colony_journal.has_unread_entries())
	else:
		_on_journal_unread_state_changed(false)
	
	set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
	
	# init labels manually in case signal fires before Main is fully ready
	if power_label and food_label and morale_label:
		_on_resources_changed(ResourceManager.net_power, ResourceManager.food, ResourceManager.morale, ResourceManager.materials)
	_on_population_changed()
	_on_hope_order_changed(GameManager.hope_order_slider)

	if has_node("BuildingSystem"):
		var bs = $BuildingSystem
		if not bs.workers_changed.is_connected(_on_population_changed):
			bs.workers_changed.connect(_on_population_changed)
	
	# Build the Ration Store buffer extension bar programmatically
	if food_bar:
		_ration_buffer_bar = ProgressBar.new()
		_ration_buffer_bar.show_percentage = false
		_ration_buffer_bar.min_value = 0.0
		_ration_buffer_bar.max_value = 100.0
		_ration_buffer_bar.value = 0.0
		_ration_buffer_bar.custom_minimum_size = Vector2(40, food_bar.size.y if food_bar.size.y > 0 else 12.0)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.35, 0.38, 0.85)
		_ration_buffer_bar.add_theme_stylebox_override("fill", style)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.05, 0.05, 0.08, 0.6)
		_ration_buffer_bar.add_theme_stylebox_override("background", bg_style)
		food_bar.get_parent().add_child(_ration_buffer_bar)
		_ration_buffer_bar.visible = false

	# TEMP VERIFICATION — remove after confirming
	# GameManager.hope_order_slider = 90.0
	# print("TEST: Slider forced to 90 — expect Order zone modifiers in next day tick")

func _on_population_changed() -> void:
	var p = GameManager.population_state
	if pop_label and p:
		pop_label.text = str(p.total_population)
	if workers_label and p:
		workers_label.text = str(p.available_workers)
	if disease_label and p:
		var sick = p.sick_count
		disease_label.text = str(sick)
		if sick > 0:
			disease_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
		else:
			disease_label.remove_theme_color_override("font_color")

func _zoom_step(direction: int) -> void:
	var mouse_world_before: Vector2 = _camera.get_global_transform().affine_inverse() \
									 * get_viewport().get_mouse_position()
	_zoom_index  = clampi(_zoom_index + direction, 0, ZOOM_STEPS.size() - 1)
	_zoom_target = ZOOM_STEPS[_zoom_index]
	var mouse_world_after: Vector2 = _camera.get_global_transform().affine_inverse() \
									* get_viewport().get_mouse_position()
	_camera.position += mouse_world_before - mouse_world_after

func _process(delta: float) -> void:
	_update_camera_zoom(delta)
	_sync_hope_order_visuals()
	_update_journal_prompt_dots(delta)
	_refresh_hope_order_visuals()
	if get_tree() and get_tree().paused:
		return

	hud_fx_t += delta

	if top_strip_glow:
		var glow_alpha: float = 0.28 + 0.32 * (0.5 + 0.5 * sin(hud_fx_t * 2.8))
		top_strip_glow.color = Color(0.42, 0.98, 1.0, glow_alpha)
	if top_sweep_line:
		var beam_width: float = 72.0
		var left_margin: float = 8.0
		var right_margin: float = 8.0
		var start_x: float = 250.0
		var end_x: float = 810.0

		if top_strip_panel:
			start_x = top_strip_panel.offset_left + left_margin
			end_x = top_strip_panel.offset_right - right_margin - beam_width

		if end_x < start_x:
			end_x = start_x

		var range_x: float = maxf(end_x - start_x, 1.0)
		var cycle: float = fmod(hud_fx_t * 280.0, range_x)
		top_sweep_line.offset_left = start_x + cycle
		top_sweep_line.offset_right = top_sweep_line.offset_left + beam_width
		var sweep_alpha: float = 0.26 + 0.46 * (0.5 + 0.5 * sin(hud_fx_t * 5.2))
		top_sweep_line.color = Color(0.58, 1.0, 1.0, sweep_alpha)

func _update_camera_zoom(delta: float) -> void:
	if not _camera:
		return
	var current: float = _camera.zoom.x
	if abs(current - _zoom_target) > 0.001:
		var next_zoom: float = lerpf(current, _zoom_target, ZOOM_LERP_SPEED * delta)
		_camera.zoom = Vector2(next_zoom, next_zoom)
	else:
		_camera.zoom = Vector2(_zoom_target, _zoom_target)

func _update_rates() -> void:
	if power_rate_lbl:
		var power_rate = ResourceManager.power_capacity - ResourceManager.power_draw
		var power_rate_i: int = int(round(power_rate))
		if power_rate_i >= 0:
			power_rate_lbl.text = "+" + str(power_rate_i) + "/day"
		else:
			power_rate_lbl.text = str(power_rate_i) + "/day"
		_set_rate_color(power_rate_lbl, power_rate)

	if food_rate_lbl:
		var food_rate = GameManager.resource_food.net_rate
		if CrisisEventSystem:
			food_rate += CrisisEventSystem.active_food_delta
		var food_rate_i: int = int(round(food_rate))
		if food_rate_i >= 0:
			food_rate_lbl.text = "+" + str(food_rate_i) + "/day"
		else:
			food_rate_lbl.text = str(food_rate_i) + "/day"
		_set_rate_color(food_rate_lbl, food_rate)

	if morale_rate_lbl:
		var morale_rate = GameManager.resource_morale.net_rate
		var morale_rate_i: int = int(round(morale_rate))
		if morale_rate_i >= 0:
			morale_rate_lbl.text = "+" + str(morale_rate_i) + "/day"
		else:
			morale_rate_lbl.text = str(morale_rate_i) + "/day"
		_set_rate_color(morale_rate_lbl, morale_rate)

func _set_rate_color(rate_label: Label, value: float) -> void:
	if value > 0.0:
		rate_label.add_theme_color_override("font_color", Color(0.58, 0.93, 0.64))
	elif value < 0.0:
		rate_label.add_theme_color_override("font_color", Color(1.0, 0.54, 0.54))
	else:
		rate_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))

func toggle_pause() -> void:
	if TimeManager.current_speed == TimeManager.GameSpeed.PAUSED:
		get_tree().paused = false
		set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
	else:
		get_tree().paused = true
		TimeManager.set_game_speed(TimeManager.GameSpeed.PAUSED)
		if btn_pause:
			btn_pause.text = "Resume"
		if speed_label:
			speed_label.text = "PAUSED"

func set_speed(speed: int, text: String) -> void:
	TimeManager.set_game_speed(speed)
	get_tree().paused = false
	if btn_pause:
		btn_pause.text = "Pause"
	if speed_label:
		speed_label.text = text

func _on_button_1x_pressed() -> void:
	set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")

func _on_button_2x_pressed() -> void:
	set_speed(TimeManager.GameSpeed.FAST, "SPEED 2x")

func _on_button_settings_pressed() -> void:
	if settings_ui and settings_ui.has_method("toggle_menu"):
		settings_ui.toggle_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: toggle_pause()
			KEY_1:     set_speed(TimeManager.GameSpeed.NORMAL, "SPEED 1x")
			KEY_2:     set_speed(TimeManager.GameSpeed.FAST,   "SPEED 2x")
			KEY_J:	   colony_journal.toggle()
			
			# Keyboard zoom shortcuts 
			KEY_EQUAL, KEY_KP_ADD:      _zoom_step(+1)   # '+'  key zooms in
			KEY_MINUS, KEY_KP_SUBTRACT: _zoom_step(-1)   # '-'  key zooms out

	# ── mouse-wheel zoom ──
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:   _zoom_step(+1)
			MOUSE_BUTTON_WHEEL_DOWN: _zoom_step(-1)

func _on_day_changed(new_day: int) -> void:
	if day_label:
		day_label.text = "DAY " + str(new_day)
	_update_storm_countdown(new_day)

func _update_storm_countdown(current_day: int) -> void:
	if not storm_countdown_label:
		return
	if current_day >= GameConstants.STORM_START_DAY and current_day < GameConstants.STORM_HIT_DAY:
		var days_remaining: int = GameConstants.STORM_HIT_DAY - current_day
		storm_countdown_label.text = "⚡ STORM IN " + str(days_remaining) + " DAYS"
		storm_countdown_label.visible = true
		# Pulse red as deadline approaches
		if days_remaining <= 3:
			storm_countdown_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
		else:
			storm_countdown_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
	else:
		storm_countdown_label.visible = false

func _on_time_changed(time_string: String) -> void:
	if time_label:
		time_label.text = "| " + time_string

func _on_time_speed_changed(old_speed: int, new_speed: int) -> void:
	if TimeManager.current_day != 1:
		return
	if old_speed != TimeManager.GameSpeed.PAUSED:
		return
	if new_speed == TimeManager.GameSpeed.PAUSED:
		return
	if colony_journal and not colony_journal.first_unpause_happened:
		colony_journal.first_unpause_happened = true
		colony_journal.fire_day1_nudge()

func _on_resources_changed(p: float, f: float, m: float, _mat: int) -> void:
	if power_label:
		var power_i: int = int(round(p))
		var power_cap_i: int = maxi(int(round(ResourceManager.power_capacity)), 0)
		power_label.text = "POWER " + str(power_i) + "/" + str(power_cap_i)

	if power_bar:
		if ResourceManager.power_capacity > 0:
			var target_power_val = clamp((p / ResourceManager.power_capacity) * 100.0, 0.0, 100.0)
			if _power_bar_tween:
				_power_bar_tween.kill()
			_power_bar_tween = create_tween()
			_power_bar_tween.tween_property(power_bar, "value", target_power_val, UI_BAR_TWEEN_DURATION)
		else:
			if _power_bar_tween:
				_power_bar_tween.kill()
			_power_bar_tween = create_tween()
			_power_bar_tween.tween_property(power_bar, "value", 0.0, UI_BAR_TWEEN_DURATION)
		
		var power_is_critical = ResourceManager.power_capacity > 0 and ResourceManager.power_capacity < ResourceManager.power_draw
		var power_is_warning = ResourceManager.power_capacity > 0 and (p / ResourceManager.power_capacity) <= GameConstants.WARNING_THRESHOLD and not power_is_critical
		
		if power_is_critical:
			power_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_power_critical:
				AudioManager.play_critical_warning()
				was_power_critical = true
		elif power_is_warning:
			power_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_power_critical = false
		else:
			power_label.remove_theme_color_override("font_color")
			was_power_critical = false

	if food_label:
		var food_i: int = int(round(f))
		var max_food_i: int = maxi(int(round(ResourceManager.max_food)), 0)
		food_label.text = "FOOD " + str(food_i) + "/" + str(max_food_i)

	if food_bar:
		if ResourceManager.max_food > 0:
			var target_food_val = clamp((f / ResourceManager.max_food) * 100.0, 0.0, 100.0)
			if _food_bar_tween:
				_food_bar_tween.kill()
			_food_bar_tween = create_tween()
			_food_bar_tween.tween_property(food_bar, "value", target_food_val, UI_BAR_TWEEN_DURATION)
		else:
			if _food_bar_tween:
				_food_bar_tween.kill()
			_food_bar_tween = create_tween()
			_food_bar_tween.tween_property(food_bar, "value", 0.0, UI_BAR_TWEEN_DURATION)
		
		var food_ratio = 0.0
		if ResourceManager.max_food > 0:
			food_ratio = f / ResourceManager.max_food
			
		var food_is_critical = ResourceManager.max_food > 0 and food_ratio <= GameConstants.CRITICAL_THRESHOLD
		var food_is_warning = ResourceManager.max_food > 0 and food_ratio <= GameConstants.WARNING_THRESHOLD and not food_is_critical
		
		if food_is_critical:
			food_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_food_critical:
				AudioManager.play_critical_warning()
				was_food_critical = true
		elif food_is_warning:
			food_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_food_critical = false
		else:
			food_label.remove_theme_color_override("font_color")
			was_food_critical = false

	if morale_label:
		var morale_i: int = int(round(m))
		morale_label.text = "MORALE " + str(morale_i) + "/100"

	if morale_bar:
		var target_morale = clamp(m, 0.0, 100.0)
		if _morale_bar_tween:
			_morale_bar_tween.kill()
		_morale_bar_tween = create_tween()
		_morale_bar_tween.tween_property(morale_bar, "value", target_morale, UI_BAR_TWEEN_DURATION)
		
		var morale_ratio = m / 100.0
		var morale_is_critical = morale_ratio <= GameConstants.CRITICAL_THRESHOLD
		var morale_is_warning = morale_ratio <= GameConstants.WARNING_THRESHOLD and not morale_is_critical
		
		if morale_is_critical:
			morale_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_CRITICAL)
			if not was_morale_critical:
				AudioManager.play_critical_warning()
				was_morale_critical = true
		elif morale_is_warning:
			morale_label.add_theme_color_override("font_color", GameConstants.UI_COLOR_WARNING)
			was_morale_critical = false
		else:
			morale_label.remove_theme_color_override("font_color")
			was_morale_critical = false

	if materials_label:
		materials_label.text = str(_mat)

	if hope_slider:
		_update_hope_order_visuals()

	_update_rates()

	# Update Ration Store buffer bar
	if _ration_buffer_bar:
		var buf: float     = GameManager.resource_food.ration_store_buffer
		var buf_max: float = GameManager.resource_food.ration_store_max
		var bar_visible: bool = buf_max > 0.0

		_ration_buffer_bar.visible = bar_visible

		if bar_visible:
			_ration_buffer_bar.value = clamp((buf / buf_max) * 100.0, 0.0, 100.0)

			var fb_rect: Rect2 = food_bar.get_rect()
			_ration_buffer_bar.position = Vector2(
				food_bar.position.x + fb_rect.size.x + 3,
				food_bar.position.y
			)
			_ration_buffer_bar.custom_minimum_size = Vector2(40, fb_rect.size.y if fb_rect.size.y > 0 else 12.0)

			if GameManager.resource_food.auto_rationing_active:
				_ration_buffer_bar.modulate = Color(1.0, 0.7, 0.2, 1.0)
			else:
				_ration_buffer_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_hope_order_changed(new_value: float) -> void:
	_last_hope_order_value = new_value
	if hope_slider:
		_update_hope_order_visuals()
		AudioManager.play_ui_sfx("slider_move")

func _sync_hope_order_visuals() -> void:
	var current_value: float = GameManager.hope_order_slider
	if is_equal_approx(current_value, _last_hope_order_value):
		return
	_last_hope_order_value = current_value
	_update_hope_order_visuals()

func _update_hope_order_visuals() -> void:
	if not hope_slider:
		return

	var slider_value: float = clampf(GameManager.hope_order_slider, 0.0, 100.0)
	if _hope_slider_tween:
		_hope_slider_tween.kill()
	_hope_slider_tween = create_tween()
	_hope_slider_tween.tween_property(hope_slider, "value", slider_value, UI_SLIDER_TWEEN_DURATION)

	var hope_upper: float = GameConstants.SLIDER_HOPE_UPPER
	var order_lower: float = GameConstants.SLIDER_ORDER_LOWER

	# Color interpolation parameter (Hope / Order / Neutral)
	var t_color: float
	if slider_value <= hope_upper:
		t_color = 0.0
	elif slider_value >= order_lower:
		t_color = 1.0
	else:
		t_color = (slider_value - hope_upper) / maxf(order_lower - hope_upper, 1.0)

	# Color choice: neutral in middle band, otherwise explicit Hope/Order
	var NEUTRAL_COLOR: Color = Color(0.85, 0.85, 0.85, 1.0)
	var slider_color: Color
	if slider_value > hope_upper and slider_value < order_lower:
		slider_color = NEUTRAL_COLOR
	elif t_color <= 0.0:
		slider_color = HOPE_COLOR
	else:
		slider_color = ORDER_COLOR
	hope_slider.modulate = slider_color

	# Apply base modulate color for the slider control
	hope_slider.modulate = slider_color

	if hope_label:
		hope_label.add_theme_color_override("font_color", HOPE_COLOR)
	if order_label:
		order_label.add_theme_color_override("font_color", ORDER_COLOR)

func _refresh_hope_order_visuals() -> void:
	if not hope_slider:
		return
	var current = hope_slider.value
	var hope_upper: float = GameConstants.SLIDER_HOPE_UPPER
	var order_lower: float = GameConstants.SLIDER_ORDER_LOWER
	var t_color: float
	if current <= hope_upper:
		t_color = 0.0
	elif current >= order_lower:
		t_color = 1.0
	else:
		t_color = (current - hope_upper) / maxf(order_lower - hope_upper, 1.0)
	var slider_color: Color
	if current > hope_upper and current < order_lower:
		slider_color = Color(0.85, 0.85, 0.85, 1.0)
	elif t_color <= 0.0:
		slider_color = HOPE_COLOR
	else:
		slider_color = ORDER_COLOR
	if hope_track_border and hope_track_fill:
		var inset: float = 0
		var inner_left: float = hope_track_border.offset_left + inset
		var inner_right: float = hope_track_border.offset_right - inset
		var inner_top: float = hope_track_border.offset_top + inset
		var inner_bottom: float = hope_track_border.offset_bottom + inset
		var inner_width: float = maxf(inner_right - inner_left, 1.0)
		var fill_right: float = inner_left + inner_width * (current / 100.0)
		hope_track_fill.offset_left = inner_left
		hope_track_fill.offset_top = inner_top
		hope_track_fill.offset_right = fill_right
		hope_track_fill.offset_bottom = inner_bottom
		hope_track_fill.color = Color(slider_color.r, slider_color.g, slider_color.b, 0.95)
	hope_slider.modulate = slider_color

func _on_journal_unread_state_changed(is_unread: bool) -> void:
	if not journal_unread_badge:
		return
	if _journal_badge_tween:
		_journal_badge_tween.kill()
		_journal_badge_tween = null
	journal_unread_badge.visible = is_unread
	_update_journal_badge_text(is_unread)

	if is_unread:
		journal_unread_badge.modulate.a = 0.72
		_journal_badge_tween = create_tween()
		_journal_badge_tween.set_loops(-1)
		_journal_badge_tween.tween_property(journal_unread_badge, "modulate:a", 1.0, 0.55)
		_journal_badge_tween.tween_property(journal_unread_badge, "modulate:a", 0.72, 0.55)
	else:
		journal_unread_badge.modulate.a = 1.0

func _on_journal_new_entry_notified() -> void:
	print("Main: _on_journal_new_entry_notified() called")
	var now_msec: int = Time.get_ticks_msec()
	var in_burst: bool = (now_msec - _last_journal_prompt_msec) <= JOURNAL_PROMPT_BURST_WINDOW_MSEC
	_last_journal_prompt_msec = now_msec
	_update_journal_badge_text(true)

	if not journal_write_prompt:
		return

	if journal_write_prompt.visible and in_burst:
		_schedule_hide_journal_prompt()
		return

	_show_journal_prompt()

func _on_journal_opened() -> void:
	_hide_journal_prompt(true)

func _show_journal_prompt() -> void:
	if not journal_write_prompt:
		return

	_journal_prompt_dot_timer = 0.0
	_journal_prompt_dot_count = 1
	if journal_prompt_text:
		journal_prompt_text.text = JOURNAL_PROMPT_BASE_TEXT + "."
	if AudioManager:
		AudioManager.play_ui_sfx("sfx_ui_journal_entry")
	if journal_prompt_gif and journal_prompt_gif.sprite_frames:
		journal_prompt_gif.visible = true
		journal_prompt_gif.play()

	journal_write_prompt.visible = true
	journal_write_prompt.modulate.a = 0.0
	journal_write_prompt.scale = Vector2(0.96, 0.96)

	var tween := create_tween()
	tween.tween_property(journal_write_prompt, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(journal_write_prompt, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_schedule_hide_journal_prompt()

func _schedule_hide_journal_prompt() -> void:
	_journal_prompt_serial += 1
	var serial_now: int = _journal_prompt_serial
	await get_tree().create_timer(JOURNAL_PROMPT_DURATION_SEC).timeout
	if serial_now != _journal_prompt_serial:
		return
	_hide_journal_prompt(false)

func _hide_journal_prompt(immediate: bool) -> void:
	if not journal_write_prompt:
		return

	_journal_prompt_serial += 1
	if immediate:
		if journal_prompt_gif:
			journal_prompt_gif.stop()
		journal_write_prompt.visible = false
		journal_write_prompt.modulate.a = 1.0
		journal_write_prompt.scale = Vector2(1.0, 1.0)
		return

	var tween := create_tween()
	tween.tween_property(journal_write_prompt, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func():
		if journal_write_prompt:
			if journal_prompt_gif:
				journal_prompt_gif.stop()
			journal_write_prompt.visible = false
			journal_write_prompt.modulate.a = 1.0
			journal_write_prompt.scale = Vector2(1.0, 1.0)
)

func _update_journal_prompt_dots(delta: float) -> void:
	if not journal_write_prompt or not journal_prompt_text:
		return
	if not journal_write_prompt.visible:
		return

	_journal_prompt_dot_timer += delta
	if _journal_prompt_dot_timer < JOURNAL_PROMPT_DOT_INTERVAL_SEC:
		return

	_journal_prompt_dot_timer = 0.0
	_journal_prompt_dot_count += 1
	if _journal_prompt_dot_count > 3:
		_journal_prompt_dot_count = 1

	journal_prompt_text.text = JOURNAL_PROMPT_BASE_TEXT + ".".repeat(_journal_prompt_dot_count)

func _update_journal_badge_text(is_unread: bool) -> void:
	if not journal_unread_badge or not journal_unread_badge_text:
		return

	var display_text: String = "!"
	if not is_unread:
		display_text = "!"
	else:
		if not use_journal_unread_count:
			display_text = "!"
		else:
			var unread_count: int = 1
			if colony_journal and colony_journal.has_method("get_unread_count"):
				unread_count = int(colony_journal.get_unread_count())
			if unread_count > 99:
				display_text = "99+"
			else:
				display_text = str(unread_count)

	journal_unread_badge_text.text = display_text
	_resize_journal_badge(display_text)

func _resize_journal_badge(display_text: String) -> void:
	if not journal_unread_badge or not journal_unread_badge_text:
		return

	var bubble_width: float = 20.0
	if display_text.length() == 2:
		bubble_width = 24.0
	elif display_text.length() >= 3:
		bubble_width = 30.0

	var right_edge: float = 38.0
	journal_unread_badge.offset_left = right_edge - bubble_width
	journal_unread_badge.offset_right = right_edge
	journal_unread_badge.offset_top = -8.0
	journal_unread_badge.offset_bottom = 12.0

	journal_unread_badge_text.offset_left = 2.0
	journal_unread_badge_text.offset_top = 1.0
	journal_unread_badge_text.offset_right = bubble_width - 2.0
	journal_unread_badge_text.offset_bottom = 19.0

func notify_journal_entry() -> void:
	print("Main: notify_journal_entry() invoked")
	_on_journal_new_entry_notified()