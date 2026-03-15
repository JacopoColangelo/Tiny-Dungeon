local pathfinding = require("src.pathfinding")

--[[
============================================================================
ENEMY TYPE: ELITE RANGED (The "Sentinel")
============================================================================
Design Intent: A high-priority elite unit providing area suppression. 
It fires 3-round magic bursts with homing capabilities, demanding player 
focus. Features aggressive emergency warps to prevent being cornered and 
uses more sophisticated pathfinding scans to maintain tactical positioning.
============================================================================
]]

local elite = {}

elite.config = {
    
    -- Stats
    displayName = "Sentinel",   -- Display Name
    maxHp = 180,                -- Health
    level = 1,                  -- Starting Level
    speed = 130,                -- Speed
    size = 24,                  -- Size
    color = {1.0, 0.8, 0.1},    -- Color = Yellow/Gold
    
    -- Damage
    damagePerHit = 0.8,         -- Damage dealt per magic ball
    
    -- UI
    hpBarOffset = -30,          -- Offset for the HP Bar (less = higher)

    -- Ranged Attack Logic
    castRange = 250,            -- Distance to cast the attack
    fleeRange = 120,            -- Distance to flee from the player
    castWindup = 1.2,           -- Time to charge the attack
    castCooldown = 3.0,         -- Time between attacks

    -- Burst Stats
    burstCount = 3,             -- Number of magic balls
    burstInterval = 0.15,       -- Delay between balls in a burst
    spreadAngle = 0.25,         -- slight spread for the burst
    homingStrength = 1.2,       -- Slight homing
    projSpeed = 300,            -- Speed of the magic balls

    -- Warp/Dash Logic
    warpSpeed = 700,            -- Speed of the warp
    warpDuration = 0.25,        -- Duration of the warp
    warpCooldown = 0.8,         -- Time between warps

    -- Perception
    perceptionRadius = 320,     -- Radius to detect the player
    groupAggroRadius = 400,     -- Radius to alert other enemies

    -- Rewards
    soulDropRate = 0.95,        -- Probability to drop souls
    soulMinDrop = 8,            -- Minimum number of souls to drop
    soulMaxDrop = 15,           -- Maximum number of souls to drop
}

function elite.create(e)
    local cfg = elite.config
    e.hp = cfg.maxHp
    e.maxHp = cfg.maxHp
    e.size = cfg.size
    e.speed = cfg.speed
    e.color = cfg.color
    e.hpBarOffset = cfg.hpBarOffset
    e.displayName = cfg.displayName
    e.level = cfg.level
    
    e.attackState = "none"
    e.attackTimer = 0
    e.attackCooldown = 0
    e.attackDirX = 0
    e.attackDirY = 0
    
    e.warpCooldown = 0
    e.burstTimer = 0
    e.burstsRemaining = 0
end

