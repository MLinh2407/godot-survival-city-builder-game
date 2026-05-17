extends Node

# ── Constants ─────────────────────────────────────────────────────────────────
const CONFIG_PATH: String = "user://config.cfg"

# ── State ─────────────────────────────────────────────────────────────────────
var tutorial_enabled: bool = true
var shown_flags: Dictionary = {}  

# Coach mark queue — only one mark shows at a time
var _mark_queue: Array  = []
var _active_mark: Node  = null

# Connection tracking
var _scene_signals_connected: bool = false
var _intro_done: bool = false
var _first_building_placed: bool = false
var _first_inspector_opened: bool = false
var _first_build_menu_opened: bool = false
var _upgrade_nudge_done: bool = false

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()

	# Connect to Autoload signals immediately — these are always available
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.speed_changed.connect(_on_speed_changed)
	ResourceManager.resources_changed.connect(_on_resources_changed)
	PopulationManager.population_changed.connect(_on_population_changed)
	PopulationManager.outbreak_started.connect(_on_outbreak_started)
	GameManager.named_character_died.connect(_on_character_died)

	# Scene-specific signals are connected lazily
	call_deferred("_try_connect_scene_signals")

func reset_for_new_game() -> void:
	shown_flags.clear()
	_mark_queue.clear()
	_intro_done = false
	_first_building_placed = false
	_first_inspector_opened = false
	_first_build_menu_opened = false
	_upgrade_nudge_done = false
	_scene_signals_connected = false
	if _active_mark and is_instance_valid(_active_mark):
		_active_mark.queue_free()
		_active_mark = null
	call_deferred("_try_connect_scene_signals")

# ── Scene signal wiring ───────────────────────────────────────────────────────

func _try_connect_scene_signals() -> void:
	if _scene_signals_connected:
		return

	var grid = _get_node("Main/GameWorld/GridSystem")
	if not grid:
		return   

	# GridManager
	if not grid.building_placed.is_connected(_on_building_placed):
		grid.building_placed.connect(_on_building_placed)

	# BuildingSystem
	var bs = _get_node("Main/BuildingSystem")
	if bs and not bs.building_selected_data.is_connected(_on_building_selected):
		bs.building_selected_data.connect(_on_building_selected)

	# BuildMenu
	var bm = _get_node("Main/BuildMenu")
	if bm and not bm.build_menu_opened.is_connected(_on_build_menu_opened):
		bm.build_menu_opened.connect(_on_build_menu_opened)

	# DialogueEngine
	var de = _get_node("Main/Events/DialogueEngine")
	if de:
		if de.has_signal("choice_made") and not de.choice_made.is_connected(_on_choice_made):
			de.choice_made.connect(_on_choice_made)
		if de.has_signal("card_dismissed") and not de.card_dismissed.is_connected(_on_card_dismissed):
			de.card_dismissed.connect(_on_card_dismissed)

	_scene_signals_connected = true

# ═════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — each one checks conditions and fires the relevant beats
# ═════════════════════════════════════════════════════════════════════════════

# ── TimeManager.speed_changed ─────────────────────────────────────────────────
# Fires when the game unpauses. We use the FIRST real unpause after intro cards
# to show the HUD explanation marks (Phase 0).

func _on_speed_changed(old_speed: int, new_speed: int) -> void:
	if not tutorial_enabled:
		return
	if old_speed == TimeManager.GameSpeed.PAUSED \
			and new_speed != TimeManager.GameSpeed.PAUSED:
		if not _scene_signals_connected:
			_try_connect_scene_signals()

# ── DialogueEngine.card_dismissed ─────────────────────────────────────────────
# We use this to detect when both intro cards have finished.

func _on_card_dismissed() -> void:
	if not tutorial_enabled or _intro_done:
		return

	var de = _get_node("Main/Events/DialogueEngine")
	if de and de.has_method("is_intro_card_active") and de.is_intro_card_active():
		return   

	# Both intro cards are dismissed — Phase 0 fires now
	_intro_done = true
	await get_tree().create_timer(0.6, false, false, true).timeout
	_fire_phase_0()

