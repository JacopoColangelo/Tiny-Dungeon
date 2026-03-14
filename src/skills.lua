-- skills.lua
-- Registry of all skill tree nodes in Tiny Dungeon.
-- Each skill has a grid position (col, row), a soul cost, an optional
-- prerequisite skill id, and an onUnlock callback applied once to the player.

local skills = {}

-- ── Registry ──────────────────────────────────────────────────────────────────

-- Ordered list used for deterministic iteration (draw order, layout)
skills.list = {

    -- ── Column 0: Survival ────────────────────────────────────────────────────
    {
        id          = "vitality_1",
        name        = "Vitality I",
        description = "Reinforce your body. Permanently increases maximum health by 1.",
        cost        = 10,
        requires    = nil,
        col         = 0,
        row         = 0,
        onUnlock    = function(player)
            player.maxHp = player.maxHp + 1
            player.hp    = player.hp + 1   -- also heal the new point
        end,
    },
    {
        id          = "vitality_2",
        name        = "Vitality II",
        description = "Harden your resolve. Permanently increases maximum health by 1 again.",
        cost        = 25,
        requires    = "vitality_1",
        col         = 0,
        row         = 1,
        onUnlock    = function(player)
            player.maxHp = player.maxHp + 1
            player.hp    = player.hp + 1
        end,
    },

    -- ── Column 1: Combat ──────────────────────────────────────────────────────
    {
        id          = "sweep_damage",
        name        = "Sweep Damage",
        description = "Channel more force into your sweep. Increases sweep damage by 10.",
        cost        = 15,
        requires    = nil,
        col         = 1,
        row         = 0,
        onUnlock    = function(player)
            player.skills.sweep.damage = player.skills.sweep.damage + 10
        end,
    },
    {
        id          = "sweep_haste",
        name        = "Sweep Haste",
        description = "Sharpened reflexes. Reduces sweep cooldown by 20%.",
        cost        = 30,
        requires    = "sweep_damage",
        col         = 1,
        row         = 1,
        onUnlock    = function(player)
            player.skills.sweep.cooldown = player.skills.sweep.cooldown * 0.80
        end,
    },

    -- ── Column 2: Utility ─────────────────────────────────────────────────────
    {
        id          = "torchbearer",
        name        = "Torchbearer",
        description = "A brighter flame. Expands your torch radius by 50.",
        cost        = 8,
        requires    = nil,
        col         = 2,
        row         = 0,
        onUnlock    = function(player)
            player.torchSize = player.torchSize + 50
        end,
    },
    {
        id          = "swiftness",
        name        = "Swiftness",
        description = "Light-footed movement. Permanently increases movement speed by 30.",
        cost        = 20,
        requires    = "torchbearer",
        col         = 2,
        row         = 1,
        onUnlock    = function(player)
            player.speed = player.speed + 30
        end,
    },
}

-- Quick lookup by id
skills.registry = {}
for _, sk in ipairs(skills.list) do
    skills.registry[sk.id] = sk
end

function skills.get(id)
    return skills.registry[id]
end

return skills
