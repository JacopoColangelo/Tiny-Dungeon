local player = {
    x = 0,
    y = 0,
    targetX = 0,
    targetY = 0,
    speed = 180,
    size = 24,
    hp = 4,
    maxHp = 4
}

-- Helper to check if a specific pixel coordinate is inside a wall
local function isWall(px, py, map)
    local gx = math.floor(px / map.gridSize) + 1
    local gy = math.floor(py / map.gridSize) + 1
    if map.data[gy] and map.data[gy][gx] == 1 then
        return true
    end
    return false
end

function player.update(dt, map)
    local dx = player.targetX - (player.x + player.size/2)
    local dy = player.targetY - (player.y + player.size/2)
    local distance = math.sqrt(dx*dx + dy*dy)

    if distance > 5 then
        local moveX = (dx / distance) * player.speed * dt
        local moveY = (dy / distance) * player.speed * dt

        -- Move X and check collision at all 4 corners of the player square
        player.x = player.x + moveX
        if isWall(player.x, player.y, map) or 
           isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or
           isWall(player.x + player.size, player.y + player.size, map) then
            player.x = player.x - moveX
        end

        -- Move Y and check collision
        player.y = player.y + moveY
        if isWall(player.x, player.y, map) or 
           isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or
           isWall(player.x + player.size, player.y + player.size, map) then
            player.y = player.y - moveY
        end
    end
end

function player.draw()
    local r_radius = 6
    love.graphics.setColor(0, 1, 1) -- Neon Cyan
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size, r_radius)
end

return player