# ── TimeManager.day_changed ───────────────────────────────────────────────────

func _on_day_changed(new_day: int) -> void:
	if not tutorial_enabled:
		return

	if not _scene_signals_connected:
		_try_connect_scene_signals()

	match new_day:
		2:   _beat_2_4_journal_nudge()          # Colony Journal introduction
		3:   _beat_3_1_after_cold_night()        # Post-crisis slider explanation
		8:   _beat_4_1_deserters_context()       # Deserters morale context
		16:  _beat_4_5_fever_context()           # Fever disease context
		21:  _beat_4_6_upgrade_nudge()           # Upgrade reminder
		26:  _beat_5_2_storm_warning()           # Storm countdown + shielding
		27:  _beat_5_5_priority_shielding()      # Which buildings to shield first
		30:  _beat_5_6_ending_calculation()      # What Day 35 calculates

	# Upgrade reminder check — fires once when player has enough materials
	if new_day >= 5 and not _has_shown("upgrade_nudge"):
		_beat_4_6_upgrade_nudge()

# ── ResourceManager.resources_changed ────────────────────────────────────────

func _on_resources_changed(_power: float, food: float, morale: float,
		_materials: int) -> void:
	if not tutorial_enabled:
		return

	# Phase 2.5 — Morale efficiency warning (first time morale drops below 40)
	if morale < 40.0 and not _has_shown("morale_efficiency_warning"):
		_beat_2_5_morale_efficiency(morale)

	# Phase 4.4 — Auto-rationing first activation
	if GameManager.resource_food.auto_rationing_active \
			and not _has_shown("auto_rationing_active"):
		_beat_4_4_auto_rationing()

	# Phase 6.1 — Power failure (net power negative)
	if ResourceManager.net_power < 0.0 and not _has_shown("power_failure_warning"):
		_beat_6_1_power_failure()

	# Phase 6.2 — Food at zero
	if food <= 0.0 and not _has_shown("food_zero_warning"):
		_beat_6_2_food_zero()

	# Phase 6.4 — Morale desertion threshold
	if morale < GameConstants.MORALE_DESERTION_THRESHOLD \
			and not _has_shown("morale_desertion_warning"):
		_beat_6_4_morale_desertion()

# ── PopulationManager.population_changed ─────────────────────────────────────

func _on_population_changed() -> void:
	if not tutorial_enabled:
		return

	# Phase 6.3 — Worker pool critically low
	var workers: int = GameManager.available_workers
	if workers <= 5 and workers > 0 and not _has_shown("workers_low_warning"):
		_beat_6_3_workers_low(workers)

	# Phase 2.6 — Building damage warning (check for any building at 2 days unstaffed)
	_check_building_damage_warning()

# ── PopulationManager.outbreak_started ───────────────────────────────────────

func _on_outbreak_started(sick_count: int) -> void:
	if not tutorial_enabled:
		return
	# Phase 4.5 — Disease mechanics explanation on first outbreak
	if not _has_shown("disease_mechanics"):
		_beat_4_5_disease_mechanics(sick_count)

# ── GridManager.building_placed ───────────────────────────────────────────────

func _on_building_placed(b_type: String, grid_pos: Vector2i) -> void:
	if not tutorial_enabled:
		return

	if not _first_building_placed:
		_first_building_placed = true
		_beat_1_3_first_placement()

		get_tree().create_timer(1.5, false, false, true).timeout.connect(
			func(): _auto_open_inspector_for_pos(grid_pos)
		)

	if b_type != "coal" and b_type != "geothermal" \
			and not _has_shown("power_dependency_warning"):
		var bs = _get_node("Main/BuildingSystem")
		if bs and not bs.has_building(BuildingData.BuildingType.COAL_GENERATOR):
			_beat_1_7_power_dependency()

	match b_type:
		"water":
			if not _has_shown("water_recycler_placed"):
				_beat_2_1_water_recycler()
		"hydro":
			if not _has_shown("hydroponic_bay_placed"):
				_beat_2_2_hydroponic_bay()
		"med":
			if not _has_shown("med_clinic_placed"):
				_beat_4_2_med_clinic()
		"ration":
			if not _has_shown("ration_store_placed"):
				_beat_4_3_ration_store()
		"archive":
			if not _has_shown("archive_hall_placed"):
				_beat_4_8_archive_hall()
		"memorial":
			if not _has_shown("memorial_wall_placed"):
				_beat_5_7_memorial_built()

