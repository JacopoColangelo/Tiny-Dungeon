-- Tiny Dungeon — Entry Point
-- All game logic lives in src/game.lua. This file just wires up LÖVE callbacks.

local game = require("src.game")

function love.load()
    love.window.setTitle("Tiny Dungeon")
    love.window.setMode(1280, 720, {resizable=false, vsync=true})
    game.load()
end

function love.update(dt)
    game.update(dt)
end

function love.keypressed(key)
    game.keypressed(key)
end

function love.mousepressed(x, y, button)
    game.mousepressed(x, y, button)
end

function love.draw()
    game.draw()
end