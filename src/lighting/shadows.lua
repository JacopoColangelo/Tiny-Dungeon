local shadows = {}

shadows.edges = {}
shadows.endpoints = {}

-- Helper to check if a tile is a wall or out of bounds
local function isWall(map, gx, gy)
    if gy < 1 or gy > map.height or gx < 1 or gx > map.width then return true end
    return map.data[gy][gx] == 1
end

function shadows.updateMapEdges(map)
    shadows.edges = {}
    shadows.endpoints = {}
    
    local s = map.gridSize
    
    -- Extract edges for each wall tile that borders an empty tile
    for y = 1, map.height do
        for x = 1, map.width do
            if map.data[y][x] == 1 then
                local px = (x - 1) * s
                local py = (y - 1) * s
                
                -- Top edge (if tile above is not a wall)
                if not isWall(map, x, y - 1) then
                    table.insert(shadows.edges, {x1 = px, y1 = py, x2 = px + s, y2 = py})
                end
                -- Bottom edge
                if not isWall(map, x, y + 1) then
                    table.insert(shadows.edges, {x1 = px, y1 = py + s, x2 = px + s, y2 = py + s})
                end
                -- Left edge
                if not isWall(map, x - 1, y) then
                    table.insert(shadows.edges, {x1 = px, y1 = py, x2 = px, y2 = py + s})
                end
                -- Right edge
                if not isWall(map, x + 1, y) then
                    table.insert(shadows.edges, {x1 = px + s, y1 = py, x2 = px + s, y2 = py + s})
                end
            end
        end
    end
    
    -- Level bounds edges to enclose the playable area completely
    local mw = map.width * s
    local mh = map.height * s
    table.insert(shadows.edges, {x1 = 0, y1 = 0, x2 = mw, y2 = 0})
    table.insert(shadows.edges, {x1 = mw, y1 = 0, x2 = mw, y2 = mh})
    table.insert(shadows.edges, {x1 = mw, y1 = mh, x2 = 0, y2 = mh})
    table.insert(shadows.edges, {x1 = 0, y1 = mh, x2 = 0, y2 = 0})

    -- Deduplicate and collect endpoints
    local pointMap = {}
    local function addPoint(x, y)
        local key = x .. "," .. y
        if not pointMap[key] then
            pointMap[key] = true
            table.insert(shadows.endpoints, {x = x, y = y})
        end
    end

    for _, edge in ipairs(shadows.edges) do
        addPoint(edge.x1, edge.y1)
        addPoint(edge.x2, edge.y2)
    end
end

-- Find intersection between ray (origin, dir) and line segment (edge)
local function getIntersection(ox, oy, dx, dy, edge)
    local rpx, rpy = ox, oy
    local rdx, rdy = dx, dy
    
    local spx, spy = edge.x1, edge.y1
    local sdx, sdy = edge.x2 - edge.x1, edge.y2 - edge.y1

    local denom = rdx * sdy - rdy * sdx
    if math.abs(denom) < 0.0001 then return nil end

    local t1 = ((spx - rpx) * sdy - (spy - rpy) * sdx) / denom
    local t2 = ((spx - rpx) * rdy - (spy - rpy) * rdx) / denom

    if t1 >= 0 and t2 >= 0 and t2 <= 1 then
        return {
            x = rpx + rdx * t1,
            y = rpy + rdy * t1,
            param = t1
        }
    end

    return nil
end

function shadows.cast(ox, oy, radius)
    local polygon = {}
    local angles = {}
    local uniqueAngles = {}

    local function addAngle(ang)
        -- Normalize angle to -pi to pi range? Not strictly needed for unique, but good to be safe
        local clamped = math.floor(ang * 1000) / 1000
        if not uniqueAngles[clamped] then
            uniqueAngles[clamped] = true
            table.insert(angles, ang)
        end
    end

    local activeEndpoints = {}
    for _, p in ipairs(shadows.endpoints) do
        local dx = p.x - ox
        local dy = p.y - oy
        local distSq = dx*dx + dy*dy
        
        if distSq <= (radius * 1.5) * (radius * 1.5) then
            local baseAngle = math.atan2(dy, dx)
            addAngle(baseAngle - 0.0001)
            addAngle(baseAngle)
            addAngle(baseAngle + 0.0001)
            table.insert(activeEndpoints, p)
        end
    end
    
    local activeEdges = {}
    -- Fast AABB culling for edges
    for _, edge in ipairs(shadows.edges) do
        local minx = math.min(edge.x1, edge.x2)
        local maxx = math.max(edge.x1, edge.x2)
        local miny = math.min(edge.y1, edge.y2)
        local maxy = math.max(edge.y1, edge.y2)
        if not (maxx < ox - radius or minx > ox + radius or maxy < oy - radius or miny > oy + radius) then
            table.insert(activeEdges, edge)
        end
    end

    -- Always cast rays to bounding radius
    local steps = 30
    for i = 1, steps do
        addAngle((i / steps) * math.pi * 2 - math.pi)
    end

    table.sort(angles)

    for _, angle in ipairs(angles) do
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        
        local closestIntersect = nil
        local minT = radius

        for _, edge in ipairs(activeEdges) do
            local intersect = getIntersection(ox, oy, dx, dy, edge)
            if intersect and intersect.param < minT then
                minT = intersect.param
                closestIntersect = intersect
            end
        end

        if closestIntersect then
            -- Push point forward into the wall (epsilon) significantly so the blur doesn't pull the edge back off the wall corner
            table.insert(polygon, {x = closestIntersect.x + dx * 5.0, y = closestIntersect.y + dy * 5.0})
        else
            table.insert(polygon, {x = ox + dx * radius, y = oy + dy * radius})
        end
    end

    return polygon
end

return shadows
