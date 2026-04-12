extends Node2D
class_name BuildingBase

@export var repair_cost: int = GameConstants.REPAIR_COST_BASE

var grid_pos: Vector2i = Vector2i.ZERO
var tier1_tex: Texture2D = null
var tier2_tex: Texture2D = null
var damaged_tex: Texture2D = null

@onready var sprite: Sprite2D = $Sprite2D

func set_grid_pos(p: Vector2i) -> void:
    grid_pos = p

func set_textures(t1: Texture2D, t2: Texture2D, damaged: Texture2D) -> void:
    # Store references; fall back to existing sprite texture for tier1
    if t1 != null:
        tier1_tex = t1
    elif sprite and sprite.texture:
        tier1_tex = sprite.texture
    else:
        tier1_tex = null

    tier2_tex = t2
    damaged_tex = damaged

func set_building_state(state: String) -> void:
    if not sprite:
        return
    match state:
        "tier1":
            if tier1_tex: sprite.texture = tier1_tex
        "tier2":
            if tier2_tex: sprite.texture = tier2_tex
            elif tier1_tex: sprite.texture = tier1_tex
        "damaged":
            if damaged_tex:
                sprite.texture = damaged_tex
            elif tier1_tex:
                sprite.texture = tier1_tex
        _:
            # unknown state: fallback to tier1
            if tier1_tex: sprite.texture = tier1_tex

func repair() -> bool:
    # Safety: only allow repairs when BuildingSystem has this building and it's damaged
    if not ResourceManager or not ResourceManager.building_system:
        print("BuildingBase: Missing ResourceManager or BuildingSystem; cannot repair")
        return false
    if grid_pos == Vector2i.ZERO or not ResourceManager.building_system.active_buildings.has(grid_pos):
        print("BuildingBase: Invalid grid_pos", grid_pos, "— cannot repair")
        return false
    var b_data = ResourceManager.building_system.active_buildings[grid_pos]
    if not b_data.is_damaged:
        print("BuildingBase: Building at", grid_pos, "is not damaged; no repair needed")
        return false

    # Spend materials and notify BuildingSystem to clear damaged flag
    print("BuildingBase: repair() called on grid_pos", grid_pos, "materials", ResourceManager.materials, "cost", repair_cost)
    # Use ResourceManager API so HUD and other listeners get updated via resources_changed
    if not ResourceManager.consume_materials(repair_cost):
        print("BuildingBase: Not enough materials to repair")
        return false
    print("BuildingBase: Materials after spending", ResourceManager.materials)
    # Audio handled by UI caller to provide immediate feedback
    # Inform BuildingSystem to mark repaired and refresh visuals
    if ResourceManager and ResourceManager.building_system and grid_pos != Vector2i.ZERO:
        print("BuildingBase: Notifying BuildingSystem to clear damaged at", grid_pos)
        ResourceManager.building_system.set_building_damaged(grid_pos, false)
    else:
        print("BuildingBase: Cannot notify BuildingSystem - missing ResourceManager or building_system or grid_pos=ZERO")
    return true
