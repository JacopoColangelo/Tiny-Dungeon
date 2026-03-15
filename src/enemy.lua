local pathfinding = require("src.pathfinding")
local soul = require("src.soul")

local enemy = {}

-- ============================================================================
-- MODULE STATE & TYPES
-- ============================================================================

enemy.list = {}
enemy.particles = {}
enemy.typeModules = {}

-- Audio Assets (Shared)
-- TODO: Separate sounds for each enemy type
enemy.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
enemy.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")

-- ============================================================================
-- DESIGNER CONFIGURATION (Shared)
-- ============================================================================

-- TODO: Separate config for each enemy type
enemy.config = {
    hitFlashDuration = 0.15,    -- How long they flash white when hit
    deathParticleCount = 15,    -- Number of particles when an enemy dies
    deathParticleSpeed = 150,   -- Speed of the particles
    deathParticleLife = 0.5,    -- Life of the particles
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

function enemy.isCircleColliding(x, y, radius, map)
    -- Check center
    if enemy.isPointInWall(x, y, map) then return true end
    -- Check 8 points on circle (cardinal + ordinal)
    for i = 0, 7 do
        local angle = i * (math.pi / 4)
        local px = x + math.cos(angle) * (radius * 0.85) -- slightly more lenient buffer
        local py = y + math.sin(angle) * (radius * 0.85)
        if enemy.isPointInWall(px, py, map) then return true end
    end
    return false
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
    enemy.typeModules.elite_ranged = require("src.enemies.elite_ranged")

    -- Call init on modules if they have it
    for _, mod in pairs(enemy.typeModules) do
        if mod.init then mod.init() end
    end
end

-- TODO: Separate spawn rates for each enemy type, check if code is in game.lua and if so move it here. Why is spawn enemy code in game.lua?
-- TODO: Add enemy roaming behavior

function enemy.spawn(map, px, py, eType)
    eType = eType or "melee"
    local typeMod = enemy.typeModules[eType]
    if not typeMod then return end

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
        }
        
        typeMod.create(e)

        function e:takeDamage(damage, kx, ky)
            if self.state == "dying" then return end
            
            self.hp = self.hp - damage
            self.hitFlash = enemy.config.hitFlashDuration
            
            if self.hp <= 0 then
                enemy.deathSound:play()
                self.state = "dying"
                
                local cfg = typeMod.config
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
                
                if cfg and soul and love.math.random() < (cfg.soulDropRate or 0.65) then
                    local amount = love.math.random(cfg.soulMinDrop or 3, cfg.soulMaxDrop or 5)
                    soul.spawn(self.x, self.y, amount)
                end
            else
                enemy.hitSound:play()
                self.kbX, self.kbY = kx, ky
                
                if self.attackState == "winding" or self.attackState == "charging" then
                    self.attackState = "none"
                    self.attackCooldown = 1.2
                end
            end
        end

        table.insert(enemy.list, e)
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
            
            -- Apply Knockback (with Axis Sliding)
            if math.abs(e.kbX) > 1 or math.abs(e.kbY) > 1 then
                local radius = (e.size or 20) / 2
                
                -- Try X movement
                local nx = e.x + e.kbX * dt
                if not enemy.isCircleColliding(nx, e.y, radius, map) then
                    e.x = nx
                else
                    e.kbX = 0 -- Stop X on hit
                end
                
                -- Try Y movement
                local ny = e.y + e.kbY * dt
                if not enemy.isCircleColliding(e.x, ny, radius, map) then
                    e.y = ny
                else
                    e.kbY = 0 -- Stop Y on hit
                end
                
                e.kbX, e.kbY = e.kbX * math.exp(-8 * dt), e.kbY * math.exp(-8 * dt)
            else
                e.kbX, e.kbY = 0, 0
            end

            -- Aggro Perception (Config from type module)
            if not e.aggro then
                local pRad = (cfg and cfg.perceptionRadius) or 250
                local d = math.sqrt((e.x - px)^2 + (e.y - py)^2)
                if d < pRad then e.aggro = true end
            end

            -- behavior via type module
            local typeMod = enemy.typeModules[e.type]
            if typeMod then
                typeMod.update(e, dt, player, enemy, map)
            end
        end
    end

    -- Chain Aggro (Pulling group aggro radius from specific type)
    local changed = true
    while changed do
        changed = false
        for _, e1 in ipairs(enemy.list) do
            if e1.aggro then
                local t1 = enemy.typeModules[e1.type]
                local gRad = (t1 and t1.config and t1.config.groupAggroRadius) or 350
                for _, e2 in ipairs(enemy.list) do
                    if not e2.aggro and math.sqrt((e1.x-e2.x)^2 + (e1.y-e2.y)^2) < gRad then
                        e2.aggro, changed = true, true
                    end
                end
            end
        end
    end
    
    -- Global Updates (delegated to modules)
    for _, mod in pairs(enemy.typeModules) do
        if mod.globalUpdate then
            mod.globalUpdate(dt, player, enemy, map)
        end
    end
    
    -- Shared Physics: Local Repulsion
    for i = 1, #enemy.list do
        local e1 = enemy.list[i]
        for j = i + 1, #enemy.list do
            local e2 = enemy.list[j]
            local dx, dy = e2.x - e1.x, e2.y - e1.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 25 and dist > 0 then
                local push = (25 - dist) / 2
                local nx, ny = (dx/dist) * push, (dy/dist) * push
                local r2 = (e2.size or 20) / 2
                local r1 = (e1.size or 20) / 2
                if not enemy.isCircleColliding(e2.x + nx, e2.y + ny, r2, map) then e2.x, e2.y = e2.x + nx, e2.y + ny end
                if not enemy.isCircleColliding(e1.x - nx, e1.y - ny, r1, map) then e1.x, e1.y = e1.x - nx, e1.y - ny end
            end
        end
    end

    -- Shared Physics: Portal Repulsion
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
                    local r = e.size / 2
                    if not enemy.isCircleColliding(nx, ny, r, map) then e.x, e.y = nx, ny
                    else
                        if not enemy.isCircleColliding(nx, e.y, r, map) then e.x = nx
                        elseif not enemy.isCircleColliding(e.x, ny, r, map) then e.y = ny end
                    end
                end
            end
        end
    end
