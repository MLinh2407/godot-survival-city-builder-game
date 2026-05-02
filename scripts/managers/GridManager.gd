class_name GridManager
extends Node2D

signal building_placed(type: String, grid_pos: Vector2i)
signal building_removed(grid_pos: Vector2i)
signal building_selected(grid_pos: Vector2i)
signal building_deselected()

# ── Footprint sizes ──────────────────────────────────────────────────────────
const BUILDING_FOOTPRINTS: Dictionary = {
	"coal":       Vector2i(2, 2),
	"geothermal": Vector2i(2, 2),   
	"relay":      Vector2i(1, 1),
	"hydro":      Vector2i(2, 2),
	"ration":     Vector2i(2, 2),
	"water":      Vector2i(2, 2),
	"med":        Vector2i(2, 2),
	"shelter":    Vector2i(2, 2),
	"archive":    Vector2i(2, 2),
	"memorial":   Vector2i(2, 2),   
}

const GRID_BOUNDS_MIN = Vector2i(-40, -40)
const GRID_BOUNDS_MAX = Vector2i(40,  40)

const BUILDING_GROUND_FACTOR: float = 0.25    
const BUILDING_PLACE_FACTOR:  float = 0.18  

var occupied_cells:  Dictionary = {}   
var cell_to_anchor:  Dictionary = {}   
var anchor_to_type:  Dictionary = {}   

@onready var base_grid:          TileMapLayer = $BaseGrid
@onready var void_layer:          TileMapLayer = $VoidLayer
@onready var special_floor_layer: TileMapLayer = $SpecialFloorLayer
@onready var decal_layer:         TileMapLayer = $DecalLayer
@onready var ghost_sprite:       Sprite2D     = $GhostSprite
@onready var hover_cursor:       Sprite2D     = $HoverCursor
@export  var building_container: Node2D
@export  var building_scenes:    Dictionary   = {}

var current_build_type:  String      = ""
var current_build_scene: PackedScene = null
var current_decoration_type: String  = ""   

var _hovered_building_node:  Node2D = null
var _selected_building_node: Node2D = null

const HOVER_MODULATE:    Color = Color(1.45, 1.45, 1.45, 1.0)   # bright white-ish
const SELECTED_MODULATE: Color = Color(0.75, 1.10, 1.25, 1.0)   # cyan tint
const NORMAL_MODULATE:   Color = Color(1.0,  1.0,  1.0,  1.0)   # restore

const DEMOLISH_HOLD_DURATION: float = 2.0   # seconds to hold for demolition

var _demolish_anchor:   Vector2i = Vector2i(-9999, -9999)
var _demolish_timer:    float    = 0.0
var _demolish_active:   bool     = false
var _demolish_arc:      Node2D   = null     
var _blocker_highlight: Node2D = null
var _hover_highlight: Node2D = null
var _demolish_armed:        bool     = false
var _demolish_armed_anchor: Vector2i = Vector2i(-9999, -9999)
var _demolish_arm_label:    Label    = null

var _hover_tip_panel:  Panel    = null
var _hover_tip_anchor: Vector2i = Vector2i(-9999, -9999)
var _hover_tip_timer:  float    = 0.0
const HOVER_TIP_DELAY: float    = 0.45

var _shake_offset: Vector2 = Vector2.ZERO

var _ghost_pulse_t: float = 0.0
var _selection_outline_node: Node2D = null
var _current_placement_anchor: Vector2i = Vector2i.ZERO

# Cached per build-mode session so _process doesn't recompute every frame
var _ghost_y_offset: float = 0.0

var _footprint_node: Node2D
var _last_fp_anchor: Vector2i = Vector2i(-9999, -9999)
var _last_fp_valid:  bool     = false
var _last_hovered_anchor: Vector2i = Vector2i(-9999, -9999)
var _selected_anchor:     Vector2i = Vector2i(-9999, -9999)

# ── _ready ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	ghost_sprite.visible    = false
	hover_cursor.visible    = false
	ghost_sprite.z_index    = 100
	ghost_sprite.z_as_relative = false

	# Footprint overlay — z=1
	_footprint_node               = Node2D.new()
	_footprint_node.z_index       = 1
	_footprint_node.z_as_relative = false
	add_child(_footprint_node)

	# Blocker highlight — z=2
	_blocker_highlight               = Node2D.new()
	_blocker_highlight.z_index       = 2
	_blocker_highlight.z_as_relative = false
	add_child(_blocker_highlight)

	# Hover / selection highlight nodes — z=3, 4
	_hover_highlight               = Node2D.new()
	_hover_highlight.z_index       = 3
	_hover_highlight.z_as_relative = false
	add_child(_hover_highlight)

	_selection_outline_node               = Node2D.new()
	_selection_outline_node.z_index       = 4
	_selection_outline_node.z_as_relative = false
	add_child(_selection_outline_node)

	# Buildings above all overlays — z=5
	if building_container:
		building_container.z_index       = 5
		building_container.z_as_relative = false

	# GridManager listens to its own signals to drive building highlights
	building_selected.connect(_on_selection_changed)
	building_deselected.connect(_on_selection_cleared)

	call_deferred("_prefill_void")

	_setup_hover_tooltip()