function elite.update(e, dt, player, enemyModule, map)
    local cfg = elite.config
    local px, py = player.x + player.size/2, player.y + player.size/2
    local dx, dy = px - e.x, py - e.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if e.attackCooldown > 0 then
        e.attackCooldown = e.attackCooldown - dt
    end
    
    if e.warpCooldown and e.warpCooldown > 0 then
        e.warpCooldown = e.warpCooldown - dt
    end

    local hasSight = enemyModule.hasLOS(e.x, e.y, px, py, map)
    
    -- ========================================================================
    -- EMERGENCY ESCAPE & CLIPPING RESET
    -- ========================================================================
    local radius = e.size / 2
    local isTrapped = false
    local isClipping = enemyModule.isCircleColliding(e.x, e.y, radius, map)
    
    -- Check for traps if we are too close OR just trying to move and blocked
    if dist < cfg.fleeRange or isClipping or (e.path and #e.path > 0) then
        local angle = math.atan2(dy, dx)
        local moveMult = (e.attackState ~= "none") and 0.5 or 1.0
        local moveX = -math.cos(angle) * e.speed * dt * moveMult
        local moveY = -math.sin(angle) * e.speed * dt * moveMult
        
        -- Check if basically any direction is blocked (Diagonal, X, or Y)
        local canMoveDirect = not enemyModule.isCircleColliding(e.x + moveX, e.y + moveY, radius, map)
        local canMoveX = not enemyModule.isCircleColliding(e.x + moveX, e.y, radius, map)
        local canMoveY = not enemyModule.isCircleColliding(e.x, e.y + moveY, radius, map)
        
        if not (canMoveDirect or canMoveX or canMoveY) then
            isTrapped = true
        end
    end

    -- Emergency reset if clipped
    if isClipping and (e.warpCooldown or 0) <= 0 then isTrapped = true end

    if isTrapped and (e.warpCooldown or 0) <= 0 and e.attackState ~= "warping" then
        -- Trigger EMERGENCY WARP (Cancels everything else)
        e.attackState = "warping"
        e.attackTimer = cfg.warpDuration
        
        -- Smarter Escape Angle Scan
        local bestAngle = nil
        local baseAngle = math.atan2(dy, dx) -- Face-to-player angle
        
        local scanDistances = {100, 70, 40}
        for _, sDist in ipairs(scanDistances) do
            for i = 1, 8 do
                local testAngle = baseAngle + math.pi + (i-4.5) * (math.pi/4) -- Scan 180 deg away
                local tx = e.x + math.cos(testAngle) * sDist
                local ty = e.y + math.sin(testAngle) * sDist
                if not enemyModule.isCircleColliding(tx, ty, radius, map) then
                    bestAngle = testAngle
                    break 
                end
            end
            if bestAngle then break end
        end
        
        local finalAngle = bestAngle or (baseAngle + math.pi)
        e.attackDirX, e.attackDirY = math.cos(finalAngle), math.sin(finalAngle)
        enemyModule.addParticle(e.x, e.y, cfg.color)
        return -- Skip standard AI for this frame
    end

    -- ========================================================================
    -- STANDARD AI STATES
    -- ========================================================================
    if (e.attackState == "none" or e.attackState == "winding" or e.attackState == "bursting") and e.aggro then
        -- Allow slight movement even during windup/bursting
        local moveMult = (e.attackState ~= "none") and 0.5 or 1.0
        
        if dist < cfg.fleeRange then
            local angle = math.atan2(dy, dx)
            local moveX = -math.cos(angle) * e.speed * moveMult * dt
            local moveY = -math.sin(angle) * e.speed * moveMult * dt
            local nx, ny = e.x + moveX, e.y + moveY
            
            if not enemyModule.isCircleColliding(nx, ny, radius, map) then
                e.x, e.y = nx, ny
            else
                if not enemyModule.isCircleColliding(e.x + moveX, e.y, radius, map) then e.x = e.x + moveX
                elseif not enemyModule.isCircleColliding(e.x, e.y + moveY, radius, map) then e.y = e.y + moveY
                end
            end
        elseif dist > cfg.castRange or not hasSight then
            e.pathTimer = e.pathTimer - dt
            if not e.path or e.pathTimer <= 0 then
                e.path = pathfinding.findPath(e.x, e.y, px, py, map)
                e.pathTimer = 0.5 
            end
            if e.path and #e.path > 0 then
                while #e.path > 1 and enemyModule.hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do table.remove(e.path, 1) end
                if #e.path > 0 then
                    local mx, my = e.path[1].x, e.path[1].y
                    local ddx, ddy = mx - e.x, my - e.y
                    local ddist = math.sqrt(ddx*ddx + ddy*ddy)
                    if ddist > 0 then
                        if not hasSight and e.warpCooldown <= 0 and e.attackState == "none" then
                            e.attackState = "warping"
                            e.attackTimer = cfg.warpDuration
                            e.attackDirX, e.attackDirY = ddx/ddist, ddy/ddist
                        else
                            local nx, ny = e.x + (ddx/ddist)*e.speed*dt, e.y + (ddy/ddist)*e.speed*dt
                            if not enemyModule.isCircleColliding(nx, ny, radius, map) then e.x, e.y = nx, ny end
                        end
                    end
                end
            end
        elseif hasSight and dist >= cfg.fleeRange and dist <= cfg.castRange then
            e.strafeTimer = (e.strafeTimer or 0) - dt
            if e.strafeTimer <= 0 then
                e.strafeDir = (love.math.random() > 0.5 and 1 or -1)
                e.strafeTimer = love.math.random() * 1.5 + 0.5
            end
            local angle = math.atan2(dy, dx) + (math.pi/2 * e.strafeDir)
            local moveX = math.cos(angle)*(e.speed*0.6*moveMult)*dt
            local moveY = math.sin(angle)*(e.speed*0.6*moveMult)*dt
            local nx, ny = e.x + moveX, e.y + moveY
            if not enemyModule.isCircleColliding(nx, ny, radius, map) then
                e.x, e.y = nx, ny
            else
                e.strafeDir = -e.strafeDir
            end
        end
    end

    -- State Machine: Casting / Bursting / Warping
    if e.attackState == "none" and e.attackCooldown <= 0 and dist < cfg.castRange and hasSight and e.aggro then
        e.attackState = "winding"
        e.attackTimer = cfg.castWindup
        local angle = math.atan2(dy, dx)
        e.attackDirX, e.attackDirY = math.cos(angle), math.sin(angle)
    
    elseif e.attackState == "winding" then
        e.attackTimer = e.attackTimer - dt
        local angle = math.atan2(dy, dx)
        e.attackDirX, e.attackDirY = math.cos(angle), math.sin(angle) 
        if e.attackTimer <= 0 then
            e.attackState = "bursting"
            e.burstsRemaining = cfg.burstCount
            e.burstTimer = 0
        end

    elseif e.attackState == "bursting" then
        e.burstTimer = e.burstTimer - dt
        if e.burstTimer <= 0 and e.burstsRemaining > 0 then
            local baseAngle = math.atan2(dy, dx)
            local spread = (love.math.random() - 0.5) * cfg.spreadAngle
            local ax, ay = math.cos(baseAngle + spread), math.sin(baseAngle + spread)
            if _G.game and _G.game.spawnEnemyProjectile then
                _G.game.spawnEnemyProjectile(e.x, e.y, ax, ay, {
                    speed = cfg.projSpeed,
                    homing = cfg.homingStrength,
                    color = cfg.color,
                    damage = cfg.damagePerHit
                })
            end
            e.burstsRemaining = e.burstsRemaining - 1
            e.burstTimer = cfg.burstInterval
            if e.burstsRemaining <= 0 then
                e.attackState = "none"
                e.attackCooldown = cfg.castCooldown
            end
        end

    elseif e.attackState == "warping" then
        e.attackTimer = e.attackTimer - dt
        local nx, ny = e.x + e.attackDirX*cfg.warpSpeed*dt, e.y + e.attackDirY*cfg.warpSpeed*dt
        
        -- Radius-aware warp movement for Elite
        if not enemyModule.isCircleColliding(nx, ny, radius, map) then
            e.x, e.y = nx, ny
            if love.math.random() > 0.5 then enemyModule.addParticle(e.x, e.y, cfg.color) end
        else 
            -- Try sliding even during warp
            if not enemyModule.isCircleColliding(nx, e.y, radius, map) then e.x = nx
            elseif not enemyModule.isCircleColliding(e.x, ny, radius, map) then e.y = ny
            else e.attackTimer = 0 end
        end
        
        if e.attackTimer <= 0 then e.attackState = "none" e.warpCooldown = cfg.warpCooldown end
    end
end

function elite.draw(e)
    local cfg = elite.config
    local cx, cy = e.x, e.y

    if e.hitFlash > 0 then 
        love.graphics.setColor(1, 1, 1, 1)
    elseif e.attackState == "winding" then
        local pulse = (math.sin(love.timer.getTime() * 25) + 1) / 2
        love.graphics.setColor(1, 1, 1, 0.6 + pulse * 0.4)
    elseif e.attackState == "bursting" then
        love.graphics.setColor(1, 1, 1, 1)
    elseif e.attackState == "warping" then
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.3)
    elseif e.aggro then 
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
    else 
        love.graphics.setColor(0.5, 0.4, 0.2, 1) -- Golden idle
    end

    -- Draw body (slightly more complex for elite)
    love.graphics.circle("fill", cx, cy, e.size/2)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", cx, cy, e.size/2 + 2)

    if e.attackState == "winding" then
        local p = 1 - (e.attackTimer / cfg.castWindup)
        love.graphics.setLineWidth(3)
        love.graphics.setColor(cfg.color[1], cfg.color[2], cfg.color[3], 0.8)
        love.graphics.circle("line", cx, cy, p * (e.size * 1.5))
    end
end

function elite.globalDraw(player, enemyModule)
    if _G.game and _G.game.getLevelType and _G.game.getLevelType() ~= "dungeon" then return end
    for _, e in ipairs(enemyModule.list) do
        if e.type == "elite_ranged" and e.path and #e.path > 0 then
            love.graphics.setColor(1, 0.8, 0, 0.3)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do love.graphics.line(lx, ly, p.x, p.y) lx, ly = p.x, p.y end
        end
    end
end

return elite