# ── _auto_open_inspector_for_pos ─────────────────────────────────────────────

func _auto_open_inspector_for_pos(grid_pos: Vector2i) -> void:
	if not tutorial_enabled or _first_inspector_opened:
		return

	_exit_build_mode_safe()


	await get_tree().process_frame
	await get_tree().process_frame

	var grid = _get_node("Main/GameWorld/GridSystem")
	if grid and grid.get("current_build_scene") != null:
		await get_tree().create_timer(2.0, false, false, true).timeout
		if _first_inspector_opened:
			return

	var bs = _get_node("Main/BuildingSystem")
	if not bs or not bs.active_buildings.has(grid_pos):
		if bs and not bs.active_buildings.is_empty():
			grid_pos = bs.active_buildings.keys()[0]
		else:
			return

	if grid and grid.has_signal("building_selected"):
		grid.building_selected.emit(grid_pos)

# ── BuildingSystem.building_selected_data ────────────────────────────────────

func _on_building_selected(b_data: BuildingData) -> void:
	if not tutorial_enabled or b_data == null:
		return

	if not _first_inspector_opened:
		_first_inspector_opened = true
		_beat_1_5_inspector()

	if TimeManager.current_day >= GameConstants.STORM_START_DAY \
			and not b_data.is_shielded \
			and not _has_shown("shield_button_explanation"):
		_beat_5_3_shield_button()

# ── BuildMenu.build_menu_opened ───────────────────────────────────────────────

func _on_build_menu_opened() -> void:
	if not tutorial_enabled:
		return

	if not _first_build_menu_opened:
		_first_build_menu_opened = true
		_beat_1_2_build_menu_tiers()

# ── DialogueEngine.choice_made ────────────────────────────────────────────────

func _on_choice_made(event_id: String, _choice_id: String,
		_choice_data: Dictionary) -> void:
	if not tutorial_enabled:
		return

	match event_id:
		"cold_night":
			# Phase 3.2 — Hope/Order slider explanation after first choice
			if not _has_shown("hope_order_explanation"):
				await get_tree().create_timer(0.5, false, false, true).timeout
				_beat_3_2_hope_order_slider()
		"meridian_contact":
			# Phase 4.7 — MERIDIAN trust consequence
			if not _has_shown("meridian_consequence"):
				_beat_4_7_meridian_consequence()
		"rooks_militia":
			# Phase 5.1 — Rook's Militia consequence
			if not _has_shown("rooks_militia_consequence"):
				_beat_5_1_rooks_militia()

# ── GameManager.named_character_died ─────────────────────────────────────────

func _on_character_died(_char_name: String) -> void:
	if not tutorial_enabled:
		return
	# Phase 5.7 — Memorial Wall unlocked notification
	if not _has_shown("memorial_wall_unlocked"):
		_beat_5_7_memorial_unlocked()

# ═════════════════════════════════════════════════════════════════════════════
# BEAT IMPLEMENTATIONS
# Each method fires exactly one tutorial beat. Named by phase number.
# ═════════════════════════════════════════════════════════════════════════════

# ── Phase 0 — HUD explanation (fires after intro cards dismiss) ───────────────

