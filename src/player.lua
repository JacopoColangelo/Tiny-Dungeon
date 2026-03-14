local inventory = require("src.inventory")

local player = {
    x = 0,
    y = 0,
    targetX = 0,
    targetY = 0,
    speed = 180,
    attackSlowdown = 0.4, -- Move at 40% speed during attack
    size = 24,
    hp = 4,
    maxHp = 4,
    soulsRun = 0,
    soulsTotal = 0,
    torchSize = 250,
    shadowPolygon = nil,
    
    -- Audio (Player specific)
    footstepSound = love.audio.newSource("assets/audio/footstep_01.wav", "static"),
    attackSound = love.audio.newSource("assets/audio/attack_sweep_02.wav", "static"),
    footstepTimer = 0,
    footstepInterval = 0.35, 
    
    -- Skills
    skills = {
        sweep = {
            cooldown = 0.66,
            timer = 0,
            radius = 65,
            arcAngle = math.pi * 0.5,
            damage = 30
        }
    },
    
    -- Visual Effects
    effects = {},
    glowParticles = {}
}

function player.performSweep(mx, my, enemyList)
    local s = player.skills.sweep
    if s.timer > 0 then return false end
    
    local px, py = player.x + player.size/2, player.y + player.size/2
    local heading = math.atan2(my - py, mx - px)
    local hitsCount = 0
    
    player.attackSound:play()

    -- Hit detection logic
    for i = #enemyList, 1, -1 do
        local e = enemyList[i]
        
        if e.state == "alive" then
            local ex, ey = e.x, e.y
            local dx, dy = ex - px, ey - py
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist < s.radius + e.size/2 then
                local angle = math.atan2(dy, dx)
                local diff = math.abs(angle - heading)
                if diff > math.pi then diff = math.pi * 2 - diff end
                
                if diff < s.arcAngle / 2 then
                    hitsCount = hitsCount + 1
                    
                    -- Calculate Knockback vector
                    local kx, ky = 0, 0
                    if dist > 0 then
                        local force = 500
                        kx = (dx / dist) * force
                        ky = (dy / dist) * force
                    end

                    -- Delegate damage to enemy
                    e:takeDamage(s.damage, kx, ky)
                end
            end
        end
    end
    
    -- Global Screen Feedback
    if hitsCount > 0 then
        if _G.camera and _G.camera.addShake then
            _G.camera.addShake(math.min(15, 5 + (hitsCount - 1) * 2), 0.12)
        end
        if _G.hitStop then
            _G.hitStop(0.07 + (hitsCount - 1) * 0.03)
        end
    end
    
    -- Sweep visual effect (Also used to track if player is attacking)
    table.insert(player.effects, {
        type = "sweep",
        x = px, y = py,
        angle = heading,
        radius = s.radius,
        timer = 0.15, -- Duration the player is slowed
        lifetime = 0.15
    })
    
    s.timer = s.cooldown
    return true
end

local function isWall(px, py, map)
    local gx = math.floor(px / map.gridSize) + 1
    local gy = math.floor(py / map.gridSize) + 1
    if map.data[gy] and map.data[gy][gx] == 1 then return true end
    return false
end

