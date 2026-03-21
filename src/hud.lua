local hud = {}

-- Fonts (loaded in hud.load)
local gothicTitleFont
local gothicButtonFont
local gothicSmallFont
local gothicTinyFont
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
hud.animTimer = 0

-- Save Notification (Moved from game.lua)
hud.saveNotificationTimer = 0
hud.saveNotificationAlpha = 0
hud.saveNotificationRect = nil

function hud.load()
    gothicTitleFont  = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 64)
    gothicButtonFont = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 20)
    gothicSmallFont  = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 12)
    gothicTinyFont   = love.graphics.newFont("assets/fonts/Metamorphous-Regular.ttf", 10)
    debugFont        = love.graphics.newFont(12)
    soulIconImg      = love.graphics.newImage("assets/sprites/soul_icon.png")
end

function hud.getFont(name)
    if name == "title" then return gothicTitleFont
    elseif name == "button" then return gothicButtonFont
    elseif name == "small" then return gothicSmallFont
    elseif name == "tiny" then return gothicTinyFont
    elseif name == "debug" then return debugFont
    end
end

function hud.keypressed(key)
    if key == "h" then showUI = not showUI end
end

function hud.update(dt, isPaused)
    -- Always tick the animation timer so UI elements (like hover glows) keep breathing
    hud.animTimer = hud.animTimer + dt

    -- Save Notification Fade
    if hud.saveNotificationTimer > 0 then
        hud.saveNotificationAlpha = math.min(1, hud.saveNotificationAlpha + dt * 4)
        hud.saveNotificationTimer = hud.saveNotificationTimer - dt
    else
        hud.saveNotificationAlpha = math.max(0, hud.saveNotificationAlpha - dt * 2)
    end

    if isPaused then return end
    
    if hud.soulPulseTimer > 0 then
        hud.soulPulseTimer = math.max(0, hud.soulPulseTimer - dt)
    end
end

function hud.triggerSaveNotification()
    hud.saveNotificationTimer = 4.0
end

function hud.isNotificationActive()
    return hud.saveNotificationAlpha > 0.05
end

function hud.closeNotification()
    hud.saveNotificationTimer = 0
end

-- ── Debug Panel ──────────────────────────────────────────────────────────────

-- Top-left margin (matches the right-side HUD margin of 30)
local HUD_MARGIN = 30

function hud.drawDebugPanel()
    if not showUI then return end

    -- Sits below the inventory hint: hint is ~24px tall, 6px gap → start at margin + 24 + 6 = 60
    local panelY = HUD_MARGIN + 30
    local panelX = HUD_MARGIN

    love.graphics.setFont(debugFont)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", panelX, panelY, 240, 120, 5)
    love.graphics.setColor(1, 1, 1, 0.9)

    local tx = panelX + 10
    love.graphics.print("FPS: " .. love.timer.getFPS(), tx, panelY + 10)
    love.graphics.print("SPACE: New Dungeon",             tx, panelY + 30)
    love.graphics.print("V: Toggle Slots",                tx, panelY + 50)
    love.graphics.print("H: Hide UI",                     tx, panelY + 70)
    love.graphics.print("K: Damage Player",                tx, panelY + 90)
end

-- ── Health Orbs ──────────────────────────────────────────────────────────────

function hud.drawHUD(player, isDungeon)
    local margin = 30
    local size = 12
    local spacing = 20

    if isDungeon then
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
    end
    love.graphics.setBlendMode("alpha")
    
    hud.drawSouls(player, isDungeon)
end

function hud.drawSouls(player, isDungeon)
    local margin = 30
    local startY = isDungeon and (margin + 35) or margin

    local currentSouls = (player.soulsRun or 0) + (player.soulsTotal or 0)
    
    -- Detection for pulse effect (Note: pulse logic is now in hud.update)
    if currentSouls > hud.lastSouls then
        hud.soulPulseTimer = 0.6
    end
    hud.lastSouls = currentSouls

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
    local flicker = math.sin(hud.animTimer * 10) * 0.1 + 0.9
    
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
        local flash = math.sin(hud.animTimer * 8) * 0.5 + 0.5
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

