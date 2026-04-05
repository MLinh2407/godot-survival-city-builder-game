class_name UI_Button
extends Button

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)

func _on_mouse_entered() -> void:
	if AudioManager:
		AudioManager.play_ui_sfx("hover")

func _on_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sfx("click")