# ── Void pre-fill ─────────────────────────────────────────────────────────────
func _prefill_void() -> void:
	if not void_layer:
		push_warning("GridManager: $VoidLayer not found — skipping void pre-fill.")
		return
	var pad: int = 4
	var min_c: Vector2i = GRID_BOUNDS_MIN - Vector2i(pad, pad)
	var max_c: Vector2i = GRID_BOUNDS_MAX + Vector2i(pad, pad)
	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			void_layer.set_cell(
				Vector2i(x, y),
				TileRegistry.FLOOR_SOURCE_ID,
				TileRegistry.M8_VOID
			)
	print("GridManager: Void pre-fill complete — %d cells." \
		% ((max_c.x - min_c.x + 1) * (max_c.y - min_c.y + 1)))

# ── Footprint helpers ─────────────────────────────────────────────────────────
func get_footprint_cells(anchor: Vector2i, b_type: String) -> Array[Vector2i]:
	var size:  Vector2i        = BUILDING_FOOTPRINTS.get(b_type, Vector2i(1, 1))
	var cells: Array[Vector2i] = []
	for dy in range(size.y):
		for dx in range(size.x):
			cells.append(anchor + Vector2i(dx, dy))
	return cells

func get_footprint_centre_offset(b_type: String) -> Vector2:
	var size: Vector2i = BUILDING_FOOTPRINTS.get(b_type, Vector2i(1, 1))
	if size == Vector2i(1, 1):
		return Vector2.ZERO
	var origin: Vector2 = base_grid.map_to_local(Vector2i(0, 0))
	var sum:    Vector2 = Vector2.ZERO
	var count:  int     = 0
	for dy in range(size.y):
		for dx in range(size.x):
			sum   += base_grid.map_to_local(Vector2i(dx, dy)) - origin
			count += 1
	return sum / float(count)

func _get_type_for_anchor(anchor: Vector2i) -> String:
	return anchor_to_type.get(anchor, "")

# ── Scale & offset helpers ────────────────────────────────────────────────────
func _get_scale_for_type(b_type: String, b_sprite: Sprite2D) -> float:
	var footprint: Vector2i = BUILDING_FOOTPRINTS.get(b_type, Vector2i(1, 1))
	var target_px: float    = float(GameConstants.TILE_SIZE) * float(footprint.x)
	if b_sprite and b_sprite.texture:
		return target_px / float(b_sprite.texture.get_width())
	return target_px / float(GameConstants.BUILDING_SPRITE_SIZE)

func _get_y_offset(b_sprite: Sprite2D, scale_factor: float, ground_factor: float = BUILDING_GROUND_FACTOR) -> float:
	if b_sprite and b_sprite.texture:
		return -float(b_sprite.texture.get_height()) * scale_factor * ground_factor
	return 0.0

# ── Footprint overlay ─────────────────────────────────────────────────────────
func _rebuild_footprint_overlay(anchor: Vector2i, b_type: String, valid: bool) -> void:
	for child in _footprint_node.get_children():
		child.queue_free()

	# Fill colour — semi-transparent
	var fill_color: Color   = Color(0.20, 1.00, 0.30, 0.35) if valid \
															 else Color(1.00, 0.20, 0.20, 0.35)
	# Border colour — darker and fully opaque so individual tiles are visible
	var border_color: Color = Color(0.05, 0.60, 0.10, 1.00) if valid \
															 else Color(0.70, 0.05, 0.05, 1.00)

	var half_w: float = 32.0
	var half_h: float = 16.0
	if base_grid and base_grid.tile_set:
		half_w = base_grid.tile_set.tile_size.x * 0.5
		half_h = half_w * 0.5

	for cell in get_footprint_cells(anchor, b_type):
		var c: Vector2 = base_grid.map_to_local(cell)

		# Diamond vertices for this cell
		var vt: Vector2 = c + Vector2(      0, -half_h)
		var vr: Vector2 = c + Vector2( half_w,       0)
		var vb: Vector2 = c + Vector2(      0,  half_h)
		var vl: Vector2 = c + Vector2(-half_w,       0)

		# --- Fill polygon ---
		var fill := Polygon2D.new()
		fill.polygon = PackedVector2Array([vt, vr, vb, vl])
		fill.color   = fill_color
		_footprint_node.add_child(fill)

		# --- Border line (closed diamond loop) ---
		var border := Line2D.new()
		border.add_point(vt)
		border.add_point(vr)
		border.add_point(vb)
		border.add_point(vl)
		border.add_point(vt)       
		border.width         = 1.5
		border.default_color = border_color
		_footprint_node.add_child(border)

		if valid:
			_clear_blocker_highlight()
		else:
			_draw_blocker_highlights(anchor, b_type)

func _clear_footprint_overlay() -> void:
	if _footprint_node.get_child_count() == 0:
		_last_fp_anchor = Vector2i(-9999, -9999)
		return
	_clear_node(_footprint_node)
	_last_fp_anchor = Vector2i(-9999, -9999)

# ── Build mode ────────────────────────────────────────────────────────────────
func enter_build_mode(b_type: String) -> void:
	if not building_scenes.has(b_type):
		return
	current_build_type  = b_type
	current_build_scene = building_scenes[b_type]

	var temp     = current_build_scene.instantiate()
	var b_sprite: Sprite2D = temp.get_node_or_null("Sprite2D")
	if b_sprite and b_sprite.texture:
		ghost_sprite.texture = b_sprite.texture
		ghost_sprite.offset  = b_sprite.offset
		var sf: float        = _get_scale_for_type(b_type, b_sprite)
		ghost_sprite.scale   = Vector2(sf, sf)
		_ghost_y_offset      = _get_y_offset(b_sprite, sf)
	temp.queue_free()

	ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.70)
	ghost_sprite.visible  = true

