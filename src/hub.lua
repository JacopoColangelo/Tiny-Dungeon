-- Hub Level: Withered Grove with Gothic Sanctuary
-- Hand-crafted map with distinct visual palette from dungeons

local shadows = require("src.shadows")

local hub = {}

hub.gridSize = 50
hub.width = 24
hub.height = 24
hub.data = {}
hub.decorations = {}
hub.contours = {}
hub.spawnX = 12
hub.spawnY = 18

-- Portal position (center of sanctuary)
hub.portalX = 12
hub.portalY = 8
hub.portalRadius = 60
hub.portalParticles = {}

-- ── Color Palette (withered grove / gothic stone) ────────────────────────────

local colors = {
    -- Floors (brighter to catch multiply lighting properly)
    floorBase     = {0.12, 0.15, 0.11},      -- mossy green
    floorAlt      = {0.14, 0.12, 0.09},      -- earthy brown
    -- Walls
    wallBase      = {0.06, 0.07, 0.05},      -- deep dark green-black
    -- Decorations
    moss          = {0.10, 0.18, 0.10, 0.8}, -- green moss patches
    lichen        = {0.18, 0.15, 0.08, 0.6}, -- yellow-brown lichen
    deadLeaf      = {0.20, 0.12, 0.06, 0.5}, -- brown dead leaves
    stone         = {0.22, 0.20, 0.18, 0.4}, -- crumbled stone
    -- Contour walls
    contourDark   = {0.05, 0.06, 0.04, 1},
    contourLight  = {0.45, 0.48, 0.42, 1},   -- much brighter for highlights
    contourAccent = {0.55, 0.58, 0.52, 1},
}

-- ── Hand-Crafted Layout ──────────────────────────────────────────────────────
-- 0 = floor, 1 = wall
-- Layout: Overgrown path from south spawn leading north to central sanctuary

