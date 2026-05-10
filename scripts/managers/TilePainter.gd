extends Node
# ══════════════════════════════════════════════════════════════════════════════
# TILE PAINTER
# Handles all automatic tile placement:
# M2 wet concrete, M4 cracked concrete, M6 pathways, M14 debris scatter
# ══════════════════════════════════════════════════════════════════════════════

# ── Node references (cached on first use) ─────────────────────────────────────
var _grid_sys:    Node         = null
var _base_grid:   TileMapLayer = null
var _decal_layer: TileMapLayer = null

# ── M2: Water Recycler surround cells ────────────────────────────────────────
var _wr_m2_cells: Dictionary = {}

# ── M2: Passive moisture spread ───────────────────────────────────────────────
var _auto_m2_cells: Array[Vector2i] = []
var _moisture_day_counter: int      = 0
const MOISTURE_INTERVAL:   int      = 5     
const MAX_M2_COVERAGE:     float    = 0.15  

# ── M4: Revert map — stores previous atlas before M4 overwrites ───────────────
var _m4_revert_map: Dictionary = {}

# ── M6: Currently painted pathway cells ───────────────────────────────────────
var _m6_cells: Array[Vector2i] = []

# ── M14: Currently placed debris cells ────────────────────────────────────────
var _m14_cells: Array[Vector2i] = []
const MAX_M14_COVERAGE: float   = 0.20

# ── Colony search bounds ──────────────────────────────────────────────────────
var _colony_min: Vector2i = Vector2i(-40, -40)  
var _colony_max: Vector2i = Vector2i(40, 40)    
const OUTER_ZONE_FRACTION: float = 0.30  

# ══════════════════════════════════════════════════════════════════════════════
# INIT
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_cache_refs()
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)

func _cache_refs() -> void:
	if _grid_sys and _base_grid and _decal_layer:
		return  
	_grid_sys    = get_tree().root.get_node_or_null("Main/GameWorld/GridSystem")
	if not _grid_sys:
		return
	_base_grid   = _grid_sys.get_node_or_null("BaseGrid")
	_decal_layer = _grid_sys.get_node_or_null("DecalLayer")
	if not _base_grid:
		push_warning("TilePainter: BaseGrid TileMapLayer not found under GridSystem.")
	if not _decal_layer:
		push_warning("TilePainter: DecalLayer TileMapLayer not found under GridSystem.")

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — called by BuildingSystem after placement / removal / damage
# ══════════════════════════════════════════════════════════════════════════════

## Call after any building is placed on the grid.
func on_building_placed(b_type: String, anchor: Vector2i) -> void:
	_cache_refs()
	if not _refs_valid():
		return
	match b_type:
		"water":
			_place_m2_around_water_recycler(anchor)
		"coal":
			_place_m4_coal_exhaust(anchor)
	recalculate_pathways()
	_run_debris_pass()

## Call after any building is removed from the grid.
func on_building_removed(b_type: String, anchor: Vector2i) -> void:
	_cache_refs()
	if not _refs_valid():
		return
	match b_type:
		"water":
			_revert_m2_water_recycler(anchor)
	recalculate_pathways()
	_run_debris_pass()

## Call when a building becomes damaged (unstaffed too long).
func on_building_damaged(anchor: Vector2i, b_type: String) -> void:
	_cache_refs()
	if not _refs_valid():
		return
	_place_m4_on_footprint(anchor, b_type)

## Call when a building is repaired.
func on_building_repaired(anchor: Vector2i, b_type: String) -> void:
	_cache_refs()
	if not _refs_valid():
		return
	_revert_m4_footprint(anchor, b_type)

## Call when the unrest riot sub-event fires.
func on_unrest_riot() -> void:
	_cache_refs()
	if not _refs_valid():
		return
	_place_m4_riot()

# ══════════════════════════════════════════════════════════════════════════════
# M2 — WET CONCRETE
# ══════════════════════════════════════════════════════════════════════════════

