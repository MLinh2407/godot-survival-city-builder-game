# Lightweight Button subclass that plays UI SFX on hover/press
class_name UI_Button
extends Button

# Wire button signals so hover and click feedback play through AudioManager.
func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)

# Play the hover sound when the pointer enters the button.
func _on_mouse_entered() -> void:
	if AudioManager:
		AudioManager.play_ui_sfx("hover")

# Play the click sound when the button is pressed.
func _on_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sfx("click")