func exit_build_mode() -> void:
	current_build_type    = ""
	current_build_scene   = null
	_ghost_y_offset       = 0.0
	_shake_offset         = Vector2.ZERO
	ghost_sprite.visible  = false
	ghost_sprite.texture  = null
	ghost_sprite.modulate = Color.WHITE
	_clear_footprint_overlay()
	_clear_blocker_highlight()  

# ── Decoration Mode ────────────────────────────────────────────────────────────

func enter_decoration_mode(dec_type: String) -> void:
	if not TileRegistry.DECORATION_TILE_MAP.has(dec_type):
		push_warning("GridManager: Unknown decoration type '%s'" % dec_type)
		return
	# Exit build mode if active
	if current_build_scene != null:
		exit_build_mode()
	current_decoration_type = dec_type
	_last_fp_anchor          = Vector2i(-9999, -9999)
	ghost_sprite.visible     = false
	hover_cursor.visible     = false
	_clear_footprint_overlay()
	_clear_blocker_highlight()

func exit_decoration_mode() -> void:
	current_decoration_type = ""
	_last_fp_anchor          = Vector2i(-9999, -9999)
	_clear_footprint_overlay()
	_clear_blocker_highlight()

# Places a decoration tile on DecalLayer. Does not create BuildingData.
func place_decoration(cell: Vector2i, dec_type: String) -> void:
	if not decal_layer:
		push_warning("GridManager: $DecalLayer not found.")
		return
	if not TileRegistry.DECORATION_TILE_MAP.has(dec_type):
		return
	var atlas_coords: Vector2i = TileRegistry.DECORATION_TILE_MAP[dec_type]
	decal_layer.set_cell(cell, TileRegistry.FLOOR_SOURCE_ID, atlas_coords)
	AudioManager.play_build_sfx("place")

# Erases a player-placed decoration tile from DecalLayer.
# Will NOT erase M15 foundation rings — those are protected.
func erase_decoration(cell: Vector2i) -> void:
	if not decal_layer:
		return
	var source: int = decal_layer.get_cell_source_id(cell)
	if source == -1:
		return   
	var atlas: Vector2i = decal_layer.get_cell_atlas_coords(cell)
	# Only erase if the tile at this cell is a known decoration tile
	for key in TileRegistry.DECORATION_TILE_MAP:
		if TileRegistry.DECORATION_TILE_MAP[key] == atlas:
			decal_layer.erase_cell(cell)
			AudioManager.play_build_sfx("remove")
			return

# Draws a single-cell cyan diamond highlight for decoration placement cursor.
func _rebuild_decoration_highlight(cell: Vector2i) -> void:
	for child in _footprint_node.get_children():
		child.queue_free()
	var half_w: float = 32.0
	var half_h: float = 16.0
	if base_grid and base_grid.tile_set:
		half_w = base_grid.tile_set.tile_size.x * 0.5
		half_h = half_w * 0.5
	var c: Vector2 = base_grid.map_to_local(cell)
	var vt := c + Vector2(0.0,    -half_h)
	var vr := c + Vector2(half_w,  0.0)
	var vb := c + Vector2(0.0,     half_h)
	var vl := c + Vector2(-half_w, 0.0)

	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([vt, vr, vb, vl])
	fill.color   = Color(0.0, 0.85, 1.0, 0.35)
	_footprint_node.add_child(fill)

	var border := Line2D.new()
	border.add_point(vt); border.add_point(vr)
	border.add_point(vb); border.add_point(vl)
	border.add_point(vt)
	border.width         = 1.5
	border.default_color = Color(0.0, 0.95, 1.0, 0.9)
	_footprint_node.add_child(border)