func _place_m2_around_water_recycler(anchor: Vector2i) -> void:
	var footprint: Array[Vector2i] = _grid_sys.get_footprint_cells(anchor, "water")
	# Build a set for fast lookup
	var fp_set: Dictionary = {}
	for c in footprint:
		fp_set[c] = true

	var surround: Array[Vector2i] = _get_surrounding_ring(footprint, fp_set, 2)
	var placed: Array[Vector2i]   = []

	for cell in surround:
		# Skip if another building occupies this cell
		if _grid_sys.cell_to_anchor.has(cell):
			continue
		var current_atlas: Vector2i = _safe_get_base_atlas(cell)
		# Only overwrite M1 dry concrete — never touch M4, M6, M7
		if current_atlas == TileRegistry.M1_DRY_CONCRETE:
			_set_base_tile(cell, TileRegistry.M2_WET_CONCRETE)
			placed.append(cell)

	_wr_m2_cells[anchor] = placed

func _revert_m2_water_recycler(anchor: Vector2i) -> void:
	if not _wr_m2_cells.has(anchor):
		return
	for cell in _wr_m2_cells[anchor]:
		# Only revert if the cell is still M2 (player or another system may
		# have changed it since we placed it)
		if _safe_get_base_atlas(cell) == TileRegistry.M2_WET_CONCRETE:
			_set_base_tile(cell, TileRegistry.M1_DRY_CONCRETE)
	_wr_m2_cells.erase(anchor)

# Passive moisture accumulation — runs every MOISTURE_INTERVAL days
func _run_moisture_spread() -> void:
	var total_m1: int = _count_base_tiles_matching(TileRegistry.M1_DRY_CONCRETE)
	if total_m1 == 0:
		return
	var cap: int = int(float(total_m1) * MAX_M2_COVERAGE)
	if _auto_m2_cells.size() >= cap:
		return

	var candidates: Array[Vector2i] = _get_moisture_candidates()
	if candidates.is_empty():
		return

	candidates.shuffle()
	var to_add: int = mini(2, cap - _auto_m2_cells.size())
	var added: int  = 0

	for cell in candidates:
		if added >= to_add:
			break
		# Confirm still M1 (may have changed since we built candidates list)
		if _safe_get_base_atlas(cell) == TileRegistry.M1_DRY_CONCRETE:
			_set_base_tile(cell, TileRegistry.M2_WET_CONCRETE)
			_auto_m2_cells.append(cell)
			added += 1

func _get_moisture_candidates() -> Array[Vector2i]:
	var results: Array[Vector2i] = []

	# Calculate inner zone boundary — moisture only appears in outer 30%
	var colony_w: int   = _colony_max.x - _colony_min.x
	var colony_h: int   = _colony_max.y - _colony_min.y
	# Use float division before converting to int to avoid integer division warning
	var shrink_x: int   = int(float(colony_w) * (1.0 - OUTER_ZONE_FRACTION) * 0.5)
	var shrink_y: int   = int(float(colony_h) * (1.0 - OUTER_ZONE_FRACTION) * 0.5)
	var inner_min: Vector2i = _colony_min + Vector2i(shrink_x, shrink_y)
	var inner_max: Vector2i = _colony_max - Vector2i(shrink_x, shrink_y)

	for x in range(_colony_min.x, _colony_max.x):
		for y in range(_colony_min.y, _colony_max.y):
			var cell := Vector2i(x, y)

			# Must be in the outer zone (skip inner)
			if x > inner_min.x and x < inner_max.x \
					and y > inner_min.y and y < inner_max.y:
				continue

			# Must currently be M1 dry concrete
			if _safe_get_base_atlas(cell) != TileRegistry.M1_DRY_CONCRETE:
				continue

			# Must not have a building on it
			if _grid_sys.cell_to_anchor.has(cell):
				continue

			# Must have no building within a 3-tile radius
			if _has_building_within_radius(cell, 3):
				continue

			results.append(cell)

	return results

## Returns true if any of the 3-tile radius cells around `centre` has a building.
func _has_building_within_radius(centre: Vector2i, radius: int) -> bool:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if _grid_sys.cell_to_anchor.has(centre + Vector2i(dx, dy)):
				return true
	return false

# ══════════════════════════════════════════════════════════════════════════════
# M4 — CRACKED CONCRETE
# ══════════════════════════════════════════════════════════════════════════════