-- ── Inventory Hint ────────────────────────────────────────────────────────────

function hud.drawInventoryHint(showSkillHint)
    local hintText  = "[Tab] Inventory"
    local skillText = "[I] Skills"
    love.graphics.setFont(gothicSmallFont)
    local tw = gothicSmallFont:getWidth(hintText)
    local th = gothicSmallFont:getHeight()

    -- Anchored top-left, same margin as right-side HUD elements
    local hx = HUD_MARGIN
    local hy = HUD_MARGIN

    -- Inventory hint pill
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", hx - 4, hy - 3, tw + 8, th + 6, 3)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.print(hintText, hx + 1, hy + 1)
    love.graphics.setColor(0.65, 0.65, 0.60, 0.65)
    love.graphics.print(hintText, hx, hy)

    -- Skills hint pill (hub only, stacked below)
    if showSkillHint then
        local sw  = gothicSmallFont:getWidth(skillText)
        local sy2 = hy + th + 6
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.rectangle("fill", hx - 4, sy2 - 3, sw + 8, th + 6, 3)
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(skillText, hx + 1, sy2 + 1)
        love.graphics.setColor(0.65, 0.65, 0.60, 0.65)
        love.graphics.print(skillText, hx, sy2)
    end
end

-- ── Stone Tablet Button (reusable) ───────────────────────────────────────────

function hud.drawStoneTablet(x, y, w, h, text, isHover, isDisabled, parentAlpha)
    local pa = parentAlpha or 1

    -- 1. Heavy Stone Shadow
    love.graphics.setColor(0, 0, 0, 0.6 * pa)
    love.graphics.rectangle("fill", x + 5, y + 5, w, h, 2)

    -- 2. Tablet Base
    if isDisabled then
        love.graphics.setColor(0.08, 0.08, 0.08, 0.7 * pa)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.35, 0.35, 0.33, 0.4 * pa)
    elseif isHover then
        love.graphics.setColor(0.3, 0.28, 0.25, 0.95 * pa)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 0.9, 0.8, 1 * pa)
    else
        love.graphics.setColor(0.12, 0.12, 0.12, 0.95 * pa)
        love.graphics.rectangle("fill", x, y, w, h, 2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.7, 0.7, 0.65, 0.8 * pa)
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
    love.graphics.setColor(0, 0, 0, 0.4 * pa)
    love.graphics.rectangle("line", x + 6, y + 6, w - 12, h - 12)

    -- 5. Typography using Metamorphous
    love.graphics.setFont(gothicButtonFont)
    local tw = gothicButtonFont:getWidth(text)
    local th = gothicButtonFont:getHeight()
    local tx, ty = x + (w/2 - tw/2), y + (h/2 - th/2)

    -- Text Shadow
    love.graphics.setColor(0, 0, 0, 0.6 * pa)
    love.graphics.print(text, tx + 1, ty + 1)

    -- Text Face
    if isDisabled then
        love.graphics.setColor(0.4, 0.4, 0.38, 0.4 * pa)
    elseif isHover then 
        love.graphics.setColor(1, 1, 0.9, 0.85 * pa)
    else 
        love.graphics.setColor(0.85, 0.85, 0.8, 0.65 * pa)
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
    hud.gameOverButtons.respawn.w = 240
    hud.gameOverButtons.respawn.h = 50
    hud.gameOverButtons.quit.w = 240
    hud.gameOverButtons.quit.h = 50

    -- 4. Chipped Stone Buttons
    local btnSpacing = 40
    local totalW = hud.gameOverButtons.respawn.w + hud.gameOverButtons.quit.w + btnSpacing
    local startX_btns = w/2 - totalW/2
    local btnY = lineY + 50

    local btns = {
        {id = "respawn", text = "Respawn"},
        {id = "quit", text = "Main Menu"}
    }

    for i, b in ipairs(btns) do
        local btnObj = hud.gameOverButtons[b.id]
        btnObj.x = startX_btns + (i-1) * (btnObj.w + btnSpacing)
        btnObj.y = btnY

        local isHover = mx >= btnObj.x and mx <= btnObj.x + btnObj.w and
                        my >= btnObj.y and my <= btnObj.y + btnObj.h

        hud.drawStoneTablet(btnObj.x, btnObj.y, btnObj.w, btnObj.h, b.text, isHover, false)
    end

    hud.resetFont()