func _fire_phase_0() -> void:
	# Queue all Phase 0 marks sequentially
	_enqueue_mark(
		"phase0_resource_bars",
		"Main/UILayer/HUD/TopStripPanel",
		"Power, Food, and Morale. If any hits zero, people die. " +
		"The number beside each bar is your daily gain or loss.",
		"below"
	)
	_enqueue_mark(
		"phase0_materials",
		"Main/UILayer/HUD/MaterialsLabel",
		"Materials — what you spend to build. Running out only stops " +
		"construction, not survival. Scavenging earns it passively each day.",
		"below"
	)
	_enqueue_mark(
		"phase0_population",
		"Main/UILayer/HUD/PopulationLabel",
		"Population is every living colonist. Workers is who can actually " +
		"work right now. These are different numbers. Watch both.",
		"below"
	)
	# After Phase 0 clears, queue Phase 1.1 with a delay
	await _wait_for_queue_empty()
	await get_tree().create_timer(1.5, false, false, true).timeout
	_beat_1_1_build_menu_prompt()

# ── Phase 1 — First Build Actions ────────────────────────────────────────────

func _beat_1_1_build_menu_prompt() -> void:
	_enqueue_mark(
		"build_menu_prompt",
		"Main/UILayer/HUD/ButtonBuild",
		"The colony needs infrastructure. Open the Build Menu to start " +
		"placing buildings. Press B or click this button.",
		"above"
	)

func _beat_1_2_build_menu_tiers() -> void:
	_fire_journal(
		"build_menu_tiers",
		"Build Menu — Priority Order",
		"The menu groups buildings by urgency. Build First: Coal Generator, " +
		"Water Recycler, Hydroponic Bay, Shelter Block — these are survival. " +
		"Build When Stable: Med Clinic, Ration Store, Relay Hub, Geothermal Tap. " +
		"Build When Ready: Archive Hall, Memorial Wall. No buildings are locked — " +
		"the grouping tells you what matters now."
	)

func _beat_1_3_first_placement() -> void:
	_fire_journal(
		"first_placement",
		"Building Placed",
		"Left-click places a building, right-click or Q cancels placement mode. " +
		"Buildings at zero workers for 3 consecutive days become damaged " +
		"and lock at 30 percent output until repaired with Materials. " +
		"The building control panel will open automatically so you can " +
		"assign workers right now."
	)

func _beat_1_5_inspector() -> void:
	if _has_shown("inspector_opened"):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var inspector: Control = _find_inspector()

	if inspector and inspector.visible and inspector.is_inside_tree():
		_enqueue_mark(
			"inspector_opened",
			"",
			"This is the building control panel. " +
			"Use + and − to assign workers from your available pool. " +
			"More workers means more output — but you can never staff " +
			"everything at once. Decide which buildings run at full capacity.",
			"right",
			inspector
		)
	else:
		_fire_journal(
			"inspector_opened",
			"Building Control Panel",
			"Click any placed building to open its control panel. " +
			"Assign workers with + and − buttons. " +
			"Partial staffing gives proportional output — " +
			"5 of 10 workers produces exactly 50 percent output."
		)

func _beat_1_7_power_dependency() -> void:
	_fire_journal(
		"power_dependency_warning",
		"Director's Log",
		"Buildings need power to operate. Without a Coal Generator running, " +
		"this building will stay dark regardless of how many workers are assigned. " +
		"Build the Generator first."
	)

# ── Phase 2 — Survival Foundations ───────────────────────────────────────────

func _beat_2_1_water_recycler() -> void:
	_fire_journal(
		"water_recycler_placed",
		"Water Recycler Operational",
		"This building must be staffed at all times. " +
		"If it sits at zero workers for two consecutive days, " +
		"a disease outbreak fires automatically. No exceptions."
	)

func _beat_2_2_hydroponic_bay() -> void:
	_fire_journal(
		"hydroponic_bay_placed",
		"Hydroponic Bay Online",
		"Food production scales directly with staffing. " +
		"At 50 percent staff it produces 50 percent food. " +
		"Watch the Food rate number on the HUD — the plus or minus " +
		"next to the bar tells you whether you are gaining or losing each day."
	)

func _beat_2_4_journal_nudge() -> void:
	if _has_shown("journal_introduction"):
		return
	await get_tree().create_timer(3.0, false, false, true).timeout
	_enqueue_mark(
		"journal_introduction",
		"Main/UILayer/HUD/ButtonJournal",
		"The Colony Journal records everything — event outcomes, deaths, " +
		"story moments. Press J or click here to read it. " +
		"The badge shows unread entries.",
		"above"
	)