# ── _process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# ── Demolish hold timer ──────────────────────────────────────────────────
	if _demolish_active:
		var current_map: Vector2i = base_grid.local_to_map(get_local_mouse_position())
		var still_on_target: bool = \
			cell_to_anchor.get(current_map, Vector2i(-9999, -9999)) == _demolish_anchor
		if not still_on_target:
			_cancel_demolish()
		else:
			_demolish_timer += delta
			_update_demolish_arc(_demolish_timer / DEMOLISH_HOLD_DURATION)
			if _demolish_timer >= DEMOLISH_HOLD_DURATION:
				_complete_demolish()
				return

	var local_mouse: Vector2 = get_local_mouse_position()
	var map_pos: Vector2i    = base_grid.local_to_map(local_mouse)

	if current_build_scene != null:
		# ── BUILD MODE ───────────────────────────────────────────────────────
		hover_cursor.visible = false
		ghost_sprite.visible = true
		_clear_node(_hover_highlight)
		_last_hovered_anchor = Vector2i(-9999, -9999)

		var snapped_anchor: Vector2i = _get_snap_anchor(map_pos)
		_current_placement_anchor = snapped_anchor

		_ghost_pulse_t += delta * 2.5
		var pulse_alpha: float = 0.60 + 0.18 * sin(_ghost_pulse_t)
		ghost_sprite.modulate  = Color(1.0, 1.0, 1.0, pulse_alpha)

		ghost_sprite.position = base_grid.map_to_local(snapped_anchor)                \
							  + get_footprint_centre_offset(current_build_type) \
							  + Vector2(0.0, _ghost_y_offset)                   \
							  + _shake_offset

		var valid: bool = is_valid_placement(snapped_anchor, current_build_type)
		if snapped_anchor != _last_fp_anchor or valid != _last_fp_valid:
			_last_fp_anchor = snapped_anchor
			_last_fp_valid  = valid
			_rebuild_footprint_overlay(snapped_anchor, current_build_type, valid)

	elif current_decoration_type != "":
		# ── DECORATION MODE ──────────────────────────────────────────────────
		ghost_sprite.visible  = false
		hover_cursor.visible  = false
		_clear_node(_hover_highlight)
		_clear_node(_selection_outline_node)
		_clear_blocker_highlight()
		if map_pos != _last_fp_anchor:
			_last_fp_anchor = map_pos
			_rebuild_decoration_highlight(map_pos)
	
	else:
		# ── SELECTION MODE ────────────────────────────────────────────────────
		ghost_sprite.visible  = false
		ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.70)
		_ghost_pulse_t        = 0.0
		_clear_footprint_overlay()
		_clear_blocker_highlight()

		if cell_to_anchor.has(map_pos):
			var anchor: Vector2i = cell_to_anchor[map_pos]
			hover_cursor.visible = false
			if anchor != _last_hovered_anchor:
				_last_hovered_anchor = anchor
				_apply_building_modulate(
					occupied_cells.get(anchor, null), HOVER_MODULATE)
				# Reset tooltip timer when hover moves to a new building
				_hover_tip_timer = 0.0
				if _hover_tip_panel:
					_hover_tip_panel.visible = false
			else:
				# Same building — tick timer and show after delay
				_hover_tip_timer += delta
				if _hover_tip_timer >= HOVER_TIP_DELAY and _hover_tip_panel \
						and not _hover_tip_panel.visible:
					_show_hover_tip(anchor)
				elif _hover_tip_panel and _hover_tip_panel.visible:
					# Keep tooltip positioned at cursor
					_hover_tip_panel.position = get_local_mouse_position() + Vector2(16, -80)
		else:
			hover_cursor.visible = false
			if _last_hovered_anchor != Vector2i(-9999, -9999):
				var prev_node: Node2D = occupied_cells.get(_last_hovered_anchor, null)
				if prev_node != null and prev_node != _selected_building_node:
					_apply_building_modulate(prev_node, NORMAL_MODULATE)
				_last_hovered_anchor = Vector2i(-9999, -9999)
				_hover_tip_timer = 0.0
				if _hover_tip_panel:
					_hover_tip_panel.visible = false

# ── Validity check ────────────────────────────────────────────────────────────
func is_valid_placement(anchor: Vector2i, b_type: String = "") -> bool:
	for cell in get_footprint_cells(anchor, b_type):
		if cell_to_anchor.has(cell):
			return false
	return true

# ── Input ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var map_pos: Vector2i = base_grid.local_to_map(get_local_mouse_position())

		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_build_scene != null:
				if is_valid_placement(_current_placement_anchor, current_build_type):
					place_building(_current_placement_anchor)
				else:
					AudioManager.play_build_sfx("invalid")
					_shake_ghost()
			elif current_decoration_type != "":
				place_decoration(map_pos, current_decoration_type)
			else:
				if cell_to_anchor.has(map_pos):
					building_selected.emit(cell_to_anchor[map_pos])
				else:
					building_deselected.emit()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_build_scene != null:
				exit_build_mode()
			elif current_decoration_type != "":
				erase_decoration(map_pos)
			elif event.pressed:
				map_pos = base_grid.local_to_map(get_local_mouse_position())
				if cell_to_anchor.has(map_pos):
					var anchor: Vector2i = cell_to_anchor[map_pos]
					if _demolish_armed and _demolish_armed_anchor == anchor:
						# Player confirmed via dialog — start the hold arc
						_demolish_anchor = anchor
						_demolish_timer  = 0.0
						_demolish_active = true
						_spawn_demolish_arc(anchor)
					else:
						# Not armed yet — select the building and let the
						# inspector's Remove button handle the confirmation flow
						building_selected.emit(anchor)
			else:
				_cancel_demolish()

	if event is InputEventKey and event.pressed:
		# ── Q cancels build mode ──────────────────────────────────────
		if event.keycode == KEY_Q:
			if current_build_scene != null:
				exit_build_mode()
			elif current_decoration_type != "":
				exit_decoration_mode()
			return
		var keys = building_scenes.keys()
		if event.keycode == KEY_1 and keys.size() > 0: enter_build_mode(keys[0])
		if event.keycode == KEY_2 and keys.size() > 1: enter_build_mode(keys[1])
		if event.keycode == KEY_3 and keys.size() > 2: enter_build_mode(keys[2])
		if event.keycode == KEY_4 and keys.size() > 3: enter_build_mode(keys[3])
		if event.keycode == KEY_5 and keys.size() > 4: enter_build_mode(keys[4])
		if event.keycode == KEY_6 and keys.size() > 5: enter_build_mode(keys[5])
		if event.keycode == KEY_7 and keys.size() > 6: enter_build_mode(keys[6])
		if event.keycode == KEY_8 and keys.size() > 7: enter_build_mode(keys[7])
		if event.keycode == KEY_9 and keys.size() > 8: enter_build_mode(keys[8])

