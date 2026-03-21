-- Portal Choice Overlay
-- Shown when interacting with the active exit portal inside a cleared dungeon.

local hud = require("src.interface.hud")
local ui_audio = require("src.interface.ui_audio")
local dungeon_data = require("src.dungeons.dungeon_data")

local pc = {}

-- State
local isOpen = false
local pendingSelection = nil  -- "hub" or "next"
local lastHoveredId = nil
local lastVX, lastVY = 0, 0

local nextIdx = nil
local options = {}

-- ── Public API ───────────────────────────────────────────────────────────────

function pc.open(currentLevelIndex)
    isOpen = true
    pendingSelection = nil
    lastHoveredId = nil
    
    local potentialNext = currentLevelIndex + 1
    if potentialNext <= #dungeon_data.levels then
        nextIdx = potentialNext
    else
        nextIdx = nil
    end
end

function pc.close()
    isOpen = false
    pendingSelection = nil
end

function pc.isOpen()
    return isOpen
end

--- Returns the selected action: "hub" or "next", or nil.
--- Caller should call pc.close() after handling the selection.
function pc.getSelection()
    return pendingSelection
end

function pc.resetSelection()
    pendingSelection = nil
end

-- ── Update ───────────────────────────────────────────────────────────────────

function pc.update(dt, vx, vy)
    if not isOpen then return end
    lastVX, lastVY = vx, vy

    local currentHoveredId = nil
    
    for _, opt in ipairs(options) do
        if vx >= opt.x and vx <= opt.x + opt.w and
           vy >= opt.y and vy <= opt.y + opt.h then
            currentHoveredId = "portal_" .. opt.action
            break
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

function pc.keypressed(key)
    if not isOpen then return end
    if key == "escape" then
        pc.close()
        ui_audio.playClick()
    end
end

function pc.mousepressed(vx, vy, button)
    if not isOpen then return end
    if button ~= 1 then return end

    for _, opt in ipairs(options) do
        if vx >= opt.x and vx <= opt.x + opt.w and
           vy >= opt.y and vy <= opt.y + opt.h then
            pendingSelection = opt.action
            ui_audio.playClick()
            return
        end
    end
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function pc.draw(vx, vy)
    if not isOpen then return end
    vx = vx or lastVX
    vy = vy or lastVY

    local w, h = 1280, 720

    -- 1. Dark Overlay
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.01, 0.01, 0.01, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- 2. Title
    local titleFont = hud.getFont("title")
    love.graphics.setFont(titleFont)
    local title = "Path Diverges"
    local tw = titleFont:getWidth(title)
    local th = titleFont:getHeight()
    local tx = w/2 - tw/2
    local ty = h/2 - 140

    -- Title shadow
    love.graphics.setColor(0.05, 0.03, 0.08, 1)
    love.graphics.print(title, tx + 3, ty + 3)
    -- Title face (Ivory)
    love.graphics.setColor(0.85, 0.85, 0.8, 1)
    love.graphics.print(title, tx, ty)

    -- 3. Ornate Divider
    local divY = ty + th + 12
    local divW = math.max(500, tw + 80)
    local ivory = {0.85, 0.85, 0.8}

    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.3, 0.15, 0.4, 0.1)
    love.graphics.ellipse("fill", w/2, divY, divW/2, 6)
    love.graphics.setBlendMode("alpha")

    love.graphics.setLineWidth(1)
    for i = 0, divW do
        local a = (1 - math.abs(i - divW/2) / (divW/2)) * 0.35
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], a)
        love.graphics.points(w/2 - divW/2 + i, divY)
    end

    local function drawKnot(fx, fy)
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], 0.4)
        love.graphics.rectangle("line", fx-4, fy-4, 8, 8, 1)
    end
    drawKnot(w/2 - divW/2, divY)
    drawKnot(w/2 + divW/2, divY)
    drawKnot(w/2, divY)

    -- 4. Options
    options = {}
    local btnW = 320
    local btnH = 60
    local btnSpacing = 20
    local numVisible = nextIdx and 2 or 1
    
    local listTotalW = numVisible * btnW + (numVisible - 1) * btnSpacing
    local startX = w/2 - listTotalW/2
    local startY = divY + 50
    
    local currX = startX
    
    -- Option: Return to Hub
    local isHoverHub = vx >= currX and vx <= currX + btnW and
                       vy >= startY and vy <= startY + btnH
    options[#options+1] = {x = currX, y = startY, w = btnW, h = btnH, action = "hub"}
    hud.drawStoneTablet(currX, startY, btnW, btnH, "Return to Hub", isHoverHub, false)
    
    currX = currX + btnW + btnSpacing

    -- Option: Descend Deeper
    if nextIdx then
        local isHoverNext = vx >= currX and vx <= currX + btnW and
                            vy >= startY and vy <= startY + btnH
        options[#options+1] = {x = currX, y = startY, w = btnW, h = btnH, action = "next"}
        
        -- Custom drawing for the Descend tablet to emphasize it (like a portal hue)
        hud.drawStoneTablet(currX, startY, btnW, btnH, "Descend Deeper", isHoverNext, false)
        
        -- Subtle purple overlay on the buttons
        if isHoverNext then
            love.graphics.setColor(0.6, 0.3, 0.8, 0.1)
            love.graphics.rectangle("fill", currX, startY, btnW, btnH, 6)
        end
    end
end

return pc
