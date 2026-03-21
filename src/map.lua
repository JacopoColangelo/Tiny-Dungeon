local map = {}
map.isHub = false

map.gridSize = 50 
map.width = 40    
map.height = 40   
map.data = {}
map.spawnX = 0
map.spawnY = 0
map.portalCollisionRadius = 15

function map.generate(seed)
    if seed then
        love.math.setRandomSeed(seed)
        math.randomseed(seed)
    end
    map.decorations = {}
    map.contours = {}
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
    
    -- 3. Solidify diagonal wall gaps (diagonal "checkerboard" detection)
    for y = 1, map.height - 1 do
        for x = 1, map.width - 1 do
            local tl = map.data[y][x]
            local tr = map.data[y][x+1]
            local bl = map.data[y+1][x]
            local br = map.data[y+1][x+1]
            
            -- If we have a diagonal connection (wall-floor-floor-wall)
            if tl == 1 and br == 1 and tr == 0 and bl == 0 then
                map.data[y][x+1] = 1 -- Fill one corner to solidify
            elseif tr == 1 and bl == 1 and tl == 0 and br == 0 then
                map.data[y][x] = 1 -- Fill one corner to solidify
            end
        end
    end

    -- 4. Finalize Safe Spawn Point (ensure it's actually on a floor tile after all passes)
    local foundSpawn = false
    -- Start from middle and search outwards or just pick first floor tile
    for y = math.floor(map.height/2), map.height do
        for x = 1, map.width do
            if map.data[y][x] == 0 then
                map.spawnX, map.spawnY = x, y
                foundSpawn = true
                break
            end
        end
        if foundSpawn then break end
    end
    if not foundSpawn then
        -- This should be rare/impossible with 600 steps, but as fallback:
        map.spawnX, map.spawnY = 20, 20
        map.data[20][20] = 0
    end

    -- 5. Find Exit Portal Location (Tile furthest from spawn)
    local maxDistSq = 0
    map.portalX, map.portalY = map.spawnX, map.spawnY
    for y = 1, map.height do
        for x = 1, map.width do
            if map.data[y][x] == 0 then
                local distSq = (x - map.spawnX)^2 + (y - map.spawnY)^2
                if distSq > maxDistSq then
                    maxDistSq = distSq
                    map.portalX, map.portalY = x, y
                end
            end
        end
    end
    
    -- 6. Generate procedural floor texture decorations and exposed Wall Edges
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
            end
        end
    end

    -- 4. Extract and Chain Edges for Contours
    local rawEdges = {}
    local s = map.gridSize
    for y = 1, map.height do
        for x = 1, map.width do
            if map.data[y][x] == 1 then
                local px, py = (x-1)*s, (y-1)*s
                if y > 1 and map.data[y-1][x] == 0 then table.insert(rawEdges, {x1=px, y1=py, x2=px+s, y2=py}) end
                if y < map.height and map.data[y+1][x] == 0 then table.insert(rawEdges, {x1=px, y1=py+s, x2=px+s, y2=py+s}) end
                if x > 1 and map.data[y][x-1] == 0 then table.insert(rawEdges, {x1=px, y1=py, x2=px, y2=py+s}) end
                if x < map.width and map.data[y][x+1] == 0 then table.insert(rawEdges, {x1=px+s, y1=py, x2=px+s, y2=py+s}) end
            end
        end
    end

    -- Build a adjacency map of points to edges
    local pointMap = {}
    for _, e in ipairs(rawEdges) do
        local k1 = string.format("%.1f,%.1f", e.x1, e.y1)
        local k2 = string.format("%.1f,%.1f", e.x2, e.y2)
        pointMap[k1] = pointMap[k1] or {}
        pointMap[k2] = pointMap[k2] or {}
        table.insert(pointMap[k1], e)
        table.insert(pointMap[k2], e)
    end

    local visitedEdges = {}
    while #rawEdges > 0 do
        local startEdge = nil
        for i = #rawEdges, 1, -1 do
            local e = rawEdges[i]
            if not visitedEdges[e] then
                startEdge = table.remove(rawEdges, i)
                break
            end
        end
        if not startEdge then break end

        local loop = {startEdge.x1, startEdge.y1, startEdge.x2, startEdge.y2}
        visitedEdges[startEdge] = true
        
        local startX, startY = startEdge.x1, startEdge.y1
        local endX, endY = startEdge.x2, startEdge.y2
        
        -- Grow forward from endX, endY
        while true do
            local key = string.format("%.1f,%.1f", endX, endY)
            local neighbors = pointMap[key] or {}
            local found = false
            for _, e in ipairs(neighbors) do
                if not visitedEdges[e] then
                    visitedEdges[e] = true
                    if math.abs(e.x1 - endX) < 0.1 and math.abs(e.y1 - endY) < 0.1 then
                        endX, endY = e.x2, e.y2
                    else
                        endX, endY = e.x1, e.y1
                    end
                    table.insert(loop, endX); table.insert(loop, endY)
                    found = true; break
                end
            end
            if not found then break end
        end
        
        -- Grow backward from startX, startY
        while true do
            local key = string.format("%.1f,%.1f", startX, startY)
            local neighbors = pointMap[key] or {}
            local found = false
            for _, e in ipairs(neighbors) do
                if not visitedEdges[e] then
                    visitedEdges[e] = true
                    if math.abs(e.x1 - startX) < 0.1 and math.abs(e.y1 - startY) < 0.1 then
                        startX, startY = e.x2, e.y2
                    else
                        startX, startY = e.x1, e.y1
                    end
                    table.insert(loop, 1, startY); table.insert(loop, 1, startX)
                    found = true; break
                end
            end
            if not found then break end
        end

        -- Smoothing Pass
        if #loop == 4 then
            table.insert(map.contours, loop)
        elseif #loop >= 6 then
            local smoothed = {}
            local radius = 10
            local isClosed = math.abs(loop[1]-loop[#loop-1]) < 0.1 and math.abs(loop[2]-loop[#loop]) < 0.1
            
            -- Remove redundant last point for simpler processing if closed
            local processLoop = {unpack(loop)}
            if isClosed then
                table.remove(processLoop)
                table.remove(processLoop)
            end

            local n = #processLoop / 2
            for i = 1, n do
                local curX, curY = processLoop[(i-1)*2+1], processLoop[(i-1)*2+2]
                local prevX, prevY, nextX, nextY
                
                -- Determine neighbors
                if i == 1 then
                    if isClosed then
                        prevX, prevY = processLoop[(n-1)*2+1], processLoop[(n-1)*2+2]
                    else
                        table.insert(smoothed, curX); table.insert(smoothed, curY)
                        goto next_point
                    end
                else
                    prevX, prevY = processLoop[(i-2)*2+1], processLoop[(i-2)*2+2]
                end

                if i == n then
                    if isClosed then
                        nextX, nextY = processLoop[1], processLoop[2]
                    else
                        table.insert(smoothed, curX); table.insert(smoothed, curY)
                        goto next_point
                    end
                else
                    nextX, nextY = processLoop[i*2+1], processLoop[i*2+2]
                end

                -- Apply smoothing to corner at curX, curY
                local dx1, dy1 = curX - prevX, curY - prevY
                local dx2, dy2 = nextX - curX, nextY - curY
                local l1 = math.sqrt(dx1*dx1 + dy1*dy1)
                local l2 = math.sqrt(dx2*dx2 + dy2*dy2)

                if math.abs(dx1*dx2 + dy1*dy2) < 0.1 then -- Perpendicular corner
                    table.insert(smoothed, curX - (dx1/l1)*radius)
                    table.insert(smoothed, curY - (dy1/l1)*radius)
                    table.insert(smoothed, curX + (dx2/l2)*radius)
                    table.insert(smoothed, curY + (dy2/l2)*radius)
                else
                    table.insert(smoothed, curX); table.insert(smoothed, curY)
                end
                
                ::next_point::
            end
            
            if isClosed and #smoothed >= 2 then
                table.insert(smoothed, smoothed[1])
                table.insert(smoothed, smoothed[2])
            end
            table.insert(map.contours, smoothed)
        end
    end
end

function map.update(dt, player, enemyModule, soulModule, projectileModule)
    enemyModule.update(dt, player, map)
    soulModule.update(dt, player, map)
    projectileModule.update(dt, player, map)
end

function map.draw()
    -- Draw walls and floors
    for y = 1, map.height do
        for x = 1, map.width do
            local px, py = (x-1)*map.gridSize, (y-1)*map.gridSize
            if map.data[y][x] == 1 then
                love.graphics.setColor(0, 0, 0, 1) 
                love.graphics.rectangle("fill", px, py, map.gridSize, map.gridSize)
            else
                love.graphics.setColor(0.12, 0.15, 0.14) 
                love.graphics.rectangle("fill", px, py, map.gridSize, map.gridSize)
            end
        end
    end
    
    -- Floor textures
    for _, dec in ipairs(map.decorations) do
        love.graphics.setColor(dec.color[1], dec.color[2], dec.color[3], 1)
        love.graphics.circle("fill", dec.x, dec.y, dec.r)
    end
    
    -- Draw textured, curved wall lines
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    -- 1. Base Layer (Dark shadow depth)
    for _, loop in ipairs(map.contours) do
        if #loop >= 4 then
            love.graphics.setLineWidth(10)
            love.graphics.setColor(0.04, 0.04, 0.06, 1)
            love.graphics.line(loop)
        end
    end
    
    -- 2. Surface Highlight (Reactive to lighting)
    for _, loop in ipairs(map.contours) do
        if #loop >= 4 then
            love.graphics.setLineWidth(3)
            -- Much brighter base highlight to ensure multiply blending makes it visible
            love.graphics.setColor(0.5, 0.55, 0.52, 1)
            love.graphics.line(loop)
            
            -- Sub-highlight for texture jitter
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(0.6, 0.65, 0.62, 1)
            love.graphics.push()
            love.graphics.translate(love.math.random()*0.5, love.math.random()*0.5)
            love.graphics.line(loop)
            love.graphics.pop()
        end
    end
end

function map.getPortalWorldPos()
    return (map.portalX - 0.5) * map.gridSize, (map.portalY - 0.5) * map.gridSize
end

function map.drawWorld(hubModule, objectCanvas, screenCanvas)
    map.draw()
    -- Draw portal to objectCanvas for highlight
    love.graphics.setCanvas(objectCanvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.push()
    love.graphics.origin()
    hubModule.drawPortal(100, 100, 60)
    love.graphics.pop()
    love.graphics.setCanvas(screenCanvas)
    
    local px, py = map.getPortalWorldPos()
    hubModule.drawPortal(px, py, 60)
end

function map.isOnPortal(px, py)
    local tx, ty = map.getPortalWorldPos()
    local dx, dy = px - tx, py - ty
    return math.sqrt(dx*dx + dy*dy) < 85
end

return map