# ── Placement & removal ────────────────────────────────────────────────────────
func place_building(anchor: Vector2i) -> void:
	var new_building        = current_build_scene.instantiate()
	var b_sprite: Sprite2D  = new_building.get_node_or_null("Sprite2D")
	var sf: float           = _get_scale_for_type(current_build_type, b_sprite)
	new_building.scale      = Vector2(sf, sf)
	new_building.position = base_grid.map_to_local(anchor)                    \
						+ get_footprint_centre_offset(current_build_type)   \
						+ Vector2(0.0, _get_y_offset(b_sprite, sf, BUILDING_PLACE_FACTOR))

	building_container.add_child(new_building)

	var target_scale: Vector2 = new_building.scale
	new_building.scale = target_scale * 0.0
	var pop_tween: Tween = new_building.create_tween()
	pop_tween.tween_property(new_building, "scale", target_scale * 1.08, 0.10) \
			 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(new_building, "scale", target_scale, 0.08)        \
			 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	occupied_cells[anchor] = new_building
	anchor_to_type[anchor] = current_build_type
	for cell in get_footprint_cells(anchor, current_build_type):
		cell_to_anchor[cell] = anchor

	# ── Automatic tile placements ─────────────────────────────────────────────
	# Foundation ring placed on DecalLayer under every building
	if decal_layer:
		for cell in get_footprint_cells(anchor, current_build_type):
			decal_layer.set_cell(
				cell,
				TileRegistry.FLOOR_SOURCE_ID,
				TileRegistry.M15_FOUNDATION
			)

	# M7: Memorial Ground placed on BaseGrid under the Memorial Wall only
	if current_build_type == "memorial" and base_grid:
		for cell in get_footprint_cells(anchor, "memorial"):
			base_grid.set_cell(
				cell,
				TileRegistry.FLOOR_SOURCE_ID,
				TileRegistry.M7_MEMORIAL_GROUND
			)
			print("GridManager: M7 set at cell %s | source %d | atlas %s" \
				% [cell, TileRegistry.FLOOR_SOURCE_ID, TileRegistry.M7_MEMORIAL_GROUND])  # Debug
	
	building_placed.emit(current_build_type, anchor)
	_clear_footprint_overlay()
	_clear_blocker_highlight()

	building_selected.emit(anchor)  

func remove_building(anchor: Vector2i) -> void:
	if not occupied_cells.has(anchor): return

	# Capture building type before dictionaries are erased
	var removed_type: String = anchor_to_type.get(anchor, "")

	# Clean up highlight state for removed building
	var node: Node2D = occupied_cells[anchor]

	# Clear hover overlay for this building
	if node == _hovered_building_node:
		_hovered_building_node  = null
		_last_hovered_anchor    = Vector2i(-9999, -9999)
		_clear_node(_hover_highlight)

	if node == _selected_building_node:
		_selected_building_node = null
		_selected_anchor        = Vector2i(-9999, -9999)
		_clear_node(_selection_outline_node)
		building_deselected.emit()   

	occupied_cells[anchor].queue_free()
	occupied_cells.erase(anchor)
	anchor_to_type.erase(anchor)
	var to_erase: Array[Vector2i] = []
	for cell in cell_to_anchor:
		if cell_to_anchor[cell] == anchor:
			to_erase.append(cell)
	for cell in to_erase:
		cell_to_anchor.erase(cell)

	# ── Tile cleanup on removal ───────────────────────────────────────────────
	# Remove foundation ring from DecalLayer
	if decal_layer and removed_type != "":
		for cell in get_footprint_cells(anchor, removed_type):
			decal_layer.erase_cell(cell)

	# Restore dry concrete under the Memorial Wall location
	if removed_type == "memorial" and base_grid:
		for cell in get_footprint_cells(anchor, "memorial"):
			base_grid.set_cell(
				cell,
				TileRegistry.FLOOR_SOURCE_ID,
				TileRegistry.M1_DRY_CONCRETE
			)

	building_removed.emit(anchor)

func clear_grid() -> void:
	for anchor in occupied_cells.keys().duplicate():
		remove_building(anchor)

func spawn_building_from_save(b_type: String, anchor: Vector2i) -> void:
	if not building_scenes.has(b_type):
		push_error("GridManager: unknown type for save spawn: " + b_type)
		return
	var new_building        = building_scenes[b_type].instantiate()
	var b_sprite: Sprite2D  = new_building.get_node_or_null("Sprite2D")
	var sf: float           = _get_scale_for_type(b_type, b_sprite)
	new_building.scale      = Vector2(sf, sf)
	new_building.position = base_grid.map_to_local(anchor)        \
						+ get_footprint_centre_offset(b_type)   \
						+ Vector2(0.0, _get_y_offset(b_sprite, sf, BUILDING_PLACE_FACTOR))

	building_container.add_child(new_building)
	occupied_cells[anchor] = new_building
	anchor_to_type[anchor] = b_type
	for cell in get_footprint_cells(anchor, b_type):
		cell_to_anchor[cell] = anchor
	building_placed.emit(b_type, anchor)

