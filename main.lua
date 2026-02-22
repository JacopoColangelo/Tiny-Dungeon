local player  = require("player")
local map     = require("map")
local utils   = require("utils")
local shadows = require("shadows")
local enemy   = require("enemy")

local camera = { x = 0, y = 0, lerpSpeed = 5 }
local clickEffect = { x = 0, y = 0, timer = 0, lifetime = 0.3, active = false }

-- Lighting canvases & Shader
local lightCanvas
local blurCanvas
local screenCanvas
local blurShader
local crtShader
local torchSize = 250

local gothicTitleFont
local gothicButtonFont
local ambient
local gameOverSound

local gameState = "play"

-- Death screen button definitions (for hit testing)
local gameOverButtons = {
    respawn = {x = 0, y = 0, w = 240, h = 60},
    quit = {x = 0, y = 0, w = 240, h = 60}
}

function resetGame()
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
    
    -- Snap camera to player immediately on reset
    camera.x = (player.x + player.size/2) - love.graphics.getWidth()/2
    camera.y = (player.y + player.size/2) - love.graphics.getHeight()/2

    -- Initialize enemies
    enemy.init()
    local px = player.x + player.size/2
    local py = player.y + player.size/2
    for i = 1, 3 do
        enemy.spawn(map, px, py)
    end
end

function love.load()
    love.window.setTitle("Tiny Dungeon")
    love.window.setMode(1280, 720, {resizable=false, vsync=true})
    
    -- Create canvases to draw the darkness and the blurred shadows on
    lightCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    blurCanvas  = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    screenCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
    
    blurShader = love.graphics.newShader("blur.glsl")
    crtShader  = love.graphics.newShader("crt.glsl")
    
    gothicTitleFont = love.graphics.newFont("Metamorphous-Regular.ttf", 72)
    gothicButtonFont = love.graphics.newFont("Metamorphous-Regular.ttf", 22)
    
    -- Load audio sources
    ambient = love.audio.newSource("dark_amb_01.wav", "stream")
    ambient:setLooping(true)
    ambient:setVolume(0.5)
    ambient:play()

    gameOverSound = love.audio.newSource("game_over.wav", "static")
    
    resetGame()
end

function love.update(dt)
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

    -- Camera Follow
    local targetCamX = (player.x + player.size/2) - love.graphics.getWidth()/2
    local targetCamY = (player.y + player.size/2) - love.graphics.getHeight()/2
    camera.x = camera.x + (targetCamX - camera.x) * camera.lerpSpeed * dt
    camera.y = camera.y + (targetCamY - camera.y) * camera.lerpSpeed * dt

    -- Visibility Polygon computation (Single Sharp Area Cast)
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    player.shadowPolygon = shadows.cast(px, py, torchSize + 20)

    -- Death check
    if player.hp <= 0 and gameState == "play" then
        player.hp = 0
        gameState = "gameover"
        
        -- Play game over sound and fade ambient
        if gameOverSound then 
            gameOverSound:setVolume(1.0)
            gameOverSound:play() 
        end
        if ambient then ambient:setVolume(0.1) end
    end

    -- Pass constant running time to the CRT shader to animate signal static noise
    crtShader:send("time", love.timer.getTime())
end

local showUI = true

function love.keypressed(key)
    if gameState == "play" then
        if key == "space" then resetGame() end
        if key == "v" then enemy.showSlots = not enemy.showSlots end
        if key == "h" then showUI = not showUI end
        if key == "k" then
            -- Debug: Damage player by 0.5 to 1.25
            local dmg = 0.5 + love.math.random() * 0.75
            player.hp = math.max(0, player.hp - dmg)
        end
    elseif gameState == "gameover" then
        if key == "r" then resetGame() end
        if key == "q" then love.event.quit() end
    end
end

function love.mousepressed(x, y, button)
    if gameState == "play" then
        if button == 1 then
            clickEffect.x, clickEffect.y = x + camera.x, y + camera.y
            clickEffect.timer = clickEffect.lifetime
            clickEffect.active = true
        end
    elseif gameState == "gameover" and button == 1 then
        -- Check buttons
        if x >= gameOverButtons.respawn.x and x <= gameOverButtons.respawn.x + gameOverButtons.respawn.w and
           y >= gameOverButtons.respawn.y and y <= gameOverButtons.respawn.y + gameOverButtons.respawn.h then
            resetGame()
        elseif x >= gameOverButtons.quit.x and x <= gameOverButtons.quit.x + gameOverButtons.quit.w and
               y >= gameOverButtons.quit.y and y <= gameOverButtons.quit.y + gameOverButtons.quit.h then
            love.event.quit()
        end
    end