func _beat_2_5_morale_efficiency(current_morale: float) -> void:
	_enqueue_mark(
		"morale_efficiency_warning",
		"Main/UILayer/HUD/MoraleBar",
		"Morale is at %.0f. Below 30, all building output drops to 80 percent. " % current_morale +
		"Morale decays every day just from living underground. " +
		"Shelter Blocks, the Med Clinic, and the Archive Hall all push it back up.",
		"below"
	)

func _beat_2_6_building_unstaffed(building_name: String) -> void:
	_fire_journal(
		"building_damage_warning_" + building_name,
		"Warning — Neglected Building",
		building_name + " has had no workers for two days. " +
		"One more day and it becomes damaged — locked at 30 percent output " +
		"even when re-staffed, until you spend Materials to repair it."
	)

func _check_building_damage_warning() -> void:
	var bs = _get_node("Main/BuildingSystem")
	if not bs:
		return
	for pos in bs.active_buildings:
		var b: BuildingData = bs.active_buildings[pos]
		if b.worker_capacity > 0 \
				and b.workers_assigned == 0 \
				and b.days_unstaffed == 2 \
				and not b.is_damaged:
			var flag_key: String = "damage_warning_" + b.building_name
			if not _has_shown(flag_key):
				_beat_2_6_building_unstaffed(b.building_name)

# ── Phase 3 — First Crisis ────────────────────────────────────────────────────

func _beat_3_1_after_cold_night() -> void:
	# The Cold Night fires on Day 3. After it resolves, point at the slider.
	# This is queued but only fires if Cold Night actually fired today.
	pass  

func _beat_3_2_hope_order_slider() -> void:
	_enqueue_mark(
		"hope_order_explanation",
		"Main/UILayer/HUD/HopeOrderTrackBorder",
		"This slider tracks the moral character of your decisions. " +
		"Hope-leaning colonies see slower Morale decay. " +
		"Order-leaning colonies produce more food but Morale falls faster. " +
		"Where it sits on Day 35 determines which ending fires.",
		"above"
	)

# ── Phase 4 — Mid-Game Unlocks ────────────────────────────────────────────────

func _beat_4_1_deserters_context() -> void:
	if not _has_shown("deserters_context") and ResourceManager.morale < 50.0:
		_fire_journal(
			"deserters_context",
			"Day 8 — Colony Cohesion",
			"When Morale stays low long enough, colonists stop believing things " +
			"will get better. Watch the Population counter — it is not just a number. " +
			"Every person who leaves or dies is someone the colony cannot get back."
		)

func _beat_4_2_med_clinic() -> void:
	_fire_journal(
		"med_clinic_placed",
		"Med Clinic Operational",
		"While staffed, the Med Clinic adds 15 Morale per day passively " +
		"and reduces colonist deaths during events by 30 percent. " +
		"When disease breaks out, it cures 5 sick colonists per day. " +
		"Without it, the sick die one to three at a time until the pool empties."
	)

func _beat_4_3_ration_store() -> void:
	await get_tree().create_timer(0.5, false, false, true).timeout
	_enqueue_mark(
		"ration_store_placed",
		"Main/UILayer/HUD/FoodBar",
		"The darker extension on the right of the Food bar is your Ration Store " +
		"emergency reserve. When food production drops to zero, " +
		"this buffer keeps colonists alive before starvation begins. " +
		"Do not let it empty.",
		"below"
	)

func _beat_4_4_auto_rationing() -> void:
	_fire_journal(
		"auto_rationing_active",
		"Auto-Rationing Active",
		"The Ration Store buffer is below 20 percent. " +
		"The colony is automatically cutting food portions to extend survival time. " +
		"This causes a Morale penalty every day it continues. " +
		"Restore food production to deactivate it."
	)

func _beat_4_5_fever_context() -> void:
	# Fires alongside the Day 16 Fever outbreak
	pass  