# ── Highlight helpers ─────────────────────────────────────────────────────────

# Draws a Line2D diamond outline for each tile in the footprint.
# color    = line colour
# width    = line thickness in pixels
# func _draw_footprint_outline(
#         container: Node2D,
#         anchor:    Vector2i,
#         b_type:    String,
#         color:     Color,
#         width:     float) -> void:

#     _clear_node(container)

#     var half_w: float = 32.0
#     var half_h: float = 16.0
#     if base_grid and base_grid.tile_set:
#         half_w = base_grid.tile_set.tile_size.x * 0.5
#         half_h = half_w * 0.5

#     for cell in get_footprint_cells(anchor, b_type):
#         var c: Vector2 = base_grid.map_to_local(cell)
#         var line := Line2D.new()
#         # Diamond: top → right → bottom → left → top (closed loop)
#         line.add_point(c + Vector2(     0, -half_h))
#         line.add_point(c + Vector2( half_w,      0))
#         line.add_point(c + Vector2(     0,  half_h))
#         line.add_point(c + Vector2(-half_w,      0))
#         line.add_point(c + Vector2(     0, -half_h))
#         line.width         = width
#         line.default_color = color
#         line.z_index       = 0
#         container.add_child(line)

# Removes all children from a Node2D container safely.
func _clear_node(container: Node2D) -> void:
	if container == null: return
	for child in container.get_children():
		child.queue_free()

# Called when GridManager emits building_selected
func _on_selection_changed(anchor: Vector2i) -> void:
	# Restore previous selection
	if _selected_building_node != null:
		_apply_building_modulate(_selected_building_node, NORMAL_MODULATE)
		_clear_node(_selection_outline_node)

	_selected_anchor        = anchor
	_selected_building_node = occupied_cells.get(anchor, null)
	_apply_building_modulate(_selected_building_node, SELECTED_MODULATE)

	_draw_selection_outline(anchor, _get_type_for_anchor(anchor))

func _on_selection_cleared() -> void:
	if _selected_building_node != null:
		_apply_building_modulate(_selected_building_node, NORMAL_MODULATE)
	_selected_building_node = null
	_selected_anchor        = Vector2i(-9999, -9999)
	_clear_node(_selection_outline_node)

# Applies modulate to the Sprite2D inside a building node.
# Falls back to the node itself if no Sprite2D child found.
func _apply_building_modulate(node: Node2D, color: Color) -> void:
	if node == null:
		return
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = color
	else:
		node.modulate = color

func _shake_ghost() -> void:
	var tween: Tween = create_tween()
	var shake_x: float = 6.0  
	# Four rapid oscillations then snap back to zero
	tween.tween_method(_set_shake_offset, 0.0, -shake_x, 0.03)
	tween.tween_method(_set_shake_offset, -shake_x, shake_x, 0.03)
	tween.tween_method(_set_shake_offset, shake_x, -shake_x, 0.03)
	tween.tween_method(_set_shake_offset, -shake_x, shake_x, 0.03)
	tween.tween_method(_set_shake_offset, shake_x, 0.0, 0.03)

func _set_shake_offset(value: float) -> void:
	_shake_offset = Vector2(value, 0.0)

func _draw_blocker_highlights(anchor: Vector2i, b_type: String) -> void:
	_clear_node(_blocker_highlight)

	# Collect all unique anchors that are blocking this placement
	var blocking_anchors: Array[Vector2i] = []
	for cell in get_footprint_cells(anchor, b_type):
		if cell_to_anchor.has(cell):
			var blocker: Vector2i = cell_to_anchor[cell]
			if not blocking_anchors.has(blocker):
				blocking_anchors.append(blocker)

	if blocking_anchors.is_empty():
		return

	var half_w: float = 32.0
	var half_h: float = 16.0
	if base_grid and base_grid.tile_set:
		half_w = base_grid.tile_set.tile_size.x * 0.5
		half_h = half_w * 0.5

	for blocker_anchor in blocking_anchors:
		var blocker_type: String = _get_type_for_anchor(blocker_anchor)

		for cell in get_footprint_cells(blocker_anchor, blocker_type):
			var c: Vector2 = base_grid.map_to_local(cell)

			# Dim red fill showing the occupied footprint
			var fill := Polygon2D.new()
			fill.polygon = PackedVector2Array([
				c + Vector2(     0, -half_h),
				c + Vector2( half_w,      0),
				c + Vector2(     0,  half_h),
				c + Vector2(-half_w,      0),
			])
			fill.color = Color(1.0, 0.15, 0.15, 0.30)
			_blocker_highlight.add_child(fill)

			# Bright red border so it reads clearly
			var border := Line2D.new()
			border.add_point(c + Vector2(     0, -half_h))
			border.add_point(c + Vector2( half_w,      0))
			border.add_point(c + Vector2(     0,  half_h))
			border.add_point(c + Vector2(-half_w,      0))
			border.add_point(c + Vector2(     0, -half_h))
			border.width         = 1.5
			border.default_color = Color(1.0, 0.20, 0.20, 1.0)
			_blocker_highlight.add_child(border)

func _clear_blocker_highlight() -> void:
	_clear_node(_blocker_highlight)

# ── Demolition arc visual ─────────────────────────────────────────────────────

