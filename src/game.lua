local player   = require("src.player")
local map      = require("src.map")
local shadows  = require("src.shadows")
local enemy    = require("src.enemy")
local camera   = require("src.camera")
local hud      = require("src.hud")
local lighting = require("src.lighting")
local hub      = require("src.hub")
local pause    = require("src.pause")
local soul     = require("src.soul")

local game = {}

-- Rendering references (assigned in refreshCanvas or passed in draw)
local screenCanvas
local ambient
local gameOverSound
local highlightShader
local objectCanvas

local gameState = "play"   -- "play" | "gameover"
local levelType = "hub"    -- "hub"  | "dungeon"
local hitStopTimer = 0
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }

local portalPromptAlpha = 0
local portalShadowPolygon = nil

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
    player.hp = player.maxHp
    
    if gameOverSound then gameOverSound:stop() end
    if ambient then
        ambient:setVolume(0.5)
        ambient:play()
    end
    
    -- Place player at hub spawn
    local sx, sy = hub.getSpawnWorldPos()
    player.x = sx - player.size/2
    player.y = sy - player.size/2
    player.targetX = sx
    player.targetY = sy
    player.shadowPolygon = nil
    
    portalPromptAlpha = 0
    
    camera.snapTo(player)
    enemy.init()
    soul.init()
    hub.portalParticles = {}
end

