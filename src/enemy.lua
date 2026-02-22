local pathfinding = require("src.pathfinding")
local enemy = {}

enemy.list = {}
enemy.slots = {}
enemy.showSlots = false
enemy.numSlots = 8
enemy.slotRadius = 50
enemy.perceptionRadius = 250
enemy.groupAggroRadius = 350

-- Added Audio for feedback
enemy.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
enemy.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")

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
    
    for i = 1, 100 do
        local tx = love.math.random(1, map.width)
        local ty = love.math.random(1, map.height)
        
        if map.data[ty] and map.data[ty][tx] == 0 then
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
            state = "alive", -- Added state track
            x = spawnX,
            y = spawnY,
            size = 20,
            speed = 80,
            slotId = nil,
            aggro = false,
            path = nil,
            pathTimer = 0,
            color = {1, 0.2, 0.2},
            hp = 100,
            maxHp = 100,
            hitFlash = 0,
            kbX = 0,
            kbY = 0
        }

        -- RESTORED: Damage detection function
        function e:takeDamage(damage, kx, ky)
            if self.state == "dying" then return end
            self.hp = self.hp - damage
            self.hitFlash = 0.15 
            if self.hp <= 0 then
                enemy.deathSound:play()
                self.state = "dying"
                self.kbX, self.kbY = 0, 0 -- Stop moving when dead
            else
                enemy.hitSound:play()
                self.kbX, self.kbY = kx, ky
            end
        end

        table.insert(enemy.list, e)
    end
end

local function isPointInWall(x, y, map)
    local tx = math.floor(x / map.gridSize) + 1
    local ty = math.floor(y / map.gridSize) + 1
    if tx < 1 or tx > map.width or ty < 1 or ty > map.height then return true end
    return map.data[ty][tx] == 1
end

local function hasLOS(x1, y1, x2, y2, map)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 5 then return true end
    
    local steps = math.ceil(dist / 10)
    for s = 1, steps do
        local t = s / steps
        if isPointInWall(x1 + dx * t, y1 + dy * t, map) then
            return false
        end
    end
    return true
end

function enemy.updateSlots(px, py, map)
    local minSlotDist = 35 
    
    for i = 1, enemy.numSlots do
        local baseAngle = ((i-1) / enemy.numSlots) * math.pi * 2
        local foundValid = false
        local bestX, bestY = px, py
        
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
        
        if not foundValid then
            for d = 1, 10 do
                local dist = enemy.slotRadius * (1 - d/10)
                local tx = px + math.cos(baseAngle) * dist
                local ty = py + math.sin(baseAngle) * dist
                if not isPointInWall(tx, ty, map) then
                    bestX, bestY = tx, ty
                    foundValid = dist > 20 
                    break
                end
            end
        end
        
        enemy.slots[i].x = bestX
        enemy.slots[i].y = bestY
        enemy.slots[i].baseX = px + math.cos(baseAngle) * enemy.slotRadius
        enemy.slots[i].baseY = py + math.sin(baseAngle) * enemy.slotRadius
        
        if foundValid then
            if not hasLOS(px, py, bestX, bestY, map) then
                foundValid = false
            end
        end
        
        enemy.slots[i].valid = foundValid
    end
    
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
    
    -- Update individual enemy physics & Death check
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]
        
        if e.state == "dying" then
            table.remove(enemy.list, i) -- Simple immediate removal for now
        else
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
            
            if math.abs(e.kbX) > 1 or math.abs(e.kbY) > 1 then
                local nx = e.x + e.kbX * dt
                local ny = e.y + e.kbY * dt
                if not isPointInWall(nx, ny, map) then
                    e.x, e.y = nx, ny
                end
                e.kbX = e.kbX * math.exp(-8 * dt)
                e.kbY = e.kbY * math.exp(-8 * dt)
            else
                e.kbX, e.kbY = 0, 0
            end
        end
    end

    enemy.updateSlots(px, py, map)
    for i = 1, enemy.numSlots do enemy.slots[i].occupied = false end
    
    for _, e in ipairs(enemy.list) do
        if not e.aggro then
            local d = math.sqrt((e.x - px)^2 + (e.y - py)^2)
            if d < enemy.perceptionRadius then e.aggro = true end
        end
    end
    
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
    
    local sortedEnemies = {}
    for _, e in ipairs(enemy.list) do
        if e.aggro and e.state ~= "dying" then
            e.currentAngle = math.atan2(e.y - py, e.x - px)
            table.insert(sortedEnemies, e)
        end
    end
    
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
        
        local oldSlotId = e.slotId
        e.slotId = bestId
        
        if e.slotId then
            enemy.slots[e.slotId].occupied = true
            local targetX = enemy.slots[e.slotId].x
            local targetY = enemy.slots[e.slotId].y
            
            e.pathTimer = e.pathTimer - dt
            
            if hasLOS(e.x, e.y, targetX, targetY, map) then
                e.path = nil
            elseif not e.path or e.slotId ~= oldSlotId or e.pathTimer <= 0 then
                e.path = pathfinding.findPath(e.x, e.y, targetX, targetY, map)
                e.pathTimer = 0.5 
            end
            
            local moveX, moveY = targetX, targetY
            if e.path and #e.path > 0 then
                while #e.path > 1 do
                    local nextP = e.path[2]
                    if hasLOS(e.x, e.y, nextP.x, nextP.y, map) then
                        table.remove(e.path, 1)
                    else break end
                end
                
                local nextPoint = e.path[1]
                local dToPoint = math.sqrt((nextPoint.x - e.x)^2 + (nextPoint.y - e.y)^2)
                if dToPoint < 15 then
                    table.remove(e.path, 1)
                    if #e.path > 0 then nextPoint = e.path[1] end
                end
                moveX, moveY = nextPoint.x, nextPoint.y
            end
            
            local dx = moveX - e.x
            local dy = moveY - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 5 then
                e.x = e.x + (dx / dist) * e.speed * dt
                e.y = e.y + (dy / dist) * e.speed * dt
            end
        else
            local dx = px - e.x
            local dy = py - e.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 120 then
                e.x = e.x + (dx / dist) * e.speed * dt
                e.y = e.y + (dy / dist) * e.speed * dt
            end
        end
    end
    
    -- Enemy Repulsion
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
                if not isPointInWall(e2.x + nx, e2.y + ny, map) then
                    e2.x, e2.y = e2.x + nx, e2.y + ny
                end
                if not isPointInWall(e1.x - nx, e1.y - ny, map) then
                    e1.x, e1.y = e1.x - nx, e1.y - ny
                end
            end
        end
    end
