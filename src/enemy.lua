local pathfinding = require("src.pathfinding")
local enemy = {}

enemy.list = {}
enemy.slots = {}
enemy.particles = {}
enemy.showSlots = false
enemy.numSlots = 8
enemy.slotRadius = 50
enemy.perceptionRadius = 250
enemy.groupAggroRadius = 350

-- Audio Assets
enemy.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
enemy.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")

function enemy.init()
    enemy.list = {}
    enemy.particles = {}
    for i = 1, enemy.numSlots do
        enemy.slots[i] = { x = 0, y = 0, baseX = 0, baseY = 0, occupied = false, valid = false }
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
            state = "alive",
            x = spawnX,
            y = spawnY,
            size = 20,
            speed = 110, --was 80
            slotId = nil,
            aggro = false,
            path = nil,
            pathTimer = 0,
            color = {1, 0.2, 0.2},
            hp = 100,
            maxHp = 100,
            hitFlash = 0,
            kbX = 0,
            kbY = 0,
            
            -- CHARGE ATTACK DATA
            chargeState = "none", -- "none", "winding", "charging", "cooldown"
            chargeTimer = 0,
            chargeCooldown = 0,
            chargeDirX = 0,
            chargeDirY = 0,
            chargeRange = 100,
            chargeSpeed = 650,    -- Speed during the lunge
            hasDealtDamage = false,
            windupTime = 0.05
        }

        function e:takeDamage(damage, kx, ky)
            if self.state == "dying" then return end
            self.hp = self.hp - damage
            self.hitFlash = 0.15 
            if self.hp <= 0 then
                enemy.deathSound:play()
                self.state = "dying"
                for p = 1, 15 do
                    table.insert(enemy.particles, {
                        x = self.x, y = self.y,
                        vx = math.random(-150, 150), vy = math.random(-150, 150),
                        life = 0.5, maxLife = 0.5, size = math.random(2, 4)
                    })
                end
            else
                enemy.hitSound:play()
                self.kbX, self.kbY = kx, ky
                -- Interrupt charge if hit
                if self.chargeState == "winding" or self.chargeState == "charging" then
                    self.chargeState = "none"
                    self.chargeCooldown = 1.2
                end
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
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 5 then return true end
    local steps = math.ceil(dist / 10)
    for s = 1, steps do
        local t = s / steps
        if isPointInWall(x1 + dx * t, y1 + dy * t, map) then return false end
    end
    return true
end

function enemy.updateSlots(px, py, map)
    local minSlotDist = 35 
    for i = 1, enemy.numSlots do
        local baseAngle = ((i-1) / enemy.numSlots) * math.pi * 2
        local foundValid, bestX, bestY = false, px, py
        for angleOffset = 0, math.pi/4, 0.1 do
            for sign = 1, -1, -2 do
                local angle = baseAngle + angleOffset * (angleOffset == 0 and 0 or sign)
                local tx, ty = px + math.cos(angle) * enemy.slotRadius, py + math.sin(angle) * enemy.slotRadius
                if not isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, true
                    break
                end
                if angleOffset == 0 then break end
            end
            if foundValid then break end
        end
        if not foundValid then
            for d = 1, 10 do
                local dist = enemy.slotRadius * (1 - d/10)
                local tx, ty = px + math.cos(baseAngle) * dist, py + math.sin(baseAngle) * dist
                if not isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, (dist > 20)
                    break
                end
            end
        end
        enemy.slots[i].x, enemy.slots[i].y = bestX, bestY
        enemy.slots[i].baseX = px + math.cos(baseAngle) * enemy.slotRadius
        enemy.slots[i].baseY = py + math.sin(baseAngle) * enemy.slotRadius
        if foundValid and not hasLOS(px, py, bestX, bestY, map) then foundValid = false end
        enemy.slots[i].valid = foundValid
    end
    
    for pass = 1, 3 do
        for i = 1, enemy.numSlots do
            if enemy.slots[i].valid then
                for j = i + 1, enemy.numSlots do
                    if enemy.slots[j].valid then
                        local dx, dy = enemy.slots[j].x - enemy.slots[i].x, enemy.slots[j].y - enemy.slots[i].y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        if dist < minSlotDist then
                            local push = (minSlotDist - dist) / 2
                            local nx, ny = (dx/dist) * push, (dy/dist) * push
                            if not isPointInWall(enemy.slots[j].x + nx, enemy.slots[j].y + ny, map) then
                                enemy.slots[j].x, enemy.slots[j].y = enemy.slots[j].x + nx, enemy.slots[j].y + ny
                            end
                            if not isPointInWall(enemy.slots[i].x - nx, enemy.slots[i].y - ny, map) then
                                enemy.slots[i].x, enemy.slots[i].y = enemy.slots[i].x - nx, enemy.slots[i].y - ny
                            end
                        end
                    end
                end
            end
        end
    end
end

