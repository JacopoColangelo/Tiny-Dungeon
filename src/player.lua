local player = {
    x = 0,
    y = 0,
    targetX = 0,
    targetY = 0,
    speed = 180,
    size = 24,
    hp = 4,
    maxHp = 4,
    
    -- Audio
    footstepSound = love.audio.newSource("assets/audio/footstep_01.wav", "static"),
    attackSound = love.audio.newSource("assets/audio/attack_sweep_02.wav", "static"),
    hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static"),
    deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static"),
    footstepTimer = 0,
    footstepInterval = 0.35, -- Seconds between footsteps
    
    -- Skills
    skills = {
        sweep = {
            cooldown = 0.66,
            timer = 0,
            radius = 65, -- Tighter range
            arcAngle = math.pi * 0.5, -- Sharper 90 degree sweep
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

    -- Hit detection
    for i = #enemyList, 1, -1 do
        local e = enemyList[i]
        local ex, ey = e.x, e.y
        local dx, dy = ex - px, ey - py
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < s.radius + e.size/2 then
            local angle = math.atan2(dy, dx)
            local diff = math.abs(angle - heading)
            if diff > math.pi then diff = math.pi * 2 - diff end
            
            if diff < s.arcAngle / 2 then
                -- HIT!
                hitsCount = hitsCount + 1
                e.hp = e.hp - s.damage
                e.hitFlash = 0.15 -- Flash white for 0.15s
                player.hitSound:play()
                
                -- Apply Knockback
                local kbd = math.sqrt(dx*dx + dy*dy)
                if kbd > 0 then
                    local force = 500
                    e.kbX = (dx / kbd) * force
                    e.kbY = (dy / kbd) * force
                end

                if e.hp <= 0 then
                    player.deathSound:play()
                    table.remove(enemyList, i)
                end
            end
        end
    end
    
    -- Add Feedback (Scaling Shake & Hit-Stop)
    if hitsCount > 0 then
        if _G.camera and _G.camera.addShake then
            local intensity = 5 + (hitsCount - 1) * 2
            _G.camera.addShake(math.min(15, intensity), 0.12)
        end
        
        if _G.hitStop then
            -- 70ms base + 30ms per extra target (Tuned for smoothness)
            _G.hitStop(0.07 + (hitsCount - 1) * 0.03)
        end
    end
    
    -- Trigger Visual Effect
    table.insert(player.effects, {
        type = "sweep",
        x = px, y = py,
        angle = heading,
        radius = s.radius,
        timer = 0.12, -- Snappier!
        lifetime = 0.12
    })
    
    s.timer = s.cooldown
    return true
end

-- Helper to check if a specific pixel coordinate is inside a wall
local function isWall(px, py, map)
    local gx = math.floor(px / map.gridSize) + 1
    local gy = math.floor(py / map.gridSize) + 1
    if map.data[gy] and map.data[gy][gx] == 1 then
        return true
    end
    return false
end

function player.update(dt, map)
    local dx = player.targetX - (player.x + player.size/2)
    local dy = player.targetY - (player.y + player.size/2)
    local distance = math.sqrt(dx*dx + dy*dy)

    if distance > 5 then
        local oldX, oldY = player.x, player.y -- Store initial position
        
        local moveX = (dx / distance) * player.speed * dt
        local moveY = (dy / distance) * player.speed * dt

        -- Move X and check collision at all 4 corners of the player square
        player.x = player.x + moveX
        if isWall(player.x, player.y, map) or 
           isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or
           isWall(player.x + player.size, player.y + player.size, map) then
            player.x = player.x - moveX
        end

        -- Move Y and check collision
        player.y = player.y + moveY
        if isWall(player.x, player.y, map) or 
           isWall(player.x + player.size, player.y, map) or
           isWall(player.x, player.y + player.size, map) or
           isWall(player.x + player.size, player.y + player.size, map) then
            player.y = player.y - moveY
        end

        -- Footstep logic: Only if we actually moved this frame
        if math.abs(player.x - oldX) > 0.01 or math.abs(player.y - oldY) > 0.01 then
            player.footstepTimer = player.footstepTimer + dt
            if player.footstepTimer >= player.footstepInterval then
                player.footstepSound:play()
                player.footstepTimer = 0
            end
        else
            -- Standing still even if distance > 5 (e.g. against a wall)
            player.footstepTimer = player.footstepInterval -- Quick reset
        end
    else
        -- Reset timer when standing still (close to target)
        player.footstepTimer = player.footstepInterval
    end

    -- Update Skills
    for _, s in pairs(player.skills) do
        if s.timer > 0 then s.timer = math.max(0, s.timer - dt) end
    end
    
    -- Update Effects (Spawning Particles for Sweep)
    for i = #player.effects, 1, -1 do
        local fx = player.effects[i]
        local oldTimer = fx.timer
        fx.timer = fx.timer - dt
        
        if fx.type == "sweep" then
            local s = player.skills.sweep
            local fullArc = s.arcAngle
            local totalTravel = fullArc * 1.5
            
            -- Calculate head angle at start and end of this frame's movement
            local pStart = 1 - (oldTimer / fx.lifetime)
            local pEnd = 1 - (fx.timer / fx.lifetime)
            
            local startA = fx.angle - fullArc/2 + pStart * totalTravel
            local endA = fx.angle - fullArc/2 + pEnd * totalTravel
            
            -- Spawn Energy Shards (Tapered Comet Look)
            local pCount = 25 -- Very dense for a "solid" look
            for j = 1, pCount do
                local lerp = (j-1)/pCount
                local angle = startA + (endA - startA) * lerp
                local dist = s.radius
                
                table.insert(player.glowParticles, {
                    x = fx.x + math.cos(angle) * dist,
                    y = fx.y + math.sin(angle) * dist,
                    life = 0.15 + math.random() * 0.1,
                    maxLife = 0.25,
                    size = 5, -- Base size, will scale down in draw
                    color = math.random() > 0.4 and {0, 0.7, 1} or {1, 1, 1}
                })
            end
        end
        
        if fx.timer <= 0 then table.remove(player.effects, i) end
    end
    
    -- Update Particles
    for i = #player.glowParticles, 1, -1 do
        local p = player.glowParticles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(player.glowParticles, i)
        end
    end
end

function player.draw()
    local r_radius = 6
    love.graphics.setColor(0, 1, 1) -- Neon Cyan
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size, r_radius)
    
    -- Draw Effects (Dithered Area Fill)
    for _, fx in ipairs(player.effects) do
        if fx.type == "sweep" then
            local alpha = (fx.timer / fx.lifetime)
            local s = player.skills.sweep
            
            -- High-density Dithered Fill (Environment Integration)
            love.graphics.setColor(0, 0.6, 0.8, alpha * 0.4)
            local points = 80 -- Substantial coverage
            for i = 1, points do
                local r = math.sqrt(math.random()) * s.radius
                local a = fx.angle - s.arcAngle/2 + math.random() * s.arcAngle
                
                if math.random() > 0.2 then
                    local px = math.floor(fx.x + math.cos(a) * r)
                    local py = math.floor(fx.y + math.sin(a) * r)
                    -- Snap to 2x2 grid for retro feel
                    love.graphics.rectangle("fill", px - px%2, py - py%2, 2, 2)
                end
            end
        end
    end

    -- Draw Shards (Tapered & Solid)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(player.glowParticles) do
        local p_alpha = p.life / p.maxLife
        local drawSize = math.max(1, math.floor(p.size * p_alpha))
        
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p_alpha * 0.8)
        -- Snap to 2px blocks
        local sx = math.floor(p.x)
        local sy = math.floor(p.y)
        love.graphics.rectangle("fill", sx - sx%2, sy - sy%2, drawSize, drawSize)
    end
    love.graphics.setBlendMode("alpha")
end

return player