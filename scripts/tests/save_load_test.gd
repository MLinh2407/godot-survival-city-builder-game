extends Node

func _ready() -> void:
    print("[TEST] Save/Load fired-events test starting")

    # Ensure autoloads exist
    if not (GameManager and CrisisEventSystem):
        push_error("[TEST] Missing required autoloads: GameManager or CrisisEventSystem")
        get_tree().quit()
        return

    # Ensure saves directory exists
    GameManager.ensure_saves_dir()

    var save_name := "test_autosave.json"
    var save_path := "user://saves/" + save_name

    # Prime CrisisEventSystem with a known fired-event
    var expected_event_key := "__test_event_persistence__"
    CrisisEventSystem.set_fired_events_state({expected_event_key: true})

    # Perform save
    GameManager.save_game(save_name)

    # Read raw file and assert the fired_events key was serialized
    var f = FileAccess.open(save_path, FileAccess.READ)
    if not f:
        push_error("[TEST] Failed to open saved file: %s" % save_path)
        get_tree().quit()
        return
    var content = f.get_as_text()
    f.close()

    var parsed = JSON.parse_string(content)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("[TEST] Saved file JSON is invalid")
        get_tree().quit()
        return

    var fired = parsed.get("fired_events", null)
    if typeof(fired) != TYPE_DICTIONARY or not fired.has(expected_event_key):
        push_error("[TEST] fired_events missing or did not contain expected key after save")
        get_tree().quit()
        return

    print("[TEST] Fired event present in save file — proceeding to load check")

    # Clear in-memory state and load the save
    CrisisEventSystem.set_fired_events_state({})
    await GameManager.load_game(save_path)

    var loaded_state = CrisisEventSystem.get_fired_events_state()
    if typeof(loaded_state) != TYPE_DICTIONARY or not loaded_state.has(expected_event_key):
        push_error("[TEST] After load, CrisisEventSystem missing expected fired-event key")
        get_tree().quit()
        return

    print("[TEST] Save/Load fired-events test PASSED")
    get_tree().quit()
