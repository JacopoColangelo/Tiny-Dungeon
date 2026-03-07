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

-- ── Rain state ───────────────────────────────────────────────────────────────
hub.rain = {}
hub.RAIN_COUNT = 280          -- total persistent drops
hub.rainWX = 0                -- world scroll offset x
hub.rainWY = 0                -- world scroll offset y

-- ── Cloud / moonlight state ──────────────────────────────────────────────────
hub.cloudOffX = 0             -- perlin noise scroll offset X
hub.cloudOffY = 0             -- perlin noise scroll offset Y
hub.cloudSpeed = 1.0        -- world units/sec noise drift
hub.moonAngle  = math.rad(-15) -- slight ray angle from vertical, pointing left

-- ── Color Palette (withered grove / gothic stone) ────────────────────────────

local colors = {
    -- Floors (brighter to catch multiply lighting properly)
    floorBase     = {0.15, 0.25, 0.12},      -- vibrant mossy green
    floorAlt      = {0.18, 0.18, 0.10},      -- warm earthy dirt
    -- Walls
    wallBase      = {0.06, 0.07, 0.05},      -- deep dark green-black
    -- Decorations
    moss          = {0.20, 0.35, 0.15, 0.8}, -- bright green moss patches
    lichen        = {0.25, 0.22, 0.10, 0.6}, -- warm yellow lichen
    deadLeaf      = {0.30, 0.15, 0.08, 0.8}, -- vibrant autumn leaves
    stone         = {0.22, 0.20, 0.18, 0.6}, -- campsite stones
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
    {1,1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1,1,1,1,1},
    -- Row  7: sanctuary widest + portal area
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row  8: portal center row
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row  9
    {1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1},
    -- Row 10
    {1,1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1,1,1,1,1},
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
    {1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1,1,1},
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
    if not hub.cloudShader then
        hub.cloudShader = love.graphics.newShader("assets/shaders/clouds.glsl")
    end

    if #hub.portalFrames == 0 then
        for i = 0, 5 do
            local path = string.format("assets/sprites/rift_spritesheet/%02d_rift_animated.png", i)
            table.insert(hub.portalFrames, love.graphics.newImage(path))
        end
    end
    hub.contours = {}
    hub.grassList = {}
    hub.decorations = {}

    -- Initialise rain drops distributed across the world with 3 Parallax layers
    hub.rain = {}
    local WW = hub.width  * hub.gridSize
    local WH = hub.height * hub.gridSize
    for i = 1, hub.RAIN_COUNT do
        local layer = love.math.random(1, 100)
        local l = 2 -- mid
        if layer > 85 then l = 3     -- foreground (15%)
        elseif layer < 35 then l = 1 -- background (35%)
        end
        
        local speedBase = l == 3 and 700 or (l == 2 and 450 or 250)
        local lenBase   = l == 3 and 18  or (l == 2 and 12  or 6)
        
        table.insert(hub.rain, {
            x = love.math.random(0, WW * 1.5), -- extra width for parallax left-ward sweeping
            y = love.math.random(0, WH * 1.5),
            layer = l,
            len = love.math.random(lenBase - 2, lenBase + 4),
            speed = love.math.random(speedBase - 50, speedBase + 50),
            alpha = love.math.random() * 0.3 + (l * 0.15),
        })
    end

    -- Copy layout into data
    for y = 1, hub.height do
        hub.data[y] = {}
        for x = 1, hub.width do
            hub.data[y][x] = layout[y][x]
        end
    end

    -- Generate floor decorations and reactive grass
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 0 then
                -- 1. Decals (moss, lichen, dead leaves, pebbles)
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

    -- Smooth contours procedurally using 1 iteration of Chaikin's Corner Cutting Algorithm
    local smoothedContours = {}
    for _, loop in ipairs(hub.contours) do
        local sl = loop
        local nl = {}
        local pts = #sl / 2
        for i = 1, pts do
            local x1, y1 = sl[i*2-1], sl[i*2]
            local nx = (i % pts) + 1
            local x2, y2 = sl[nx*2-1], sl[nx*2]
            table.insert(nl, x1 * 0.75 + x2 * 0.25)
            table.insert(nl, y1 * 0.75 + y2 * 0.25)
            table.insert(nl, x1 * 0.25 + x2 * 0.75)
            table.insert(nl, y1 * 0.25 + y2 * 0.75)
        end
        table.insert(smoothedContours, nl)
    end
    hub.contours = smoothedContours

    -- Generate tiny protruding pixel leaves along the organic rounded edges
    hub.canopyLobes = {}
    for _, loop in ipairs(hub.contours) do
        for i = 1, #loop - 2, 2 do
            local x1, y1 = loop[i], loop[i+1]
            local x2, y2 = loop[i+2], loop[i+3]
            local dx, dy = x2 - x1, y2 - y1
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Keep it tight and thin for a beautiful crisp pixel-art look
            local numLeaves = math.max(1, math.floor(dist / 2)) * 1.5
            
            -- Normal vector mathematically pushing inward towards the play area 7 pixels
            local nx = (dy / dist) * 7
            local ny = (-dx / dist) * 7

            for j = 0, numLeaves do
                local t = j / numLeaves
                
                -- Shift coordinates inward onto the visual wall edge boundary
                local cx = x1 + dx * t + nx + (love.math.random() * 6 - 3)
                local cy = y1 + dy * t + ny + (love.math.random() * 6 - 3)
                
                -- 2 to 4 pixel sized leaves
                local size = love.math.random() > 0.8 and 4 or 2
                
                -- 3 colors: dark, mid, bright green
                local cType = love.math.random(1, 10)
                local col = colors.contourDark
                if cType > 8 then col = colors.contourLight
                elseif cType > 5 then col = {0.08, 0.16, 0.06, 1} end

                table.insert(hub.canopyLobes, {
                    x = cx,
                    y = cy,
                    size = size,
                    color = col,
                    phase = love.math.random() * math.pi * 2,
                    speed = 0.5 + love.math.random() * 1.5
                })
            end
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

-- ── Rain update / draw ────────────────────────────────────────────────────────

local RAIN_ANGLE = math.rad(-15)   -- right-to-left slant
local RAIN_DX    = math.sin(RAIN_ANGLE)
local RAIN_DY    = math.cos(RAIN_ANGLE)

function hub.updateRain(dt, cameraX, cameraY)
    local WW = hub.width  * hub.gridSize
    local WH = hub.height * hub.gridSize
    
    local dx = cameraX - (hub.rainWX or cameraX)
    local dy = cameraY - (hub.rainWY or cameraY)
    hub.rainWX = cameraX
    hub.rainWY = cameraY

    for _, d in ipairs(hub.rain) do
        -- Camera Parallax (layer 3 = closest/fastest)
        local parallax = d.layer * 0.2
        d.x = d.x + RAIN_DX * d.speed * dt + (dx * parallax)
        d.y = d.y + RAIN_DY * d.speed * dt + (dy * parallax)
        
        -- Wrap back to top/right when drop exits bottom/left
        if d.y > WH + 200 or d.x < -200 then
            d.x = love.math.random(0, WW + 400)
            d.y = -love.math.random(0, 150)
        end
    end
end

-- additive = true → bright glint pass drawn after lighting
function hub.drawRain(camera, additive)
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    love.graphics.setLineStyle("smooth")

    if additive then
        love.graphics.setBlendMode("add")
        for layer = 1, 3 do
            love.graphics.setLineWidth(layer == 3 and 2 or 1)
            for _, d in ipairs(hub.rain) do
                if d.layer == layer then
                    local a = d.alpha * (layer * 0.12)
                    love.graphics.setColor(0.7, 0.85, 1.0, a)
                    love.graphics.line(d.x, d.y, d.x - RAIN_DX * d.len * 0.4, d.y - RAIN_DY * d.len * 0.4)
                end
            end
        end
        love.graphics.setBlendMode("alpha")
    else
        love.graphics.setBlendMode("alpha")
        for layer = 1, 3 do
            love.graphics.setLineWidth(layer == 3 and 2 or 1)
            for _, d in ipairs(hub.rain) do
                if d.layer == layer then
                    love.graphics.setColor(0.75, 0.88, 1.0, d.alpha * 0.6)
                    love.graphics.line(d.x, d.y, d.x - RAIN_DX * d.len, d.y - RAIN_DY * d.len)
                end
            end
        end
    end

    love.graphics.pop()
end


-- ── Cloud shadow update / draw / sample ───────────────────────────────────────

function hub.updateClouds(dt, player)
    hub.cloudOffX = hub.cloudOffX + hub.cloudSpeed * dt
    hub.cloudOffY = hub.cloudOffY + hub.cloudSpeed * 0.4 * dt
    
    if player then
        hub.torchX = player.x + player.size/2
        hub.torchY = player.y + player.size/2
        hub.torchR = player.torchSize
    end
end

function hub.drawClouds(camera)
    if not hub.cloudShader then return end
    -- Draws clouds directly into the lighting mask over the dark ambient layer
    -- using "alpha" blend, allowing the player's "replace" torch to burn exactly through it!
    love.graphics.setShader(hub.cloudShader)
    
    -- Send world offset mapping scaled down appropriately
    hub.cloudShader:send("cameraPos", {camera.x, camera.y})
    hub.cloudShader:send("cloudScroll", {-hub.cloudOffX * 50, -hub.cloudOffY * 50})
    hub.cloudShader:send("scale", 0.001)
    
    if hub.torchX then
        hub.cloudShader:send("torchPos", {hub.torchX, hub.torchY})
        hub.cloudShader:send("torchRadius", hub.torchR or 60)
    else
        hub.cloudShader:send("torchPos", {-9999, -9999})
        hub.cloudShader:send("torchRadius", 1)
    end
    
    -- Draw fullscreen quad in screen space since Shader calculates true worldPos
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    
    -- Draw purely on the screen coordinates 0,0 since translation shifts the camera
    local W, H = 1280, 720
    love.graphics.rectangle("fill", camera.x - W/2, camera.y - H/2, W * 2, H * 2)
    
    love.graphics.setShader()
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

function hub.draw(camera)
    local s = hub.gridSize


    -- 1. Endless Void Background
    -- Draw a massive rectangle covering the viewport to represent the infinite void walls
    local cx, cy = camera.x, camera.y
    love.graphics.setColor(colors.wallBase)
    love.graphics.rectangle("fill", cx - 1280, cy - 720, 1280 * 3, 720 * 3)

    -- 2. Draw defined floors
    for y = 1, hub.height do
        for x = 1, hub.width do
            if hub.data[y][x] == 0 then
                local px, py = (x-1)*s, (y-1)*s
                
                -- Fast base rectangular floor
                love.graphics.setColor(colors.floorBase)
                love.graphics.rectangle("fill", px, py, s, s)
            end
        end
    end

    -- 2.5 Mask out protruding interior square corners naturally
    -- This thick outline travels exactly along the Chaikin-smoothed contours,
    -- efficiently chopping the sharp 90-degree corners off the floor grid.
    -- Width 14 means 7px inward and 7px outward, masking the 12.5px square tip elegantly.
    love.graphics.setColor(colors.wallBase)
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(14)
    for _, loop in ipairs(hub.contours) do
        -- A loop must be polygonable
        if #loop >= 6 then
            -- Note: 'loop' array is closed by our generator
            love.graphics.polygon("line", loop)
        end
    end

    -- Floor decorations
    for _, dec in ipairs(hub.decorations) do
        love.graphics.setColor(dec.color[1], dec.color[2], dec.color[3], dec.color[4] or 1)
        love.graphics.circle("fill", dec.x, dec.y, dec.r)
    end
    
    hub.drawGrass()


    -- Draw pixel-leaf canopy along the edges
    -- Since the contours are now naturally rounded, these beautiful, thin pixel lobes
    -- precisely trace the visual wall edge natively shifted by 7 pixels inward.
    local t = love.timer.getTime()
    for _, leaf in ipairs(hub.canopyLobes) do
        local swayX = math.sin(t * leaf.speed + leaf.phase) * 1.5
        local swayY = math.cos(t * leaf.speed * 0.8 + leaf.phase) * 1.0
        local lx, ly = math.floor(leaf.x + swayX), math.floor(leaf.y + swayY)
        
        love.graphics.setColor(leaf.color)
        love.graphics.rectangle("fill", lx, ly, leaf.size, leaf.size)
    end
    
    -- Finally, apply cloud shadow shader directly to the floor environment layer
    if camera and hub.cloudShader then
        hub.drawClouds(camera)
    end
    
    -- Contour lines are replaced by the perimeter canopy. End draw.
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
        
        love.graphics.setColor(0.08, 0.18, 0.08, 1) -- Base dark green
        love.graphics.line(grass.x, grass.y, grass.x + (tipX - grass.x)*0.4, grass.y + (tipY - grass.y)*0.4)
        
        love.graphics.setColor(0.20 + bendAmount*0.1, 0.40 + bendAmount*0.15, 0.15, 1) -- Tip bright green
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
