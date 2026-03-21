-- ============================================================================
-- Tiny Dungeon — Main Entry Point
-- ============================================================================
-- Routes execution between menu, options, and gameplay states.
-- Manages the virtual resolution canvas and CRT shader rendering.
-- ============================================================================

-- ─── Dependencies ───────────────────────────────────────────────────────────

local menu    = require("src.interface.menu")
local options = require("src.interface.options")
local pause   = require("src.interface.pause")
local ui_audio= require("src.interface.ui_audio")
local game    = require("src.gameplay.game")
local storage = require("src.gameplay.storage")

-- ─── Configuration & State ──────────────────────────────────────────────────

local VIRTUAL_W = 1280
local VIRTUAL_H = 720

-- "menu" | "options" | "playing" | "paused"
local appState = "menu"           
local optionsReturnState = "menu"  

-- Rendering references
local screenCanvas
local crtShader

-- Screen scaling bounds
local scale = 1
local offsetX = 0
local offsetY = 0

-- ─── Core Utilities ─────────────────────────────────────────────────────────

-- Rebuilds canvases to match the current window size
local function refreshAllCanvases()
    screenCanvas = love.graphics.newCanvas(VIRTUAL_W, VIRTUAL_H)
    game.refreshCanvas()
    
    local sw, sh = love.graphics.getDimensions()
    scale = math.min(sw / VIRTUAL_W, sh / VIRTUAL_H)
    offsetX = (sw - VIRTUAL_W * scale) / 2
    offsetY = (sh - VIRTUAL_H * scale) / 2
end

-- Converts physical window coordinates to virtual game coordinates
local function getVirtualMousePos(mx, my)
    local vx = (mx - offsetX) / scale
    local vy = (my - offsetY) / scale
    return vx, vy
end

-- Safely aborts gameplay state and returns to the titlescreen
local function transitionToMenu()
    game.stop()
    menu.load(storage.exists())
    appState = "menu"
end

-- ─── LÖVE Callbacks ─────────────────────────────────────────────────────────

function love.load()
    love.window.setTitle("Tiny Dungeon")

    options.load()
    refreshAllCanvases()
    
    crtShader = love.graphics.newShader("assets/shaders/crt.glsl")

    menu.load(storage.exists())
    ui_audio.load()
    game.load()
end

function love.update(dt)
    crtShader:send("time", love.timer.getTime())
    ui_audio.update(dt)

    local vx, vy = getVirtualMousePos(love.mouse.getPosition())

    if appState == "menu" then
        game.update(dt, vx, vy, true, false)
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
        game.update(dt, vx, vy, true, false)
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
        game.update(dt, vx, vy, false, false)

    elseif appState == "paused" then
        game.update(dt, vx, vy, true, true)
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
            transitionToMenu()
        end
    end
end

function love.keypressed(key)
    if appState == "menu" then
        menu.keypressed(key)
        
    elseif appState == "options" then
        options.keypressed(key)
        
    elseif appState == "playing" then
        -- Forward UI overlay/menu inputs directly
        if key == "escape" then
            if game.isInventoryOpen() or game.isSkillTreeOpen() or game.isDungeonSelectOpen() or game.isPortalChoiceOpen() then
                game.keypressed(key)
            elseif not game.isNotificationActive() and not game.isGameOver() then
                appState = "paused"
            end
            
        elseif key == "tab" or key == "i" then
            if not game.isNotificationActive() and not game.isGameOver() then
                if game.keypressed(key) == "menu" then
                    transitionToMenu()
                end
            end
            
        -- Forward all standard gameplay inputs
        else
            if game.keypressed(key) == "menu" then
                transitionToMenu()
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
        if game.mousepressed(vx, vy, button) == "menu" then
            transitionToMenu()
        end
    elseif appState == "paused" then
        pause.mousepressed(vx, vy, button)
    end
end

function love.mousemoved(mx, my)
    if appState == "playing" then
        local vx, vy = getVirtualMousePos(mx, my)
        game.mousemoved(vx, vy)
    end
end

function love.wheelmoved(x, y)
    if appState == "playing" then
        game.wheelmoved(x, y)
    end
end

function love.draw()
    local vx, vy = getVirtualMousePos(love.mouse.getPosition())
    
    -- 1. Draw active state to virtual canvas
    if appState == "menu" then
        menu.draw(screenCanvas, vx, vy)
    elseif appState == "options" then
        options.draw(screenCanvas)
    elseif appState == "playing" then
        game.draw(screenCanvas, false, vx, vy)
    elseif appState == "paused" then
        game.draw(screenCanvas, true, vx, vy)
    end

    -- 2. Draw Virtual Canvas to window (scaled, centered, bordered with CRT effect)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(screenCanvas, offsetX, offsetY, 0, scale, scale)
    love.graphics.setShader()
end