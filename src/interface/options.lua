local hud = require("src.interface.hud")
local ui_audio = require("src.interface.ui_audio")

local options = {}

-- ── Settings ─────────────────────────────────────────────────────────────────

local resolutions = {
    {w = 1280, h = 720,  label = "1280 x 720"},
    {w = 1920, h = 1080, label = "1920 x 1080"},
    {w = 2560, h = 1440, label = "2560 x 1440"},
}

local settings = {
    resIndex = 1,
    fullscreen = false,
    volume = 80,  -- 0–100
}

-- Current state on disk or actually applied
local appliedSettings = {
    resIndex = 1,
    fullscreen = false,
    volume = 80,
}

local pendingAction = nil
local isDraggingVolume = false
local lastHoveredId = nil

-- ── Persistence ──────────────────────────────────────────────────────────────

local SETTINGS_FILE = "settings.dat"

local function saveSettings()
    local data = string.format("%d\n%s\n%d",
        appliedSettings.resIndex,
        tostring(appliedSettings.fullscreen),
        appliedSettings.volume)
    love.filesystem.write(SETTINGS_FILE, data)
end

local function loadSettings()
    if love.filesystem.getInfo(SETTINGS_FILE) then
        local data = love.filesystem.read(SETTINGS_FILE)
        if data then
            local lines = {}
            for line in data:gmatch("[^\n]+") do table.insert(lines, line) end
            if #lines >= 3 then
                appliedSettings.resIndex   = tonumber(lines[1]) or 1
                appliedSettings.fullscreen = lines[2] == "true"
                appliedSettings.volume     = tonumber(lines[3]) or 80
                
                -- Sync working settings
                settings.resIndex = appliedSettings.resIndex
                settings.fullscreen = appliedSettings.fullscreen
                settings.volume = appliedSettings.volume
            end
        end
    end
end

-- ── Apply ────────────────────────────────────────────────────────────────────

local function updateVolume()
    love.audio.setVolume(settings.volume / 100)
    appliedSettings.volume = settings.volume
    saveSettings()
end

local function applyWindowSettings()
    local res = resolutions[settings.resIndex] or resolutions[1]
    
    if settings.fullscreen then
        love.window.setFullscreen(true, "desktop")
    else
        love.window.setFullscreen(false)
        love.window.setMode(res.w, res.h, {resizable=false, vsync=true})
    end

    appliedSettings.resIndex = settings.resIndex
    appliedSettings.fullscreen = settings.fullscreen
    saveSettings()
end

function options.load()
    loadSettings()
    -- Apply initially
    local res = resolutions[appliedSettings.resIndex] or resolutions[1]
    if appliedSettings.fullscreen then
        love.window.setFullscreen(true, "desktop")
    else
        love.window.setMode(res.w, res.h, {resizable=false, vsync=true})
    end
    love.audio.setVolume(appliedSettings.volume / 100)
end

-- Shared for layout sync
local controlRects = {}

local lastVX, lastVY = 0, 0

function options.update(dt, vx, vy)
    lastVX, lastVY = vx, vy
    if isDraggingVolume then
        if not love.mouse.isDown(1) then
            isDraggingVolume = false
        else
            -- Use the virtual mouse pos for dragging
            for _, r in ipairs(controlRects) do
                if r.action == "volume_bar" then
                    local pct = math.max(0, math.min(1, (vx - r.barX) / r.barW))
                    local newVol = math.floor(pct * 100 + 0.5)
                    if newVol ~= settings.volume then
                        settings.volume = newVol
                        updateVolume()
                    end
                    break
                end
            end
        end
    end

    local sig = pendingAction
    pendingAction = nil
    return sig
end

local function handleControlHover(vx, vy)
    local currentHoveredId = nil
    for _, r in ipairs(controlRects) do
        if vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h then
            currentHoveredId = r.action
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

