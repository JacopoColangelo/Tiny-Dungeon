local enemy = {}

enemy.list = {}
enemy.slots = {}
enemy.showSlots = false
enemy.numSlots = 8
enemy.slotRadius = 50
enemy.perceptionRadius = 250
enemy.groupAggroRadius = 350

function enemy.init()
    enemy.list = {}
    for i = 1, enemy.numSlots do
        enemy.slots[i] = { x = 0, y = 0, occupied = false, valid = false }
    end
end

function enemy.spawn(map, px, py)
    local spawnX, spawnY
    local minDist = 400
    local found = false
    
    -- Try up to 100 times to find a valid spawn point away from player
    for i = 1, 100 do
        local tx = love.math.random(1, map.width)
        local ty = love.math.random(1, map.height)
        
        if map.data[ty][tx] == 0 then
            local x = (tx - 1) * map.gridSize + map.gridSize/2
            local y = (ty - 1) * map.gridSize + map.gridSize/2
            local dist = math.sqrt((x - px)^2 + (y - py)^2)
            
            if dist > minDist then
                spawnX, spawnY = x, y
                found = true
                break
            end
        end
    end
    
    if found then
        local e = {
            x = spawnX,
            y = spawnY,
            size = 20,
            speed = 80,
            slotId = nil,
            aggro = false,
            color = {1, 0.2, 0.2}
        }
        table.insert(enemy.list, e)
    end
end

local function isPointInWall(x, y, map)
    local tx = math.floor(x / map.gridSize) + 1
    local ty = math.floor(y / map.gridSize) + 1
    if tx < 1 or tx > map.width or ty < 1 or ty > map.height then return true end
    return map.data[ty][tx] == 1
end

function enemy.updateSlots(px, py, map)
    local minSlotDist = 35 -- Minimum distance between slots
    
    for i = 1, enemy.numSlots do
        local baseAngle = ((i-1) / enemy.numSlots) * math.pi * 2
        local foundValid = false
        local bestX, bestY = px, py
        
        -- Try sliding angle within +- 45 degrees
        for angleOffset = 0, math.pi/4, 0.1 do
            for sign = 1, -1, -2 do
                local angle = baseAngle + angleOffset * (angleOffset == 0 and 0 or sign)
                local tx = px + math.cos(angle) * enemy.slotRadius
                local ty = py + math.sin(angle) * enemy.slotRadius
                
                if not isPointInWall(tx, ty, map) then
                    bestX, bestY = tx, ty
                    foundValid = true
                    break
                end
                if angleOffset == 0 then break end
            end
            if foundValid then break end
        end
        
        -- If still not found, pull back as last resort
        if not foundValid then
            for d = 1, 10 do
                local dist = enemy.slotRadius * (1 - d/10)
                local tx = px + math.cos(baseAngle) * dist
                local ty = py + math.sin(baseAngle) * dist
                if not isPointInWall(tx, ty, map) then
                    bestX, bestY = tx, ty
                    foundValid = dist > 20 -- Mark invalid if too close to player
                    break
                end
            end
        end
        
        enemy.slots[i].x = bestX
        enemy.slots[i].y = bestY
        enemy.slots[i].baseX = px + math.cos(baseAngle) * enemy.slotRadius
        enemy.slots[i].baseY = py + math.sin(baseAngle) * enemy.slotRadius
        
        -- FINAL LOS CHECK: Invalidate if line trace hits a wall between player and slot
        if foundValid then
            local losSteps = 10
            for s = 1, losSteps do
                local t = s / losSteps
                local lx = px + (bestX - px) * t
                local ly = py + (bestY - py) * t
                if isPointInWall(lx, ly, map) then
                    foundValid = false
                    break
                end
            end
        end
        
        enemy.slots[i].valid = foundValid
    end
    
    -- Inter-slot repulsion (relaxation pass)
    for pass = 1, 3 do
        for i = 1, enemy.numSlots do
            if enemy.slots[i].valid then
                for j = i + 1, enemy.numSlots do
                    if enemy.slots[j].valid then
                        local dx = enemy.slots[j].x - enemy.slots[i].x
                        local dy = enemy.slots[j].y - enemy.slots[i].y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        if dist < minSlotDist then
                            local push = (minSlotDist - dist) / 2
                            local nx = (dx/dist) * push
                            local ny = (dy/dist) * push
                            
                            -- Only apply if the new position is still on floor
                            if not isPointInWall(enemy.slots[j].x + nx, enemy.slots[j].y + ny, map) then
                                enemy.slots[j].x = enemy.slots[j].x + nx
                                enemy.slots[j].y = enemy.slots[j].y + ny
                            end
                            if not isPointInWall(enemy.slots[i].x - nx, enemy.slots[i].y - ny, map) then
                                enemy.slots[i].x = enemy.slots[i].x - nx
                                enemy.slots[i].y = enemy.slots[i].y - ny
                            end
                        end
                    end
                end
            end
        end
    end
end

