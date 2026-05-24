 # Test runner entrypoint used by the test scene runner
extends SceneTree

# Swap straight into the test scene so the runner can execute automatically.
func _initialize() -> void:
	change_scene_to_file("res://scenes/tests/TestRunner.tscn")
