extends Marker2D

# Tiny floating text used for feedback (e.g., +1 Worker)
@onready var label: Label = $Label

# Set text and tint color for the floating label
func setup(text_value: String, color: Color) -> void:
    label.text = text_value
    label.modulate = color

# Animate floating up and fade out, then free
func _ready() -> void:
    var tween = create_tween().set_parallel(true)
    
    tween.tween_property(self, "position:y", position.y - 80.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    
    tween.tween_property(self, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
    
    tween.chain().tween_callback(queue_free)