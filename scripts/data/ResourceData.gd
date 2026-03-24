# Represents one of the three survival resources (Power, Food, Morale) and Materials

class_name ResourceData
extends Resource

# Identity
@export var res_name: String = ""       # "Power", "Food", "Morale", "Materials"
@export var display_unit: String = ""   # "kW", "rations", "", ""

# Current State
@export var current_value: float = 0.0
@export var max_value: float = 100.0    # Morale cap is 100. Power/Food scale with buildings.

# Daily flow
@export var production_rate: float = 0.0       # Total produced per game day
@export var consumption_rate: float = 0.0      # Total consumed per game day

# Net rate is computed on read 
var net_rate: float:
	get: return production_rate - consumption_rate

# HUD Display Flags
@export var show_as_bar: bool = true           # False for Materials (shown as counter)
@export var is_critical: bool = false          # True when current_value <= 0

# Ration Store buffer 
# The Food bar has a visible buffer extension for the Ration Store reserve.
@export var ration_store_buffer: float = 0.0     # 0 unless a Ration Store building exists
@export var ration_store_max: float = 0.0        # 50-day reserve cap (base), 100-day upgraded
@export var auto_rationing_active: bool = false  # Triggers when buffer < 20%