# Place M4 on 2–3 cells adjacent to a Coal Generator's exhaust side
func _place_m4_coal_exhaust(anchor: Vector2i) -> void:
	var footprint: Array[Vector2i] = _grid_sys.get_footprint_cells(anchor, "coal")
	var fp_set: Dictionary = {}
	for c in footprint:
		fp_set[c] = true

	# Exhaust side = upper-right of the isometric 2×2 footprint
	var exhaust_offsets: Array[Vector2i] = [
		Vector2i(2, -1),
		Vector2i(2,  0),
		Vector2i(1, -2),
	]
	for offset in exhaust_offsets:
		var cell: Vector2i = anchor + offset
		if fp_set.has(cell):
			continue
		if _grid_sys.cell_to_anchor.has(cell):
			continue
		var prev: Vector2i = _safe_get_base_atlas(cell)
		if prev == TileRegistry.M2_WET_CONCRETE \
				or prev == TileRegistry.M7_MEMORIAL_GROUND \
				or prev == TileRegistry.M4_CRACKED_CONCRETE:
			continue
		if not _m4_revert_map.has(cell):
			_m4_revert_map[cell] = prev
		_set_base_tile(cell, TileRegistry.M4_CRACKED_CONCRETE)

# Place M4 tiles over the building's footprint when it becomes damaged
func _place_m4_on_footprint(anchor: Vector2i, b_type: String) -> void:
	for cell in _grid_sys.get_footprint_cells(anchor, b_type):
		var prev: Vector2i = _safe_get_base_atlas(cell)
		if prev == TileRegistry.M4_CRACKED_CONCRETE:
			continue
		if not _m4_revert_map.has(cell):
			_m4_revert_map[cell] = prev
		_set_base_tile(cell, TileRegistry.M4_CRACKED_CONCRETE)

# Revert M4 on footprint to the tile that was there before damage
func _revert_m4_footprint(anchor: Vector2i, b_type: String) -> void:
	for cell in _grid_sys.get_footprint_cells(anchor, b_type):
		if _safe_get_base_atlas(cell) != TileRegistry.M4_CRACKED_CONCRETE:
			continue
		if _m4_revert_map.has(cell):
			_set_base_tile(cell, _m4_revert_map[cell])
			_m4_revert_map.erase(cell)
		else:
			_set_base_tile(cell, TileRegistry.M1_DRY_CONCRETE)

# Place 3–5 random M4 tiles across the colony during an unrest riot
func _place_m4_riot() -> void:
	var candidates: Array[Vector2i] = []
	for x in range(_colony_min.x, _colony_max.x):
		for y in range(_colony_min.y, _colony_max.y):
			var cell := Vector2i(x, y)
			if _grid_sys.cell_to_anchor.has(cell):
				continue
			var atlas: Vector2i = _safe_get_base_atlas(cell)
			if atlas == TileRegistry.M1_DRY_CONCRETE \
					or atlas == TileRegistry.M6_PATHWAY:
				candidates.append(cell)

	candidates.shuffle()
	var count: int = randi_range(3, 5)
	for i in range(mini(count, candidates.size())):
		var cell: Vector2i = candidates[i]
		if not _m4_revert_map.has(cell):
			_m4_revert_map[cell] = _safe_get_base_atlas(cell)
		_set_base_tile(cell, TileRegistry.M4_CRACKED_CONCRETE)

# ══════════════════════════════════════════════════════════════════════════════
# M6 — WORN COLONIST PATHWAY
# ══════════════════════════════════════════════════════════════════════════════

func recalculate_pathways() -> void:
	var bs = get_tree().root.get_node_or_null("Main/BuildingSystem")
	if not bs:
		return

	# Step 1: revert all previous M6 cells that no longer have a building on them
	for cell in _m6_cells:
		if not _grid_sys.cell_to_anchor.has(cell):
			if _safe_get_base_atlas(cell) == TileRegistry.M6_PATHWAY:
				_set_base_tile(cell, TileRegistry.M1_DRY_CONCRETE)
	_m6_cells.clear()

	# Step 2: collect priority building pairs
	var pairs: Array = _get_priority_pairs(bs)
	if pairs.is_empty():
		return

	# Step 3: paint paths
	var painted_set: Dictionary = {}
	for pair in pairs:
		var path: Array[Vector2i] = _find_path_between(pair[0], pair[1])
		for cell in path:
			if painted_set.has(cell):
				continue
			if _grid_sys.cell_to_anchor.has(cell):
				continue
			var atlas: Vector2i = _safe_get_base_atlas(cell)
			# Only paint on M1 or existing M6 — never overwrite M2, M4, M7
			if atlas != TileRegistry.M1_DRY_CONCRETE \
					and atlas != TileRegistry.M6_PATHWAY:
				continue
			_set_base_tile(cell, TileRegistry.M6_PATHWAY)
			_m6_cells.append(cell)
			painted_set[cell] = true

