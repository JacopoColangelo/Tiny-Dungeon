local pathfinding = require("src.pathfinding")
local soul = require("src.soul")

local enemy = {}

-- ============================================================================
-- MODULE STATE & TYPES
-- ============================================================================

enemy.list = {}
enemy.slots = {}
enemy.particles = {}
enemy.typeModules = {}

-- Audio Assets
enemy.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
enemy.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")

-- ============================================================================
-- DESIGNER CONFIGURATION (Shared)
-- ============================================================================

enemy.config = {
    perceptionRadius = 250,  -- Distance to notice player
    groupAggroRadius = 350,  -- Distance to alert nearby friends
    hitFlashDuration = 0.15, -- How long they flash white when hit
    
    soulDropRate = 0.65,
    soulMinDrop = 3,
    soulMaxDrop = 5,
    
    deathParticleCount = 15,
    deathParticleSpeed = 150,
    deathParticleLife = 0.5,
    
    numSlots = 8,
    slotRadius = 50,
    minSlotDist = 35,
    showSlots = false
}

-- ============================================================================
-- HELPERS (Exposed to enemy types)
-- ============================================================================

function enemy.isPointInWall(x, y, map)
    local tx = math.floor(x / map.gridSize) + 1
    local ty = math.floor(y / map.gridSize) + 1
    if tx < 1 or tx > map.width or ty < 1 or ty > map.height then return true end
    return map.data[ty][tx] == 1
end

function enemy.hasLOS(x1, y1, x2, y2, map)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 5 then return true end
    local steps = math.ceil(dist / 10)
    for s = 1, steps do
        local t = s / steps
        if enemy.isPointInWall(x1 + dx * t, y1 + dy * t, map) then return false end
    end
    return true
end

function enemy.addParticle(x, y, color)
    table.insert(enemy.particles, {
        x = x, y = y,
        vx = (math.random() * 10 - 5),
        vy = (math.random() * 10 - 5),
        life = 0.2,
        maxLife = 0.2,
        size = math.random(2, 6),
        color = color
    })
end

-- ============================================================================
-- CORE LOGIC
-- ============================================================================

function enemy.init()
    enemy.list = {}
    enemy.particles = {}
    
    -- Load Enemy Types
    enemy.typeModules.melee = require("src.enemies.melee")
    enemy.typeModules.ranged = require("src.enemies.ranged")

    local num = enemy.config.numSlots
    for i = 1, num do
        enemy.slots[i] = { x = 0, y = 0, baseX = 0, baseY = 0, occupied = false, valid = false }
    end
end

function enemy.spawn(map, px, py, eType)
    eType = eType or "melee"
    local typeMod = enemy.typeModules[eType]
    if not typeMod then return end

    local spawnX, spawnY
    local minDist = 400
    local found = false
    
    -- Attempt to find a valid floor tile away from the player
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
            type = eType,
            state = "alive",
            x = spawnX,
            y = spawnY,
            aggro = false,
            hitFlash = 0,
            kbX = 0,
            kbY = 0,
            path = nil,
            pathTimer = 0,
            slotId = nil
        }
        
        -- Let type-specific module init stats/state
        typeMod.create(e)

        function e:takeDamage(damage, kx, ky)
            if self.state == "dying" then return end
            
            self.hp = self.hp - damage
            self.hitFlash = enemy.config.hitFlashDuration
            
            if self.hp <= 0 then
                enemy.deathSound:play()
                self.state = "dying"
                
                -- Death Burst Particles
                for p = 1, enemy.config.deathParticleCount do
                    local spd = enemy.config.deathParticleSpeed
                    table.insert(enemy.particles, {
                        x = self.x, y = self.y,
                        vx = math.random(-spd, spd), 
                        vy = math.random(-spd, spd),
                        life = enemy.config.deathParticleLife, 
                        maxLife = enemy.config.deathParticleLife, 
                        size = math.random(2, 4)
                    })
                end
                
                -- Soul Drops
                if love.math.random() < enemy.config.soulDropRate then
                    local amount = love.math.random(enemy.config.soulMinDrop, enemy.config.soulMaxDrop)
                    soul.spawn(self.x, self.y, amount)
                end
            else
                enemy.hitSound:play()
                self.kbX, self.kbY = kx, ky
                
                -- Interrupt attack if hit
                if self.attackState == "winding" or self.attackState == "charging" then
                    self.attackState = "none"
                    self.attackCooldown = 1.2
                end
            end
        end

        table.insert(enemy.list, e)
    end