function enemy.update(dt, player, map)
    local px, py = player.x + player.size/2, player.y + player.size/2
    
    -- Particles
    for i = #enemy.particles, 1, -1 do
        local p = enemy.particles[i]
        p.life = p.life - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.life <= 0 then table.remove(enemy.particles, i) end
    end

    -- Update enemies
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]
        if e.state == "dying" then
            table.remove(enemy.list, i)
        else
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
            
            -- Knockback friction
            if math.abs(e.kbX) > 1 or math.abs(e.kbY) > 1 then
                local nx, ny = e.x + e.kbX * dt, e.y + e.kbY * dt
                if not isPointInWall(nx, ny, map) then e.x, e.y = nx, ny end
                e.kbX, e.kbY = e.kbX * math.exp(-8 * dt), e.kbY * math.exp(-8 * dt)
            else
                e.kbX, e.kbY = 0, 0
            end

            -- CHARGE ATTACK LOGIC
            local dx, dy = px - e.x, py - e.y
            local dist = math.sqrt(dx*dx + dy*dy)

            if e.chargeCooldown > 0 then
                e.chargeCooldown = e.chargeCooldown - dt
            end

            if e.chargeState == "none" and e.chargeCooldown <= 0 and dist < e.chargeRange and e.aggro then
                -- Start Wind-up
                e.chargeState = "winding"
                e.chargeTimer = 0.4
                local angle = math.atan2(dy, dx)
                e.chargeDirX, e.chargeDirY = math.cos(angle), math.sin(angle)
            elseif e.chargeState == "winding" then
                e.chargeTimer = e.chargeTimer - dt
                if e.chargeTimer <= 0 then
                    e.chargeState = "charging"
                    e.chargeTimer = 0.3 -- Dash duration
                    e.hasDealtDamage = false
                end
            elseif e.chargeState == "charging" then
                e.chargeTimer = e.chargeTimer - dt
                local nx, ny = e.x + e.chargeDirX * e.chargeSpeed * dt, e.y + e.chargeDirY * e.chargeSpeed * dt
                
                -- Dash collision with walls
                if not isPointInWall(nx, ny, map) then
                    e.x, e.y = nx, ny
                else
                    e.chargeTimer = 0 -- Stop on wall hit
                end

                -- Collision with Player
                if not e.hasDealtDamage and dist < (e.size + player.size) / 2 then
                    player.hp = player.hp - 0.7
                    e.hasDealtDamage = true
                    if _G.camera and _G.camera.addShake then _G.camera.addShake(12, 0.12) end
                end

                if e.chargeTimer <= 0 then
                    e.chargeState = "none"
                    e.chargeCooldown = 2.0
                end
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

    -- Chain Aggro
    local changed = true
    while changed do
        changed = false
        for _, e1 in ipairs(enemy.list) do
            if e1.aggro then
                for _, e2 in ipairs(enemy.list) do
                    if not e2.aggro and math.sqrt((e1.x-e2.x)^2 + (e1.y-e2.y)^2) < enemy.groupAggroRadius then
                        e2.aggro, changed = true, true
                    end
                end
            end
        end
    end
    
    local sortedEnemies = {}
    for _, e in ipairs(enemy.list) do
        -- ONLY move if not winding up or charging
        if e.aggro and e.state ~= "dying" and e.chargeState == "none" then
            e.currentAngle = math.atan2(e.y - py, e.x - px)
            table.insert(sortedEnemies, e)
        end
    end
    
    table.sort(sortedEnemies, function(a, b) return a.currentAngle < b.currentAngle end)
    
    for _, e in ipairs(sortedEnemies) do
        local bestAngleDiff, bestId = 999, nil
        for i = 1, enemy.numSlots do
            local s = enemy.slots[i]
            if s.valid and not s.occupied then
                local slotAngle = math.atan2(s.y - py, s.x - px)
                local diff = math.abs(e.currentAngle - slotAngle)
                if diff > math.pi then diff = math.pi * 2 - diff end
                if diff < bestAngleDiff then bestAngleDiff, bestId = diff, i end
            end
        end
        
        local oldSlotId = e.slotId
        e.slotId = bestId
        
        if e.slotId then
            enemy.slots[e.slotId].occupied = true
            local tx, ty = enemy.slots[e.slotId].x, enemy.slots[e.slotId].y
            e.pathTimer = e.pathTimer - dt
            if hasLOS(e.x, e.y, tx, ty, map) then e.path = nil
            elseif not e.path or e.slotId ~= oldSlotId or e.pathTimer <= 0 then
                e.path = pathfinding.findPath(e.x, e.y, tx, ty, map)
                e.pathTimer = 0.5 
            end
            local mx, my = tx, ty
            if e.path and #e.path > 0 then
                while #e.path > 1 and hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do table.remove(e.path, 1) end
                if math.sqrt((e.path[1].x-e.x)^2 + (e.path[1].y-e.y)^2) < 15 then table.remove(e.path, 1) end
                if #e.path > 0 then mx, my = e.path[1].x, e.path[1].y end
            end
            local ddx, ddy = mx - e.x, my - e.y
            local ddist = math.sqrt(ddx*ddx + ddy*ddy)
            if ddist > 5 then
                e.x, e.y = e.x + (ddx/ddist)*e.speed*dt, e.y + (ddy/ddist)*e.speed*dt
            end
        else
            local ddx, ddy = px - e.x, py - e.y
            local ddist = math.sqrt(ddx*ddx + ddy*ddy)
            if ddist > 120 then e.x, e.y = e.x + (ddx/ddist)*e.speed*dt, e.y + (ddy/ddist)*e.speed*dt end
        end
    end
    
    -- Repulsion
    for i = 1, #enemy.list do
        local e1 = enemy.list[i]
        for j = i + 1, #enemy.list do
            local e2 = enemy.list[j]
            local dx, dy = e2.x - e1.x, e2.y - e1.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 25 and dist > 0 then
                local push = (25 - dist) / 2
                local nx, ny = (dx/dist) * push, (dy/dist) * push
                if not isPointInWall(e2.x + nx, e2.y + ny, map) then e2.x, e2.y = e2.x + nx, e2.y + ny end
                if not isPointInWall(e1.x - nx, e1.y - ny, map) then e1.x, e1.y = e1.x - nx, e1.y - ny end
            end
        end
    end
    -- Portal Repulsion
    local hpx, hpy = map.getPortalWorldPos()
    if hpx and hpy then
        for _, e in ipairs(enemy.list) do
            local dx, dy = e.x - hpx, e.y - hpy
            local distSq = dx*dx + dy*dy
            local minDist = (map.portalCollisionRadius or 30) + e.size/2
            if distSq < minDist * minDist then
                local dist = math.sqrt(distSq)
                if dist > 0 then
                    local push = minDist - dist
                    e.x, e.y = e.x + (dx / dist) * push, e.y + (dy / dist) * push
                end
            end
        end
    end