func _beat_4_5_disease_mechanics(sick_count: int) -> void:
	_enqueue_mark(
		"disease_mechanics",
		"Main/UILayer/HUD/DiseaseLabel",
		"%d colonists are sick and cannot work. " % sick_count +
		"A staffed Med Clinic cures 5 per day. " +
		"Without it, 1 to 3 die each day until the sick pool is empty. " +
		"The red number here tracks the active outbreak.",
		"below"
	)

func _beat_4_6_upgrade_nudge() -> void:
	if _has_shown("upgrade_nudge"):
		return
	if GameManager.materials < GameConstants.UPGRADE_COST_BASE:
		return
	var bs = _get_node("Main/BuildingSystem")
	if not bs or bs.active_buildings.is_empty():
		return
	_mark_shown("upgrade_nudge")
	_fire_journal(
		"upgrade_nudge_journal",
		"Building Upgrades Available",
		"You have enough Materials to upgrade a building. " +
		"Select any placed building and press the Upgrade button in the inspector. " +
		"Upgrades are permanent — Tier 2 buildings produce significantly more, " +
		"and some upgrades affect story outcomes. " +
		"The Med Clinic upgrade matters especially before Day 20."
	)

func _beat_4_7_meridian_consequence() -> void:
	var trusted: bool = GameManager.meridian_trusted
	if trusted:
		_fire_journal(
			"meridian_consequence",
			"MERIDIAN Integration Active",
			"MERIDIAN now has access to every colonist's biometric data. " +
			"All production buildings gain 20 percent efficiency. " +
			"Some colonists are uncomfortable. Morale drains 1 point per day from unease. " +
			"Click the Archive Hall building to read MERIDIAN's terminal messages."
		)
	else:
		_fire_journal(
			"meridian_consequence",
			"MERIDIAN Access Refused",
			"MERIDIAN remains in the terminal without biometric access. " +
			"Its optional messages are still readable through the Archive Hall. " +
			"The 20 percent efficiency boost will not apply."
		)

func _beat_4_8_archive_hall() -> void:
	_fire_journal(
		"archive_hall_placed",
		"Archive Hall Built",
		"The Archive Hall adds 8 Morale per day from cultural activity. " +
		"It also unlocks pre-collapse records in the Colony Journal automatically. " +
		"Once upgraded, clicking the Archive Hall opens MERIDIAN's terminal — " +
		"messages update as the days advance."
	)

# ── Phase 5 — Late Game ───────────────────────────────────────────────────────

func _beat_5_1_rooks_militia() -> void:
	_fire_journal(
		"rooks_militia_consequence",
		"Rook's Militia — Your Decision",
		"Whatever you chose, it will matter at the end. " +
		"Rook's survival flag is one of four variables that determine " +
		"whether the secret ending is reachable. " +
		"If you stopped the militia, a reconciliation window opens before Day 33."
	)

func _beat_5_2_storm_warning() -> void:
	if _has_shown("storm_warning_explained"):
		return
	_mark_shown("storm_warning_explained")

	# Coach mark on the storm countdown label
	_enqueue_mark(
		"storm_countdown_mark",
		"Main/UILayer/HUD/StormCountdownLabel",
		"9 days until the electromagnetic storm hits. " +
		"Everything you have built will be tested. " +
		"Unshielded buildings go offline permanently on Day 35.",
		"below"
	)

	# Journal nudge with full explanation
	_fire_journal(
		"storm_warning_journal",
		"Day 26 — Storm Preparation",
		"Select any building and use the Shield button in the inspector. " +
		"Shielding costs Materials and requires workers assigned for 2 days. " +
		"You cannot shield everything — choose what matters most. " +
		"The Storm Shield Panel on the left tracks every building's status."
	)

func _beat_5_3_shield_button() -> void:
	_fire_journal(
		"shield_button_explanation",
		"Shielding a Building",
		"Click the Shield button in the building inspector. " +
		"Assign workers for 2 full days and spend the Materials cost. " +
		"Once shielded, the building survives Day 35 and continues operating. " +
		"Shielded buildings show a green tick in the Storm Shield Panel."
	)

