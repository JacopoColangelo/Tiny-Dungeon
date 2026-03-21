local player    = require("src.player")
local map       = require("src.map")
local shadows   = require("src.shadows")
local enemy     = require("src.enemy")
local camera    = require("src.camera")
local hud       = require("src.hud")
local lighting  = require("src.lighting")
local hub       = require("src.hub")
local pause     = require("src.pause")
local soul      = require("src.soul")
local storage   = require("src.storage")
local ui_audio  = require("src.ui_audio")
local inventory = require("src.inventory")
local skilltree = require("src.skilltree")
local projectile= require("src.projectile")
local game = {}

-- Difficulty/Spawning Config
game.config = {
    mapCR = 4,              -- Challenge Rating for the dungeon
}

-- Rendering references (assigned in refreshCanvas or passed in draw)
local screenCanvas
local ambient
local ambientMuffled
local gameOverSound
local highlightShader
local objectCanvas

local gameState = "play"   -- "play" | "gameover"
local levelType = "hub"    -- "hub"  | "dungeon"
local hitStopTimer = 0
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }
local baseAmbientVolume = 0.5
local worldReady = false

local muffleFilter = {type = "lowpass", volume = 1.0, highgain = 0.05}
local muffleFactor = 0 -- 0: clean, 1: fully muffled
local isMuffled = false
local portalShadowPolygon = nil
local lastHoveredId = nil

function _G.hitStop(duration)
    hitStopTimer = math.max(hitStopTimer, duration)
end

-- ── Current Map Accessor (hub or dungeon map) ────────────────────────────────

local function currentMap()
    if levelType == "hub" then return hub else return map end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

function game.refreshCanvas()
    local w, h = 1280, 720
    -- screenCanvas is now owned by main.lua and passed in draw()
    objectCanvas = love.graphics.newCanvas(200, 200)
 -- Medium canvas for 720p
    lighting.load()  -- recreates lighting canvases at 720p
end

-- ── Level Loading ────────────────────────────────────────────────────────────

function game.loadHub()
    game.refreshCanvas()
    hub.generate()
    
    levelType = "hub"
    gameState = "play"
    worldReady = true
    player.hp = player.maxHp
    
    if gameOverSound then gameOverSound:stop() end
    if ambient and ambientMuffled then
        local cleanVol = 1.0 - muffleFactor
        local muffledVol = muffleFactor * 0.5
        ambient:setVolume(baseAmbientVolume * cleanVol)
        ambientMuffled:setVolume(baseAmbientVolume * muffledVol)
        ambient:play()
        ambientMuffled:play()
    end
    
    -- Place player at hub spawn
    local sx, sy = hub.getSpawnWorldPos()
    player.x = sx - player.size/2
    player.y = sy - player.size/2
    player.targetX = sx
    player.targetY = sy
    player.shadowPolygon = nil
    
    camera.snapTo(player)
    enemy.init()
    soul.init()
    hub.generate() 
end

