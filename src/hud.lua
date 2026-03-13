local hud = {}

-- Fonts (loaded in hud.load)
local gothicTitleFont
local gothicButtonFont
local gothicSmallFont
local debugFont
local soulIconImg

-- UI state
local showUI = true

-- Death screen button definitions (for hit testing)
hud.gameOverButtons = {
    respawn = {x = 0, y = 0, w = 240, h = 60},
    quit = {x = 0, y = 0, w = 240, h = 60}
}

-- Animation state
hud.lastSouls = 0
hud.soulPulseTimer = 0

function hud.load()
    gothicTitleFont  = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 64)
    gothicButtonFont = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 20)
    gothicSmallFont  = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 12)
    debugFont        = love.graphics.newFont(12)
    soulIconImg      = love.graphics.newImage("assets/sprites/soul_icon.png")
end

function hud.getFont(name)
    if name == "title" then return gothicTitleFont
    elseif name == "button" then return gothicButtonFont
    elseif name == "small" then return gothicSmallFont
    elseif name == "debug" then return debugFont
    end
end

function hud.keypressed(key)
    if key == "h" then showUI = not showUI end
end

-- ── Debug Panel ──────────────────────────────────────────────────────────────

function hud.drawDebugPanel()
    if not showUI then return end

    love.graphics.setFont(debugFont)
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

-- ── Health Orbs ──────────────────────────────────────────────────────────────

function hud.drawHUD(player)
    local margin = 30
    local size = 12
    local spacing = 20

    -- Anchor to top-right
    local totalWidth = (player.maxHp - 1) * spacing + size
    local startX = 1280 - margin - totalWidth
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

        end
    end
    love.graphics.setBlendMode("alpha")
    
    hud.drawSouls(player)
end

function hud.drawSouls(player)
    local dt = love.timer.getDelta()
    local margin = 30
    local startY = margin + 35 -- Under health orbs

    local currentSouls = (player.soulsRun or 0) + (player.soulsTotal or 0)
    
    -- Detection for pulse effect
    if currentSouls > hud.lastSouls then
        hud.soulPulseTimer = 0.6
    end
    hud.lastSouls = currentSouls
    
    if hud.soulPulseTimer > 0 then
        hud.soulPulseTimer = math.max(0, hud.soulPulseTimer - dt)
    end

    -- Format: Total (+Run)
    local soulsText = tostring(player.soulsTotal or 0)
    if (player.soulsRun or 0) > 0 then
        soulsText = soulsText .. " (+" .. player.soulsRun .. ")"
    end
    
    local font = gothicButtonFont
    love.graphics.setFont(font)
    local textWidth = font:getWidth(soulsText)
    
    -- Pulse scaling
    local pulse = hud.soulPulseTimer / 0.6
    local iconScalePulse = 1.0 + math.sin(pulse * math.pi) * 0.5
    local textScalePulse = 1.0 + math.sin(pulse * math.pi) * 0.2
    
    local iconSize = 48
    local iconPadding = 8
    local totalW = iconSize + iconPadding + textWidth
    
    -- Calculate alignment with health bar (startX)
    local healthSpacing = 20
    local healthSize = 12
    local healthTotalWidth = (player.maxHp - 1) * healthSpacing + healthSize
    local healthStartX = 1280 - margin - healthTotalWidth
    
    local x = (healthStartX + healthTotalWidth) - totalW
    local y = startY - 8

    -- Center point for the icon (base position)
    local cx, cy = x + iconSize/2, y + iconSize/2

    -- Draw Soul Icon with pulse scaling and flicker
    love.graphics.setBlendMode("add")
    local t = love.timer.getTime()
    local flicker = math.sin(t * 10) * 0.1 + 0.9
    
    love.graphics.setColor(1, 1, 1, 0.9 * flicker)
    love.graphics.draw(soulIconImg, cx, cy, 0, (iconSize/soulIconImg:getWidth()) * iconScalePulse, (iconSize/soulIconImg:getHeight()) * iconScalePulse, soulIconImg:getWidth()/2, soulIconImg:getHeight()/2)
    love.graphics.setBlendMode("alpha")

    -- Draw Counter
    if pulse > 0 then
        love.graphics.setColor(0.5, 1, 1, 0.9 + pulse * 0.1)
    else
        love.graphics.setColor(1, 1, 1, 0.9)
    end
    
    local textHeight = font:getHeight()
    local tx = x + iconSize + iconPadding
    local ty = cy -- Align text center with icon center
    
    -- Draw text with pulse scaling, origin at vertical center
    love.graphics.print(soulsText, tx, ty, 0, textScalePulse, textScalePulse, 0, textHeight/2)
end

-- ── Skill Bar ────────────────────────────────────────────────────────────────

