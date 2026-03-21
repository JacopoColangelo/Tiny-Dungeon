local walls = {
    {x = 500, y = 400, w = 200, h = 50},
    {x = 800, y = 200, w = 100, h = 300},
    {x = 300, y = 600, w = 400, h = 40}
}

function walls.draw()
    love.graphics.setColor(0.3, 0.3, 0.3)
    for _, wall in ipairs(walls) do
        love.graphics.rectangle("fill", wall.x, wall.y, wall.w, wall.h)
    end
end

return walls