func _spawn_demolish_arc(anchor: Vector2i) -> void:
	_clear_demolish_arc()
	var b_type: String   = _get_type_for_anchor(anchor)
	var centre: Vector2  = base_grid.map_to_local(anchor) + \
						   get_footprint_centre_offset(b_type)

	_demolish_arc = Node2D.new()
	_demolish_arc.position     = centre
	_demolish_arc.z_index      = 200
	_demolish_arc.z_as_relative = false
	add_child(_demolish_arc)

	# Background ring (dark, full circle)
	var bg := _make_arc_polygon(0.0, 1.0, 14.0, 10.0, Color(0.1, 0.1, 0.1, 0.7))
	_demolish_arc.add_child(bg)

	# Progress arc starts empty — updated each frame
	var progress_node := Node2D.new()
	progress_node.name = "Progress"
	_demolish_arc.add_child(progress_node)

	# Label
	var label := Label.new()
	label.text                    = "HOLD"
	label.name                    = "Label"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.position                = Vector2(-14, -6)
	_demolish_arc.add_child(label)

func _update_demolish_arc(progress: float) -> void:
	if _demolish_arc == null: return
	var progress_node: Node2D = _demolish_arc.get_node_or_null("Progress")
	if progress_node == null: return
	for child in progress_node.get_children():
		child.queue_free()
	if progress <= 0.0: return
	# Red fill arc showing how far along the hold is
	var arc := _make_arc_polygon(0.0, progress, 14.0, 10.0, Color(1.0, 0.25, 0.25, 0.90))
	progress_node.add_child(arc)

# Builds a filled arc as a Polygon2D.
func _make_arc_polygon(from_t: float, to_t: float, outer_r: float, inner_r: float, color: Color) -> Polygon2D:
	var steps:      int   = 32
	var start_angle: float = -PI * 0.5                         
	var sweep:       float = TAU * clampf(to_t - from_t, 0, 1)
	var from_angle:  float = start_angle + TAU * from_t

	var points: PackedVector2Array = PackedVector2Array()
	# Outer arc (clockwise)
	for i in range(steps + 1):
		var a: float = from_angle + sweep * (float(i) / float(steps))
		points.append(Vector2(cos(a), sin(a)) * outer_r)
	# Inner arc (counter-clockwise, closes the ring shape)
	for i in range(steps + 1):
		var a: float = from_angle + sweep * (float(steps - i) / float(steps))
		points.append(Vector2(cos(a), sin(a)) * inner_r)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color   = color
	return poly

func _clear_demolish_arc() -> void:
	if _demolish_arc != null:
		_demolish_arc.queue_free()
		_demolish_arc = null

func _cancel_demolish() -> void:
	_demolish_active  = false
	_demolish_timer   = 0.0
	_demolish_anchor  = Vector2i(-9999, -9999)
	_clear_demolish_arc()

# Called by BuildingInspector after player confirms removal in the dialog.
func arm_demolish(anchor: Vector2i) -> void:
	_demolish_armed        = true
	_demolish_armed_anchor = anchor
	# Show a floating hint label near the building
	if _demolish_arm_label == null:
		_demolish_arm_label               = Label.new()
		_demolish_arm_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2, 1.0))
		_demolish_arm_label.add_theme_font_size_override("font_size", 11)
		_demolish_arm_label.z_index       = 300
		_demolish_arm_label.z_as_relative = false
		add_child(_demolish_arm_label)
	_demolish_arm_label.text     = "⚠ Hold right-click on building to remove"
	_demolish_arm_label.visible  = true
	# Position above the building sprite
	if base_grid:
		var world_pos: Vector2 = base_grid.map_to_local(anchor)
		_demolish_arm_label.position = world_pos + Vector2(-80, -80)
	# Auto-disarm after 12 seconds
	var t := create_tween()
	t.tween_interval(12.0)
	t.tween_callback(disarm_demolish)

func disarm_demolish() -> void:
	_demolish_armed        = false
	_demolish_armed_anchor = Vector2i(-9999, -9999)
	if _demolish_arm_label:
		_demolish_arm_label.visible = false
	_cancel_demolish()

func _complete_demolish() -> void:
	var anchor: Vector2i = _demolish_anchor
	_cancel_demolish()
	if occupied_cells.has(anchor):
		remove_building(anchor)
		AudioManager.play_build_sfx("remove")

func _setup_hover_tooltip() -> void:
	_hover_tip_panel               = Panel.new()
	_hover_tip_panel.z_index       = 250
	_hover_tip_panel.z_as_relative = false
	_hover_tip_panel.visible       = false
	_hover_tip_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.03, 0.05, 0.10, 0.95)
	s.border_color = Color(0.0, 0.75, 0.85, 0.65)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	_hover_tip_panel.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.name = "TipVBox"
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tip_panel.add_child(vb)

	add_child(_hover_tip_panel)

