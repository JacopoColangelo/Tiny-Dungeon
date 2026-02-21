local player  = require("player")
local map     = require("map")
local utils   = require("utils")
local shadows = require("shadows")

local camera = { x = 0, y = 0, lerpSpeed = 5 }
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }

-- Lighting canvases & Shader
local lightCanvas
local blurCanvas
local blurShader
local torchSize = 250

function resetGame()
    map.generate()
    shadows.updateMapEdges(map)
    
    -- Center player in the starting tile
    player.x = (map.spawnX - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    player.y = (map.spawnY - 1) * map.gridSize + (map.gridSize/2 - player.size/2)
    
    player.targetX = player.x + player.size/2
    player.targetY = player.y + player.size/2

    player.shadowPolygon = nil
    
    -- Snap camera to player immediately on reset
    camera.x = (player.x + player.size/2) - love.graphics.getWidth()/2
    camera.y = (player.y + player.size/2) - love.graphics.getHeight()/2
end

function love.load()
    love.window.setTitle("Tiny Dungeon")
    love.window.setMode(1280, 720, {resizable=false, vsync=true})
    
    -- Create canvases to draw the darkness and the blurred shadows on
    lightCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    blurCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    
    blurShader = love.graphics.newShader("blur.glsl")
    
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

    -- Visibility Polygon computation (Single Sharp Area Cast)
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    player.shadowPolygon = shadows.cast(px, py, torchSize + 20)
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

    -- 2. DRAW SHARP LIGHT MASK
    love.graphics.setCanvas({lightCanvas, stencil=true})
        -- Clear with ambient darkness (0.35 brightness = 65% dark, less heavy than before)
        love.graphics.clear(0.35, 0.35, 0.40, 1)

        love.graphics.push()
        love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
        
        local px = player.x + player.size / 2
        local py = player.y + player.size / 2

        local function drawStencil()
            if player.shadowPolygon and #player.shadowPolygon > 2 then
                for i = 1, #player.shadowPolygon - 1 do
                    local p1 = player.shadowPolygon[i]
                    local p2 = player.shadowPolygon[i+1]
                    love.graphics.polygon("fill", px, py, p1.x, p1.y, p2.x, p2.y)
                end
                local p1 = player.shadowPolygon[#player.shadowPolygon]
                local p2 = player.shadowPolygon[1]
                love.graphics.polygon("fill", px, py, p1.x, p1.y, p2.x, p2.y)
            end
        end

        love.graphics.stencil(drawStencil, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        local flicker = math.sin(love.timer.getTime() * 6) * 4
        local currentTorch = torchSize + flicker

        -- Replace blend clears the ambient grey to the pure radial lighting brightness
        love.graphics.setBlendMode("replace")
        for i = 15, 1, -1 do
            local radius = currentTorch * (i / 15)
            local fraction = i / 15
            -- The fraction dictates the brightness, reaching 1.0 (pure white/no shadow) at the core
            local brightness = (1 - fraction) + 0.35
            brightness = math.min(brightness, 1.0)
            love.graphics.setColor(brightness, brightness, brightness, 1)
            love.graphics.circle("fill", px, py, radius)
        end
        
        love.graphics.setStencilTest()
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    love.graphics.setCanvas()

    -- 3. HORIZONTAL BLUR PASS (Render to blurCanvas)
    love.graphics.setCanvas(blurCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(blurShader)
    
    -- 16.0 is the blur radius strength
    blurShader:send("direction", {1.0 / love.graphics.getWidth(), 0.0})
    blurShader:send("radius", 16.0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(lightCanvas)
    
    love.graphics.setCanvas()

    -- 4. VERTICAL BLUR PASS & APPLY TO SCREEN
    love.graphics.setShader(blurShader)
    blurShader:send("direction", {0.0, 1.0 / love.graphics.getHeight()})
    blurShader:send("radius", 16.0)
    
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(blurCanvas)
    
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    -- 4. UI
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, 10, 220, 55, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 20)
    love.graphics.print("SPACE: New Dungeon", 20, 40)
end