local map = {}

map.gridSize = 50 
map.width = 40    
map.height = 40   
map.data = {}
map.spawnX = 0
map.spawnY = 0

function map.generate()
    -- 1. Fill map with walls (1)
    for y = 1, map.height do
        map.data[y] = {}
        for x = 1, map.width do
            map.data[y][x] = 1
        end
    end

    -- 2. Setup the "Walker"
    -- Start in the middle-ish to avoid edge issues
    local walkX = math.random(10, map.width - 10)
    local walkY = math.random(10, map.height - 10)
    
    -- Record this as the safe spawn point
    map.spawnX = walkX
    map.spawnY = walkY
    
    map.data[walkY][walkX] = 0 
    
    local steps = 600 
    for i = 1, steps do
        local dir = love.math.random(1, 4)
        if dir == 1 and walkY > 2 then walkY = walkY - 1
        elseif dir == 2 and walkY < map.height - 1 then walkY = walkY + 1
        elseif dir == 3 and walkX > 2 then walkX = walkX - 1
        elseif dir == 4 and walkX < map.width - 1 then walkX = walkX + 1
        end
        map.data[walkY][walkX] = 0 
    end
end

function map.draw()
    for y = 1, map.height do
        for x = 1, map.width do
            if map.data[y][x] == 1 then
                love.graphics.setColor(0.15, 0.1, 0.2) 
                love.graphics.rectangle("fill", (x-1)*map.gridSize, (y-1)*map.gridSize, map.gridSize, map.gridSize)
            else
                love.graphics.setColor(0.05, 0.05, 0.1) 
                love.graphics.rectangle("fill", (x-1)*map.gridSize, (y-1)*map.gridSize, map.gridSize, map.gridSize)
                love.graphics.setColor(1, 1, 1, 0.03)
                love.graphics.rectangle("line", (x-1)*map.gridSize, (y-1)*map.gridSize, map.gridSize, map.gridSize)
            end
        end
    end
end

return map