-- Storage module for Tiny Dungeon
-- Handles persistent game data using standard Lua I/O.
-- Saves are stored locally in the "save/" folder in the game root.

local storage = {}
local SAVE_DIR = "save/"
local SAVE_PATH = "save/save.data"

-- ============================================================================
-- SERIALIZATION HELPERS (Unchanged)
-- ============================================================================

local function serialize(val, indent)
    indent = indent or ""
    local t = type(val)
    
    if t == "table" then
        local s = "{\n"
        local nextIndent = indent .. "  "
        for k, v in pairs(val) do
            local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))
            s = s .. nextIndent .. key .. " = " .. serialize(v, nextIndent) .. ",\n"
        end
        return s .. indent .. "}"
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "nil"
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local dirVerified = false

-- Ensure directory exists (High-performance check to prevent stutters)
local function ensureDir()
    if dirVerified then return end
    
    -- Fast check: os.rename returns true if the directory exists on Windows
    local ok, err, code = os.rename(SAVE_DIR, SAVE_DIR)
    
    if ok or (err and (code == 13 or err:find("Permission denied"))) then
        -- Directory exists or we have no permission to rename (which means it exists)
        dirVerified = true
    else
        -- Only shell out to system if the directory is TRULY missing
        os.execute("mkdir " .. SAVE_DIR:gsub("/", "\\") .. " > nul 2>&1")
        dirVerified = true
    end
end

-- Saves the provided table to the local save folder.
function storage.save(data)
    ensureDir()
    
    local content = "return " .. serialize(data)
    local f, err = io.open(SAVE_PATH, "w")
    
    if f then
        f:write(content)
        f:close()
        return true
    else
        print("Storage Error: Failed to open save file for writing: " .. tostring(err))
        return false, err
    end
end

-- Loads the save data and returns it as a table.
function storage.load()
    local f = io.open(SAVE_PATH, "r")
    if not f then return nil end
    
    local content = f:read("*all")
    f:close()
    
    -- Use load string to evaluate the returned table
    local chunk, err = load(content)
    if chunk then
        local ok, result = pcall(chunk)
        if ok then
            return result
        else
            print("Storage Error: Failed to execute save data: " .. tostring(result))
        end
    else
        print("Storage Error: Failed to parse save file: " .. tostring(err))
    end
    return nil
end

-- Checks if a save file exists locally.
function storage.exists()
    local f = io.open(SAVE_PATH, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Deletes the save file.
function storage.delete()
    os.remove(SAVE_PATH)
end

-- ============================================================================
-- GAME SPECIFIC PERSISTENCE
-- ============================================================================

function storage.saveGame(player, inventory, skilltree, levelType)
    local saveData = {
        soulsTotal = player.soulsTotal,
        playerX = player.x,
        playerY = player.y,
        level = levelType,
        inventory = inventory.getSlots(),
        skilltree = skilltree.getUnlocked(),
    }
    local success, msg = storage.save(saveData)
    if success then
        print("Game Saved!")
        return true
    else
        print("Save failed: " .. tostring(msg))
        return false, msg
    end
end

function storage.loadGame(gameModule, player, inventory, skilltree, cameraModule)
    local data = storage.load()
    if data then
        player.soulsTotal = data.soulsTotal or 0
        player.soulsRun = 0
        player.x = data.playerX or player.x
        player.y = data.playerY or player.y
        local levelType = data.level or "hub"

        -- Inventory: restore saved slots (or fall back to starter set)
        inventory.init()
        if data.inventory then
            inventory.setSlots(data.inventory)
        else
            inventory.addItem("health_potion", 3)
        end

        -- Skill tree: restore unlocked skills
        if data.skilltree then
            skilltree.setUnlocked(data.skilltree, player)
        else
            skilltree.init()
        end
        
        if levelType == "hub" then
            gameModule.loadHub()
            -- Override position after loadHub defaults it
            player.x = data.playerX
            player.y = data.playerY
            player.targetX = player.x + player.size/2
            player.targetY = player.y + player.size/2
            if cameraModule then cameraModule.snapTo(player) end
        else
            -- We don't support saving inside dungeons yet
            gameModule.loadHub() 
            player.targetX = player.x + player.size/2
            player.targetY = player.y + player.size/2
            if cameraModule then cameraModule.snapTo(player) end
        end
        print("Game Loaded!")
        return true
    end
    return false
end

function storage.newGame(gameModule, player, inventory, skilltree)
    -- Reset Player stats
    player.maxHp = 4
    player.soulsTotal = 0
    player.soulsRun = 0
    player.hp = player.maxHp
    
    -- Reset Session/UI state
    -- (Other UI resets will happen in game.lua)

    -- Inventory: fresh start with 3 health potions
    inventory.init()
    inventory.addItem("health_potion", 3)

    -- Skill tree: fresh start
    skilltree.init()
    
    -- Switch to Hub
    gameModule.loadHub()
    print("New Game Started!")
end

-- Proactively verify directory at startup to prevent first-save stutter
ensureDir()

return storage