function options.draw(screenCanvas)
    local w, h = 1280, 720

    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- Background vignette
    for i = 1, 6 do
        local a = (1 - i/6) * 0.03
        love.graphics.setColor(0.04, 0.04, 0.06, a)
        love.graphics.ellipse("fill", w/2, h/2, w/2 * (i/6), h/2 * (i/6))
    end

    -- Title
    local titleFont = hud.getFont("title")
    local btnFont   = hud.getFont("button")
    love.graphics.setFont(titleFont)
    local title = "Options"
    local tw = titleFont:getWidth(title)
    local tx = w/2 - tw/2
    local ty = h * 0.08

    love.graphics.setColor(0.2, 0, 0, 0.8)
    love.graphics.print(title, tx + 3, ty + 3)
    love.graphics.setColor(0.55, 0.1, 0.08, 1)
    love.graphics.print(title, tx, ty)

    -- Settings rows
    love.graphics.setFont(btnFont)
    controlRects = {}

    local rowX = w/2 - 240
    local rowW = 480
    local startY = ty + titleFont:getHeight() + 40
    local rowH = 50
    local rowGap = 12

    -- ── Resolution ───────────────────────────────────────────────────────
    local ry = startY
    love.graphics.setColor(0.85, 0.85, 0.8, 0.7)
    love.graphics.print("Resolution", rowX, ry + 15)

    local arrowW, arrowH = 30, 30
    local arrowLX = rowX + 180
    local arrowRX = rowX + rowW - arrowW
    local arrowY = ry + 8

    local lHover = lastVX >= arrowLX and lastVX <= arrowLX + arrowW and lastVY >= arrowY and lastVY <= arrowY + arrowH
    hud.drawStoneTablet(arrowLX, arrowY, arrowW, arrowH, "<", lHover, false)
    table.insert(controlRects, {x=arrowLX, y=arrowY, w=arrowW, h=arrowH, action="res_prev"})

    local rHover = lastVX >= arrowRX and lastVX <= arrowRX + arrowW and lastVY >= arrowY and lastVY <= arrowY + arrowH
    hud.drawStoneTablet(arrowRX, arrowY, arrowW, arrowH, ">", rHover, false)
    table.insert(controlRects, {x=arrowRX, y=arrowY, w=arrowW, h=arrowH, action="res_next"})

    local res = resolutions[settings.resIndex] or resolutions[1]
    local resText = res.label
    local rtw = btnFont:getWidth(resText)
    love.graphics.setColor(1, 1, 0.9, 0.9)
    love.graphics.print(resText, arrowLX + arrowW + (arrowRX - arrowLX - arrowW)/2 - rtw/2, ry + 14)

    -- ── Fullscreen ───────────────────────────────────────────────────────
    ry = startY + (rowH + rowGap)
    love.graphics.setColor(0.85, 0.85, 0.8, 0.7)
    love.graphics.print("Display", rowX, ry + 15)

    local toggleW, toggleH = 150, 34
    local toggleX = rowX + rowW - toggleW
    local toggleY = ry + 10
    local toggleText = settings.fullscreen and "Fullscreen" or "Windowed"
    local tHover = lastVX >= toggleX and lastVX <= toggleX + toggleW and lastVY >= toggleY and lastVY <= toggleY + toggleH
    hud.drawStoneTablet(toggleX, toggleY, toggleW, toggleH, toggleText, tHover, false)
    table.insert(controlRects, {x=toggleX, y=toggleY, w=toggleW, h=toggleH, action="toggle_fs"})

    -- ── Volume ───────────────────────────────────────────────────────────
    ry = startY + 2 * (rowH + rowGap)
    love.graphics.setColor(0.85, 0.85, 0.8, 0.7)
    love.graphics.print("Volume", rowX, ry + 15)

    local barX = rowX + 220
    local barW = rowW - 220
    local barY = ry + 20
    local barH = 8

    love.graphics.setColor(0.08, 0.08, 0.08, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2)
    love.graphics.setColor(0.3, 0.3, 0.28, 0.5)
    love.graphics.rectangle("line", barX, barY, barW, barH, 2)

    local fillW = (settings.volume / 100) * barW
    love.graphics.setColor(0.6, 0.12, 0.08, 0.8)
    love.graphics.rectangle("fill", barX, barY, fillW, barH, 2)

    local handleX = barX + fillW - 4
    love.graphics.setColor(0.85, 0.85, 0.8, 0.9)
    love.graphics.rectangle("fill", handleX, barY - 3, 8, barH + 6, 2)

    local volText = tostring(settings.volume) .. "%"
    love.graphics.setColor(1, 1, 0.9, 0.7)
    love.graphics.print(volText, barX + barW + 10, ry + 12)

    table.insert(controlRects, {x=barX, y=barY - 15, w=barW, h=barH + 30, action="volume_bar", barX=barX, barW=barW})

    -- ── Apply Button (Only if window settings differ) ────────────────────
    local hasChanges = (settings.resIndex ~= appliedSettings.resIndex or settings.fullscreen ~= appliedSettings.fullscreen)
    
    local applyY = ry + (rowH + rowGap) + 10
    if hasChanges then
        local applyW, applyH = 120, 40
        local applyX = w/2 - applyW/2
        local apHover = lastVX >= applyX and lastVX <= applyX + applyW and lastVY >= applyY and lastVY <= applyY + applyH
        hud.drawStoneTablet(applyX, applyY, applyW, applyH, "Apply", apHover, false)
        table.insert(controlRects, {x=applyX, y=applyY, w=applyW, h=applyH, action="apply"})
    end

    -- ── Back Button ──────────────────────────────────────────────────────
    local backW, backH = 200, 48
    local backX = w/2 - backW/2
    local backY = h - 80
    local bkHover = lastVX >= backX and lastVX <= backX + backW and lastVY >= backY and lastVY <= backY + backH
    hud.drawStoneTablet(backX, backY, backW, backH, "Back", bkHover, false)
    table.insert(controlRects, {x=backX, y=backY, w=backW, h=backH, action="back"})

    -- Finish screen
    love.graphics.setCanvas()
    
    handleControlHover(lastVX, lastVY)
end

function options.keypressed(key)
    if key == "escape" then
        pendingAction = "back"
    end
end

function options.mousepressed(vx, vy, button)
    if button ~= 1 then return end
    for _, r in ipairs(controlRects) do
        if vx >= r.x and vx <= r.x + r.w and vy >= r.y and vy <= r.y + r.h then
            ui_audio.playClick()
            if r.action == "res_prev" then
                settings.resIndex = settings.resIndex - 1
                if settings.resIndex < 1 then settings.resIndex = #resolutions end
            elseif r.action == "res_next" then
                settings.resIndex = settings.resIndex + 1
                if settings.resIndex > #resolutions then settings.resIndex = 1 end
            elseif r.action == "toggle_fs" then
                settings.fullscreen = not settings.fullscreen
            elseif r.action == "volume_bar" then
                isDraggingVolume = true
                local pct = math.max(0, math.min(1, (vx - r.barX) / r.barW))
                settings.volume = math.floor(pct * 100 + 0.5)
                updateVolume()
            elseif r.action == "apply" then
                applyWindowSettings()
                pendingAction = "refresh"
            elseif r.action == "back" then
                if settings.resIndex ~= appliedSettings.resIndex or 
                   settings.fullscreen ~= appliedSettings.fullscreen then
                    applyWindowSettings()
                    pendingAction = "refresh_back"
                else
                    pendingAction = "back"
                end
            end
            return
        end
    end
end

return options