func _beat_5_5_priority_shielding() -> void:
	if _has_shown("priority_shielding"):
		return
	_fire_journal(
		"priority_shielding",
		"Shielding Priority",
		"Food and water determine survival rate on Day 35. " +
		"Shield the Hydroponic Bay and Water Recycler before anything else. " +
		"Power matters less than calories. " +
		"If you must choose between the Coal Generator and the Hydroponic Bay, " +
		"protect the food."
	)

func _beat_5_6_ending_calculation() -> void:
	if _has_shown("ending_calculation"):
		return
	var rate: float = float(GameManager.current_population) / 847.0
	_fire_journal(
		"ending_calculation",
		"Day 30 — Five Days Remaining",
		"Survival rate is currently %.0f percent (%d of 847). " % [rate * 100.0, GameManager.current_population] +
		"65 percent is the threshold between a full ending and The Quiet. " +
		"The Hope/Order slider selects between The Torch and The Necessary Evil. " +
		"Both numbers are visible on your HUD right now. " +
		"You have been building toward this since Day 1."
	)

func _beat_5_7_memorial_unlocked() -> void:
	_fire_journal(
		"memorial_wall_unlocked",
		"Memorial Wall Unlocked",
		"A named character has died. The Memorial Wall can now be placed. " +
		"It is free. It gives 20 Morale immediately and 3 Morale every day permanently. " +
		"Clicking it opens the stone plaque with every lost character's name and the day they died."
	)

func _beat_5_7_memorial_built() -> void:
	_fire_journal(
		"memorial_wall_placed",
		"Memorial Wall Standing",
		"The names are recorded. The wall gives 3 Morale every day for the rest of the run. " +
		"Click it at any time to read the plaque."
	)

# ── Phase 6 — Persistent Critical Warnings ────────────────────────────────────

func _beat_6_1_power_failure() -> void:
	_enqueue_mark(
		"power_failure_warning",
		"Main/UILayer/HUD/PowerBar",
		"Power draw exceeds capacity. Buildings are shutting down. " +
		"Build or upgrade a Coal Generator immediately. " +
		"Buildings with no power produce nothing regardless of staffing.",
		"below"
	)

func _beat_6_2_food_zero() -> void:
	_enqueue_mark(
		"food_zero_warning",
		"Main/UILayer/HUD/FoodBar",
		"Food has hit zero. The colony has two days before starvation deaths begin. " +
		"Staff the Hydroponic Bay at full capacity now. " +
		"The Ration Store buffer buys time if it has reserves remaining.",
		"below"
	)

func _beat_6_3_workers_low(workers: int) -> void:
	_fire_journal(
		"workers_low_warning",
		"Worker Pool Critical",
		"Only %d workers available. " % workers +
		"You cannot staff new buildings and existing output is reduced. " +
		"Disease, desertion, and starvation all shrink the pool further. " +
		"Raise Morale and resolve any active disease outbreak."
	)

func _beat_6_4_morale_desertion() -> void:
	_enqueue_mark(
		"morale_desertion_warning",
		"Main/UILayer/HUD/MoraleBar",
		"Morale is below 10. Workers are leaving every day now. " +
		"Build the Archive Hall or Shelter Block, staff the Med Clinic, " +
		"or take Hope-aligned story choices to push Morale back up " +
		"before the colony dissolves.",
		"below"
	)

# ═════════════════════════════════════════════════════════════════════════════
# COACH MARK QUEUE SYSTEM
# ═════════════════════════════════════════════════════════════════════════════

func _enqueue_mark(id: String, target_path: String, text: String,
		direction: String = "below", node_ref: Control = null) -> void:
	if not tutorial_enabled or _has_shown(id):
		return
	_mark_shown(id)
	_mark_queue.append({
		"id":       id,
		"path":     target_path,
		"text":     text,
		"dir":      direction,
		"node_ref": node_ref
	})
	_try_show_next()