## Collect up to 5 priority building anchor pairs for path generation.
func _get_priority_pairs(bs: Node) -> Array:
	var shelters:  Array[Vector2i] = []
	var hydros:    Array[Vector2i] = []
	var meds:      Array[Vector2i] = []
	var waters:    Array[Vector2i] = []
	var coals:     Array[Vector2i] = []

	for pos in bs.active_buildings:
		var b: BuildingData = bs.active_buildings[pos]
		match b.building_type:
			BuildingData.BuildingType.SHELTER_BLOCK:   shelters.append(pos)
			BuildingData.BuildingType.HYDROPONIC_BAY:  hydros.append(pos)
			BuildingData.BuildingType.MED_CLINIC:      meds.append(pos)
			BuildingData.BuildingType.WATER_RECYCLER:  waters.append(pos)
			BuildingData.BuildingType.COAL_GENERATOR:  coals.append(pos)

	var pairs: Array = []

	# Priority 1: Shelter → Hydroponic Bay
	if shelters.size() > 0 and hydros.size() > 0:
		pairs.append([shelters[0], hydros[0]])

	# Priority 2: Shelter → Med Clinic
	if shelters.size() > 0 and meds.size() > 0:
		pairs.append([shelters[0], meds[0]])

	# Priority 3: Hydroponic Bay → Water Recycler
	if hydros.size() > 0 and waters.size() > 0:
		pairs.append([hydros[0], waters[0]])

	# Priority 4: Coal Generator → nearest Shelter or Hydro
	if coals.size() > 0:
		var target: Vector2i = Vector2i.ZERO
		var found: bool = false
		if shelters.size() > 0:
			target = shelters[0]
			found  = true
		elif hydros.size() > 0:
			target = hydros[0]
			found  = true
		if found:
			pairs.append([coals[0], target])

	# Priority 5: closest remaining pair not already covered
	if pairs.size() < 5:
		var all_anchors: Array[Vector2i] = []
		for pos in bs.active_buildings:
			all_anchors.append(pos)
		if all_anchors.size() >= 2:
			var best_dist: int  = 9999
			var best_a: Vector2i = all_anchors[0]
			var best_b: Vector2i = all_anchors[1]
			for i in range(all_anchors.size()):
				for j in range(i + 1, all_anchors.size()):
					var d: int = _manhattan(all_anchors[i], all_anchors[j])
					if d < best_dist:
						best_dist = d
						best_a    = all_anchors[i]
						best_b    = all_anchors[j]
			if best_dist < 20:
				# Only add if this pair isn't already in the list
				var already_in: bool = false
				for p in pairs:
					if (p[0] == best_a and p[1] == best_b) \
							or (p[0] == best_b and p[1] == best_a):
						already_in = true
						break
				if not already_in:
					pairs.append([best_a, best_b])

	return pairs