end

function love.draw()
    -- 0. TARGET SCREEN CANVAS FOR ALL WORLD + SHADOW RENDERING
    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- 1. DRAW WORLD
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
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

    -- 2. DRAW SHARP LIGHT MASK
    love.graphics.setCanvas({lightCanvas, stencil=true})
        -- Clear with pleasant dim dungeon ambient (0.35 brightness = 65% dark)
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
            local lerp = 1.0 - fraction
            
            -- Tint light to warm vibrant orange/yellow torch hue, fading perfectly into the 35% light ambient
            local r = 0.35 + (1.0 - 0.35) * lerp
            local g = 0.35 + (0.80 - 0.35) * lerp
            local b = 0.40 + (0.50 - 0.40) * lerp
            
            love.graphics.setColor(r, g, b, 1)
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

    -- 4. VERTICAL BLUR PASS & APPLY TO SCREEN CANVAS
    love.graphics.setCanvas(screenCanvas)
    love.graphics.setShader(blurShader)
    blurShader:send("direction", {0.0, 1.0 / love.graphics.getHeight()})
    blurShader:send("radius", 16.0)
    
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(blurCanvas)
    
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")

    -- 5. DRAW EMISSIVE PLAYER BLOOM
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    love.graphics.setBlendMode("add")
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    
    -- Reverted to previous warm torch bloom (circles)
    for i = 20, 1, -1 do
        local r = 50 * (i / 20)
        local a = (1 - (i / 20)) * 0.06
        love.graphics.setColor(1.0, 0.6, 0.2, a)
        love.graphics.circle("fill", px, py, r)
    end
    -- Solid white hot spark at center
    love.graphics.setColor(1, 1, 0.8, 0.8)
    love.graphics.circle("fill", px, py, 6)
    
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
    
    -- 6. UI & HUD (Drawn inside screenCanvas so CRT shader affects them)
    if showUI then
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 10, 10, 240, 120, 5)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 20)
        love.graphics.print("SPACE: New Dungeon", 20, 40)
        love.graphics.print("V: Toggle Slots", 20, 60)
        love.graphics.print("H: Hide UI", 20, 80)
        love.graphics.print("K: Damage Player", 20, 100)
    end
    drawHUD()

    if gameState == "gameover" then
        drawGameOver()
    end

    -- Finish screen drawing
    love.graphics.setCanvas()

    -- 7. APPLY CRT POST-PROCESSING
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(screenCanvas)
    love.graphics.setShader()
end

function drawHUD()
    local margin = 30
    local size = 12
    local spacing = 20
    
    -- Anchor to top-right
    local totalWidth = (player.maxHp - 1) * spacing + size
    local startX = love.graphics.getWidth() - margin - totalWidth
    local startY = margin
    
    for i = 1, player.maxHp do
        -- Deplete from Left to Right: 
        -- This means if we have 3/4 health, we draw spheres 2, 3, and 4.
        if i > (player.maxHp - player.hp) then
            local x = startX + (i-1) * spacing
            local y = startY
            
            -- Alpha for partial hits
            local healthDiff = i - (player.maxHp - player.hp)
            local alpha = math.min(1, math.max(0, healthDiff))
            
            love.graphics.setBlendMode("add")
            
            -- Outer Glow (Blocky)
            love.graphics.setColor(0.1, 0.8, 0.4, 0.2 * alpha)
            love.graphics.rectangle("fill", x-2, y+2, size+4, size-4)
            love.graphics.rectangle("fill", x+2, y-2, size-4, size+4)
            
            -- Core Pixel Orb
            love.graphics.setColor(0.3, 1.0, 0.6, 0.9 * alpha)
            love.graphics.rectangle("fill", x, y+2, size, size-4) -- Horiz
            love.graphics.rectangle("fill", x+2, y, size-4, size) -- Vert
            
            -- Highlight (Top-left pixel)
            love.graphics.setColor(1, 1, 1, 0.5 * alpha)
            love.graphics.rectangle("fill", x+3, y+3, 3, 3)
            
            love.graphics.setBlendMode("alpha")
        end
    end
end