local layout = {
    -- Row  1: all walls
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    -- Row  2: walls with thin clearing
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    -- Row  3
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    -- Row  4: sanctuary top edge
    {1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1},
    -- Row  5: sanctuary interior
    {1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1},
    -- Row  6
    {1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1},
    -- Row  7: sanctuary widest + portal area
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row  8: portal center row
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row  9
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 10
    {1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1},
    -- Row 11: sanctuary narrows into path
    {1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1},
    -- Row 12: path with side alcoves
    {1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1},
    -- Row 13: narrow path
    {1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1},
    -- Row 14: path widens to grove
    {1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1},
    -- Row 15: grove area (wider)
    {1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1},
    -- Row 16
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 17: grove widest
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 18: spawn row
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 19
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 20: grove narrows
    {1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1},
    -- Row 21
    {1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1},
    -- Row 22
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    -- Row 23
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    -- Row 24
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

-- ── Pillar positions (gothic stone pillars in the sanctuary) ─────────────────

local pillars = {
    {x = 7,  y = 6},
    {x = 17, y = 6},
    {x = 7,  y = 10},
    {x = 17, y = 10},
    -- Grove pillars (crumbled)
    {x = 6,  y = 16},
    {x = 18, y = 16},
}

-- ── Dead tree positions ──────────────────────────────────────────────────────

local deadTrees = {
    {x = 5,  y = 15, size = 1.2},
    {x = 19, y = 15, size = 1.0},
    {x = 5,  y = 19, size = 0.9},
    {x = 19, y = 19, size = 1.1},
    {x = 8,  y = 20, size = 0.7},
    {x = 16, y = 20, size = 0.8},
}

-- ── Generate ─────────────────────────────────────────────────────────────────

function hub.generate()
    hub.decorations = {}
    hub.contours = {}

    -- Copy layout into data
    for y = 1, hub.height do
        hub.data[y] = {}
        for x = 1, hub.width do
            hub.data[y][x] = layout[y][x]
        end
    end

    -- Place pillars as walls
    for _, p in ipairs(pillars) do
        if hub.data[p.y] then hub.data[p.y][p.x] = 1 end
    end

    -- Generate floor decorations (moss, lichen, dead leaves, pebbles)
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 0 then
                local numDecals = love.math.random(2, 7)
                for i = 1, numDecals do
                    local px = (x - 1) * hub.gridSize + love.math.random(4, hub.gridSize - 4)
                    local py = (y - 1) * hub.gridSize + love.math.random(4, hub.gridSize - 4)
                    local pr = love.math.random(1, 4)
                    local roll = love.math.random()
                    local color
                    if roll < 0.35 then
                        color = colors.moss
                    elseif roll < 0.55 then
                        color = colors.lichen
                    elseif roll < 0.75 then
                        color = colors.deadLeaf
                    else
                        color = colors.stone
                    end
                    table.insert(hub.decorations, {x = px, y = py, r = pr, color = color})
                end
            end
        end
    end

    -- Build contours (same edge-chaining as map.lua)
    local rawEdges = {}
    local s = hub.gridSize
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 1 then
                local px, py = (x-1)*s, (y-1)*s
                if y > 1 and hub.data[y-1][x] == 0 then table.insert(rawEdges, {x1=px, y1=py, x2=px+s, y2=py}) end
                if y < hub.height and hub.data[y+1][x] == 0 then table.insert(rawEdges, {x1=px, y1=py+s, x2=px+s, y2=py+s}) end
                if x > 1 and hub.data[y][x-1] == 0 then table.insert(rawEdges, {x1=px, y1=py, x2=px, y2=py+s}) end
                if x < hub.width and hub.data[y][x+1] == 0 then table.insert(rawEdges, {x1=px+s, y1=py, x2=px+s, y2=py+s}) end
            end
        end
    end

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

        if #loop >= 4 then
            table.insert(hub.contours, loop)
        end
    end

    -- Update shadow edges
    shadows.updateMapEdges(hub)
end

function hub.updatePortal(dt, map)
    -- Spawn portal particles
    if #hub.portalParticles < 25 then
        local portalX, portalY = map.getPortalWorldPos()
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(10, hub.portalRadius + 20)
        table.insert(hub.portalParticles, {
            x = portalX + math.cos(angle) * dist,
            y = portalY + math.sin(angle) * dist,
            vx = math.cos(angle) * love.math.random(20, 50),
            vy = math.sin(angle) * love.math.random(20, 50),
            life = love.math.random(1.0, 2.5),
            maxLife = 2.5,
            size = love.math.random(2, 4)
        })
    end

    -- Update particles
    for i = #hub.portalParticles, 1, -1 do
        local p = hub.portalParticles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        -- Spiral towards center slightly
        local portalX, portalY = map.getPortalWorldPos()
        local dx, dy = portalX - p.x, portalY - p.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 5 then
            p.vx = p.vx + (dx/dist) * 15 * dt
            p.vy = p.vy + (dy/dist) * 15 * dt
        end
        if p.life <= 0 then table.remove(hub.portalParticles, i) end
    end
end

-- ── Spawn & Portal accessors ─────────────────────────────────────────────────

function hub.getSpawnWorldPos()
    local x = (hub.spawnX - 1) * hub.gridSize + hub.gridSize/2
    local y = (hub.spawnY - 1) * hub.gridSize + hub.gridSize/2
    return x, y
end

function hub.getPortalWorldPos()
    local x = (hub.portalX - 1) * hub.gridSize + hub.gridSize/2
    local y = (hub.portalY - 1) * hub.gridSize + hub.gridSize/2
    return x, y
end

function hub.isOnPortal(px, py)
    local portalWX, portalWY = hub.getPortalWorldPos()
    local dx = px - portalWX
    local dy = py - portalWY
    return (dx*dx + dy*dy) < (120 * 120)
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

function hub.draw()
    local s = hub.gridSize

    -- Draw walls and floors with grove palette
    for y = 1, hub.height do
        for x = 1, hub.width do
            local px, py = (x-1)*s, (y-1)*s
            if hub.data[y][x] == 1 then
                love.graphics.setColor(colors.wallBase)
                love.graphics.rectangle("fill", px, py, s, s)
            else
                -- Alternate floor colors for texture
                if (x + y) % 3 == 0 then
                    love.graphics.setColor(colors.floorAlt)
                else
                    love.graphics.setColor(colors.floorBase)
                end
                love.graphics.rectangle("fill", px, py, s, s)
            end
        end
    end

    -- Floor decorations
    for _, dec in ipairs(hub.decorations) do
        love.graphics.setColor(dec.color[1], dec.color[2], dec.color[3], dec.color[4] or 1)
        love.graphics.circle("fill", dec.x, dec.y, dec.r)
    end

    -- Dead trees (gnarled pixel shapes)
    for _, tree in ipairs(deadTrees) do
        local tx = (tree.x - 1) * s + s/2
        local ty = (tree.y - 1) * s + s/2
        local sz = tree.size

        -- Trunk
        love.graphics.setColor(0.12, 0.08, 0.04, 0.8)
        love.graphics.rectangle("fill", tx - 3*sz, ty - 10*sz, 6*sz, 20*sz)

        -- Branches (angular, dead)
        love.graphics.setLineWidth(2 * sz)
        love.graphics.setColor(0.10, 0.07, 0.03, 0.7)
        love.graphics.line(tx, ty - 5*sz, tx - 12*sz, ty - 18*sz)
        love.graphics.line(tx, ty - 8*sz, tx + 10*sz, ty - 20*sz)
        love.graphics.line(tx - 12*sz, ty - 18*sz, tx - 16*sz, ty - 14*sz)
        love.graphics.line(tx + 10*sz, ty - 20*sz, tx + 14*sz, ty - 17*sz)

        -- Root bumps
        love.graphics.setColor(0.09, 0.06, 0.03, 0.5)
        love.graphics.circle("fill", tx - 5*sz, ty + 9*sz, 3*sz)
        love.graphics.circle("fill", tx + 4*sz, ty + 8*sz, 2.5*sz)
    end

    -- Gothic stone pillars
    for _, p in ipairs(pillars) do
        local px = (p.x - 1) * s
        local py = (p.y - 1) * s

        -- Pillar base (dark stone)
        love.graphics.setColor(0.10, 0.10, 0.09, 1)
        love.graphics.rectangle("fill", px + 8, py + 4, s - 16, s - 8)
        -- Pillar highlight
        love.graphics.setColor(0.20, 0.19, 0.16, 0.6)
        love.graphics.rectangle("fill", px + 10, py + 6, 4, s - 14)
        -- Pillar crack
        love.graphics.setColor(0.05, 0.05, 0.04, 0.5)
        love.graphics.line(px + s/2, py + 8, px + s/2 + 3, py + s - 10)
    end

    -- Wall contour lines (grove style: earthy, mossy tones)
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineJoin("bevel")

    for _, loop in ipairs(hub.contours) do
        if #loop >= 4 then
            love.graphics.setLineWidth(8)
            love.graphics.setColor(colors.contourDark)
            love.graphics.line(loop)
        end
    end
    for _, loop in ipairs(hub.contours) do
        if #loop >= 4 then
            love.graphics.setLineWidth(3)
            love.graphics.setColor(colors.contourLight)
            love.graphics.line(loop)
            love.graphics.setLineWidth(1.5)
            love.graphics.setColor(colors.contourAccent)
            love.graphics.push()
            love.graphics.translate(love.math.random()*0.5, love.math.random()*0.5)
            love.graphics.line(loop)
            love.graphics.pop()
        end
    end
end

-- ── Portal Drawing ───────────────────────────────────────────────────────────

function hub.drawPortal(px, py, radius)
    px = px or hub.getPortalWorldPos()
    py = py or select(2, hub.getPortalWorldPos())
    radius = radius or hub.portalRadius
    local t = love.timer.getTime()

    love.graphics.setBlendMode("add")

    -- 1. Outer Ethereal Atmosphere
    for i = 8, 1, -1 do
        local pulse = math.sin(t * 1.5 + i * 0.4) * 0.2 + 0.8
        local rad = radius * (1.2 - i/10) * pulse
        local a = (1 - i/8) * 0.08
        love.graphics.setColor(0.5, 0.2, 0.8, a)
        love.graphics.circle("fill", px, py, rad)
    end

    -- 2. Pulsing Runic Rings
    for i = 4, 1, -1 do
        local pulse = math.sin(t * 2.5 + i * 0.8) * 0.2 + 0.8
        local rad = radius * (i / 4) * pulse
        local a = (1 - i/5) * 0.2
        love.graphics.setLineWidth(2)
        love.graphics.setColor(0.6, 0.3, 1.0, a * pulse)
        love.graphics.circle("line", px, py, rad)
        -- Cyan accent ring
        love.graphics.setColor(0.2, 0.8, 1.0, a * 0.5)
        love.graphics.circle("line", px, py, rad * 0.92)
    end

    -- 3. Mystical Particles (from updatePortal)
    for _, p in ipairs(hub.portalParticles) do
        local alpha = (p.life / p.maxLife) * 0.7
        love.graphics.setColor(0.7, 0.4, 1.0, alpha)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
        -- Trailing glow
        love.graphics.setColor(0.4, 0.1, 0.8, alpha * 0.3)
        love.graphics.rectangle("fill", math.floor(p.x)-2, math.floor(p.y)-2, p.size+4, p.size+4)
    end

    -- 4. Deep Core Vapor
    for i = 15, 1, -1 do
        local r = (radius * 0.5) * (i / 15)
        local a = (1 - i/15) * 0.15
        local flicker = math.sin(t * 8) * 0.03
        love.graphics.setColor(0.2, 0.0, 0.4, a + flicker)
        love.graphics.circle("fill", px, py, r)
    end

    -- 5. Radiant Singularity (Center)
    local sPulse = math.sin(t * 6) * 0.4 + 0.6
    love.graphics.setColor(120/255, 80/255, 255/255, 0.8 * sPulse)
    love.graphics.circle("fill", px, py, 10 * sPulse)
    love.graphics.setColor(1, 1, 1, 0.5 * sPulse)
    love.graphics.circle("fill", px, py, 4)

    love.graphics.setBlendMode("alpha")
end

return hub
