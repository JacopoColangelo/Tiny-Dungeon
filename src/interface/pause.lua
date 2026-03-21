local hud = require("src.interface.hud")
local ui_audio = require("src.interface.ui_audio")

local pause = {}

-- ── Button Definitions ───────────────────────────────────────────────────────

local buttons = {
    {id = "resume", text = "Resume",    w = 240, h = 48},
    {id = "options", text = "Options",   w = 240, h = 48},
    {id = "menu",    text = "Main Menu", w = 240, h = 48},
}

-- Runtime button positions
local buttonRects = {}

-- Pending action
local pendingAction = nil
local lastHoveredId = nil

-- ── Public API ───────────────────────────────────────────────────────────────

local lastVX, lastVY = 0, 0

function pause.update(dt, vx, vy)
    lastVX, lastVY = vx, vy

    local currentHoveredId = nil
    for _, rect in ipairs(buttonRects) do
        if vx >= rect.x and vx <= rect.x + rect.w and
           vy >= rect.y and vy <= rect.y + rect.h then
            currentHoveredId = rect.id
            break
        end
    end

    if currentHoveredId ~= lastHoveredId then
        if currentHoveredId then
            ui_audio.playHover()
        end
        lastHoveredId = currentHoveredId
    end

    return pendingAction
end

function pause.drawOverlay(vx, vy)
    local w, h = 1280, 720
    -- If vx, vy not provided (e.g. from game.draw calling), use last known
    vx = vx or lastVX
    vy = vy or lastVY

    -- 1. Dark Overlay (Dimming the game world)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- 2. Title: "Paused"
    local titleFont = hud.getFont("title")
    love.graphics.setFont(titleFont)
    local title = "Paused"
    local tw = titleFont:getWidth(title)
    local tx = w/2 - tw/2
    local ty = h * 0.2

    -- Title shadow
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.print(title, tx + 3, ty + 3)
    -- Title face
    love.graphics.setColor(0.8, 0.8, 0.7, 1)
    love.graphics.print(title, tx, ty)

    -- 3. Buttons
    local btnSpacing = 14
    local startY = ty + titleFont:getHeight() + 35
    buttonRects = {}

    for i, b in ipairs(buttons) do
        local bx = w/2 - b.w/2
        local by = startY + (i-1) * (b.h + btnSpacing)

        buttonRects[i] = {x = bx, y = by, w = b.w, h = b.h, id = b.id}

        local isHover = vx >= bx and vx <= bx + b.w and
                        vy >= by and vy <= by + b.h

        hud.drawStoneTablet(bx, by, b.w, b.h, b.text, isHover, false)
    end
end

function pause.keypressed(key)
    if key == "escape" then
        pendingAction = "resume"
    end
end

function pause.mousepressed(vx, vy, button)
    if button ~= 1 then return end
    for _, rect in ipairs(buttonRects) do
        if vx >= rect.x and vx <= rect.x + rect.w and
           vy >= rect.y and vy <= rect.y + rect.h then
                pendingAction = rect.id
                ui_audio.playClick()
                return
        end
    end
end

function pause.resetAction()
    pendingAction = nil
end

return pause
