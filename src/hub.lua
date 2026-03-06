-- Hub Level: Withered Grove with Gothic Sanctuary
-- Hand-crafted map with distinct visual palette from dungeons

local shadows = require("src.shadows")

local hub = {}
hub.isHub = true

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
hub.portalBaseImg = nil
hub.portalFrames = {}
hub.portalFrame = 1
hub.portalTimer = 0
hub.portalFPS = 8
hub.portalCollisionRadius = 15
hub.tiles = {}
hub.tileData = {}

-- ── Color Palette (withered grove / gothic stone) ────────────────────────────

local colors = {
    -- Floors (Lush Forest Camp)
    floorBase     = {0.15, 0.25, 0.12},      -- vibrant mossy green
    floorAlt      = {0.18, 0.18, 0.10},      -- warm earthy dirt
    -- Walls
    wallBase      = {0.05, 0.08, 0.04},      -- very dark forest green
    -- Decorations
    moss          = {0.20, 0.35, 0.15, 0.8}, -- bright green moss patches
    lichen        = {0.25, 0.22, 0.10, 0.6}, -- warm yellow lichen
    deadLeaf      = {0.30, 0.15, 0.08, 0.8}, -- vibrant autumn leaves
    stone         = {0.22, 0.20, 0.18, 0.6}, -- campsite stones
    -- Contour walls
    contourDark   = {0.04, 0.07, 0.03, 1},
    contourLight  = {0.35, 0.45, 0.28, 1},   -- lush highlights
    contourAccent = {0.45, 0.55, 0.35, 1},
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
    if not hub.portalBaseImg then
        hub.portalBaseImg = love.graphics.newImage("assets/sprites/portal_base.png")
    end
    if #hub.portalFrames == 0 then
        for i = 0, 5 do
            local path = string.format("assets/sprites/rift_spritesheet/%02d_rift_animated.png", i)
            table.insert(hub.portalFrames, love.graphics.newImage(path))
        end
    end
    hub.contours = {}
    hub.grassList = {}
    hub.tileData = {}

    -- Load tiles if not loaded
    if #hub.tiles == 0 then
        for i = 0, 63 do
            local path = string.format("assets/sprites/grass_tileset/%02d_TX Tileset Grass.png", i)
            local success, img = pcall(love.graphics.newImage, path)
            if success then
                hub.tiles[i] = img
            end
        end
    end

    -- Copy layout into data and initialize tileData
    for y = 1, hub.height do
        hub.data[y] = {}
        hub.tileData[y] = {}
        for x = 1, hub.width do
            hub.data[y][x] = layout[y][x]
            if layout[y][x] == 0 then
                -- Default to random grass (0-31)
                hub.tileData[y][x] = love.math.random(0, 31)
            end
        end
    end

    -- Create Slab Path (32-61) from Spawn to Portal
    -- Simple linear path for now, we can make it "organic" by adding some width/noise
    local startX, startY = hub.spawnX, hub.spawnY
    local endX, endY = hub.portalX, hub.portalY
    
    local currX, currY = startX, startY
    while currX ~= endX or currY ~= endY do
        -- Mark current and immediate neighbors for a thicker path
        for dy = -1, 1 do
            for dx = -1, 1 do
                local nx, ny = currX + dx, currY + dy
                if hub.tileData[ny] and hub.tileData[ny][nx] then
                    hub.tileData[ny][nx] = love.math.random(32, 61)
                end
            end
        end

        if currX < endX then currX = currX + 1
        elseif currX > endX then currX = currX - 1
        end
        if currY < endY then currY = currY + 1
        elseif currY > endY then currY = currY - 1
        end
    end
    -- Mark end point too
    hub.tileData[endY][endX] = love.math.random(32, 61)
    if hub.tileData[endY-1] then hub.tileData[endY-1][endX] = love.math.random(32, 61) end
    if hub.tileData[endY+1] then hub.tileData[endY+1][endX] = love.math.random(32, 61) end
    if hub.tileData[endY][endX-1] then hub.tileData[endY][endX-1] = love.math.random(32, 61) end
    if hub.tileData[endY][endX+1] then hub.tileData[endY][endX+1] = love.math.random(32, 61) end

    -- Place pillars as walls
    for _, p in ipairs(pillars) do
        if hub.data[p.y] then hub.data[p.y][p.x] = 1 end
    end

    -- Generate floor decorations and reactive grass
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 0 then
                -- 2. Reactive Grass

                -- 2. Reactive Grass
                -- Spawn more grass near the edges, less in the direct path
                local spawnChance = (x < 8 or x > 16) and 0.8 or 0.3
                if love.math.random() < spawnChance then
                    local numGrass = love.math.random(3, 8)
                    for i = 1, numGrass do
                        local gx = (x - 1) * hub.gridSize + love.math.random(2, hub.gridSize - 2)
                        local gy = (y - 1) * hub.gridSize + love.math.random(2, hub.gridSize - 2)
                        
                        -- Keep grass away from the portal center so it doesn't clip into it
                        local pdx, pdy = gx - hub.portalX * hub.gridSize, gy - hub.portalY * hub.gridSize
                        if (pdx*pdx + pdy*pdy) > (hub.portalRadius * hub.portalRadius + 400) then
                            table.insert(hub.grassList, {
                                x = gx,
                                y = gy,
                                length = love.math.random(8, 18),
                                baseAngle = -math.pi / 2 + (love.math.random() - 0.5) * 0.4, -- mostly straight up, slight variance
                                currentAngle = 0,
                                targetAngle = 0,
                                swayOffset = love.math.random() * math.pi * 2,
                                stiffness = love.math.random(8, 15) -- how fast it springs back
                            })
                        end
                    end
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

function hub.updateGrass(dt, player)
    local t = love.timer.getTime()
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    
    -- Calculate velocity manually since player doesn't store vx/vy
    local vx = player.x - (player.lastX or player.x)
    local vy = player.y - (player.lastY or player.y)
    local pVelocitySq = (vx * vx + vy * vy) / (dt * dt + 0.0001)
    
    local isPlayerMoving = pVelocitySq > 100 -- speed threshold

    local windSway = math.sin(t * 1.5) * 0.15 + math.sin(t * 0.8) * 0.1

    for _, grass in ipairs(hub.grassList) do
        -- Base wind
        local ambientAngle = grass.baseAngle + math.sin(t * 2 + grass.swayOffset) * windSway

        -- Player interaction
        local dx = grass.x - px
        local dy = grass.y - py
        local distSq = dx*dx + dy*dy
        
        local interactionRadius = (player.size * 1.2)
        local interactSq = interactionRadius * interactionRadius

        if isPlayerMoving and distSq < interactSq then
            -- Bend away from player based on distance and player speed
            local dist = math.sqrt(distSq)
            local pushFactor = 1.0 - (dist / interactionRadius)
            local pushAngle = math.atan2(dy, dx)
            
            -- Clamp push angle relative to base angle so it doesn't bend completely flat or backwards unnaturally
            local angleDiff = pushAngle - grass.baseAngle
            -- Normalize difference
            while angleDiff > math.pi do angleDiff = angleDiff - 2*math.pi end
            while angleDiff < -math.pi do angleDiff = angleDiff + 2*math.pi end
            
            -- Max bend is about 70 degrees (1.2 rad)
            local maxBend = 1.2 * pushFactor
            if angleDiff > 0 then
                grass.targetAngle = grass.baseAngle + math.min(angleDiff, maxBend)
            else
                grass.targetAngle = grass.baseAngle + math.max(angleDiff, -maxBend)
            end
        else
            -- Snap back to wind angle
            grass.targetAngle = ambientAngle
        end

        -- Spring physics
        local diff = grass.targetAngle - grass.currentAngle
        grass.currentAngle = grass.currentAngle + diff * grass.stiffness * dt
    end
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

    -- Update animation frame
    hub.portalTimer = hub.portalTimer + dt
    if hub.portalTimer >= 1 / hub.portalFPS then
        hub.portalTimer = hub.portalTimer - (1 / hub.portalFPS)
        hub.portalFrame = (hub.portalFrame % 6) + 1
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

    -- Draw tiled floors (Grass & Slabs)
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 0 then
                local tIdx = hub.tileData[y][x]
                local img = hub.tiles[tIdx]
                if img then
                    local px, py = (x-1)*s, (y-1)*s
                    local iw, ih = img:getDimensions()
                    
                    -- Original tile colors (no tint)
                    love.graphics.setColor(1, 1, 1, 1) 
                    
                    love.graphics.draw(img, px, py, 0, s/iw, s/ih)
                end
            end
        end
    end
    
    -- Draw portal base sprite
    if hub.portalBaseImg then
        local px, py = hub.getPortalWorldPos()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(hub.portalBaseImg, px, py, 0, 1, 1, hub.portalBaseImg:getWidth()/2, hub.portalBaseImg:getHeight()/2)
    end
    
    hub.drawGrass()

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
            love.graphics.line(loop)
            love.graphics.pop()
        end
    end
end

function hub.drawGrass()
    love.graphics.setLineStyle("rough") -- Keep it pixelated/sharp
    love.graphics.setLineWidth(2)

    for _, grass in ipairs(hub.grassList) do
        -- Calculate the tip of the grass blade
        local tipX = grass.x + math.cos(grass.currentAngle) * grass.length
        local tipY = grass.y + math.sin(grass.currentAngle) * grass.length
        
        -- Color calculation: darker at the base, lighter/more vibrant at the tip
        -- We also shift the hue slightly based on the bend angle to simulate caught light
        local bendAmount = math.abs(grass.currentAngle - grass.baseAngle)
        
        love.graphics.setColor(0.20, 0.35, 0.20, 1) -- Lightened base green
        love.graphics.line(grass.x, grass.y, grass.x + (tipX - grass.x)*0.4, grass.y + (tipY - grass.y)*0.4)
        
        love.graphics.setColor(0.40 + bendAmount*0.1, 0.70 + bendAmount*0.15, 0.30, 1) -- Lightened tip green
        love.graphics.line(grass.x + (tipX - grass.x)*0.4, grass.y + (tipY - grass.y)*0.4, tipX, tipY)
    end
end

-- ── Draw Portal ──────────────────────────────────────────────────────────────

function hub.drawPortal(px, py, radius)
    px = px or hub.getPortalWorldPos()
    py = py or select(2, hub.getPortalWorldPos())
    
    local rPy = py - 25 -- Visual rift offset (only affects drawing, not collision)
    radius = radius or hub.portalRadius
    local t = love.timer.getTime()

    -- 1. Outer Ethereal Atmosphere (Alpha pass for softness)
    love.graphics.setBlendMode("alpha")
    for i = 4, 1, -1 do
        local pulse = math.sin(t * 1.5 + i * 0.4) * 0.2 + 0.8
        local rad = radius * (1.1 - i/8) * pulse
        local a = (1 - i/4) * 0.05
        love.graphics.setColor(0.6, 0.3, 0.9, a) -- Richer purple
        love.graphics.circle("fill", px, rPy, rad)
    end

    -- 2. Animated Rift Sprite - TWO PASSES for Opaque + Glow
    if hub.portalFrames[hub.portalFrame] then
        local img = hub.portalFrames[hub.portalFrame]
        local qw, qh = img:getDimensions()
        local baseScale = (radius * 0.8) / qw 
        
        -- Pass A: Opaque Base (Alpha)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1) -- Fully opaque sprite
        love.graphics.draw(img, px, rPy, 0, baseScale, baseScale, qw/2, qh/2)
        
        -- Pass B: Additive Glow (Add)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.8, 0.4, 1.0, 0.8) -- Bright purple glow
        love.graphics.draw(img, px, rPy, 0, baseScale * 1.1, baseScale * 1.1, qw/2, qh/2)
    end

    -- 3. Mystical Particles (Pixelated Squares - Additive)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(hub.portalParticles) do
        local alpha = (p.life / p.maxLife) * 0.7
        love.graphics.setColor(0.8, 0.4, 1.0, alpha) -- Matching purple
        love.graphics.rectangle("fill", math.floor(p.x - p.size/2), math.floor(p.y - p.size/2 - 25), p.size, p.size)
        -- Trailing glow
        love.graphics.setColor(0.6, 0.2, 0.9, alpha * 0.3)
        love.graphics.rectangle("fill", math.floor(p.x - p.size/2 - 1), math.floor(p.y - p.size/2 - 1 - 25), p.size + 2, p.size + 2)
    end

    -- 4. Radiant Singularity (Center - Additive)
    local sPulse = math.sin(t * 6) * 0.4 + 0.6
    love.graphics.setColor(0.8, 0.5, 1.0, 0.9 * sPulse)
    love.graphics.rectangle("fill", px - 4 * sPulse, rPy - 4 * sPulse, 8 * sPulse, 8 * sPulse)
    love.graphics.setColor(1, 1, 1, 0.6 * sPulse)
    love.graphics.rectangle("fill", px - 1.5, rPy - 1.5, 3, 3)

    love.graphics.setBlendMode("alpha")
end

return hub