local function loadDungeon()
    map.generate()
    shadows.updateMapEdges(map)
    
    levelType = "dungeon"
    gameState = "play"
    player.hp = player.maxHp
    
    if gameOverSound then gameOverSound:stop() end
    if ambient then
        ambient:setVolume(0.5)
        ambient:play()
    end
    
    -- Center player in starting tile
    player.x = (map.spawnX - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.y = (map.spawnY - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2
    player.shadowPolygon = nil
    
    portalPromptAlpha = 0
    
    camera.snapTo(player)

    -- Spawn enemies
    enemy.init()
    soul.init()
    local px = player.x + player.size/2
    local py = player.y + player.size/2
    for i = 1, 3 do
        enemy.spawn(map, px, py)
    end
end

function game.load()
    game.refreshCanvas()
    highlightShader = love.graphics.newShader("assets/shaders/highlight.glsl")
    hud.load()
    soul.load()

    -- Audio
    ambient = love.audio.newSource("assets/audio/dark_amb_01.wav", "stream")
    ambient:setLooping(true)
    ambient:setVolume(0.5)
    ambient:play()

    gameOverSound = love.audio.newSource("assets/audio/game_over.wav", "static")
end

function game.getCanvas() return screenCanvas end
function game.getShader() return crtShader end

-- ── Update ───────────────────────────────────────────────────────────────────

function game.update(dt, vx, vy, isPaused)
    -- Hit-Stop
    if hitStopTimer > 0 then
        hitStopTimer = hitStopTimer - dt
        return
    end

    if isPaused then return end

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
        enemy.update(dt, player, map)
        soul.update(dt, player, map)
        hub.updatePortal(dt, map)
    else
        hub.updatePortal(dt, hub)
        hub.updateGrass(dt, player)
        hub.updateRain(dt, camera.x, camera.y)
        hub.updateClouds(dt, player)
        if enemy.showSlots then
            -- Update slots in Hub if requested for debug visibility
            enemy.updateSlots(player.x + player.size/2, player.y + player.size/2, currentMap())
        end
    end

    -- Click Animation
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
    -- Only cull if very far away (well off-screen)
    if distSq < 1500 * 1500 then
        portalShadowPolygon = shadows.cast(pWX, pWY, 700)
    else
        portalShadowPolygon = nil
    end

    -- Portal check
    if currentMap().isOnPortal(player.x, player.y) then
        portalPromptAlpha = math.min(1, portalPromptAlpha + dt * 4)
    else
        portalPromptAlpha = math.max(0, portalPromptAlpha - dt * 4)
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
            if ambient then ambient:setVolume(0.1) end
        end
    else
        -- Safety: keep hp max in hub
        player.hp = player.maxHp
    end
end

-- ── Input ────────────────────────────────────────────────────────────────────

function game.keypressed(key)
    if gameState == "play" then
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
            end
        end

        if levelType == "dungeon" then
            if key == "space" then loadDungeon() end -- regenerate dungeon
        end
        if key == "v" then enemy.showSlots = not enemy.showSlots end
        if key == "k" and levelType == "dungeon" then
            local dmg = 0.5 + love.math.random() * 0.75
            player.hp = math.max(0, player.hp - dmg)
        end
        hud.keypressed(key)
    elseif gameState == "gameover" then
        if key == "r" then game.loadHub() end  -- respawn in hub
        if key == "q" then love.event.quit() end
    end
end

function game.mousepressed(vx, vy, button, isPaused)
    if isPaused then
        pause.mousepressed(vx, vy, button)
        return
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
        elseif vx >= btns.quit.x and vx <= btns.quit.x + btns.quit.w and
               vy >= btns.quit.y and vy <= btns.quit.y + btns.quit.h then
            love.event.quit()
        end
    end
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function game.draw(canvas, isPaused, vx, vy)
    screenCanvas = canvas -- keep reference for lighting module
    local w, h = 1280, 720

    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- 1. Game World
    love.graphics.push()
        camera.updateShake(love.timer.getDelta())
        local sx, sy = camera.getShakeOffset()
        love.graphics.translate(-math.floor(camera.x) + sx, -math.floor(camera.y) + sy)
        
        if levelType == "hub" then
            hub.draw(camera)
            hub.drawRain(camera, false)   -- base rain pass (before lighting)
            -- Draw portal to objectCanvas for highlight
            love.graphics.setCanvas(objectCanvas)
            love.graphics.clear(0,0,0,0)
            love.graphics.push()
            love.graphics.origin()
            hub.drawPortal(100, 100, 60) -- Scaled for 720p bigger portal
            love.graphics.pop()
            love.graphics.setCanvas(screenCanvas)
            
            local px, py = hub.getPortalWorldPos()
            if portalPromptAlpha > 0.01 then
                highlightShader:send("highlightColor", {0.8, 0.6, 1.0})
                highlightShader:send("stepSize", {1/200, 1/200})
                love.graphics.setShader(highlightShader)
                love.graphics.setColor(1, 1, 1, portalPromptAlpha * 0.6)
                love.graphics.draw(objectCanvas, px - 100, py - 100)
                love.graphics.setShader()
            end
            
            hub.drawPortal(px, py, 60)
        else
            map.draw()
            -- Draw portal to objectCanvas for highlight
            love.graphics.setCanvas(objectCanvas)
            love.graphics.clear(0,0,0,0)
            love.graphics.push()
            love.graphics.origin()
            hub.drawPortal(100, 100, 60)
            love.graphics.pop()
            love.graphics.setCanvas(screenCanvas)
            
            local px, py = map.getPortalWorldPos()
            if portalPromptAlpha > 0.01 then
                highlightShader:send("highlightColor", {0.8, 0.6, 1.0})
                highlightShader:send("stepSize", {1/200, 1/200})
                love.graphics.setShader(highlightShader)
                love.graphics.setColor(1, 1, 1, portalPromptAlpha * 0.6)
                love.graphics.draw(objectCanvas, px - 100, py - 100)
                love.graphics.setShader()
            end
            
            hub.drawPortal(px, py, 60)
        end
        
        enemy.draw(player)
        soul.draw()
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
    if levelType == "hub" then
        hub.drawRain(camera, true)  -- additive glint pass (after lighting)
    end
    
    -- 6. UI Pass
    if portalPromptAlpha > 0 then
        local tx_world, ty_world = currentMap().getPortalWorldPos()
        local tx = tx_world - math.floor(camera.x) + sx
        local ty = ty_world - math.floor(camera.y) + sy
        
        local label = (levelType == "hub") and "Sanctuary Portal" or "Hub Portal"
        local smallFont = hud.getFont("small")
        love.graphics.setFont(smallFont)
        local ltw = smallFont:getWidth(label)
        
        local bob = math.sin(love.timer.getTime() * 1.5) * 5
        local ly = ty - 80 + bob
        
        love.graphics.setColor(0, 0, 0, 0.8 * portalPromptAlpha)
        love.graphics.print(label, tx - ltw/2 + 2, ly + 2)
        love.graphics.setColor(1, 1, 1, 1.0 * portalPromptAlpha)
        love.graphics.print(label, tx - ltw/2, ly)
    end

    hud.drawDebugPanel()
    hud.drawHUD(player)
    if levelType == "dungeon" then
        hud.drawSkillBar(player)
    end

    if portalPromptAlpha > 0 then
        local smallFont = hud.getFont("small")
        love.graphics.setFont(smallFont)
        local text = "[E] to Interact"
        local tw = smallFont:getWidth(text)
        
        local py = 600
        love.graphics.setColor(0, 0, 0, 0.5 * portalPromptAlpha)
        love.graphics.rectangle("fill", w/2 - tw/2 - 10, py - 5, tw + 20, 26, 4)
        love.graphics.setColor(0.7, 0.9, 1.0, 0.9 * portalPromptAlpha)
        love.graphics.print(text, w/2 - tw/2, py)
    end

    if gameState == "gameover" then
        hud.drawGameOver(vx, vy)
    end

    -- ── NEW: Pause Overlay pass
    if isPaused then
        pause.drawOverlay(vx, vy)
    end

    love.graphics.setCanvas()
end

return game
