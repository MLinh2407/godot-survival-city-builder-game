extends Node

# ─────────────────────────────────────────────────────────────────────────────
# SOURCE ID
# ─────────────────────────────────────────────────────────────────────────────
const FLOOR_SOURCE_ID: int = 0

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 0 — Void (auto pre-filled on startup across entire map)
# ─────────────────────────────────────────────────────────────────────────────
const M8_VOID:              Vector2i = Vector2i(3, 1)

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1 — Base Floor (hand-painted in TileMap editor)
# These constants are here for reference when painting and for restore-on-remove.
# ─────────────────────────────────────────────────────────────────────────────
const M1_DRY_CONCRETE:      Vector2i = Vector2i(0, 0)
const M2_WET_CONCRETE:      Vector2i = Vector2i(1, 0)
const M3_ROCK_FLOOR:        Vector2i = Vector2i(2, 0)
const M4_CRACKED_CONCRETE:  Vector2i = Vector2i(3, 0)
const M6_PATHWAY:           Vector2i = Vector2i(1, 1)
const M7_MEMORIAL_GROUND:   Vector2i = Vector2i(2, 1) 
const M12A_TRANSITION:      Vector2i = Vector2i(0, 3)
const M12B_TRANSITION:      Vector2i = Vector2i(1, 3)
const M12C_TRANSITION:      Vector2i = Vector2i(2, 3) 
const M12D_TRANSITION:      Vector2i = Vector2i(3, 3) 

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2 — Special Floor (auto-placed by code)
# ─────────────────────────────────────────────────────────────────────────────
const M5_STORM_DAMAGED:     Vector2i = Vector2i(0, 1)  # placed on Day 35 over unshielded buildings
const M13_WATER_L:          Vector2i = Vector2i(0, 4)  
const M13_WATER_R:          Vector2i = Vector2i(1, 4) 

# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3 — Decals (auto-placed + player-placed)
# ─────────────────────────────────────────────────────────────────────────────
const M14_DEBRIS:           Vector2i = Vector2i(2, 4)  
const M15_FOUNDATION:       Vector2i = Vector2i(3, 4) 

# Player-placed decoration tiles
const M9A_NEON_H:           Vector2i = Vector2i(0, 2)
const M9B_NEON_D:           Vector2i = Vector2i(1, 2)
const M10_CABLE_H:          Vector2i = Vector2i(2, 2)
const M11_CABLE_D:          Vector2i = Vector2i(3, 2)

# ─────────────────────────────────────────────────────────────────────────────
# DECORATION TYPE → ATLAS COORDS
# Keys must exactly match the decoration type strings used in BuildMenu.gd
# ─────────────────────────────────────────────────────────────────────────────
const DECORATION_TILE_MAP: Dictionary = {
	"neon_h":  M9A_NEON_H,
	"neon_d":  M9B_NEON_D,
	"cable_h": M10_CABLE_H,
	"cable_d": M11_CABLE_D,
}