end

function enemy.draw(player)
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        
        -- DRAW CHARGE TELEGRAPH
        if e.chargeState == "winding" then
            local p = 1 - (e.chargeTimer / 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(1, 0, 0, 0.4)
            -- Draw a line in the direction of the lunge
            love.graphics.line(cx, cy, cx + e.chargeDirX * e.chargeRange, cy + e.chargeDirY * e.chargeRange)
            -- Pulsing triangle/arrow at the end
            love.graphics.circle("line", cx + e.chargeDirX * e.chargeRange * p, cy + e.chargeDirY * e.chargeRange * p, 5)
        end

        -- Glow
        love.graphics.setBlendMode("add")
        for i = 10, 1, -1 do
            local r, a = 30 * (i / 10), (1 - (i / 10)) * 0.2
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], a)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        -- Body
        if e.hitFlash > 0 then love.graphics.setColor(1, 1, 1, 1) 
        elseif e.chargeState == "winding" then love.graphics.setColor(1, 1, 1, 1) -- Flash white during windup
        elseif e.chargeState == "charging" then love.graphics.setColor(1, 0.5, 0) -- Orange lunge
        elseif e.aggro then love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
        else love.graphics.setColor(0.4, 0.4, 0.4, 1) end
        
        love.graphics.rectangle("fill", cx - e.size/2, cy - e.size/2, e.size, e.size, 6)

        -- Health Bar
        if player then
            local dist = math.sqrt((cx - (player.x+player.size/2))^2 + (cy - (player.y+player.size/2))^2)
            if dist < 300 then
                local alpha = (1 - (dist / 300)) * 0.9
                love.graphics.setColor(0, 0, 0, alpha * 0.6)
                love.graphics.rectangle("fill", cx-15, cy-20, 30, 4)
                love.graphics.setColor(1, 0.2, 0.2, alpha)
                love.graphics.rectangle("fill", cx-15, cy-20, 30 * (e.hp/e.maxHp), 4)
            end
        end

        -- Slots Debug
        if enemy.showSlots and e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 1, 0.2)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do love.graphics.line(lx, ly, p.x, p.y) lx, ly = p.x, p.y end
        end
    end
    
    -- Particles and Slot Debug (keeping your original logic)
    for _, p in ipairs(enemy.particles) do
        love.graphics.setColor(1, 0.1, 0.1, p.life / p.maxLife) 
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    if enemy.showSlots and player then
        local px, py = player.x + player.size/2, player.y + player.size/2
        for i = 1, enemy.numSlots do
            local s = enemy.slots[i]
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.line(px, py, s.baseX, s.baseY)
            love.graphics.line(s.baseX, s.baseY, s.x, s.y)
            if s.valid then
                love.graphics.setColor(s.occupied and {0, 0.8, 1, 0.6} or {0, 1, 0, 0.5})
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