func _show_hover_tip(anchor: Vector2i) -> void:
	if not _hover_tip_panel: return
	var b_data = null
	var bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if bs and bs.active_buildings.has(anchor):
		b_data = bs.active_buildings[anchor]
	if b_data == null:
		return

	var vb: VBoxContainer = _hover_tip_panel.get_node_or_null("TipVBox")
	if not vb: return
	for c in vb.get_children():
		c.queue_free()

	# Name line
	_tip_label(vb, b_data.building_name,
		Color(0.0, 0.96, 1.0, 1.0), 12, true)

	# Tier
	var tier_str := "T2 (Upgraded)" if b_data.is_upgraded else "T1"
	if b_data.is_damaged:
		tier_str += "  ⚠ DAMAGED"
	_tip_label(vb, tier_str,
		Color(1.0, 0.65, 0.2, 1.0) if b_data.is_damaged else Color(0.6, 0.6, 0.65, 0.85),
		10, false)

	# Workers
	if b_data.worker_capacity > 0:
		_tip_label(vb, "Workers: %d / %d" % [b_data.workers_assigned, b_data.worker_capacity],
			Color(0.55, 0.80, 0.60, 0.90), 10, false)
	else:
		_tip_label(vb, "Passive (no workers needed)",
			Color(0.48, 0.58, 0.62, 0.80), 10, false)

	# Output preview
	if bs:
		var out: Dictionary = bs.get_effective_output(anchor)
		if out.get("power", 0.0) != 0.0:
			_tip_label(vb, "⚡ Power: %.0f kW" % out["power"],
				Color(1.0, 0.75, 0.2, 0.9), 10, false)
		if out.get("food", 0.0) > 0.0:
			_tip_label(vb, "🍲 Food: +%.0f/day" % out["food"],
				Color(0.55, 0.85, 0.45, 0.9), 10, false)
		if out.get("morale", 0.0) > 0.0:
			_tip_label(vb, "✦ Morale: +%.0f/day" % out["morale"],
				Color(0.65, 0.55, 0.95, 0.9), 10, false)

	# Position tooltip near cursor, avoiding screen edges
	_hover_tip_panel.custom_minimum_size = Vector2(160, 0)
	var local_mouse: Vector2 = get_local_mouse_position()
	_hover_tip_panel.position = local_mouse + Vector2(16, -80)
	_hover_tip_panel.visible  = true

func _tip_label(parent: VBoxContainer, text: String,
		color: Color, size: int, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	if bold:
		lbl.add_theme_font_size_override("font_size", size + 1)
	parent.add_child(lbl)

# ── selection perimeter outline ──────────────────────────────────────
func _draw_selection_outline(anchor: Vector2i, b_type: String) -> void:
	_clear_node(_selection_outline_node)

	var cells:    Array[Vector2i] = get_footprint_cells(anchor, b_type)
	var cell_set: Dictionary      = {}
	for c in cells:
		cell_set[c] = true

	var half_w: float = 32.0
	var half_h: float = 16.0
	if base_grid and base_grid.tile_set:
		half_w = base_grid.tile_set.tile_size.x * 0.5
		half_h = half_w * 0.5

	var edge_defs: Array = [
		[Vector2i( 0, -1), Vector2(     0, -half_h), Vector2( half_w,      0)],
		[Vector2i( 1,  0), Vector2( half_w,      0), Vector2(     0,  half_h)],
		[Vector2i( 0,  1), Vector2(     0,  half_h), Vector2(-half_w,      0)],
		[Vector2i(-1,  0), Vector2(-half_w,      0), Vector2(     0, -half_h)],
	]

	for cell in cells:
		var c: Vector2 = base_grid.map_to_local(cell)
		for edge in edge_defs:
			var neighbour: Vector2i = cell + edge[0]
			if not cell_set.has(neighbour):
				var line := Line2D.new()
				line.add_point(c + edge[1])
				line.add_point(c + edge[2])
				line.width         = 2.5
				line.default_color = Color(0.0, 0.95, 1.0, 1.0)   # neon cyan
				_selection_outline_node.add_child(line)

# ── snap assist ───────────────────────────────────────────────────────
func _get_snap_anchor(cursor_anchor: Vector2i) -> Vector2i:
	if occupied_cells.is_empty() or current_build_type == "":
		return cursor_anchor

	# Only activate when the cursor footprint is already near an occupied cell
	var near_occupied: bool = false
	var probe_dirs: Array[Vector2i] = [
		Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(0,0)
	]
	for cell in get_footprint_cells(cursor_anchor, current_build_type):
		for d in probe_dirs:
			if cell_to_anchor.has(cell + d):
				near_occupied = true
				break
		if near_occupied:
			break

	if not near_occupied:
		return cursor_anchor

	var best_anchor: Vector2i = cursor_anchor
	var best_adj:    int      = _count_adjacencies(cursor_anchor, current_build_type)

	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
	]
	for offset in offsets:
		var candidate: Vector2i = cursor_anchor + offset
		if is_valid_placement(candidate, current_build_type):
			var adj: int = _count_adjacencies(candidate, current_build_type)
			if adj > best_adj:
				best_adj    = adj
				best_anchor = candidate

	return best_anchor

func _count_adjacencies(anchor: Vector2i, b_type: String) -> int:
	var footprint_cells: Array[Vector2i] = get_footprint_cells(anchor, b_type)
	var fp_set: Dictionary = {}
	for cell in footprint_cells:
		fp_set[cell] = true

	var count: int = 0
	var dirs: Array[Vector2i] = [
		Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)
	]
	for cell in footprint_cells:
		for d in dirs:
			var nb: Vector2i = cell + d
			if cell_to_anchor.has(nb) and not fp_set.has(nb):
				count += 1
	return count
