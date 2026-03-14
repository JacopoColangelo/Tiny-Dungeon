-- items.lua
-- Registry of all collectible items in Tiny Dungeon.
-- Each entry defines display data, stacking rules and the onUse callback.

local items = {}

-- ── Registry ──────────────────────────────────────────────────────────────────

items.registry = {}

-- Icons are loaded lazily on first access (items.load must be called once)
local icons = {}

function items.load()
    icons["health_potion"] = love.graphics.newImage("assets/sprites/health_potion.png")
end

function items.getIcon(itemId)
    return icons[itemId]
end

-- ── Item Definitions ──────────────────────────────────────────────────────────

items.registry["health_potion"] = {
    id          = "health_potion",
    name        = "Health Potion",
    description = "A vial of crimson liquid. Restores 50% of your maximum health when consumed.",
    maxStack    = 10,
    onUse       = function(player)
        local heal = math.floor(player.maxHp * 0.5)
        player.hp = math.min(player.maxHp, player.hp + heal)
    end,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

--- Returns the item definition table for a given id, or nil.
function items.get(itemId)
    return items.registry[itemId]
end

return items