end

function enemy.updateSlots(px, py, map)
    local cfg = enemy.config
    local num = cfg.numSlots
    
    for i = 1, num do
        local baseAngle = ((i-1) / num) * math.pi * 2
        local foundValid, bestX, bestY = false, px, py
        
        for angleOffset = 0, math.pi/4, 0.1 do
            for sign = 1, -1, -2 do
                local angle = baseAngle + angleOffset * (angleOffset == 0 and 0 or sign)
                local tx, ty = px + math.cos(angle) * cfg.slotRadius, py + math.sin(angle) * cfg.slotRadius
                if not enemy.isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, true
                    break
                end
                if angleOffset == 0 then break end
            end
            if foundValid then break end
        end
        
        if not foundValid then
            for d = 1, 10 do
                local dist = cfg.slotRadius * (1 - d/10)
                local tx, ty = px + math.cos(baseAngle) * dist, py + math.sin(baseAngle) * dist
                if not enemy.isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, (dist > 20)
                    break
                end
            end
        end
        
        enemy.slots[i].x, enemy.slots[i].y = bestX, bestY
        enemy.slots[i].baseX = px + math.cos(baseAngle) * cfg.slotRadius
        enemy.slots[i].baseY = py + math.sin(baseAngle) * cfg.slotRadius
        
        if foundValid and not enemy.hasLOS(px, py, bestX, bestY, map) then foundValid = false end
        enemy.slots[i].valid = foundValid
    end
    
    -- Slot Repulsion
    for pass = 1, 3 do
        for i = 1, num do
            if enemy.slots[i].valid then
                for j = i + 1, num do
                    if enemy.slots[j].valid then
                        local dx, dy = enemy.slots[j].x - enemy.slots[i].x, enemy.slots[j].y - enemy.slots[i].y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        if dist < cfg.minSlotDist then
                            local push = (cfg.minSlotDist - dist) / 2
                            local nx, ny = (dx/dist) * push, (dy/dist) * push
                            if not enemy.isPointInWall(enemy.slots[j].x + nx, enemy.slots[j].y + ny, map) then
                                enemy.slots[j].x, enemy.slots[j].y = enemy.slots[j].x + nx, enemy.slots[j].y + ny
                            end
                            if not enemy.isPointInWall(enemy.slots[i].x - nx, enemy.slots[i].y - ny, map) then
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
    local cfg = enemy.config
    local px, py = player.x + player.size/2, player.y + player.size/2
    
    -- Update Blood/Death Particles
    for i = #enemy.particles, 1, -1 do
        local p = enemy.particles[i]
        p.life = p.life - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.life <= 0 then table.remove(enemy.particles, i) end
    end

    -- Update Enemies
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]
        if e.state == "dying" then
            table.remove(enemy.list, i)
        else
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
            
            -- Apply Knockback
            if math.abs(e.kbX) > 1 or math.abs(e.kbY) > 1 then
                local nx, ny = e.x + e.kbX * dt, e.y + e.kbY * dt
                if not enemy.isPointInWall(nx, ny, map) then e.x, e.y = nx, ny end
                e.kbX, e.kbY = e.kbX * math.exp(-8 * dt), e.kbY * math.exp(-8 * dt)
            else
                e.kbX, e.kbY = 0, 0
            end

            -- Aggro Perception
            if not e.aggro then
                local d = math.sqrt((e.x - px)^2 + (e.y - py)^2)
                if d < cfg.perceptionRadius then e.aggro = true end
            end

            -- Update behavior via type module
            local typeMod = enemy.typeModules[e.type]
            if typeMod then
                typeMod.update(e, dt, player, enemy, map)
            end
        end
    end

    -- Chain Aggro
    local changed = true
    while changed do
        changed = false
        for _, e1 in ipairs(enemy.list) do
            if e1.aggro then
                for _, e2 in ipairs(enemy.list) do
                    if not e2.aggro and math.sqrt((e1.x-e2.x)^2 + (e1.y-e2.y)^2) < cfg.groupAggroRadius then
                        e2.aggro, changed = true, true
                    end
                end
            end
        end
    end
    
    -- Slot Assignment
    enemy.updateSlots(px, py, map)
    for i = 1, cfg.numSlots do enemy.slots[i].occupied = false end
    
    local sortedEnemies = {}
    for _, e in ipairs(enemy.list) do
        if e.aggro and e.state ~= "dying" and e.attackState == "none" and e.type == "melee" then
            e.currentAngle = math.atan2(e.y - py, e.x - px)
            table.insert(sortedEnemies, e)
        end
    end
    table.sort(sortedEnemies, function(a, b) return a.currentAngle < b.currentAngle end)
    
    for _, e in ipairs(sortedEnemies) do
        local bestAngleDiff, bestId = 999, nil
        for i = 1, cfg.numSlots do
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
            
            if enemy.hasLOS(e.x, e.y, tx, ty, map) then 
                e.path = nil
            elseif not e.path or e.slotId ~= oldSlotId or e.pathTimer <= 0 then
                e.path = pathfinding.findPath(e.x, e.y, tx, ty, map)
                e.pathTimer = 0.5 
            end
            
            local mx, my = tx, ty
            if e.path and #e.path > 0 then
                while #e.path > 1 and enemy.hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do table.remove(e.path, 1) end
                if math.sqrt((e.path[1].x-e.x)^2 + (e.path[1].y-e.y)^2) < 15 then table.remove(e.path, 1) end
                if #e.path > 0 then mx, my = e.path[1].x, e.path[1].y end
            end
            
            local ddx, ddy = mx - e.x, my - e.y
            local ddist = math.sqrt(ddx*ddx + ddy*ddy)
            if ddist > 5 then
                local nx, ny = e.x + (ddx/ddist)*e.speed*dt, e.y + (ddy/ddist)*e.speed*dt
                if not enemy.isPointInWall(nx, ny, map) then e.x, e.y = nx, ny
                else
                    if not enemy.isPointInWall(nx, e.y, map) then e.x = nx
                    elseif not enemy.isPointInWall(e.x, ny, map) then e.y = ny end
                end
            end
        end
    end
    
    -- Local Repulsion
    for i = 1, #enemy.list do
        local e1 = enemy.list[i]
        for j = i + 1, #enemy.list do
            local e2 = enemy.list[j]
            local dx, dy = e2.x - e1.x, e2.y - e1.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 25 and dist > 0 then
                local push = (25 - dist) / 2
                local nx, ny = (dx/dist) * push, (dy/dist) * push
                if not enemy.isPointInWall(e2.x + nx, e2.y + ny, map) then e2.x, e2.y = e2.x + nx, e2.y + ny end
                if not enemy.isPointInWall(e1.x - nx, e1.y - ny, map) then e1.x, e1.y = e1.x - nx, e1.y - ny end
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
                    local nx, ny = e.x + (dx / dist) * push, e.y + (dy / dist) * push
                    if not enemy.isPointInWall(nx, ny, map) then e.x, e.y = nx, ny
                    else
                        if not enemy.isPointInWall(nx, e.y, map) then e.x = nx
                        elseif not enemy.isPointInWall(e.x, ny, map) then e.y = ny end
                    end
                end
            end
        end
    end
end

function enemy.draw(player)
    local cfg = enemy.config
    
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        
        -- Additive Glow
        love.graphics.setBlendMode("add")
        for i = 10, 1, -1 do
            local r, a = 30 * (i / 10), (1 - (i / 10)) * 0.2
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], a)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        -- Delegate draw
        local typeMod = enemy.typeModules[e.type]
        if typeMod then
            typeMod.draw(e)
        end

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

        -- Debug: Paths
        if cfg.showSlots and e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 1, 0.2)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do love.graphics.line(lx, ly, p.x, p.y) lx, ly = p.x, p.y end
        end
    end
    
    -- Death Particles
    for _, p in ipairs(enemy.particles) do
        local r, g, b = 1, 0.1, 0.1
        if p.color then r, g, b = p.color[1], p.color[2], p.color[3] end
        love.graphics.setColor(r, g, b, p.life / p.maxLife) 
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Debug: Combat Slots
    if cfg.showSlots and player then
        local px, py = player.x + player.size/2, player.y + player.size/2
        for i = 1, cfg.numSlots do
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
        end
    end
end

return enemy