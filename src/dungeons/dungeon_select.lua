-- Dungeon Selection Overlay
-- Shown when interacting with the hub portal. Lets the player pick an unlocked dungeon.

local hud = require("src.interface.hud")
local ui_audio = require("src.interface.ui_audio")
local dungeon_data = require("src.dungeons.dungeon_data")

local ds = {}

-- State
local isOpen = false
local pendingSelection = nil  -- index of selected dungeon, or "back"
local lastHoveredId = nil
local lastVX, lastVY = 0, 0

local targetScroll = 0
local currentScroll = 0

-- Cached button rects (computed each frame in draw)
local dungeonRects = {}
local backRect = {}

-- Difficulty color palette
local difficultyColors = {
    Normal    = {0.5, 0.8, 0.5},
    Hard      = {0.9, 0.6, 0.2},
    Nightmare = {0.9, 0.2, 0.2},
}

-- ── Public API ───────────────────────────────────────────────────────────────

function ds.open()
    isOpen = true
    pendingSelection = nil
    lastHoveredId = nil
    targetScroll = 0
    currentScroll = 0
end

function ds.close()
    isOpen = false
    pendingSelection = nil
end

function ds.isOpen()
    return isOpen
end

--- Returns the selected dungeon index, or nil.
--- Caller should call ds.close() after handling the selection.
function ds.getSelection()
    return pendingSelection
end

function ds.resetSelection()
    pendingSelection = nil
end

-- ── Update ───────────────────────────────────────────────────────────────────

function ds.update(dt, vx, vy, unlockSet)
    if not isOpen then return end
    lastVX, lastVY = vx, vy

    -- Smooth scroll interpolation
    currentScroll = currentScroll + (targetScroll - currentScroll) * math.min(1, dt * 10)

    -- Hover sound tracking
    local currentHoveredId = nil

    for _, rect in ipairs(dungeonRects) do
        if vx >= rect.x and vx <= rect.x + rect.w and
           vy >= rect.y and vy <= rect.y + rect.h then
            if rect.unlocked then
                currentHoveredId = "dungeon_" .. rect.index
            end
            break
        end
    end

    if backRect.x then
        if vx >= backRect.x and vx <= backRect.x + backRect.w and
           vy >= backRect.y and vy <= backRect.y + backRect.h then
            currentHoveredId = "back"
        end
    end

    if currentHoveredId ~= lastHoveredId then
        if currentHoveredId then
            ui_audio.playHover()
        end
        lastHoveredId = currentHoveredId
    end
end

-- ── Input ────────────────────────────────────────────────────────────────────

function ds.keypressed(key)
    if not isOpen then return end
    if key == "escape" then
        ds.close()
        ui_audio.playClick()
    end
end

function ds.mousepressed(vx, vy, button, unlockSet)
    if not isOpen then return end
    if button ~= 1 then return end

    -- Check back button first (not scissored/scrolled)
    if backRect.x then
        if vx >= backRect.x and vx <= backRect.x + backRect.w and
           vy >= backRect.y and vy <= backRect.y + backRect.h then
            pendingSelection = "back"
            ui_audio.playClick()
            return
        end
    end

    -- Scissor area for items:
    local ty = 50 + hud.getFont("title"):getHeight() + 47
    local listStartY = ty
    local listClipH = 460 -- viewport height for the list

    if vy < listStartY or vy > listStartY + listClipH then
        return -- click outside scroll area
    end

    -- Scroll area check (adjust for currentScroll)
    local adjY = vy - currentScroll

    for _, rect in ipairs(dungeonRects) do
        if rect.unlocked and
           vx >= rect.x and vx <= rect.x + rect.w and
           adjY >= rect.y and adjY <= rect.y + rect.h then
            
            pendingSelection = rect.index
            ui_audio.playClick()
            return
        end
    end
end

