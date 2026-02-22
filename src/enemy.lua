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
        enemy.slots[i] = { x = 0, y = 0, occupied = false, valid = false }
    end
end

function enemy.spawn(map, px, py)
    local spawnX, spawnY
    local found = false
    
    for i = 1, 100 do
        local tx, ty = love.math.random(1, map.width), love.math.random(1, map.height)
        if map.data[ty][tx] == 0 then
            local x = (tx - 1) * map.gridSize + map.gridSize/2
            local y = (ty - 1) * map.gridSize + map.gridSize/2
            if math.sqrt((x - px)^2 + (y - py)^2) > 400 then
                spawnX, spawnY, found = x, y, true
                break
            end
        end
    end
    
    if found then
        local e = {
            state = "alive",     
            deathTimer = 0,      
            originalSize = 20,   
            x = spawnX, y = spawnY,
            size = 20, speed = 80,
            slotId = nil, aggro = false,
            path = nil, pathTimer = 0,
            color = {1, 0.2, 0.2},
            hp = 100, maxHp = 100,
            hitFlash = 0, kbX = 0, kbY = 0
        }
        
        -- ENCAPSULATED DAMAGE LOGIC
        function e:takeDamage(damage, kx, ky)
            if self.state == "dying" then return end
            
            self.hp = self.hp - damage
            self.hitFlash = 0.15 
            
            if self.hp <= 0 then
                enemy.deathSound:play()
                self.state = "dying"
                self.deathTimer = 0.25 
                self.originalSize = self.size
                self.aggro = false 
                self.slotId = nil
                -- STOP INSTANTLY ON DEATH
                self.kbX = 0
                self.kbY = 0
            else
                enemy.hitSound:play()
                self.kbX = kx
                self.kbY = ky
            end
        end

        table.insert(enemy.list, e)
    end
end

local function isPointInWall(x, y, map)
    local tx, ty = math.floor(x / map.gridSize) + 1, math.floor(y / map.gridSize) + 1
    if tx < 1 or tx > map.width or ty < 1 or ty > map.height then return true end
    return map.data[ty][tx] == 1
end

local function hasLOS(x1, y1, x2, y2, map)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 5 then return true end
    local steps = math.ceil(dist / 10)
    for s = 1, steps do
        if isPointInWall(x1 + dx * (s/steps), y1 + dy * (s/steps), map) then return false end
    end
    return true
end

function enemy.updateSlots(px, py, map)
    for i = 1, enemy.numSlots do
        local angle = ((i-1) / enemy.numSlots) * math.pi * 2
        local tx = px + math.cos(angle) * enemy.slotRadius
        local ty = py + math.sin(angle) * enemy.slotRadius
        
        local valid = not isPointInWall(tx, ty, map) and hasLOS(px, py, tx, ty, map)
        enemy.slots[i].x, enemy.slots[i].y, enemy.slots[i].valid = tx, ty, valid
        enemy.slots[i].occupied = false
    end
end

function enemy.update(dt, player, map)
    local px, py = player.x + player.size/2, player.y + player.size/2

    -- Particles
    for i = #enemy.particles, 1, -1 do
        local p = enemy.particles[i]
        p.life = p.life - dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.vx, p.vy = p.vx * math.exp(-6 * dt), p.vy * math.exp(-6 * dt)
        if p.life <= 0 then table.remove(enemy.particles, i) end
    end

    -- Update List
    for i = #enemy.list, 1, -1 do
        local e = enemy.list[i]
        
        if e.state == "dying" then
            e.deathTimer = e.deathTimer - dt
            e.size = math.max(0, (e.deathTimer / 0.25) * e.originalSize)
            if e.deathTimer <= 0 then
                for p = 1, 40 do
                    local ang = love.math.random() * math.pi * 2
                    local spd = love.math.random(50, 250)
                    table.insert(enemy.particles, {
                        x = e.x, y = e.y, vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
                        life = love.math.random(0.3, 0.7), maxLife = 0.7, size = love.math.random(2, 5)
                    })
                end
                table.remove(enemy.list, i)
            end
        else
            -- ALIVE PHYSICS (KNOCKBACK)
            if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
            if math.abs(e.kbX) > 1 or math.abs(e.kbY) > 1 then
                local nx, ny = e.x + e.kbX * dt, e.y + e.kbY * dt
                if not isPointInWall(nx, ny, map) then e.x, e.y = nx, ny end
                e.kbX, e.kbY = e.kbX * math.exp(-8 * dt), e.kbY * math.exp(-8 * dt)
            end

            -- Aggro and Pathfinding
            if not e.aggro and math.sqrt((e.x - px)^2 + (e.y - py)^2) < enemy.perceptionRadius then
                e.aggro = true
            end
        end
    end

    -- Slot logic & movement for aggro'd enemies
    enemy.updateSlots(px, py, map)
    for _, e in ipairs(enemy.list) do
        if e.state == "alive" and e.aggro then
            local bestId, bestDiff = nil, 999
            local curA = math.atan2(e.y - py, e.x - px)
            
            for i = 1, enemy.numSlots do
                local s = enemy.slots[i]
                if s.valid and not s.occupied then
                    local diff = math.abs(curA - math.atan2(s.y - py, s.x - px))
                    if diff > math.pi then diff = math.pi * 2 - diff end
                    if diff < bestDiff then bestDiff, bestId = diff, i end
                end
            end

            if bestId then
                enemy.slots[bestId].occupied = true
                local tx, ty = enemy.slots[bestId].x, enemy.slots[bestId].y
                local dx, dy = tx - e.x, ty - e.y
                local d = math.sqrt(dx*dx + dy*dy)
                if d > 5 then
                    e.x, e.y = e.x + (dx/d) * e.speed * dt, e.y + (dy/d) * e.speed * dt
                end
            end
        end
    end
end

function enemy.draw(player)
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        
        -- Glow
        love.graphics.setBlendMode("add")
        for i = 10, 1, -1 do
            local r = 30 * (i / 10) * (e.size / e.originalSize)
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], (1 - (i / 10)) * 0.2)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        -- Body
        if e.hitFlash > 0 then love.graphics.setColor(1, 1, 1)
        elseif e.aggro then love.graphics.setColor(e.color[1], e.color[2], e.color[3])
        else love.graphics.setColor(0.4, 0.4, 0.4) end
        
        love.graphics.rectangle("fill", cx - e.size/2, cy - e.size/2, e.size, e.size, 6)

        -- HP Bar
        if e.state == "alive" and player then
            local dist = math.sqrt((cx - (player.x+player.size/2))^2 + (cy - (player.y+player.size/2))^2)
            if dist < 300 then
                local alpha = (1 - (dist / 300)) * 0.9
                love.graphics.setColor(0, 0, 0, alpha * 0.6)
                love.graphics.rectangle("fill", cx - 15, cy - e.size/2 - 10, 30, 4)
                love.graphics.setColor(1, 0.2, 0.2, alpha)
                love.graphics.rectangle("fill", cx - 15, cy - e.size/2 - 10, 30 * (e.hp / e.maxHp), 4)
            end
        end
    end
    
    -- Death Particles
    for _, p in ipairs(enemy.particles) do
        love.graphics.setColor(1, 0.1, 0.1, p.life / p.maxLife) 
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end
end

return enemy