func _try_show_next() -> void:
	if _active_mark and is_instance_valid(_active_mark):
		return
	if _mark_queue.is_empty():
		return

	_exit_build_mode_safe()

	var data: Dictionary = _mark_queue.pop_front()
	var mark = load("res://scripts/ui/CoachMark.gd").new()
	get_tree().root.add_child(mark)
	mark.process_mode = Node.PROCESS_MODE_ALWAYS

	var target: Control = null
	var stored_ref = data.get("node_ref", null)
	if stored_ref and is_instance_valid(stored_ref):
		target = stored_ref as Control
	elif data.path != "":
		var n = _get_node(data.path)
		if n and n is Control:
			target = n as Control

	if target and not target.is_inside_tree():
		target = null

	if target:
		mark.show_for_target(data.id, target, data.text, data.dir)
	else:
		if not data.text.is_empty():
			var vp: Vector2 = get_viewport().get_visible_rect().size
			mark.show_floating(data.id,
				Vector2(vp.x * 0.5, vp.y * 0.72), data.text)
		else:
			mark.queue_free()
			_try_show_next()
			return

	mark.coach_mark_dismissed.connect(func(_mid: String):
		_active_mark = null
		_try_show_next()
	)
	_active_mark = mark

## Await until the mark queue is empty (for sequencing Phase 0 → Phase 1.1)
func _wait_for_queue_empty() -> void:
	while not _mark_queue.is_empty() \
			or (_active_mark and is_instance_valid(_active_mark)):
		await get_tree().create_timer(0.3, false, false, true).timeout

# ═════════════════════════════════════════════════════════════════════════════
# JOURNAL NUDGE
# ═════════════════════════════════════════════════════════════════════════════

func _fire_journal(slug: String, title: String, body: String) -> void:
	if not tutorial_enabled or _has_shown(slug):
		return
	_mark_shown(slug)

	var journal = get_tree().root.get_node_or_null("Main/UILayer/ColonyJournal")
	if journal and journal.has_method("add_entry"):
		var entry_type = preload("res://scripts/data/JournalEntry.gd").EntryType.ONBOARDING
		journal.add_entry(TimeManager.current_day, body, entry_type, title)

# ═════════════════════════════════════════════════════════════════════════════
# FLAG HELPERS
# ═════════════════════════════════════════════════════════════════════════════

func _has_shown(id: String) -> bool:
	return shown_flags.get(id, false)

func _mark_shown(id: String) -> void:
	shown_flags[id] = true

# ═════════════════════════════════════════════════════════════════════════════
# NODE HELPERS
# ═════════════════════════════════════════════════════════════════════════════

func _get_node(path: String) -> Node:
	return get_tree().root.get_node_or_null(path)

func _find_inspector() -> Control:
	var paths := [
		"Main/UILayer/BuildingInspector",
		"Main/UILayer/HUD/BuildingInspector",
		"Main/BuildingInspector"
	]
	for p in paths:
		var n = get_tree().root.get_node_or_null(p)
		if n and n is Control:
			return n as Control

	# Fallback: recursive search
	var found = get_tree().root.find_child("BuildingInspector", true, false)
	if found and found is Control:
		return found as Control

	return null

# ── _exit_build_mode_safe ─────────────────────────────────────────────────────

func _exit_build_mode_safe() -> void:
	var grid = _get_node("Main/GameWorld/GridSystem")
	if grid:
		if grid.get("current_build_scene") != null \
				and grid.has_method("exit_build_mode"):
			grid.exit_build_mode()
		if grid.get("current_decoration_type") != "" \
				and grid.has_method("exit_decoration_mode"):
			grid.exit_decoration_mode()

	var bm = _get_node("Main/BuildMenu")
	if bm and bm.get("is_open") == true and bm.has_method("close"):
		bm.close()

# ═════════════════════════════════════════════════════════════════════════════
# CONFIG 
# ═════════════════════════════════════════════════════════════════════════════

func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		tutorial_enabled = cfg.get_value("tutorial", "enabled", true)

func save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "enabled", tutorial_enabled)
	cfg.save(CONFIG_PATH)