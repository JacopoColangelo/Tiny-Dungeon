local dungeon_data = {}

dungeon_data.levels = {
    {
        name = "The Forsaken Halls",
        difficulty = "Normal",
        cr = 4.0,           -- Challenge Rating (Difficulty)
        width = 40,         -- Tiles wide
        height = 40,        -- Tiles high
        walkerSteps = 600,  -- Maze density
        roomChance = 0.4    -- Chance of creating a room
    },
    {
        name = "The Crimson Depths",
        difficulty = "Hard",
        cr = 6.5,
        width = 50,
        height = 50,
        walkerSteps = 900,
        roomChance = 0.3
    },
    {
        name = "The Void Cathedral",
        difficulty = "Nightmare",
        cr = 10.0,
        width = 60,
        height = 60,
        walkerSteps = 1200,
        roomChance = 0.5
    }
}

function dungeon_data.get(index)
    index = index or 1
    if index < 1 then index = 1 end
    if index > #dungeon_data.levels then index = #dungeon_data.levels end
    return dungeon_data.levels[index]
end

return dungeon_data