function player.update(dt, map)
    local dx = player.targetX - (player.x + player.size/2)
    local dy = player.targetY - (player.y + player.size/2)
    local distance = math.sqrt(dx*dx + dy*dy)

    -- Determine if we are currently in an attack animation
    local isAttacking = false
    for _, fx in ipairs(player.effects) do
        if fx.type == "sweep" then
            isAttacking = true
            break
        end
    end

    -- Movement logic with slowdown check
    if distance > 5 then
        local oldX, oldY = player.x, player.y 
        
        -- Apply slowdown if attacking
        local currentSpeed = player.speed
        if isAttacking then
            currentSpeed = player.speed * player.attackSlowdown
        end

        local moveX = (dx / distance) * currentSpeed * dt
        local moveY = (dy / distance) * currentSpeed * dt

        player.x = player.x + moveX
        if isWall(player.x, player.y, map) or isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or isWall(player.x + player.size, player.y + player.size, map) then
            player.x = player.x - moveX
        end

        player.y = player.y + moveY
        if isWall(player.x, player.y, map) or isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or isWall(player.x + player.size, player.y + player.size, map) then
            player.y = player.y - moveY
        end

        -- Portal Collision (Circular)
        local hpx, hpy = map.getPortalWorldPos()
        if hpx and hpy then
            local p_center_x, p_center_y = player.x + player.size/2, player.y + player.size/2
            local dx, dy = p_center_x - hpx, p_center_y - hpy
            local distSq = dx*dx + dy*dy
            local minDist = (map.portalCollisionRadius or 30) + player.size/2
            if distSq < minDist * minDist then
                local dist = math.sqrt(distSq)
                if dist > 0 then
                    local push = minDist - dist
                    player.x = player.x + (dx / dist) * push
                    player.y = player.y + (dy / dist) * push
                else
                    -- Exactly on top? Push slightly in any direction
                    player.y = player.y + 1
                end
            end
        end

        player.lastX = oldX
        player.lastY = oldY

        -- Footstep Audio (Slowed down if movement is slow)
        if math.abs(player.x - oldX) > 0.01 or math.abs(player.y - oldY) > 0.01 then
            local interval = isAttacking and (player.footstepInterval * 1.5) or player.footstepInterval
            player.footstepTimer = player.footstepTimer + dt
            if player.footstepTimer >= interval then
                player.footstepSound:play()
                player.footstepTimer = 0
            end
        else
            player.footstepTimer = player.footstepInterval 
        end
    else
        player.footstepTimer = player.footstepInterval
    end

    -- Update Cooldowns
    for _, s in pairs(player.skills) do
        if s.timer > 0 then s.timer = math.max(0, s.timer - dt) end
    end
    
    -- Update Effects and Particles
    for i = #player.effects, 1, -1 do
        local fx = player.effects[i]
        local oldTimer = fx.timer
        fx.timer = fx.timer - dt
        
        if fx.type == "sweep" then
            local s = player.skills.sweep
            local fullArc = s.arcAngle
            local totalTravel = fullArc * 1.5
            local pStart = 1 - (oldTimer / fx.lifetime)
            local pEnd = 1 - (fx.timer / fx.lifetime)
            local startA = fx.angle - fullArc/2 + pStart * totalTravel
            local endA = fx.angle - fullArc/2 + pEnd * totalTravel
            
            for j = 1, 25 do
                local angle = startA + (endA - startA) * ((j-1)/25)
                table.insert(player.glowParticles, {
                    x = fx.x + math.cos(angle) * s.radius,
                    y = fx.y + math.sin(angle) * s.radius,
                    life = 0.15 + math.random() * 0.1,
                    maxLife = 0.25,
                    size = 10, 
                    color = math.random() > 0.4 and {0, 0.7, 1} or {1, 1, 1}
                })
            end
        end
        if fx.timer <= 0 then table.remove(player.effects, i) end
    end
    
    for i = #player.glowParticles, 1, -1 do
        local p = player.glowParticles[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(player.glowParticles, i) end
    end
end

function player.draw()
    -- Draw Player Body
    love.graphics.setColor(0, 1, 1) 
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size, 6)
    
    -- Draw Sweep Visuals
    for _, fx in ipairs(player.effects) do
        if fx.type == "sweep" then
            local alpha = (fx.timer / fx.lifetime)
            love.graphics.setColor(0, 0.6, 0.8, alpha * 0.4)
            for i = 1, 80 do
                local r = math.sqrt(math.random()) * player.skills.sweep.radius
                local a = fx.angle - player.skills.sweep.arcAngle/2 + math.random() * player.skills.sweep.arcAngle
                if math.random() > 0.2 then
                    local px, py = fx.x + math.cos(a) * r, fx.y + math.sin(a) * r
                    love.graphics.rectangle("fill", px - px%2, py - py%2, 2, 2)
                end
            end
        end
    end

    -- Draw Particles
    love.graphics.setBlendMode("add")
    for _, p in ipairs(player.glowParticles) do
        local p_alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p_alpha * 0.8)
        love.graphics.rectangle("fill", p.x - p.x%2, p.y - p.y%2, math.floor(p.size * p_alpha), math.floor(p.size * p_alpha))
    end
    love.graphics.setBlendMode("alpha")
end

return player