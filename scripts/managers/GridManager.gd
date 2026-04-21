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

const GRID_BOUNDS_MIN = Vector2i(-5, -5)
const GRID_BOUNDS_MAX = Vector2i(5,  5)

const BUILDING_GROUND_FACTOR: float = 0.25

var occupied_cells:  Dictionary = {}   
var cell_to_anchor:  Dictionary = {}   
var anchor_to_type:  Dictionary = {}   

@onready var base_grid:          TileMapLayer = $BaseGrid
@onready var ghost_sprite:       Sprite2D     = $GhostSprite
@onready var hover_cursor:       Sprite2D     = $HoverCursor
@export  var building_container: Node2D
@export  var building_scenes:    Dictionary   = {}

var current_build_type:  String      = ""
var current_build_scene: PackedScene = null

# Cached per build-mode session so _process doesn't recompute every frame
var _ghost_y_offset: float = 0.0

var _footprint_node: Node2D
var _last_fp_anchor: Vector2i = Vector2i(-9999, -9999)
var _last_fp_valid:  bool     = false
var _hover_highlight:     Node2D
var _selection_highlight: Node2D
var _last_hovered_anchor: Vector2i = Vector2i(-9999, -9999)
var _selected_anchor:     Vector2i = Vector2i(-9999, -9999)

# ── _ready ───────────────────────────────────────────────────────────────────
func _ready() -> void:
    ghost_sprite.visible = false
    hover_cursor.visible = false
    ghost_sprite.z_index = 100

    # Footprint fill — absolute z=1, above base grid tiles (z=0)
    _footprint_node              = Node2D.new()
    _footprint_node.z_index      = 1
    _footprint_node.z_as_relative = false
    add_child(_footprint_node)

    # Hover outline — absolute z=2
    _hover_highlight              = Node2D.new()
    _hover_highlight.z_index      = 2
    _hover_highlight.z_as_relative = false
    add_child(_hover_highlight)

    # Selection outline — absolute z=3
    _selection_highlight              = Node2D.new()
    _selection_highlight.z_index      = 3
    _selection_highlight.z_as_relative = false
    add_child(_selection_highlight)

    # Buildings render above all overlays — absolute z=4
    if building_container:
        building_container.z_index      = 4
        building_container.z_as_relative = false

    # Ghost is absolute z=100 (above everything during placement)
    ghost_sprite.z_as_relative = false

    # GridManager listens to its own signals to drive selection highlight
    building_selected.connect(_on_selection_changed)
    building_deselected.connect(_on_selection_cleared)

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

func _get_y_offset(b_sprite: Sprite2D, scale_factor: float) -> float:
    if b_sprite and b_sprite.texture:
        return -float(b_sprite.texture.get_height()) * scale_factor * BUILDING_GROUND_FACTOR
    return 0.0

# ── Footprint overlay ─────────────────────────────────────────────────────────
func _rebuild_footprint_overlay(anchor: Vector2i, b_type: String, valid: bool) -> void:
    for child in _footprint_node.get_children():
        child.queue_free()

    var color: Color = Color(0.20, 1.00, 0.30, 0.50) if valid \
                                                      else Color(1.00, 0.20, 0.20, 0.50)

    var half_w: float = 32.0
    var half_h: float = 16.0
    if base_grid and base_grid.tile_set:
        half_w = base_grid.tile_set.tile_size.x * 0.5
        half_h = half_w * 0.5   

    for cell in get_footprint_cells(anchor, b_type):
        var c: Vector2 = base_grid.map_to_local(cell)
        var poly := Polygon2D.new()
        poly.polygon = PackedVector2Array([
            c + Vector2(     0, -half_h),   # top
            c + Vector2( half_w,      0),   # right
            c + Vector2(     0,  half_h),   # bottom
            c + Vector2(-half_w,      0),   # left
        ])
        poly.color = color
        _footprint_node.add_child(poly)

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
    ghost_sprite.visible  = false
    ghost_sprite.texture  = null
    ghost_sprite.modulate = Color.WHITE
    _clear_footprint_overlay()

