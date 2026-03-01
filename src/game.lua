local player   = require("src.player")
local map      = require("src.map")
local shadows  = require("src.shadows")
local enemy    = require("src.enemy")
local camera   = require("src.camera")
local hud      = require("src.hud")
local lighting = require("src.lighting")

local game = {}

-- ── State ────────────────────────────────────────────────────────────────────

local screenCanvas
local crtShader
local ambient
local gameOverSound

local gameState = "play"
local hitStopTimer = 0
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }

function _G.hitStop(duration)
    hitStopTimer = math.max(hitStopTimer, duration)
end

-- ── Reset ────────────────────────────────────────────────────────────────────

local function resetGame()
    map.generate()
    shadows.updateMapEdges(map)
    
    gameState = "play"
    player.hp = player.maxHp
    
    if gameOverSound then gameOverSound:stop() end
    
    if ambient then
        ambient:setVolume(0.5)
        ambient:play()
    end
    
    -- Center player in the starting tile
    player.x = (map.spawnX - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.y = (map.spawnY - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2
    player.shadowPolygon = nil
    
    camera.snapTo(player)

    -- Initialize enemies
    enemy.init()
    local px = player.x + player.size/2
    local py = player.y + player.size/2
    for i = 1, 3 do
        enemy.spawn(map, px, py)
    end
end

-- ── Load ─────────────────────────────────────────────────────────────────────

function game.load()
    screenCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    crtShader    = love.graphics.newShader("assets/shaders/crt.glsl")

    hud.load()
    lighting.load()

    -- Audio
    ambient = love.audio.newSource("assets/audio/dark_amb_01.wav", "stream")
    ambient:setLooping(true)
    ambient:setVolume(0.5)
    ambient:play()

    gameOverSound = love.audio.newSource("assets/audio/game_over.wav", "static")

    resetGame()
end

-- ── Update ───────────────────────────────────────────────────────────────────

function game.update(dt)
    -- Hit-Stop (visual freeze for impact)
    if hitStopTimer > 0 then
        hitStopTimer = hitStopTimer - dt
        return
    end

    if gameState == "gameover" then 
        -- Handle game over sound fade out
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
    
    -- Input handling
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        player.targetX = mx + camera.x
        player.targetY = my + camera.y
    end

    player.update(dt, map)
    enemy.update(dt, player, map)

    -- Click Animation Timer
    if clickEffect.active then
        clickEffect.timer = clickEffect.timer - dt
        if clickEffect.timer <= 0 then clickEffect.active = false end
    end

    -- Camera
    camera.follow(player, dt)
    camera.updateShake(dt)

    -- Visibility Polygon (shadow cast)
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    player.shadowPolygon = shadows.cast(px, py, player.torchSize + 20)

    -- Death check
    if player.hp <= 0 and gameState == "play" then
        player.hp = 0
        gameState = "gameover"
        if gameOverSound then 
            gameOverSound:setVolume(1.0)
            gameOverSound:play() 
        end
        if ambient then ambient:setVolume(0.1) end
    end

    -- CRT shader time
    crtShader:send("time", love.timer.getTime())
end

-- ── Input ────────────────────────────────────────────────────────────────────

function game.keypressed(key)
    if gameState == "play" then
        if key == "space" then resetGame() end
        if key == "v" then enemy.showSlots = not enemy.showSlots end
        if key == "k" then
            local dmg = 0.5 + love.math.random() * 0.75
            player.hp = math.max(0, player.hp - dmg)
        end
        hud.keypressed(key)
    elseif gameState == "gameover" then
        if key == "r" then resetGame() end
        if key == "q" then love.event.quit() end
    end
end

function game.mousepressed(x, y, button)
    if gameState == "play" then
        if button == 1 then
            clickEffect.x, clickEffect.y = x + camera.x, y + camera.y
            clickEffect.timer = clickEffect.lifetime
            clickEffect.active = true
        elseif button == 2 then
            local mx, my = x + camera.x, y + camera.y
            player.performSweep(mx, my, enemy.list)
        end
    elseif gameState == "gameover" and button == 1 then
        local btns = hud.gameOverButtons
        if x >= btns.respawn.x and x <= btns.respawn.x + btns.respawn.w and
           y >= btns.respawn.y and y <= btns.respawn.y + btns.respawn.h then
            resetGame()
        elseif x >= btns.quit.x and x <= btns.quit.x + btns.quit.w and
               y >= btns.quit.y and y <= btns.quit.y + btns.quit.h then
            love.event.quit()
        end
    end
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function game.draw()
    -- 0. Target screen canvas
    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- 1. Draw World
    love.graphics.push()
    local sx, sy = camera.getShakeOffset()
    
    love.graphics.translate(-math.floor(camera.x) + sx, -math.floor(camera.y) + sy)
        map.draw()
        enemy.draw(player)
        player.draw()
        
        -- Click Visual
        if clickEffect.active then
            local p = 1 - (clickEffect.timer / clickEffect.lifetime)
            love.graphics.setColor(1, 1, 1, 1 - p)
            love.graphics.circle("line", clickEffect.x, clickEffect.y, (1 - p) * 15)
        end
    love.graphics.pop()

    -- 2–4. Lighting (shadow mask, blur passes)
    lighting.drawLightMask(screenCanvas, player, camera, sx, sy)

    -- 5. Player bloom
    lighting.drawBloom(player, camera)
    
    -- 6. UI & HUD
    hud.drawDebugPanel()
    hud.drawHUD(player)
    hud.drawSkillBar(player)

    if gameState == "gameover" then
        hud.drawGameOver()
    end

    -- Finish screen drawing
    love.graphics.setCanvas()

    -- 7. CRT post-processing
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(screenCanvas)
    love.graphics.setShader()
end

return game
