extends Control


# Emitted when credits roll completes
signal roll_finished

# Configurable scroll and file path
@export var scroll_speed: float = 50.0
@export var speed_multiplier: float = 5.0
@export var credits_path: String = "res://data/credits.txt"

# Node references inside the credits content panel
@onready var credits_content: Control = $CreditsContent
@onready var credits_column: VBoxContainer = $CreditsContent/CreditsColumn
@onready var credits_title: Panel = $CreditsContent/CreditsColumn/CreditsTitle
@onready var credits_text: RichTextLabel = $CreditsContent/CreditsColumn/CreditsText
@onready var speed_hint: Label = $SpeedHint


# Fallback and styling constants
const FALLBACK_CREDITS := "LOOK FOR THE LIGHT\n\nA Game By\nTeam03\n"
const TITLE_HEIGHT: float = 60.0

const COLOR_HEADER := "#a8f5c0"
const COLOR_SUBHEADER := "#f1f1f1"
const COLOR_NAME := "#cfe9ff"
const COLOR_ROLE := "#ffd6a6"
const COLOR_TASK := "#c3d0ff"

# Runtime scroll state
var _scrolling: bool = false
var _end_y: float = 0.0
var _hint_tween: Tween

# Initialize credits roll visibility and load text
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_credits_text()
	if speed_hint:
		speed_hint.visible = false
	if resized.is_connected(_on_resized) == false:
		resized.connect(_on_resized)

# Begin scrolling the credits
func start_roll() -> void:
	visible = true
	_scrolling = true
	call_deferred("_reset_scroll")

# Reset the roll and hide UI
func reset_roll() -> void:
	_scrolling = false
	_end_y = 0.0
	if visible:
		visible = false
	_stop_hint_fx()

# Scroll content each frame; accelerate while holding space
func _process(delta: float) -> void:
	if not _scrolling:
		return
	if not credits_content:
		return
	var speed := scroll_speed
	if Input.is_key_pressed(KEY_SPACE):
		speed *= speed_multiplier
	credits_content.position.y -= speed * delta
	if credits_content.position.y <= _end_y:
		_finish_roll()

# Recompute layout and begin hint tween
func _reset_scroll() -> void:
	_layout_text(true)
	_start_hint_fx()

# Layout text containers and defer final positioning
func _layout_text(reset_position: bool) -> void:
	if not credits_content:
		return
	var max_width := size.x * 0.75
	if max_width <= 0.0:
		return
	if credits_text:
		credits_text.bbcode_enabled = true
		credits_text.autowrap_mode = TextServer.AUTOWRAP_WORD
		credits_text.fit_content = true
		credits_text.custom_minimum_size = Vector2(max_width, 0.0)
	if credits_column:
		credits_column.custom_minimum_size = Vector2(max_width, 0.0)
	call_deferred("_finalize_layout", reset_position)

# Final layout step after content sizes are known
func _finalize_layout(reset_position: bool) -> void:
	await get_tree().process_frame
	var max_width := size.x * 0.75
	if credits_text:
		credits_text.custom_minimum_size = Vector2(max_width, 0.0)
		var text_height := float(credits_text.get_content_height())
		credits_text.custom_minimum_size = Vector2(max_width, text_height)
	if credits_column:
		var column_height := 0.0
		if credits_title:
			column_height += credits_title.get_combined_minimum_size().y
		if credits_title and credits_text:
			column_height += credits_column.get_theme_constant("separation")
		if credits_text:
			column_height += credits_text.custom_minimum_size.y
		credits_column.custom_minimum_size = Vector2(max_width, column_height)
		credits_column.size = credits_column.custom_minimum_size
	credits_content.size = credits_column.size
	var centered_x := (size.x - credits_content.size.x) * 0.5
	if reset_position:
		credits_content.position = Vector2(centered_x, size.y + 20.0)
	else:
		credits_content.position.x = centered_x
	_end_y = -credits_content.size.y - 20.0

# Load credits from disk or use fallback text
func _load_credits_text() -> void:
	var text := FALLBACK_CREDITS
	if FileAccess.file_exists(credits_path):
		var file := FileAccess.open(credits_path, FileAccess.READ)
		if file:
			text = file.get_as_text()
			file.close()
	if credits_text:
		credits_text.bbcode_text = _to_bbcode(text.strip_edges())
		credits_text.visible = true

# Stop scrolling and emit completion signal
func _finish_roll() -> void:
	_scrolling = false
	if speed_hint:
		speed_hint.visible = false
	_stop_hint_fx()
	roll_finished.emit()