local function loadDungeon()
    map.generate()
    shadows.updateMapEdges(map)
    
    levelType = "dungeon"
    gameState = "play"
    
    -- Center player in the new dungeon
    player.x = map.width * map.gridSize / 2
    player.y = map.height * map.gridSize / 2
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2
    player.hp = player.maxHp

    -- Spawn Enemies
    local mapCR = game.config and game.config.mapCR or 1.5
    enemy.spawnAll(map, player, mapCR)
    camera.snapTo(player)
    
    if gameOverSound then gameOverSound:stop() end
    if ambient and ambientMuffled then
        local cleanVol = 1.0 - muffleFactor
        local muffledVol = muffleFactor * 0.5
        ambient:setVolume(baseAmbientVolume * cleanVol)
        ambientMuffled:setVolume(baseAmbientVolume * muffledVol)
        ambient:play()
        ambientMuffled:play()
    end
    
    -- Center player in starting tile
    player.x = (map.spawnX - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.y = (map.spawnY - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2
    player.shadowPolygon = nil
    
    portalPromptAlpha = 0
    
    -- Spawn enemies
    enemy.init()
    soul.init()
    projectile.init()
    
    enemy.spawnAll(map, player, game.config.mapCR)
end

function game.load()
    game.refreshCanvas()
    highlightShader = love.graphics.newShader("assets/shaders/highlight.glsl")
    hud.load()
    soul.load()
    inventory.load()

    -- Audio
    ambient = love.audio.newSource("assets/audio/dark_amb_01.wav", "static")
    ambient:setLooping(true)
    ambient:setVolume(baseAmbientVolume)
    ambient:play()

    ambientMuffled = love.audio.newSource("assets/audio/dark_amb_01.wav", "static")
    ambientMuffled:setLooping(true)
    ambientMuffled:setFilter({type = "lowpass", highgain = 0.03, volume = 1.0})
    ambientMuffled:setVolume(0)
    ambientMuffled:play()

    gameOverSound = love.audio.newSource("assets/audio/game_over.wav", "static")

    _G.game = game
    _G.hud = hud
end

function game.spawnEnemyProjectile(x, y, dx, dy, params)
    projectile.spawn(x, y, dx, dy, params)
end

function game.isNotificationActive()
    return hud.isNotificationActive()
end

function game.isInventoryOpen()
    return inventory.isOpen()
end

function game.isSkillTreeOpen()
    return skilltree.isOpen()
end

function game.getCanvas() return screenCanvas end
function game.getShader() return crtShader end
function game.getLevelType() return levelType end
function game.isGameOver() return gameState == "gameover" end

-- ── Update ───────────────────────────────────────────────────────────────────

function game.mousemoved(vx, vy)
    inventory.mousemoved(vx, vy)
    skilltree.mousemoved(vx, vy)
end

function game.update(dt, vx, vy, logicPaused, audioMuffled)
    -- If save notification is highly visible, effectively pause the game
    local notificationPause = hud.isNotificationActive()

    -- Handle Audio Muffling with smooth cross-fade
    local targetMuffle = (audioMuffled or notificationPause or gameState == "gameover") and 1 or 0
    if muffleFactor ~= targetMuffle then
        local speed = 8 -- transition speed
        if muffleFactor < targetMuffle then
            muffleFactor = math.min(targetMuffle, muffleFactor + dt * speed)
        else
            muffleFactor = math.max(targetMuffle, muffleFactor - dt * speed)
        end
        
        if ambient and ambientMuffled then
            -- Cross-fade volumes instead of shifting filter coefficients (prevents artifacts)
            local cleanVol = 1.0 - muffleFactor
            local muffledVol = muffleFactor * 0.5 -- 50% volume drop for muffled version
            
            ambient:setVolume(baseAmbientVolume * cleanVol)
            ambientMuffled:setVolume(baseAmbientVolume * muffledVol)
        end
    end

    -- Hover sounds for Death / Save UI (Run even if world is paused)
    local currentHoveredId = nil
    if gameState == "gameover" then
        local btns = hud.gameOverButtons
        if vx >= btns.respawn.x and vx <= btns.respawn.x + btns.respawn.w and
           vy >= btns.respawn.y and vy <= btns.respawn.y + btns.respawn.h then
            currentHoveredId = "gameover_respawn"
        elseif vx >= btns.quit.x and vx <= btns.quit.x + btns.quit.w and
               vy >= btns.quit.y and vy <= btns.quit.y + btns.quit.h then
            currentHoveredId = "gameover_quit"
        end
    end

    if notificationPause and hud.saveNotificationRect then
        local r = hud.saveNotificationRect
        if vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h then
            currentHoveredId = "save_notification_close"
        end
    end

    if currentHoveredId ~= lastHoveredId then
        if currentHoveredId then
            ui_audio.playHover()
        end
        lastHoveredId = currentHoveredId
    end

    camera.updateShake(dt)

    -- Hit stop logic
    if hitStopTimer > 0 then
        hitStopTimer = hitStopTimer - dt
        return
    end

    -- Inventory and skill tree act as soft pauses for game logic
    local inventoryPause = inventory.isOpen()
    local skilltreePause = skilltree.isOpen()
    inventory.update(dt, vx, vy)
    if levelType == "hub" then
        skilltree.update(dt, vx, vy)
    end

    if worldReady then
        -- Update HUD with logical pause state
        hud.update(dt, logicPaused or inventoryPause or skilltreePause)
    end

    -- Save Notification and other hard pauses return early here
    if logicPaused or notificationPause or inventoryPause or skilltreePause then return end
    
    if worldReady then
        hub.update(dt, player, levelType, currentMap())

        if gameState == "gameover" then 
            if gameOverSound and gameOverSound:isPlaying() then
                local dur = gameOverSound:getDuration()
                local pos = gameOverSound:tell()
                local fadeTime = 1.5
                if pos > dur - fadeTime then
                    local alpha = (dur - pos) / fadeTime
                    gameOverSound:setVolume(math.max(0, alpha))
                end
            end
            return 
        end
        
        if gameState == "play" then
            if love.mouse.isDown(1) then
                local sx, sy = camera.getShakeOffset()
                player.targetX = vx + camera.x - sx
                player.targetY = vy + camera.y - sy
            end
        end

        player.update(dt, currentMap())
        
        if levelType == "dungeon" then
            map.update(dt, player, enemy, soul, projectile)
        end

        -- Click Animation (Keep for loop)
        if clickEffect.active then
            clickEffect.timer = clickEffect.timer - dt
            if clickEffect.timer <= 0 then clickEffect.active = false end
        end

        -- Camera
        camera.follow(player, dt)

        -- Shadow cast
        local px = player.x + player.size / 2
        local py = player.y + player.size / 2
        player.shadowPolygon = shadows.cast(px, py, player.torchSize + 20)
        
        local pWX, pWY = currentMap().getPortalWorldPos()
        local distSq = (px - pWX)^2 + (py - pWY)^2
        if distSq < 1500 * 1500 then
            portalShadowPolygon = shadows.cast(pWX, pWY, 700)
        else
            portalShadowPolygon = nil
        end

        -- Death check (dungeon only)
        if levelType == "dungeon" then
            if player.hp <= 0 and gameState == "play" then
                player.hp = 0
                player.soulsRun = 0 -- Lose souls on death
                gameState = "gameover"
                if gameOverSound then 
                    gameOverSound:setVolume(1.0)
                    gameOverSound:play() 
                end
            end
        else
            -- Safety: keep hp max in hub
            player.hp = player.maxHp
        end
    end
end

-- ── Input ────────────────────────────────────────────────────────────────────

function game.keypressed(key)
    if gameState == "play" then
        -- Tab toggles inventory
        if key == "tab" then
            if skilltree.isOpen() then return nil end
            inventory.keypressed(key)
            return nil
        end

        -- I toggles skill tree (hub only)
        if key == "i" and levelType == "hub" then
            if inventory.isOpen() then return nil end
            skilltree.keypressed(key, player)
            return nil
        end

        -- Escape closes inventory or skill tree before pause
        if key == "escape" then
            if inventory.isOpen() then
                inventory.keypressed(key)
                return nil
            elseif skilltree.isOpen() then
                skilltree.keypressed(key, player)
                return nil
            end
        end

        -- While either overlay is open, swallow other keypresses
        if inventory.isOpen() or skilltree.isOpen() then return nil end

        -- Enter/Exit portal
        if key == "e" or key == "return" then
            local px = player.x + player.size/2
            local py = player.y + player.size/2
            if levelType == "hub" and hub.isOnPortal(px, py) then
                loadDungeon()
                return
            elseif levelType == "dungeon" and map.isOnPortal(px, py) then
                -- Extract souls
                player.soulsTotal = (player.soulsTotal or 0) + (player.soulsRun or 0)
                player.soulsRun = 0
                game.loadHub()
                return
            elseif levelType == "hub" and hub.isOnSaveShrine(px, py) then
                game.saveGame()
                return
            end
        end

        if levelType == "dungeon" then
            if key == "space" then loadDungeon() end -- regenerate dungeon
        end
        if key == "v" then 
            enemy.showSlots = not enemy.showSlots 
            print("Debug Slots: " .. tostring(enemy.showSlots))
        end
        if key == "k" and levelType == "dungeon" then
            local dmg = 0.5 + love.math.random() * 0.75
            player.hp = math.max(0, player.hp - dmg)
        end
        hud.keypressed(key)
    elseif gameState == "gameover" then
        if key == "r" then game.loadHub() end  -- respawn in hub
        if key == "q" then return "menu" end
    end
    return nil
end

function game.mousepressed(vx, vy, button, isPaused)
    if isPaused then
        pause.mousepressed(vx, vy, button)
        return
    end

    -- Skill tree intercepts when open
    if skilltree.isOpen() then
        skilltree.mousepressed(vx, vy, button, player)
        return
    end

    -- Inventory intercepts ALL mouse presses when open
    if inventory.isOpen() then
        inventory.mousepressed(vx, vy, button, player)
        return
    end
    
    -- 1. Save Notification interaction (High priority intercept)
    if hud.isNotificationActive() and hud.saveNotificationRect and button == 1 then
        local r = hud.saveNotificationRect
        if vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h then
            hud.closeNotification()
            ui_audio.playClick()
            return
        end
        return -- Intercept all clicks while notification is active
    end

    if gameState == "play" then
        if button == 1 then
            local sx, sy = camera.getShakeOffset()
            clickEffect.x = vx + camera.x - sx
            clickEffect.y = vy + camera.y - sy
            clickEffect.timer = clickEffect.lifetime
            clickEffect.active = true
        elseif button == 2 and levelType == "dungeon" then
            local mx, my = vx + camera.x, vy + camera.y
            player.performSweep(mx, my, enemy.list)
        end
    elseif gameState == "gameover" and button == 1 then
        local btns = hud.gameOverButtons
        if vx >= btns.respawn.x and vx <= btns.respawn.x + btns.respawn.w and
           vy >= btns.respawn.y and vy <= btns.respawn.y + btns.respawn.h then
            game.loadHub()  -- respawn in hub
            ui_audio.playClick()
        elseif vx >= btns.quit.x and vx <= btns.quit.x + btns.quit.w and
               vy >= btns.quit.y and vy <= btns.quit.y + btns.quit.h then
            ui_audio.playClick()
            return "menu"
        end
    end

    return nil
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function game.draw(canvas, isPaused, vx, vy)
    screenCanvas = canvas -- keep reference for lighting module
    local w, h = 1280, 720

    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- 1. Game World
    love.graphics.push()
        local sx, sy = camera.getShakeOffset()
        love.graphics.translate(-math.floor(camera.x) + sx, -math.floor(camera.y) + sy)
        
        if levelType == "hub" then
            hub.drawWorld(camera, player, highlightShader, objectCanvas, screenCanvas)
        else
            map.drawWorld(hub, objectCanvas, screenCanvas)
        end
        
        enemy.draw(player)
        soul.draw()
        if levelType == "dungeon" then
            projectile.draw()
        end
        player.draw()
        
        if clickEffect.active then
            -- Store properties for drawing after lighting pass to stay bright
            clickEffect.drawReq = true
        end
    love.graphics.pop()

    -- 2–4. Lighting pass (tint/darken world)
    local pWX, pWY = currentMap().getPortalWorldPos()
    lighting.drawLightMask(screenCanvas, player, camera, sx, sy, pWX, pWY, portalShadowPolygon)

    -- Return to world coordinates for click effect
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x) + sx, -math.floor(camera.y) + sy)
        if clickEffect.drawReq then
            local p = 1 - (clickEffect.timer / clickEffect.lifetime)
            love.graphics.setColor(1, 1, 1, 1 - p)
            love.graphics.circle("line", clickEffect.x, clickEffect.y, (1 - p) * 15)
            clickEffect.drawReq = false
        end
    love.graphics.pop()

    -- 2. Emissive Bloom (Additive Overlay)
    local pWX, pWY = currentMap().getPortalWorldPos()
    lighting.drawPortalBloom(pWX, pWY, camera)
    lighting.drawBloom(player, camera) -- Player torch bloom
    
    -- 6. UI Pass
    hub.drawPrompts(camera, hud, levelType, currentMap())

    hud.drawDebugPanel()
    hud.drawHUD(player, levelType == "dungeon")
    if levelType == "dungeon" then
        hud.drawSkillBar(player)
    end
    hud.drawInventoryHint(levelType == "hub")

    if gameState == "gameover" then
        hud.drawGameOver(vx, vy)
    end

    -- ── NEW: Pause Overlay pass
    if isPaused then
        pause.drawOverlay(vx, vy)
    end

    -- ── Inventory Overlay pass
    inventory.draw(vx, vy)

    -- ── Skill Tree Overlay pass (hub only)
    if levelType == "hub" then
        skilltree.draw(vx, vy, player)
    end

    -- ── Save Notification pass
    hud.drawSaveNotificationPopup(vx, vy)

    love.graphics.setCanvas()
end



function game.saveGame()
    if storage.saveGame(player, inventory, skilltree, levelType) then
        hud.triggerSaveNotification()
    end
end

function game.loadGame()
    storage.loadGame(game, player, inventory, skilltree, camera)
end

function game.newGame()
    -- Reset Session/UI state
    hitStopTimer = 0
    clickEffect.active = false
    
    storage.newGame(game, player, inventory, skilltree)
end

function game.stop()
    worldReady = false
    gameState = "play"
    
    -- Volume reset
    if ambient and ambientMuffled then
        muffleFactor = 0
        ambient:setVolume(baseAmbientVolume)
        ambientMuffled:setVolume(0)
    end
    
    if gameOverSound then
        gameOverSound:stop()
    end
end

return game