end

function enemy.draw(player)
    for _, e in ipairs(enemy.list) do
        local cx, cy = e.x, e.y
        
        -- Additive Glow (Scales with size and color)
        love.graphics.setBlendMode("add")
        local glowSize = e.size * 1.5
        for i = 10, 1, -1 do
            local r, a = glowSize * (i / 10), (1 - (i / 10)) * 0.25
            love.graphics.setColor(e.color[1], e.color[2], e.color[3], a)
            love.graphics.circle("fill", cx, cy, r)
        end
        love.graphics.setBlendMode("alpha")
        
        -- Body/Attack visuals via type module
        local typeMod = enemy.typeModules[e.type]
        if typeMod then
            typeMod.draw(e)
        end

        -- Health Bar (Shared UI)
        if player then
            local dist = math.sqrt((cx - (player.x+player.size/2))^2 + (cy - (player.y+player.size/2))^2)
            if dist < 300 then
                local alpha = (1 - (dist / 300)) * 0.9
                local hbo = e.hpBarOffset or -20
                love.graphics.setColor(0, 0, 0, alpha * 0.6)
                love.graphics.rectangle("fill", cx-15, cy + hbo, 30, 4)
                love.graphics.setColor(1, 0.2, 0.2, alpha)
                love.graphics.rectangle("fill", cx-15, cy + hbo, 30 * (e.hp/e.maxHp), 4)

                -- Display Name & Level
                if e.displayName then
                    local tinyFont = _G.hud and _G.hud.getFont and _G.hud.getFont("tiny")
                    if tinyFont then
                        love.graphics.setFont(tinyFont)
                        local nameStr = e.displayName
                        local levelStr = tostring(e.level or 1)
                        local nw = tinyFont:getWidth(nameStr)
                        local lw = tinyFont:getWidth(levelStr)
                        
                        -- Layout: [D] Name  (D is diamond)
                        local diamondSize = 10
                        local spacing = 4
                        local totalW = diamondSize + spacing + nw
                        local baseX = cx - totalW/2
                        local baseY = cy + hbo - 18
                        
                        -- Stable alpha: clear but non-invasive
                        local uiAlpha = 0.5
                        
                        -- Draw Diamond
                        love.graphics.setColor(1, 1, 1, uiAlpha)
                        local dx = baseX + diamondSize/2
                        local dy = baseY + tinyFont:getHeight()/2
                        love.graphics.polygon("line", 
                            dx, dy - diamondSize/2, -- top
                            dx + diamondSize/2, dy, -- right
                            dx, dy + diamondSize/2, -- bottom
                            dx - diamondSize/2, dy  -- left
                        )
                        
                        -- Draw Level Number (centered in diamond)
                        love.graphics.print(levelStr, dx - lw/2, dy - tinyFont:getHeight()/2)
                        
                        -- Draw Name
                        love.graphics.print(nameStr, baseX + diamondSize + spacing, baseY)
                    end
                end
            end
        end
    end

    -- Global Debug Drawing (e.g., Slots)
    if enemy.config.showSlots and player then
        for _, mod in pairs(enemy.typeModules) do
            if mod.globalDraw then
                mod.globalDraw(player, enemy)
            end
        end
    end

    -- Particles
    for _, p in ipairs(enemy.particles) do
        local r, g, b = 1, 0.1, 0.1
        if p.color then r, g, b = p.color[1], p.color[2], p.color[3] end
        love.graphics.setColor(r, g, b, p.life / p.maxLife) 
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end
end

return enemy