## Greedy Manhattan path between two building footprint edge cells.
func _find_path_between(from_anchor: Vector2i, to_anchor: Vector2i) -> Array[Vector2i]:
	var from_type: String = _grid_sys.anchor_to_type.get(from_anchor, "")
	var to_type:   String = _grid_sys.anchor_to_type.get(to_anchor,   "")
	if from_type == "" or to_type == "":
		return []

	var from_fp: Array[Vector2i] = _grid_sys.get_footprint_cells(from_anchor, from_type)
	var to_fp:   Array[Vector2i] = _grid_sys.get_footprint_cells(to_anchor,   to_type)

	# Find the two closest cells between the footprints to start/end the path
	var best_dist: int     = 9999
	var start_cell: Vector2i = from_anchor
	var end_cell:   Vector2i = to_anchor

	for a in from_fp:
		for b in to_fp:
			var d: int = _manhattan(a, b)
			if d < best_dist:
				best_dist  = d
				start_cell = a
				end_cell   = b

	# Build a set of all footprint cells so we don't path through buildings
	var all_fp: Dictionary = {}
	for c in from_fp:
		all_fp[c] = true
	for c in to_fp:
		all_fp[c] = true

	var path: Array[Vector2i] = []
	var cur: Vector2i = start_cell
	var max_steps: int = best_dist + 20  
	var steps: int     = 0

	while cur != end_cell and steps < max_steps:
		var dx: int = end_cell.x - cur.x
		var dy: int = end_cell.y - cur.y

		var primary: Vector2i
		var secondary: Vector2i
		if abs(dx) >= abs(dy):
			primary   = cur + Vector2i(sign(dx), 0)
			secondary = cur + Vector2i(0, sign(dy))
		else:
			primary   = cur + Vector2i(0, sign(dy))
			secondary = cur + Vector2i(sign(dx), 0)

		# Use primary unless it cuts through an occupied building cell
		var next: Vector2i = primary
		if _grid_sys.cell_to_anchor.has(primary) and not all_fp.has(primary):
			next = secondary

		cur = next
		# Add to path only if not inside either footprint
		if not all_fp.has(cur):
			path.append(cur)
		steps += 1

	return path

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# ══════════════════════════════════════════════════════════════════════════════
# M14 — DEBRIS SCATTER
# ══════════════════════════════════════════════════════════════════════════════

func _run_debris_pass() -> void:
	if not _decal_layer:
		return

	var total_floor: int = _count_empty_floor_cells()
	if total_floor == 0:
		return

	var cap: int = int(float(total_floor) * MAX_M14_COVERAGE)
	if _m14_cells.size() >= cap:
		return

	var candidates: Array[Vector2i] = _find_debris_candidates()
	if candidates.is_empty():
		return

	candidates.shuffle()
	var max_to_add: int = cap - _m14_cells.size()
	var placed: int     = 0
	var idx: int        = 0

	while idx < candidates.size() and placed < max_to_add:
		var cell: Vector2i = candidates[idx]
		idx += 1

		# Skip if this cell already has a decal
		if _decal_layer.get_cell_source_id(cell) != -1:
			continue
		# Require at least one building-edge or rock/void neighbour
		if not _has_building_or_edge_neighbour(cell):
			continue

		# Grow a small cluster of 3–6 cells from this seed
		var cluster_size: int          = randi_range(3, 6)
		var cluster: Array[Vector2i]   = _grow_cluster(cell, cluster_size, candidates)

		for cluster_cell in cluster:
			if placed >= max_to_add:
				break
			if _decal_layer.get_cell_source_id(cluster_cell) != -1:
				continue
			_decal_layer.set_cell(
				cluster_cell,
				TileRegistry.FLOOR_SOURCE_ID,
				TileRegistry.M14_DEBRIS
			)
			_m14_cells.append(cluster_cell)
			placed += 1

func _find_debris_candidates() -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for x in range(_colony_min.x, _colony_max.x):
		for y in range(_colony_min.y, _colony_max.y):
			var cell := Vector2i(x, y)
			# Skip occupied cells
			if _grid_sys.cell_to_anchor.has(cell):
				continue
			var atlas: Vector2i = _safe_get_base_atlas(cell)
			# Must be colony floor — not rock, void, or pathway
			if atlas != TileRegistry.M1_DRY_CONCRETE \
					and atlas != TileRegistry.M2_WET_CONCRETE \
					and atlas != TileRegistry.M4_CRACKED_CONCRETE:
				continue
			results.append(cell)
	return results

