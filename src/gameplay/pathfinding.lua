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

    local closedSet = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    local nodePos = {}

    -- Min-heap for open set keys, plus key->heap-index map.
    local openHeap = {}
    local openIndex = {}

    local function heapSwap(i, j)
        openHeap[i], openHeap[j] = openHeap[j], openHeap[i]
        openIndex[openHeap[i]] = i
        openIndex[openHeap[j]] = j
    end

    local function heapLess(i, j)
        local ki = openHeap[i]
        local kj = openHeap[j]
        local fi = fScore[ki] or math.huge
        local fj = fScore[kj] or math.huge
        if fi == fj then
            return (gScore[ki] or math.huge) > (gScore[kj] or math.huge)
        end
        return fi < fj
    end

    local function siftUp(i)
        while i > 1 do
            local parent = math.floor(i / 2)
            if heapLess(i, parent) then
                heapSwap(i, parent)
                i = parent
            else
                break
            end
        end
    end

    local function siftDown(i)
        while true do
            local left = i * 2
            local right = left + 1
            local smallest = i
            if left <= #openHeap and heapLess(left, smallest) then smallest = left end
            if right <= #openHeap and heapLess(right, smallest) then smallest = right end
            if smallest ~= i then
                heapSwap(i, smallest)
                i = smallest
            else
                break
            end
        end
    end

    local function pushOpen(key)
        openHeap[#openHeap + 1] = key
        openIndex[key] = #openHeap
        siftUp(#openHeap)
    end

    local function popOpen()
        local root = openHeap[1]
        local last = openHeap[#openHeap]
        openHeap[#openHeap] = nil
        openIndex[root] = nil
        if #openHeap > 0 then
            openHeap[1] = last
            openIndex[last] = 1
            siftDown(1)
        end
        return root
    end

    local function touchOpen(key)
        local idx = openIndex[key]
        if idx then
            siftUp(idx)
            siftDown(idx)
        else
            pushOpen(key)
        end
    end

    local startKey = get_node_key(startGX, startGY)
    nodePos[startKey] = {x = startGX, y = startGY}
    gScore[startKey] = 0
    fScore[startKey] = heuristic(startGX, startGY, endGX, endGY)
    pushOpen(startKey)

    while #openHeap > 0 do
        local currentKey = popOpen()
        local current = nodePos[currentKey]
        if current.x == endGX and current.y == endGY then
            -- Reconstruct path
            local path = {}
            local tempKey = currentKey
            while cameFrom[tempKey] do
                local node = nodePos[tempKey]
                -- Convert back to pixels (center of tile)
                local px = (node.x - 1) * map.gridSize + map.gridSize/2
                local py = (node.y - 1) * map.gridSize + map.gridSize/2
                table.insert(path, 1, {x = px, y = py})
                tempKey = cameFrom[tempKey]
            end
            return path
        end

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
                        if gScore[neighborKey] == nil or tentativeG < gScore[neighborKey] then
                            cameFrom[neighborKey] = currentKey
                            gScore[neighborKey] = tentativeG
                            fScore[neighborKey] = gScore[neighborKey] + heuristic(neighbor.x, neighbor.y, endGX, endGY)
                            nodePos[neighborKey] = neighbor
                            touchOpen(neighborKey)
                        end
                    end
                end
            end
        end
    end

    return nil -- No path
end

return pathfinding
