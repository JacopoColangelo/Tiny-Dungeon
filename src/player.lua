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
    footstepTimer = 0,
    footstepInterval = 0.35, -- Seconds between footsteps
    
    -- Skills
    skills = {
        sweep = {
            cooldown = 0.66,
            timer = 0,
            radius = 80,
            arcAngle = math.pi * 0.6, -- Narrower, sharper sweep
            damage = 30
        }
    },
    
    -- Visual Effects
    effects = {}
}

function player.performSweep(mx, my, enemyList)
    local s = player.skills.sweep
    if s.timer > 0 then return false end
    
    local px, py = player.x + player.size/2, player.y + player.size/2
    local heading = math.atan2(my - py, mx - px)
    local hitsCount = 0
    
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
                
                -- Apply Knockback
                local kbd = math.sqrt(dx*dx + dy*dy)
                if kbd > 0 then
                    local force = 500
                    e.kbX = (dx / kbd) * force
                    e.kbY = (dy / kbd) * force
                end

                if e.hp <= 0 then
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
        timer = 0.15,
        lifetime = 0.15
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
    
    -- Update Effects
    for i = #player.effects, 1, -1 do
        local fx = player.effects[i]
        fx.timer = fx.timer - dt
        if fx.timer <= 0 then table.remove(player.effects, i) end
    end
end

function player.draw()
    local r_radius = 6
    love.graphics.setColor(0, 1, 1) -- Neon Cyan
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size, r_radius)
    
    -- Draw Effects (Slashes)
    for _, fx in ipairs(player.effects) do
        if fx.type == "sweep" then
            local progress = 1 - (fx.timer / fx.lifetime) -- 0 to 1
            local alpha = (fx.timer / fx.lifetime)
            local s = player.skills.sweep
            
            love.graphics.setBlendMode("add")
            
            -- Directional Swipe Logic:
            -- The "leading edge" of the swing moves from -arc/2 to +arc/2
            local fullArc = s.arcAngle
            local headAngle = fx.angle - fullArc/2 + progress * (fullArc * 1.5) -- Over-swing slightly
            local trailSize = fullArc * 0.4
            
            -- Draw several trailing layers
            local layers = 5
            for i = 1, layers do
                local layerAlpha = alpha * (1 - (i-1)/layers)
                local layerAngle = headAngle - (i-1) * (trailSize / layers)
                local startA = layerAngle - (trailSize / layers)
                local endA = layerAngle
                
                -- Outer Glow
                love.graphics.setLineWidth(12)
                love.graphics.setColor(0, 0.4, 1, layerAlpha * 0.15)
                love.graphics.arc("line", "open", fx.x, fx.y, fx.radius, startA, endA)
                
                -- Inner Glow
                love.graphics.setLineWidth(6)
                love.graphics.setColor(0, 0.8, 1, layerAlpha * 0.4)
                love.graphics.arc("line", "open", fx.x, fx.y, fx.radius, startA, endA)
                
                -- Core
                love.graphics.setLineWidth(2)
                love.graphics.setColor(1, 1, 1, layerAlpha * 0.8)
                love.graphics.arc("line", "open", fx.x, fx.y, fx.radius, startA, endA)
            end
            
            love.graphics.setBlendMode("alpha")
        end
    end
end

return player