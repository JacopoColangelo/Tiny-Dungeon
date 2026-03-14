local melee = {}

melee.config = {
    maxHp = 100,
    speed = 110,
    size = 20,
    color = {1, 0.2, 0.2}, -- Red
    
    -- Charge Attack Logic
    chargeRange = 100,       -- Distance to trigger the charge
    chargeSpeed = 650,       -- Velocity during the dash
    chargeDuration = 0.3,    -- How long the dash lasts
    chargeWindup = 0.4,      -- Pre-charge delay (telegraph)
    chargeCooldown = 2.0,    -- Time between charges
    damagePerHit = 0.7,      -- Damage dealt to player
}

function melee.create(e)
    local cfg = melee.config
    e.hp = cfg.maxHp
    e.maxHp = cfg.maxHp
    e.size = cfg.size
    e.speed = cfg.speed
    e.color = cfg.color
    
    e.attackState = "none"
    e.attackTimer = 0
    e.attackCooldown = 0
    e.attackDirX = 0
    e.attackDirY = 0
    e.hasDealtDamage = false
end

function melee.update(e, dt, player, enemyModule, map)
    local cfg = melee.config
    local px, py = player.x + player.size/2, player.y + player.size/2
    local dx, dy = px - e.x, py - e.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if e.attackCooldown > 0 then
        e.attackCooldown = e.attackCooldown - dt
    end

    -- Trigger Charge Windup
    if e.attackState == "none" and e.attackCooldown <= 0 and dist < cfg.chargeRange and e.aggro then
        e.attackState = "winding"
        e.attackTimer = cfg.chargeWindup
        local angle = math.atan2(dy, dx)
        e.attackDirX, e.attackDirY = math.cos(angle), math.sin(angle)
    
    -- Execute Windup
    elseif e.attackState == "winding" then
        e.attackTimer = e.attackTimer - dt
        if e.attackTimer <= 0 then
            e.attackState = "charging"
            e.attackTimer = cfg.chargeDuration
            e.hasDealtDamage = false
        end
    
    -- Execute Dash
    elseif e.attackState == "charging" then
        e.attackTimer = e.attackTimer - dt
        local nx = e.x + e.attackDirX * cfg.chargeSpeed * dt
        local ny = e.y + e.attackDirY * cfg.chargeSpeed * dt
        
        -- Dash collision with walls (with sliding)
        if not enemyModule.isPointInWall(nx, ny, map) then
            e.x, e.y = nx, ny
        else
            local nx1, ny1 = nx, e.y
            local nx2, ny2 = e.x, ny
            if not enemyModule.isPointInWall(nx1, ny1, map) then e.x, e.y = nx1, ny1
            elseif not enemyModule.isPointInWall(nx2, ny2, map) then e.x, e.y = nx2, ny2
            else e.attackTimer = 0 end -- Stop dash on strict corner
        end

        -- Collision with player
        if not e.hasDealtDamage and dist < (e.size + player.size) / 2 then
            player.hp = player.hp - cfg.damagePerHit
            e.hasDealtDamage = true
            if _G.camera and _G.camera.addShake then _G.camera.addShake(12, 0.12) end
        end

        if e.attackTimer <= 0 then
            e.attackState = "none"
            e.attackCooldown = cfg.chargeCooldown
        end
    end
end

function melee.draw(e)
    local cfg = melee.config
    local cx, cy = e.x, e.y
    
    if e.hitFlash > 0 then 
        love.graphics.setColor(1, 1, 1, 1) -- White flash when hit
    elseif e.attackState == "winding" then 
        love.graphics.setColor(1, 1, 1, 1) -- White flash during windup
    elseif e.attackState == "charging" then 
        love.graphics.setColor(1, 0.5, 0) -- Orange during lunge
    elseif e.aggro then 
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
    else 
        love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Dull grey when idle
    end
    
    love.graphics.rectangle("fill", cx - e.size/2, cy - e.size/2, e.size, e.size, 6)

    -- Draw Charge Lunge Telegraph
    if e.attackState == "winding" then
        local p = 1 - (e.attackTimer / cfg.chargeWindup)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 0, 0, 0.4)
        love.graphics.line(cx, cy, cx + e.attackDirX * cfg.chargeRange, cy + e.attackDirY * cfg.chargeRange)
        love.graphics.circle("line", cx + e.attackDirX * cfg.chargeRange * p, cy + e.attackDirY * cfg.chargeRange * p, 5)
    end
end

return melee