end

-- ── Save Notification Popup ─────────────────────────────────────────────────

function hud.drawSaveNotificationPopup(mx, my)
    local alpha = hud.saveNotificationAlpha
    if alpha <= 0 then return end
    
    local tr = hud.saveNotificationTimer / 4.0
    local w, h = 1280, 720
    local pw, ph = 500, 240
    local px, py = w/2 - pw/2, h/2 - ph/2
    
    -- Fade based on alpha (Matching menu.lua overlay)
    love.graphics.setColor(0.02, 0.02, 0.02, 0.8 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Neutral Shadow underneath (Matching menu.lua)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.4 * alpha)
    love.graphics.ellipse("fill", w/2, h/2 + 10, pw/2 + 20, ph/2 + 20)

    -- Stone Slate Dialog Box
    love.graphics.setColor(0.1, 0.1, 0.1, 0.98 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 4)
    
    -- Subtle top highlight (Ivory-ish)
    love.graphics.setColor(0.7, 0.7, 0.65, 0.2 * alpha)
    love.graphics.line(px + 4, py + 1, px + pw - 4, py + 1)
    
    -- Weathered stone border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.35, 0.35, 0.33, 0.8 * alpha)
    love.graphics.rectangle("line", px, py, pw, ph, 4)
    
    -- Success Icon (Information 'i' in Rounded Square)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.85, 0.85, 0.8, 0.7 * alpha) -- Subtle Ivory
    local cx, cy = w/2, py + 45
    local rs = 9 -- Smaller size to match warning icon scale
    
    -- Rounded Square
    love.graphics.rectangle("line", cx - rs, cy - rs, rs*2, rs*2, 4)
    
    -- The 'i'
    love.graphics.rectangle("fill", cx - 0.5, cy - 2, 1, 6) -- thinner stem
    love.graphics.rectangle("fill", cx - 0.5, cy - 5, 1, 1.5) -- dot
    
    -- Message (Matching menu.lua styling)
    love.graphics.setFont(gothicButtonFont)
    love.graphics.setColor(0.85, 0.85, 0.8, 0.9 * alpha)
    love.graphics.printf("Game Saved", px + 20, py + 85, pw - 40, "center")
    
    -- --- Etched Progress Bar ---
    local barW, barH = 200, 4
    local barX, barY = w/2 - barW/2, py + 125
    
    -- Carved slot
    love.graphics.setColor(0.05, 0.05, 0.05, 0.6 * alpha)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 1)
    
    -- Draining fill (Ivory glow)
    if tr > 0 then
        love.graphics.setColor(0.8, 0.75, 0.6, 0.75 * alpha)
        love.graphics.rectangle("fill", barX, barY, barW * tr, barH, 1)
    end
    
    -- "Ok" Button (Matching menu.lua layout)
    local bw, bh = 140, 45
    local bx, by = w/2 - bw/2, py + ph - 70
    local isHover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
    
    hud.drawStoneTablet(bx, by, bw, bh, "Ok", isHover, false, alpha)
    
    -- Return button rect for hit testing in game.lua
    hud.saveNotificationRect = {x = bx, y = by, w = bw, h = bh}
end

-- ── Reset to default font ───────────────────────────────────────────────────

function hud.resetFont()
    love.graphics.setNewFont(12)
end

return hud
