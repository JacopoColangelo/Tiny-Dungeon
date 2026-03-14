-- Tiny Dungeon — Entry Point
-- Routes between menu, options, and gameplay.

local menu    = require("src.menu")
local options = require("src.options")
local game    = require("src.game")
local pause   = require("src.pause")
local storage = require("src.storage")

local appState = "menu"           -- "menu" | "options" | "playing" | "paused"
local optionsReturnState = "menu"  -- where to return after options

-- Virtual Resolution Constants
local VIRTUAL_W = 1280
local VIRTUAL_H = 720

-- ── State ────────────────────────────────────────────────────────────────────

-- Rendering references (assigned in refreshCanvas or passed in draw)
local screenCanvas
local crtShader

-- Scale/Offset for drawing virtual canvas to screen
local scale = 1
local offsetX = 0
local offsetY = 0

local function refreshAllCanvases()
    -- Always use 1080p for internal rendering
    screenCanvas = love.graphics.newCanvas(VIRTUAL_W, VIRTUAL_H)
    game.refreshCanvas()
    
    -- Recalculate scaling/centering for current window
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    scale = math.min(sw / VIRTUAL_W, sh / VIRTUAL_H)
    offsetX = (sw - VIRTUAL_W * scale) / 2
    offsetY = (sh - VIRTUAL_H * scale) / 2
end

-- Convert real mouse coords to virtual 1080p coords
local function getVirtualMousePos(mx, my)
    local vx = (mx - offsetX) / scale
    local vy = (my - offsetY) / scale
    return vx, vy
end

function love.load()
    love.window.setTitle("Tiny Dungeon")

    -- Load options first (applies saved resolution/fullscreen/volume)
    options.load()

    refreshAllCanvases()
    crtShader = love.graphics.newShader("assets/shaders/crt.glsl")

    menu.load(storage.exists())
    game.load()
end

function love.update(dt)
    -- Animate CRT
    crtShader:send("time", love.timer.getTime())

    if appState == "menu" then
        local vx, vy = getVirtualMousePos(love.mouse.getPosition())
        game.update(dt, vx, vy, false) -- Unmuffle in menu
        local action = menu.update(dt, vx, vy)
        if action == "newgame" then
            menu.resetAction()
            storage.delete()
            menu.load(false)
            appState = "playing"
            game.newGame()
        elseif action == "loadgame" then
            menu.resetAction()
            appState = "playing"
            game.loadGame()
        elseif action == "options" then
            menu.resetAction()
            appState = "options"
            optionsReturnState = "menu"
        elseif action == "quit" then
            love.event.quit()
        end
    elseif appState == "options" then
        local vx, vy = getVirtualMousePos(love.mouse.getPosition())
        game.update(dt, vx, vy, false) -- Unmuffle in options
        local result = options.update(dt, vx, vy)
        if result == "refresh" then
            refreshAllCanvases()
        elseif result == "back" then
            appState = optionsReturnState
        elseif result == "refresh_back" then
            refreshAllCanvases()
            appState = optionsReturnState
        end
    elseif appState == "playing" then
        local vx, vy = getVirtualMousePos(love.mouse.getPosition())
        game.update(dt, vx, vy, false)
    elseif appState == "paused" then
        local vx, vy = getVirtualMousePos(love.mouse.getPosition())
        game.update(dt, vx, vy, true)
        local action = pause.update(dt, vx, vy)
        if action == "resume" then
            pause.resetAction()
            appState = "playing"
        elseif action == "options" then
            pause.resetAction()
            appState = "options"
            optionsReturnState = "paused"
        elseif action == "menu" then
            pause.resetAction()
            game.stop()
            menu.load(storage.exists())
            appState = "menu"
        end
    end
end

function love.keypressed(key)
    if appState == "menu" then
        menu.keypressed(key)
    elseif appState == "options" then
        options.keypressed(key)
    elseif appState == "playing" then
        if key == "escape" then
            if not game.isNotificationActive() and not game.isGameOver() then
                appState = "paused"
            end
        else
            local result = game.keypressed(key)
            if result == "menu" then
                game.stop()
                menu.load(storage.exists())
                appState = "menu"
            end
        end
    elseif appState == "paused" then
        pause.keypressed(key)
    end
end

function love.mousepressed(mx, my, button)
    local vx, vy = getVirtualMousePos(mx, my)
    
    if appState == "menu" then
        menu.mousepressed(vx, vy, button)
    elseif appState == "options" then
        options.mousepressed(vx, vy, button)
    elseif appState == "playing" then
        local result = game.mousepressed(vx, vy, button)
        if result == "menu" then
            game.stop()
            menu.load(storage.exists())
            appState = "menu"
        end
    elseif appState == "paused" then
        pause.mousepressed(vx, vy, button)
    end
end

function love.draw()
    -- Draw state content to virtual canvas
    local vx, vy = getVirtualMousePos(love.mouse.getPosition())
    if appState == "menu" then
        menu.draw(screenCanvas, vx, vy)
    elseif appState == "options" then
        options.draw(screenCanvas)
    elseif appState == "playing" then
        game.draw(screenCanvas, false, vx, vy)
    elseif appState == "paused" then
        game.draw(screenCanvas, true, vx, vy)
    end

    -- Draw Virtual Canvas to screen with CRT and Letterboxing
    love.graphics.clear(0, 0, 0, 1) -- Black for pillar/letterbox
    
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Uniform scaling and centering
    love.graphics.draw(screenCanvas, offsetX, offsetY, 0, scale, scale)
    
    love.graphics.setShader()
end