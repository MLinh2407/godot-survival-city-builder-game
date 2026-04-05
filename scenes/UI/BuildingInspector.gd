extends PanelContainer

# ══════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ══════════════════════════════════════════════════════════════════════════════
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var worker_label: Label = $VBoxContainer/WorkerLabel
@onready var output_label: Label = $VBoxContainer/OutputLabel

@export var building_system: Node 

# We track the currently selected building so we can disconnect signals when we click away
var current_building: BuildingData = null

func _ready() -> void:
    # Hide the panel by default
    visible = false
    modulate.a = 0.0 # Make it totally transparent for our fade-in effect
    
    if building_system:
        building_system.building_selected_data.connect(_on_building_selected)
    else:
        push_error("BuildingInspector: BuildingSystem is not assigned in the Inspector!")

# ══════════════════════════════════════════════════════════════════════════════
# SELECTION HANDLING
# ══════════════════════════════════════════════════════════════════════════════
func _on_building_selected(b_data: BuildingData) -> void:
    # 1. Disconnect from the old building if we were looking at one
    if current_building != null and current_building.staffing_changed.is_connected(_on_staffing_changed):
        current_building.staffing_changed.disconnect(_on_staffing_changed)
        
    current_building = b_data
    
    # 2. If we clicked the dirt (deselected), hide the UI
    if current_building == null:
        _hide_panel()
        return
        
    # 3. We clicked a real building! Connect to its specific data signal
    current_building.staffing_changed.connect(_on_staffing_changed)
    
    # 4. Update the text and show the panel
    _refresh_ui_text()
    _show_panel()

# Triggered exactly when you press + or - on the active building
func _on_staffing_changed(_current: int, _capacity: int) -> void:
    _refresh_ui_text()

# ══════════════════════════════════════════════════════════════════════════════
# TEXT FORMATTING
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_ui_text() -> void:
    if current_building == null: return
    
    title_label.text = current_building.building_name
    
    # Format the Worker text
    if current_building.worker_capacity > 0:
        worker_label.text = "Workers: " + str(current_building.workers_assigned) + " / " + str(current_building.worker_capacity)
    else:
        worker_label.text = "Workers: Automated (Passive)"
        
    # Format the Output text using the helper function we wrote in Week 5!
    var output = building_system.get_effective_output(current_building.grid_position)
    
    var output_text = "Daily Output:\n"
    if output.power != 0: output_text += "⚡ Power: " + str(output.power) + " kW\n"
    if output.food != 0:  output_text += "🍲 Food: " + str(output.food) + " rations\n"
    if output.morale != 0: output_text += "😊 Morale: +" + str(output.morale) + "\n"
    
    # If it produces nothing (like a passive building with no output), just say Active
    if output.power == 0 and output.food == 0 and output.morale == 0:
        output_text += "Status: Active"
        
    output_label.text = output_text

# ══════════════════════════════════════════════════════════════════════════════
# UX JUICE (Animations)
# ══════════════════════════════════════════════════════════════════════════════
func _show_panel() -> void:
    visible = true
    # A tiny Tween makes the UI fade in smoothly instead of snapping aggressively
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _hide_panel() -> void:
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.15)
    tween.tween_callback(func(): visible = false) # Hide it fully after the fade finishes