local function drawStoneTablet(x, y, w, h, text, isHover)
    -- 1. Heavy Stone Shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x + 5, y + 5, w, h, 2)

    -- 2. Tablet Base
    if isHover then
        love.graphics.setColor(0.3, 0.28, 0.25, 0.95)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 0.9, 0.8, 1)
    else
        love.graphics.setColor(0.12, 0.12, 0.12, 0.95)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.7, 0.7, 0.65, 0.8)
    end

    -- 3. Chipped Edges
    local function chip(cx, cy, cw, ch)
        love.graphics.line(cx, cy+2, cx+2, cy)
        love.graphics.line(cx+cw-2, cy, cx+cw, cy+2)
        love.graphics.line(cx+cw, cy+ch-2, cx+cw-2, cy+ch)
        love.graphics.line(cx+2, cy+ch, cx, cy+ch-2)
    end
    chip(x, y, w, h)
    love.graphics.rectangle("line", x, y, w, h, 2)
    
    -- 4. Inset border
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12)
    
    -- 5. Typography using Metamorphous
    love.graphics.setFont(gothicButtonFont)
    local tw = gothicButtonFont:getWidth(text)
    local th = gothicButtonFont:getHeight()
    local tx, ty = x + (w/2 - tw/2), y + (h/2 - th/2)
    
    -- Text Shadow (Reduced opacity)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(text, tx + 1, ty + 1)
    
    -- Text Face (Reduced opacity for "etched" look)
    if isHover then 
        love.graphics.setColor(1, 1, 0.9, 0.85) -- Brighter on hover
    else 
        love.graphics.setColor(0.85, 0.85, 0.8, 0.65) -- Faded ivory idle
    end
    love.graphics.print(text, tx, ty)
end

function drawGameOver()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local mx, my = love.mouse.getPosition()
    
    -- 1. Deep Abyssal Veil
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.01, 0.01, 0.01, 0.98)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- 2. "You have died" (Metamorphous Title)
    love.graphics.setFont(gothicTitleFont)
    local title = "You have died"
    local tw = gothicTitleFont:getWidth(title)
    local th = gothicTitleFont:getHeight()
    local tx, ty = w/2 - tw/2, h/2 - 140
    
    -- Title Shadow (Blood Red)
    love.graphics.setColor(0.3, 0, 0, 0.8)
    love.graphics.print(title, tx + 4, ty + 4)
    
    -- Title Face (Crimson)
    love.graphics.setColor(0.6, 0.1, 0.1, 1)
    love.graphics.print(title, tx, ty)

    -- 3. Ornate Masonry Divider
    local lineY = ty + th + 10
    local lineW = math.max(600, tw + 100)
    local ivory = {0.85, 0.85, 0.8}
    
    -- Atmospheric Glow
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.4, 0.1, 0.1, 0.1)
    love.graphics.ellipse("fill", w/2, lineY, lineW/2, 12)
    love.graphics.setBlendMode("alpha")

    -- Main Line
    love.graphics.setLineWidth(1)
    for i = 0, lineW do
        local alpha = (1 - math.abs(i - lineW/2) / (lineW/2)) * 0.4
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], alpha)
        love.graphics.points(w/2 - lineW/2 + i, lineY)
    end
    
    -- Archaic Flourishes
    local function drawKnot(fx, fy)
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], 0.5)
        love.graphics.rectangle("line", fx-6, fy-6, 12, 12, 2)
        love.graphics.rectangle("fill", fx-2, fy-2, 4, 4)
    end
    drawKnot(w/2 - lineW/2, lineY)
    drawKnot(w/2 + lineW/2, lineY)
    drawKnot(w/2, lineY)

    -- 4. Chipped Stone Buttons
    local btnSpacing = 50
    local totalW = gameOverButtons.respawn.w + gameOverButtons.quit.w + btnSpacing
    local startX_btns = w/2 - totalW/2
    local btnY = lineY + 60
    
    local btns = {
        {id = "respawn", text = "Respawn"},
        {id = "quit", text = "Quit"}
    }
    
    for i, b in ipairs(btns) do
        local btnObj = gameOverButtons[b.id]
        btnObj.x = startX_btns + (i-1) * (btnObj.w + btnSpacing)
        btnObj.y = btnY
        
        local isHover = mx >= btnObj.x and mx <= btnObj.x + btnObj.w and
                        my >= btnObj.y and my <= btnObj.y + btnObj.h
        
        drawStoneTablet(btnObj.x, btnObj.y, btnObj.w, btnObj.h, b.text, isHover)
    end

    -- Reset to default font
    love.graphics.setNewFont(12) 
end