function enemy.update(dt, player, map)
    local px = player.x + player.size/2
    local py = player.y + player.size/2
    
    enemy.updateSlots(px, py, map)
    
    -- Clear slot occupancy
    for i = 1, enemy.numSlots do enemy.slots[i].occupied = false end
    
    -- 1. Update Aggro States
    for _, e in ipairs(enemy.list) do
        if not e.aggro then
            local d = math.sqrt((e.x - px)^2 + (e.y - py)^2)
            if d < enemy.perceptionRadius then
                e.aggro = true
            end
        end
    end
    
    -- 2. Broadcast Aggro (Chain Reaction)
    local changed = true
    while changed do
        changed = false
        for _, e1 in ipairs(enemy.list) do
            if e1.aggro then
                for _, e2 in ipairs(enemy.list) do
                    if not e2.aggro then
                        local d = math.sqrt((e1.x - e2.x)^2 + (e1.y - e2.y)^2)
                        if d < enemy.groupAggroRadius then
                            e2.aggro = true
                            changed = true
                        end
                    end
                end
            end
        end
    end
    
    -- 3. Dynamic Assignment (Sorted by Angle to prevent crossing and stickiness)
    local sortedEnemies = {}
    for _, e in ipairs(enemy.list) do
        if e.aggro then
            e.currentAngle = math.atan2(e.y - py, e.x - px)
            table.insert(sortedEnemies, e)
        end
    end
    
    -- Sort enemies clockwise to ensure stable mapping to the ring
    table.sort(sortedEnemies, function(a, b) return a.currentAngle < b.currentAngle end)
    
    for _, e in ipairs(sortedEnemies) do
        local bestAngleDiff = 999
        local bestId = nil
        
        for i = 1, enemy.numSlots do
            local s = enemy.slots[i]
            if s.valid and not s.occupied then
                local slotAngle = math.atan2(s.y - py, s.x - px)
                local diff = math.abs(e.currentAngle - slotAngle)
                if diff > math.pi then diff = math.pi * 2 - diff end
                
                if diff < bestAngleDiff then
                    bestAngleDiff = diff
                    bestId = i
                end
            end
        end
        
        e.slotId = bestId
        if e.slotId then
            enemy.slots[e.slotId].occupied = true
            
            local targetX = enemy.slots[e.slotId].x
            local targetY = enemy.slots[e.slotId].y
            local dx = targetX - e.x
            local dy = targetY - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 5 then
                e.x = e.x + (dx / dist) * e.speed * dt
                e.y = e.y + (dy / dist) * e.speed * dt
            end
        else
            -- No valid free slot, move towards player safely
            local dx = px - e.x
            local dy = py - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 120 then
                e.x = e.x + (dx / dist) * e.speed * dt
                e.y = e.y + (dy / dist) * e.speed * dt
            end
        end
    end
    
    -- Inter-enemy collision repulsion pass
    local minEnemyDist = 25
    for i = 1, #enemy.list do
        local e1 = enemy.list[i]
        for j = i + 1, #enemy.list do
            local e2 = enemy.list[j]
            local dx = e2.x - e1.x
            local dy = e2.y - e1.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist < minEnemyDist and dist > 0 then
                local push = (minEnemyDist - dist) / 2
                local nx, ny = (dx/dist) * push, (dy/dist) * push
                
                -- Attempt to push both away if not hitting walls
                if not isPointInWall(e2.x + nx, e2.y + ny, map) then
                    e2.x = e2.x + nx
                    e2.y = e2.y + ny
                end
                if not isPointInWall(e1.x - nx, e1.y - ny, map) then
                    e1.x = e1.x - nx
                    e1.y = e1.y - ny
                end
            end
        end
    end
end

function enemy.draw(player)
    -- Draw enemies
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        local r_radius = 6
        -- Draw Glow (Additive Circular Glow for consistency)
        love.graphics.setBlendMode("add")
        for i = 10, 1, -1 do
            local r = 30 * (i / 10)
            local a = (1 - (i / 10)) * 0.2
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], a)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        if e.aggro then
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Dim if not aggroed
        end
        love.graphics.rectangle("fill", cx - e.size/2, cy - e.size/2, e.size, e.size, r_radius)

        -- Debug perception range
        if enemy.showSlots and not e.aggro then
            love.graphics.setColor(1, 1, 0, 0.1)
            love.graphics.circle("line", cx, cy, enemy.perceptionRadius)
        end
    end
    
    if enemy.showSlots and player then
        local px = player.x + player.size/2
        local py = player.y + player.size/2
        
        for i = 1, enemy.numSlots do
            local s = enemy.slots[i]
            
            -- Draw slide path
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.line(px, py, s.baseX, s.baseY)
            love.graphics.line(s.baseX, s.baseY, s.x, s.y)
            
            if s.valid then
                if s.occupied then
                    love.graphics.setColor(0, 0.8, 1, 0.6) -- Occupied: Cyan/Blue
                else
                    love.graphics.setColor(0, 1, 0, 0.5) -- Available: Green
                end
                love.graphics.circle("line", s.x, s.y, 8)
            else
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.print("X", s.x - 4, s.y - 7)
            end
            love.graphics.print(tostring(i), s.x - 4, s.y + 10, 0, 0.7, 0.7)
        end
    end
end

return enemy