function ds.wheelmoved(x, y, maxScroll)
    if not isOpen then return end
    -- scroll wheel
    local scrollSpeed = 40
    targetScroll = targetScroll + y * scrollSpeed
    
    -- clamp
    if targetScroll > 0 then targetScroll = 0 end
    if targetScroll < -maxScroll then targetScroll = -maxScroll end
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function ds.draw(vx, vy, unlockedDungeons)
    if not isOpen then return end
    vx = vx or lastVX
    vy = vy or lastVY
    unlockedDungeons = unlockedDungeons or {1}

    local w, h = 1280, 720

    -- Build unlock lookup
    local unlockSet = {}
    for _, idx in ipairs(unlockedDungeons) do
        unlockSet[idx] = true
    end

    -- 1. Dark Overlay
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.01, 0.01, 0.01, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- 2. Title
    local titleFont = hud.getFont("title")
    love.graphics.setFont(titleFont)
    local title = "Choose Your Descent"
    local tw = titleFont:getWidth(title)
    local th = titleFont:getHeight()
    local tx = w/2 - tw/2
    local ty = 50

    -- Title shadow
    love.graphics.setColor(0.05, 0.03, 0.08, 1)
    love.graphics.print(title, tx + 3, ty + 3)
    -- Title face (Ivory to match other UI)
    love.graphics.setColor(0.85, 0.85, 0.8, 1)
    love.graphics.print(title, tx, ty)

    -- 3. Ornate Divider (matching menu/game-over style)
    local divY = ty + th + 12
    local divW = math.max(600, tw + 100)
    local ivory = {0.85, 0.85, 0.8}

    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.3, 0.15, 0.4, 0.1)
    love.graphics.ellipse("fill", w/2, divY, divW/2, 8)
    love.graphics.setBlendMode("alpha")

    love.graphics.setLineWidth(1)
    for i = 0, divW do
        local a = (1 - math.abs(i - divW/2) / (divW/2)) * 0.35
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], a)
        love.graphics.points(w/2 - divW/2 + i, divY)
    end

    -- Flourish knots
    local function drawKnot(fx, fy)
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], 0.4)
        love.graphics.rectangle("line", fx-5, fy-5, 10, 10, 2)
        love.graphics.rectangle("fill", fx-2, fy-2, 4, 4)
    end
    drawKnot(w/2 - divW/2, divY)
    drawKnot(w/2 + divW/2, divY)
    drawKnot(w/2, divY)

    -- 4. Dungeon List
    local levels = dungeon_data.levels
    local btnW = 400
    local btnH = 70
    local btnSpacing = 16
    local listStartY = divY + 35
    local totalListH = #levels * (btnH + btnSpacing) - btnSpacing
    local listClipH = 460 -- Maximum list height to draw before scissoring
    
    -- Compute max scroll
    local maxScroll = math.max(0, totalListH - listClipH)
    -- Update clamping on target scroll each frame in case levels changed dynamically
    if targetScroll < -maxScroll then targetScroll = -maxScroll end
    
    -- Apply Scissor for scroll area
    local _scx, _scy, _scw, _sch = love.graphics.getScissor()
    
    -- We assume the base canvas/window size matches our coordinates. In a scaled game,
    -- getScissor would need the actual window scale factor. 
    -- For safety, we use love.graphics.setScissor in local coordinate space if push/translate isn't messing it up 
    -- However, getScissor/setScissor uses WINDOW coordinates, so using a simple translate and scissor requires care.
    -- Assuming w=1280, h=720 is the base game resolution without scaling at this specific UI pass.
    local canvasScaleX, canvasScaleY = love.graphics.getCanvas():getWidth() / 1280, love.graphics.getCanvas():getHeight() / 720
    love.graphics.setScissor(0, listStartY * canvasScaleY, w * canvasScaleX, listClipH * canvasScaleY)
    
    love.graphics.push()
    love.graphics.translate(0, math.floor(currentScroll))

    dungeonRects = {}
    local adjYMouse = vy - currentScroll
    
    for i, level in ipairs(levels) do
        local bx = w/2 - btnW/2
        local by = listStartY + (i-1) * (btnH + btnSpacing)

        local isUnlocked = unlockSet[i] == true
        -- Hover only applies if mouse is inside the un-scrolled scissor area visually, 
        -- but for simplicity we rely on mousepressed to reject out-of-bounds clicks. 
        -- Visual hover outside bounds is hidden by scissor anyway.
        local isHover = isUnlocked and
            vx >= bx and vx <= bx + btnW and
            adjYMouse >= by and adjYMouse <= by + btnH

        dungeonRects[i] = {x = bx, y = by, w = btnW, h = btnH, index = i, unlocked = isUnlocked}

        -- Draw using stone tablet style
        hud.drawStoneTablet(bx, by, btnW, btnH, "", isHover, not isUnlocked)

        -- Custom content inside the tablet
        local buttonFont = hud.getFont("button")
        local smallFont = hud.getFont("small")

        -- Dungeon Name
        love.graphics.setFont(buttonFont)
        local nameText = level.name
        local nameW = buttonFont:getWidth(nameText)

        if not isUnlocked then
            -- Locked state: show lock icon + "Locked"
            love.graphics.setColor(0.4, 0.4, 0.38, 0.5)

            -- Draw a small lock icon
            local lockX = bx + btnW/2 - 40
            local lockY = by + btnH/2 - 8
            -- Lock body
            love.graphics.rectangle("fill", lockX, lockY, 12, 10, 1)
            -- Lock shackle
            love.graphics.setLineWidth(2)
            love.graphics.arc("line", "open", lockX + 6, lockY, 5, math.pi, 0)

            love.graphics.setFont(buttonFont)
            love.graphics.print("Locked", lockX + 18, by + btnH/2 - buttonFont:getHeight()/2)
        else
            -- Unlocked state: show name + difficulty
            -- Name shadow
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.print(nameText, bx + btnW/2 - nameW/2 + 1, by + 12 + 1)
            -- Name face
            if isHover then
                love.graphics.setColor(1, 1, 0.9, 0.9)
            else
                love.graphics.setColor(0.85, 0.85, 0.8, 0.75)
            end
            love.graphics.print(nameText, bx + btnW/2 - nameW/2, by + 12)

            -- Difficulty label
            love.graphics.setFont(smallFont)
            local diffText = level.difficulty or "Unknown"
            local diffW = smallFont:getWidth(diffText)
            local diffColor = difficultyColors[diffText] or {0.7, 0.7, 0.7}

            love.graphics.setColor(diffColor[1], diffColor[2], diffColor[3], isHover and 0.9 or 0.6)
            love.graphics.print(diffText, bx + btnW/2 - diffW/2, by + 40)
        end
    end

    love.graphics.pop()
    
    -- Restore Scissor
    love.graphics.setScissor(_scx, _scy, _scw, _sch)

    -- Pass maxScroll out to target clamping
    ds.maxScroll = maxScroll

    -- 5. Back Button (Drawn AFTER scroll so it stays fixed at bottom)
    local backW = 180
    local backH = 45
    local backX = w/2 - backW/2
    local backY = listStartY + listClipH + 20

    backRect = {x = backX, y = backY, w = backW, h = backH}

    local backHover = vx >= backX and vx <= backX + backW and
                      vy >= backY and vy <= backY + backH

    hud.drawStoneTablet(backX, backY, backW, backH, "Back", backHover, false)
end

return ds