# Start hint tween for the speed hint label
func _start_hint_fx() -> void:
	if not speed_hint:
		return
	_stop_hint_fx()
	speed_hint.visible = true
	speed_hint.modulate.a = 0.2
	_hint_tween = create_tween()
	_hint_tween.set_loops(-1)
	_hint_tween.tween_property(speed_hint, "modulate:a", 1.0, 0.6)
	_hint_tween.tween_property(speed_hint, "modulate:a", 0.2, 0.6)

# Stop hint tween and reset alpha
func _stop_hint_fx() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	if speed_hint:
		speed_hint.modulate.a = 1.0

# Re-layout when parent control resizes
func _on_resized() -> void:
	if not visible:
		return
	_layout_text(false)

# Convert plain credits text to styled BBCode for display
func _to_bbcode(raw_text: String) -> String:
	var lines := raw_text.split("\n")
	var output: Array[String] = []
	var last_was_section := false
	var last_was_name := false
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty():
			output.append("")
			last_was_section = false
			last_was_name = false
			continue
		if line == "[LOOK FOR THE LIGHT]":
			last_was_section = false
			last_was_name = false
			continue
		if line == "---":
			output.append("")
			last_was_section = false
			last_was_name = false
			continue
		if _is_section_header(line):
			output.append(_style_line(line, COLOR_HEADER, 26))
			last_was_section = true
			last_was_name = false
			continue
		if _is_subheader(line):
			output.append(_style_line(line, COLOR_SUBHEADER, 24))
			last_was_section = false
			last_was_name = false
			continue
		var next_line := ""
		if i + 1 < lines.size():
			next_line = lines[i + 1].strip_edges()
		if last_was_name and _looks_like_role(line):
			output.append(_style_line(line, COLOR_ROLE, 22))
			last_was_name = false
			last_was_section = false
			continue
		if (last_was_section or _looks_like_role(next_line)) and _is_name_line(line):
			output.append(_style_line(line, COLOR_NAME, 24))
			last_was_name = true
			last_was_section = false
			continue
		if _is_task_header(line):
			output.append(_style_line(line, COLOR_TASK, 22))
			last_was_name = false
			last_was_section = false
			continue
		output.append(_escape_bbcode(line))
		last_was_name = false
		last_was_section = false
	return "\n".join(output)

# Wrap a line in BBCode color and font size
func _style_line(text: String, color: String, font_size: int) -> String:
	var safe_text := _escape_bbcode(text)
	return "[color=%s][font_size=%d]%s[/font_size][/color]" % [color, font_size, safe_text]

# Escape literal BBCode brackets
func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

# Heuristics to detect subheader lines
func _is_subheader(line: String) -> bool:
	return line == "A Game By" or line == "Team03"

# Heuristics to detect large section headers
func _is_section_header(line: String) -> bool:
	if line.find("👨") != -1 or line.find("🧪") != -1 or line.find("🎨") != -1 or line.find("🛠") != -1 or line.find("🙏") != -1:
		return true
	var upper := line.to_upper()
	if line == upper and line.length() >= 6:
		return true
	if line.find("TOOLS & TECHNOLOGY") != -1:
		return true
	if line.find("SPECIAL THANKS") != -1:
		return true
	return false

# Heuristics to detect role/occupation lines
func _looks_like_role(line: String) -> bool:
	var role_keywords := ["Developer", "Programmer", "Director", "Designer", "Artist", "Lead", "Producer", "Writer"]
	for keyword in role_keywords:
		if line.find(keyword) != -1:
			return true
	return false

# Heuristics to detect name lines (person names)
func _is_name_line(line: String) -> bool:
	if _looks_like_role(line):
		return false
	if line.find(":") != -1:
		return false
	if line == line.to_upper():
		return false
	var parts := line.split(" ", false)
	return parts.size() >= 2

# Heuristics to detect short task/role headers
func _is_task_header(line: String) -> bool:
	if _looks_like_role(line) or _is_section_header(line) or _is_subheader(line):
		return false
	if line.find(":") != -1:
		return false
	var parts := line.split(" ", false)
	if parts.size() < 2 or parts.size() > 6:
		return false
	return _is_title_case(line)

# Check whether each word starts with an uppercase letter
func _is_title_case(line: String) -> bool:
	var parts := line.split(" ", false)
	for part in parts:
		var trimmed := part.replace("&", "").replace("/", "").replace("-", "").strip_edges()
		if trimmed.is_empty():
			continue
		var first := trimmed.substr(0, 1)
		if first != first.to_upper():
			return false
	return true