function hud.drawSkillBar(player)
    local w, h = 1280, 720
    local boxSize = 36
    local barW = boxSize + 14
    local barH = boxSize + 14
    local bx = w/2 - barW/2
    local by = h - barH - 18

    -- Background Bar (Glassy/Stone)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", bx-2, by+2, barW, barH, 4)
    love.graphics.setColor(0.08, 0.08, 0.08, 0.9)
    love.graphics.rectangle("fill", bx, by, barW, barH, 4)

    -- Sweep Skill Box
    local sx = bx + (barW - boxSize)/2
    local sy = by + (barH - boxSize)/2
    local skill = player.skills.sweep

    -- Draw box (Stone style)
    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.rectangle("fill", sx, sy, boxSize, boxSize, 2)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.6, 0.6, 0.55, 0.4)
    love.graphics.rectangle("line", sx, sy, boxSize, boxSize, 2)

    -- Cooldown overlay
    if skill.timer > 0 then
        local pct = skill.timer / skill.cooldown
        -- Vibrant Crimson Overlay
        love.graphics.setColor(0.8, 0, 0, 0.6)
        love.graphics.rectangle("fill", sx, sy + boxSize * (1 - pct), boxSize, boxSize * pct, 2)
        -- Top "shimmer" line
        love.graphics.setColor(1, 0.4, 0.4, 0.8)
        love.graphics.rectangle("fill", sx, sy + boxSize * (1 - pct), boxSize, 1)
    else
        -- Ready Flash/Glow
        local flash = math.sin(love.timer.getTime() * 8) * 0.5 + 0.5
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0, 0.8, 1, 0.2 * flash)
        love.graphics.rectangle("fill", sx, sy, boxSize, boxSize, 2)
        love.graphics.setBlendMode("alpha")
    end

    -- Label "RMB"
    love.graphics.setFont(gothicButtonFont)
    love.graphics.setColor(0.8, 0.8, 0.7, 0.8)
    love.graphics.print("RMB", sx + 3, sy + 1, 0, 0.45, 0.45)

    -- Icon: Stylized Slash
    love.graphics.setLineWidth(2)
    love.graphics.setBlendMode("add")
    if skill.timer <= 0 then
        love.graphics.setColor(0, 1, 1, 0.6) -- Bright cyan when ready
    else
        love.graphics.setColor(1, 1, 1, 0.15) -- Dim when on cooldown
    end
    love.graphics.line(sx + 10, sy + 30, sx + 30, sy + 10)
    love.graphics.setBlendMode("alpha")
end

-- ── Stone Tablet Button (reusable) ───────────────────────────────────────────

function hud.drawStoneTablet(x, y, w, h, text, isHover, isDisabled)
    -- 1. Heavy Stone Shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x + 5, y + 5, w, h, 2)

    -- 2. Tablet Base
    if isDisabled then
        love.graphics.setColor(0.08, 0.08, 0.08, 0.7)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.35, 0.35, 0.33, 0.4)
    elseif isHover then
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
    if isDisabled then
        love.graphics.setColor(0.4, 0.4, 0.38, 0.4) -- Dim when disabled
    elseif isHover then 
        love.graphics.setColor(1, 1, 0.9, 0.85) -- Brighter on hover
    else 
        love.graphics.setColor(0.85, 0.85, 0.8, 0.65) -- Faded ivory idle
    end
    love.graphics.print(text, tx, ty)
end

-- ── Game Over Screen ─────────────────────────────────────────────────────────

function hud.drawGameOver(mx, my)
    local w, h = 1280, 720
    -- mx, my should be virtual coordinates from main.lua

    -- 1. Deep Abyssal Veil
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.01, 0.01, 0.01, 0.98)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- 2. "You have died" (Metamorphous Title)
    love.graphics.setFont(gothicTitleFont)
    local title = "You have died"
    local tw = gothicTitleFont:getWidth(title)
    local th = gothicTitleFont:getHeight()
    local tx, ty = w/2 - tw/2, h/2 - 110

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

    -- Stone Tablet sizes for Game Over
    hud.gameOverButtons.respawn.w = 200
    hud.gameOverButtons.respawn.h = 50
    hud.gameOverButtons.quit.w = 200
    hud.gameOverButtons.quit.h = 50

    -- 4. Chipped Stone Buttons
    local btnSpacing = 40
    local totalW = hud.gameOverButtons.respawn.w + hud.gameOverButtons.quit.w + btnSpacing
    local startX_btns = w/2 - totalW/2
    local btnY = lineY + 50

    local btns = {
        {id = "respawn", text = "Respawn"},
        {id = "quit", text = "Quit"}
    }

    for i, b in ipairs(btns) do
        local btnObj = hud.gameOverButtons[b.id]
        btnObj.x = startX_btns + (i-1) * (btnObj.w + btnSpacing)
        btnObj.y = btnY

        local isHover = mx >= btnObj.x and mx <= btnObj.x + btnObj.w and
                        my >= btnObj.y and my <= btnObj.y + btnObj.h

        hud.drawStoneTablet(btnObj.x, btnObj.y, btnObj.w, btnObj.h, b.text, isHover, false)
    end

    -- Reset to default font
    love.graphics.setNewFont(12) 
end

return hud