end

-- Your exact Draw function preserved
function enemy.draw(player)
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        local r_radius = 6
        love.graphics.setBlendMode("add")
        for i = 10, 1, -1 do
            local r = 30 * (i / 10)
            local a = (1 - (i / 10)) * 0.2
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], a)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        if e.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1, 1) 
        elseif e.aggro then
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
        else
            love.graphics.setColor(0.4, 0.4, 0.4, 1) 
        end
        love.graphics.rectangle("fill", cx - e.size/2, cy - e.size/2, e.size, e.size, r_radius)

        if player then
            local px = player.x + player.size/2
            local py = player.y + player.size/2
            local dist = math.sqrt((cx - px)^2 + (cy - py)^2)
            local viewDist = 300
            
            if dist < viewDist then
                local alpha = (1 - (dist / viewDist)) * 0.9
                local bw, bh = 30, 4
                local bx, by = cx - bw/2, cy - e.size/2 - 10
                love.graphics.setColor(0, 0, 0, alpha * 0.6)
                love.graphics.rectangle("fill", bx, by, bw, bh)
                local fillPct = math.max(0, e.hp / e.maxHp)
                love.graphics.setColor(1, 0.2, 0.2, alpha)
                love.graphics.rectangle("fill", bx, by, bw * fillPct, bh)
            end
        end

        if enemy.showSlots and not e.aggro then
            love.graphics.setColor(1, 1, 0, 0.1)
            love.graphics.circle("line", cx, cy, enemy.perceptionRadius)
        end

        if enemy.showSlots and e.path and #e.path > 0 then
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 0.2)
            local lastX, lastY = e.x, e.y
            for _, p in ipairs(e.path) do
                love.graphics.line(lastX, lastY, p.x, p.y)
                lastX, lastY = p.x, p.y
            end
        end
    end
    
    if enemy.showSlots and player then
        local px = player.x + player.size/2
        local py = player.y + player.size/2
        for i = 1, enemy.numSlots do
            local s = enemy.slots[i]
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.line(px, py, s.baseX, s.baseY)
            love.graphics.line(s.baseX, s.baseY, s.x, s.y)
            if s.valid then
                if s.occupied then love.graphics.setColor(0, 0.8, 1, 0.6)
                else love.graphics.setColor(0, 1, 0, 0.5) end
                love.graphics.circle("line", s.x, s.y, 8)
            else
                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.print("X", s.x - 4, s.y - 7)
            end
            local oldFont = love.graphics.getFont()
            love.graphics.setFont(debugFont or love.graphics.newFont(12))
            love.graphics.print(tostring(i), s.x - 4, s.y + 10)
            if oldFont then love.graphics.setFont(oldFont) end
        end
    end
end

return enemy