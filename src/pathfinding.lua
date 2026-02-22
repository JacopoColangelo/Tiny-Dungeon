local pathfinding = {}

local function heuristic(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function get_node_key(x, y)
    return x .. "," .. y
end

function pathfinding.findPath(startX, startY, endX, endY, map)
    -- Start and end are in pixel coordinates, convert to grid
    local startGX = math.floor(startX / map.gridSize) + 1
    local startGY = math.floor(startY / map.gridSize) + 1
    local endGX = math.floor(endX / map.gridSize) + 1
    local endGY = math.floor(endY / map.gridSize) + 1

    -- Boundary checks
    if startGX < 1 or startGX > map.width or startGY < 1 or startGY > map.height then return nil end
    if endGX < 1 or endGX > map.width or endGY < 1 or endGY > map.height then return nil end
    
    -- If end is in a wall, return nil (slots should already be checked, but for safety)
    if map.data[endGY][endGX] == 1 then return nil end
    
    -- If start is in a wall (pushed by collision), try to find nearest neighbor floor
    if map.data[startGY][startGX] == 1 then
        local foundFloor = false
        local neighbors = {{x=startGX+1, y=startGY}, {x=startGX-1, y=startGY}, {x=startGX, y=startGY+1}, {x=startGX, y=startGY-1}}
        for _, n in ipairs(neighbors) do
            if n.x >= 1 and n.x <= map.width and n.y >= 1 and n.y <= map.height then
                if map.data[n.y][n.x] == 0 then
                    startGX, startGY = n.x, n.y
                    foundFloor = true
                    break
                end
            end
        end
        if not foundFloor then return nil end -- Surrounded by walls
    end

    if startGX == endGX and startGY == endGY then return {} end

    local openSet = {}
    local closedSet = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}

    local startKey = get_node_key(startGX, startGY)
    openSet[startKey] = {x = startGX, y = startGY}
    gScore[startKey] = 0
    fScore[startKey] = heuristic(startGX, startGY, endGX, endGY)

    local function getLowestF()
        local bestNode = nil
        local bestScore = math.huge
        local bestKey = nil
        for key, node in pairs(openSet) do
            if fScore[key] < bestScore then
                bestScore = fScore[key]
                bestNode = node
                bestKey = key
            end
        end
        return bestNode, bestKey
    end

    while next(openSet) do
        local current, currentKey = getLowestF()
        if current.x == endGX and current.y == endGY then
            -- Reconstruct path
            local path = {}
            local tempKey = currentKey
            while cameFrom[tempKey] do
                -- Convert back to pixels (center of tile)
                local px = (current.x - 1) * map.gridSize + map.gridSize/2
                local py = (current.y - 1) * map.gridSize + map.gridSize/2
                table.insert(path, 1, {x = px, y = py})
                tempKey = cameFrom[tempKey]
                current = closedSet[tempKey] or openSet[tempKey] 
                -- Note: current needs to be updated based on tempKey
                if tempKey then
                    local coords = {}
                    for v in tempKey:gmatch("%d+") do table.insert(coords, tonumber(v)) end
                    current = {x = coords[1], y = coords[2]}
                end
            end
            return path
        end

        openSet[currentKey] = nil
        closedSet[currentKey] = true

        local neighbors = {
            {x = current.x + 1, y = current.y},
            {x = current.x - 1, y = current.y},
            {x = current.x, y = current.y + 1},
            {x = current.x, y = current.y - 1}
        }

        for _, neighbor in ipairs(neighbors) do
            if neighbor.x >= 1 and neighbor.x <= map.width and neighbor.y >= 1 and neighbor.y <= map.height then
                if map.data[neighbor.y][neighbor.x] == 0 then
                    local neighborKey = get_node_key(neighbor.x, neighbor.y)
                    if not closedSet[neighborKey] then
                        local tentativeG = gScore[currentKey] + 1
                        if not openSet[neighborKey] or tentativeG < gScore[neighborKey] then
                            cameFrom[neighborKey] = currentKey
                            gScore[neighborKey] = tentativeG
                            fScore[neighborKey] = gScore[neighborKey] + heuristic(neighbor.x, neighbor.y, endGX, endGY)
                            openSet[neighborKey] = neighbor
                        end
                    end
                end
            end
        end
    end

    return nil -- No path
end

return pathfinding