# ── _process ───────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
    var local_mouse: Vector2 = get_local_mouse_position()
    var map_pos: Vector2i    = base_grid.local_to_map(local_mouse)

    if current_build_scene != null:
        # ── BUILD MODE ───────────────────────────────────────────────────────
        hover_cursor.visible = false
        ghost_sprite.visible = true
        _clear_node(_hover_highlight)
        _last_hovered_anchor = Vector2i(-9999, -9999)

        ghost_sprite.position = base_grid.map_to_local(map_pos)                \
                              + get_footprint_centre_offset(current_build_type) \
                              + Vector2(0.0, _ghost_y_offset)

        var valid: bool = is_valid_placement(map_pos, current_build_type)
        if map_pos != _last_fp_anchor or valid != _last_fp_valid:
            _last_fp_anchor = map_pos
            _last_fp_valid  = valid
            _rebuild_footprint_overlay(map_pos, current_build_type, valid)

    else:
        # ── SELECTION MODE ────────────────────────────────────────────────────
        ghost_sprite.visible = false
        _clear_footprint_overlay()

        # Hover highlight over whichever building tile the cursor is on
        if cell_to_anchor.has(map_pos):
            var anchor: Vector2i = cell_to_anchor[map_pos]
            hover_cursor.visible = false

            if anchor != _last_hovered_anchor:
                _last_hovered_anchor = anchor
                var b_type: String = _get_type_for_anchor(anchor)
                _draw_footprint_outline(
                    _hover_highlight, anchor, b_type,
                    Color(0.0, 0.95, 1.0, 0.85), 
                    2.0
                )
        else:
            hover_cursor.visible = false
            if _last_hovered_anchor != Vector2i(-9999, -9999):
                _clear_node(_hover_highlight)
                _last_hovered_anchor = Vector2i(-9999, -9999)

# ── Validity check ────────────────────────────────────────────────────────────
func is_valid_placement(anchor: Vector2i, b_type: String = "") -> bool:
    for cell in get_footprint_cells(anchor, b_type):
        if cell_to_anchor.has(cell):
            return false
    return true

# ── Input ──────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var map_pos: Vector2i = base_grid.local_to_map(get_local_mouse_position())

        if event.button_index == MOUSE_BUTTON_LEFT:
            if current_build_scene != null:
                if is_valid_placement(map_pos, current_build_type):
                    place_building(map_pos)
                else:
                    AudioManager.play_build_sfx("invalid")
            else:
                if cell_to_anchor.has(map_pos):
                    building_selected.emit(cell_to_anchor[map_pos])
                else:
                    building_deselected.emit()

        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if current_build_scene != null:
                exit_build_mode()
            elif cell_to_anchor.has(map_pos):
                remove_building(cell_to_anchor[map_pos])

    if event is InputEventKey and event.pressed:
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
    new_building.position   = base_grid.map_to_local(anchor)                    \
                            + get_footprint_centre_offset(current_build_type)   \
                            + Vector2(0.0, _get_y_offset(b_sprite, sf))

    building_container.add_child(new_building)
    occupied_cells[anchor] = new_building
    anchor_to_type[anchor] = current_build_type
    for cell in get_footprint_cells(anchor, current_build_type):
        cell_to_anchor[cell] = anchor

    building_placed.emit(current_build_type, anchor)
    _clear_footprint_overlay()

func remove_building(anchor: Vector2i) -> void:
    if not occupied_cells.has(anchor): return
    occupied_cells[anchor].queue_free()
    occupied_cells.erase(anchor)
    anchor_to_type.erase(anchor)
    var to_erase: Array[Vector2i] = []
    for cell in cell_to_anchor:
        if cell_to_anchor[cell] == anchor:
            to_erase.append(cell)
    for cell in to_erase:
        cell_to_anchor.erase(cell)
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
    new_building.position   = base_grid.map_to_local(anchor)        \
                            + get_footprint_centre_offset(b_type)   \
                            + Vector2(0.0, _get_y_offset(b_sprite, sf))

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
func _draw_footprint_outline(
        container: Node2D,
        anchor:    Vector2i,
        b_type:    String,
        color:     Color,
        width:     float) -> void:

    _clear_node(container)

    var half_w: float = 32.0
    var half_h: float = 16.0
    if base_grid and base_grid.tile_set:
        half_w = base_grid.tile_set.tile_size.x * 0.5
        half_h = half_w * 0.5

    for cell in get_footprint_cells(anchor, b_type):
        var c: Vector2 = base_grid.map_to_local(cell)
        var line := Line2D.new()
        # Diamond: top → right → bottom → left → top (closed loop)
        line.add_point(c + Vector2(     0, -half_h))
        line.add_point(c + Vector2( half_w,      0))
        line.add_point(c + Vector2(     0,  half_h))
        line.add_point(c + Vector2(-half_w,      0))
        line.add_point(c + Vector2(     0, -half_h))
        line.width         = width
        line.default_color = color
        line.z_index       = 0
        container.add_child(line)

# Removes all children from a Node2D container safely.
func _clear_node(container: Node2D) -> void:
    if container == null: return
    for child in container.get_children():
        child.queue_free()

# Called when GridManager emits building_selected
func _on_selection_changed(anchor: Vector2i) -> void:
    _selected_anchor = anchor
    var b_type: String = _get_type_for_anchor(anchor)
    _draw_footprint_outline(
        _selection_highlight, anchor, b_type,
        Color(1.0, 0.85, 0.0, 1.0),
        3.0
    )

# Called when GridManager emits building_deselected
func _on_selection_cleared() -> void:
    _selected_anchor = Vector2i(-9999, -9999)
    _clear_node(_selection_highlight)