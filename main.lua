local player = require("player")
local map    = require("map")
local utils  = require("utils")

local camera = { x = 0, y = 0, lerpSpeed = 5 }
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }

-- Lighting (simple circular torch)
local lightCanvas
local torchSize = 250

function resetGame()
    map.generate()
    
    -- Center player in the starting tile
    player.x = (map.spawnX - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.y = (map.spawnY - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2
    
    -- Snap camera to player immediately on reset
    camera.x = (player.x + player.size/2) - love.graphics.getWidth()/2
    camera.y = (player.y + player.size/2) - love.graphics.getHeight()/2
end

function love.load()
    love.window.setTitle("Tiny Dungeon")
    love.window.setMode(1280, 720, {resizable=false, vsync=true})
    
    -- Create a canvas to draw the darkness on
    lightCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    
    resetGame()
end

function love.update(dt)
    -- Input handling
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        player.targetX = mx + camera.x
        player.targetY = my + camera.y
    end

    player.update(dt, map)

    -- Click Animation Timer
    if clickEffect.active then
        clickEffect.timer = clickEffect.timer - dt
        if clickEffect.timer <= 0 then clickEffect.active = false end
    end

    -- Camera Follow
    local targetCamX = (player.x + player.size/2) - love.graphics.getWidth()/2
    local targetCamY = (player.y + player.size/2) - love.graphics.getHeight()/2
    camera.x = camera.x + (targetCamX - camera.x) * camera.lerpSpeed * dt
    camera.y = camera.y + (targetCamY - camera.y) * camera.lerpSpeed * dt
end

function love.keypressed(key)
    if key == "space" then resetGame() end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        clickEffect.x, clickEffect.y = x + camera.x, y + camera.y
        clickEffect.timer = clickEffect.lifetime
        clickEffect.active = true
    end
end

function love.draw()
    -- 1. DRAW WORLD
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
        map.draw()
        player.draw()
        
        -- Click Visual
        if clickEffect.active then
            local p = 1 - (clickEffect.timer / clickEffect.lifetime)
            love.graphics.setColor(1, 1, 1, 1 - p)
            love.graphics.circle("line", clickEffect.x, clickEffect.y, (1 - p) * 15)
        end
    love.graphics.pop()

    -- 2. DRAW DARKNESS & SIMPLE CIRCULAR TORCH
    love.graphics.setCanvas(lightCanvas)
        love.graphics.clear(0, 0, 0, 0.97)

        local screenX = (player.x + player.size / 2) - camera.x
        local screenY = (player.y + player.size / 2) - camera.y
        local flicker = math.sin(love.timer.getTime() * 6) * 4
        local currentTorch = torchSize + flicker

        love.graphics.setBlendMode("replace")
        for i = 1, 15 do
            local radius = currentTorch * (i / 15)
            local alpha = i / 15
            love.graphics.setColor(0, 0, 0, 1 - alpha)
            love.graphics.circle("fill", screenX, screenY, radius)
        end
        love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()

    -- 3. APPLY DARKNESS TO SCREEN
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(lightCanvas)

    -- 4. UI
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, 10, 220, 55, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 20)
    love.graphics.print("SPACE: New Dungeon", 20, 40)
end