local map = {}

map.gridSize = 50 
map.width = 40    
map.height = 40   
map.data = {}
map.spawnX = 0
map.spawnY = 0

function map.generate()
    map.decorations = {}
    map.edgeDecorations = {}
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
    
    -- 3. Generate procedural floor texture decorations and exposed Wall Edges
    for y = 1, map.height do
        for x = 1, map.width do
            if map.data[y][x] == 0 then
                -- Floor decorations
                local numDecals = love.math.random(1, 5)
                for i = 1, numDecals do
                    local px = (x - 1) * map.gridSize + love.math.random(6, map.gridSize - 6)
                    local py = (y - 1) * map.gridSize + love.math.random(6, map.gridSize - 6)
                    local pr = love.math.random(2, 5)
                    local color = (love.math.random() > 0.5) and {0.08, 0.11, 0.10} or {0.14, 0.17, 0.16}
                    table.insert(map.decorations, {x = px, y = py, r = pr, color = color})
                end
            elseif map.data[y][x] == 1 then
                -- Wall Edge textures (Only where they touch a floor tile)
                local isEdge = false
                local edges = {top = false, bottom = false, left = false, right = false}
                
                if y > 1 and map.data[y-1][x] == 0 then edges.top = true; isEdge = true end
                if y < map.height and map.data[y+1][x] == 0 then edges.bottom = true; isEdge = true end
                if x > 1 and map.data[y][x-1] == 0 then edges.left = true; isEdge = true end
                if x < map.width and map.data[y][x+1] == 0 then edges.right = true; isEdge = true end
                
                if isEdge then
                    local numRocks = love.math.random(3, 8)
                    for i = 1, numRocks do
                        local px = (x - 1) * map.gridSize
                        local py = (y - 1) * map.gridSize
                        
                        -- Place rocks heavily biased toward the exposed edges
                        if edges.top then py = py + love.math.random(0, 10); px = px + love.math.random(0, map.gridSize)
                        elseif edges.bottom then py = py + map.gridSize - love.math.random(0, 10); px = px + love.math.random(0, map.gridSize)
                        elseif edges.left then px = px + love.math.random(0, 10); py = py + love.math.random(0, map.gridSize)
                        elseif edges.right then px = px + map.gridSize - love.math.random(0, 10); py = py + love.math.random(0, map.gridSize)
                        else
                           px = px + love.math.random(0, map.gridSize); py = py + love.math.random(0, map.gridSize)
                        end
                        
                        local pr = love.math.random(3, 8)
                        -- Wall-colored moss/stone highlighting
                        local color = (love.math.random() > 0.5) and {0.15, 0.14, 0.16} or {0.10, 0.10, 0.12}
                        table.insert(map.edgeDecorations, {x = px, y = py, r = pr, color = color})
                    end
                end
            end
        end
    end
end

function map.draw()
    for y = 1, map.height do
        for x = 1, map.width do
            local px = (x - 1) * map.gridSize
            local py = (y - 1) * map.gridSize
            
            if map.data[y][x] == 1 then
                -- Walls: pure continuous black void (no blocky curves, no gaps)
                love.graphics.setColor(0, 0, 0, 1) 
                love.graphics.rectangle("fill", px, py, map.gridSize, map.gridSize)
            else
                -- Floors: Base dungeon color
                love.graphics.setColor(0.12, 0.15, 0.14) 
                love.graphics.rectangle("fill", px, py, map.gridSize, map.gridSize)
            end
        end
    end
    
    -- Draw procedural floor texture over the walking paths
    for _, dec in ipairs(map.decorations) do
        love.graphics.setColor(dec.color[1], dec.color[2], dec.color[3], 1)
        love.graphics.circle("fill", dec.x, dec.y, dec.r)
    end
    
    -- Draw textured dungeon borders on exposed wall edges
    for _, edge in ipairs(map.edgeDecorations) do
        love.graphics.setColor(edge.color[1], edge.color[2], edge.color[3], 1)
        love.graphics.circle("fill", edge.x, edge.y, edge.r)
    end
end

return map