func _has_building_or_edge_neighbour(cell: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for d in dirs:
		var nb: Vector2i = cell + d
		if _grid_sys.cell_to_anchor.has(nb):
			return true
		var nb_atlas: Vector2i = _safe_get_base_atlas(nb)
		if nb_atlas == TileRegistry.M3_ROCK_FLOOR \
				or nb_atlas == TileRegistry.M8_VOID \
				or nb_atlas == Vector2i(-1, -1):   # empty / out of range
			return true
	return false

## Grow a debris cluster from `origin_cell` up to `size` cells,
## staying within the provided `pool` of valid candidates.
func _grow_cluster(
		origin_cell: Vector2i,
		size: int,
		pool: Array[Vector2i]
) -> Array[Vector2i]:
	# Build a fast lookup set from the pool
	var pool_set: Dictionary = {}
	for c in pool:
		pool_set[c] = true

	var cluster: Array[Vector2i]  = [origin_cell]
	var frontier: Array[Vector2i] = [origin_cell]
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]

	while cluster.size() < size and not frontier.is_empty():
		# Pick a random frontier cell to expand from
		var pick_idx: int   = randi() % frontier.size()
		var cur: Vector2i   = frontier[pick_idx]
		frontier.remove_at(pick_idx)

		# Try each direction in random order
		var shuffled_dirs: Array[Vector2i] = dirs.duplicate()
		shuffled_dirs.shuffle()
		for d in shuffled_dirs:
			var nb: Vector2i = cur + d
			if cluster.has(nb):
				continue
			if not pool_set.has(nb):
				continue
			cluster.append(nb)
			frontier.append(nb)
			if cluster.size() >= size:
				break

	return cluster

# ══════════════════════════════════════════════════════════════════════════════
# DAILY TICK
# ══════════════════════════════════════════════════════════════════════════════

func _on_day_changed(_new_day: int) -> void:
	_moisture_day_counter += 1
	if _moisture_day_counter >= MOISTURE_INTERVAL:
		_moisture_day_counter = 0
		_cache_refs()
		if _refs_valid():
			_run_moisture_spread()

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _refs_valid() -> bool:
	return _grid_sys != null and _base_grid != null

func _set_base_tile(cell: Vector2i, atlas: Vector2i) -> void:
	_base_grid.set_cell(cell, TileRegistry.FLOOR_SOURCE_ID, atlas)

## Returns the atlas coords of the tile on BaseGrid at `cell`,
## or Vector2i(-1, -1) if the cell is empty or outside the tileset.
func _safe_get_base_atlas(cell: Vector2i) -> Vector2i:
	var source: int = _base_grid.get_cell_source_id(cell)
	if source == -1:
		return Vector2i(-1, -1)
	return _base_grid.get_cell_atlas_coords(cell)

## Returns the cells forming a ring around `footprint` up to `radius` tiles out.
## Cells that are part of `fp_set` are excluded.
func _get_surrounding_ring(
		footprint: Array[Vector2i],
		fp_set: Dictionary,
		radius: int
) -> Array[Vector2i]:
	var ring: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i( 1,  0), Vector2i(-1,  0),
		Vector2i( 0,  1), Vector2i( 0, -1),
		Vector2i( 1,  1), Vector2i(-1, -1),
		Vector2i( 1, -1), Vector2i(-1,  1),
	]
	for cell in footprint:
		for d in dirs:
			for r in range(1, radius + 1):
				var nb: Vector2i = cell + Vector2i(d.x * r, d.y * r)
				if not fp_set.has(nb):
					ring[nb] = true
	var result: Array[Vector2i] = []
	for cell in ring.keys():
		result.append(cell)
	return result

## Count tiles on BaseGrid within colony bounds that match `atlas`.
func _count_base_tiles_matching(atlas: Vector2i) -> int:
	var count: int = 0
	for x in range(_colony_min.x, _colony_max.x):
		for y in range(_colony_min.y, _colony_max.y):
			if _safe_get_base_atlas(Vector2i(x, y)) == atlas:
				count += 1
	return count

## Count empty (no building) floor cells within colony bounds.
func _count_empty_floor_cells() -> int:
	var count: int = 0
	for x in range(_colony_min.x, _colony_max.x):
		for y in range(_colony_min.y, _colony_max.y):
			var cell := Vector2i(x, y)
			if _grid_sys.cell_to_anchor.has(cell):
				continue
			var atlas: Vector2i = _safe_get_base_atlas(cell)
			if atlas == TileRegistry.M1_DRY_CONCRETE \
					or atlas == TileRegistry.M2_WET_CONCRETE \
					or atlas == TileRegistry.M4_CRACKED_CONCRETE \
					or atlas == TileRegistry.M6_PATHWAY:
				count += 1
	return count