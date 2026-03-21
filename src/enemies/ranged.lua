local pathfinding = require("src.gameplay.pathfinding")

--[[
============================================================================
ENEMY TYPE: RANGED (The "Skirmisher")
============================================================================
Design Intent: Hit-and-run harassment. This enemy type prioritizes maintaining 
safe distance. It fires single projectiles and uses a "Warp Dash" to quickly 
reposition or retreat when pressured. It forces the player to manage 
projectiles while trying to close the distance on a slippery target.
============================================================================
]]

local ranged = {}

ranged.config = {
    -- Stats
    displayName = "Skirmisher",
    maxHp = 70,
    level = 1,
    speed = 160,
    size = 18,
    color = {0.6, 0.2, 1.0},
    
    -- Damage
    damagePerHit = 0.5,
    
    -- UI
    hpBarOffset = -20,
    
    -- Ranged Attack Logic
    castRange = 200,
    fleeRange = 100,
    castWindup = 0.8,
    castCooldown = 2.0,
    
    -- Warp/Dash Logic
    warpSpeed = 600,
    warpDuration = 0.2,
    warpCooldown = 1.0,

    -- Projectile
    projSpeed = 400,

    -- Perception
    perceptionRadius = 260,
    groupAggroRadius = 350,

    -- Rewards
    soulDropRate = 0.65,
    soulMinDrop = 3,
    soulMaxDrop = 5,

    -- Spawning & CR
    challengeRating = 2,
    spawnWeight = 4,

    -- Roaming
    roamSpeed = 60,
    roamWaitMin = 3,
    roamWaitMax = 7,
    roamRadius = 200,

    -- Visuals
    hitFlashDuration = 0.15,
    deathParticleCount = 10,
    deathParticleSpeed = 120,
    deathParticleLife = 0.4,
}

function ranged.init()
    ranged.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
    ranged.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")
end

function ranged.create(e)
    local cfg = ranged.config
    e.hp, e.maxHp = cfg.maxHp, cfg.maxHp
    e.size = cfg.size
    e.speed = cfg.speed
    e.color = cfg.color
    e.hpBarOffset = cfg.hpBarOffset
    e.displayName = cfg.displayName
    e.level = cfg.level
    
    e.attackState = "none"
    e.attackTimer = 0
    e.attackCooldown = 0
    e.attackDirX, e.attackDirY = 0, 0
    e.warpCooldown = 0
end

-- ============================================================================
-- MOVEMENT & BEHAVIOR HELPERS
-- ============================================================================

local function executeEmergencyWarp(e, dx, dy, enemyModule, map)
    local cfg = ranged.config
    local radius = e.size / 2
    
    e.attackState = "warping"
    e.attackTimer = cfg.warpDuration
    
    -- Smarter Escape Angle Scan (Try multiple distances)
    local bestAngle = nil
    local baseAngle = math.atan2(dy, dx) -- Face-to-player angle
    
    local scanDistances = {80, 50, 30}
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
end

local function checkEmergencyEscape(e, dt, dist, dx, dy, enemyModule, map)
    local cfg = ranged.config
    local radius = e.size / 2
    local isTrapped = false
    local isClipping = enemyModule.isCircleColliding(e.x, e.y, radius, map)
    
    -- Check for traps if we are too close OR just trying to move and blocked
    if dist < cfg.fleeRange or isClipping or (e.path and #e.path > 0) then
        local angle = math.atan2(dy, dx)
        local moveMult = (e.attackState == "winding") and 0.4 or 1.0
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

    if isClipping and (e.warpCooldown or 0) <= 0 then 
        isTrapped = true 
    end

    if isTrapped and (e.warpCooldown or 0) <= 0 and e.attackState ~= "warping" then
        executeEmergencyWarp(e, dx, dy, enemyModule, map)
        return true
    end
    
    return false
end

local function handleFleeing(e, dt, dx, dy, enemyModule, map, moveMult)
    local angle = math.atan2(dy, dx)
    local moveX = -math.cos(angle) * e.speed * moveMult * dt
    local moveY = -math.sin(angle) * e.speed * moveMult * dt
    local nx, ny = e.x + moveX, e.y + moveY
    local radius = e.size / 2
    
    if not enemyModule.isCircleColliding(nx, ny, radius, map) then
        e.x, e.y = nx, ny
    else
        if not enemyModule.isCircleColliding(e.x + moveX, e.y, radius, map) then e.x = e.x + moveX
        elseif not enemyModule.isCircleColliding(e.x, e.y + moveY, radius, map) then e.y = e.y + moveY
        end
    end
end

local function handleSeeking(e, dt, px, py, hasSight, enemyModule, map)
    e.pathTimer = e.pathTimer - dt
    if not e.path or e.pathTimer <= 0 then
        e.path = pathfinding.findPath(e.x, e.y, px, py, map)
        e.pathTimer = 0.5 
    end
    
    if e.path and #e.path > 0 then
        while #e.path > 1 and enemyModule.hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do 
            table.remove(e.path, 1) 
        end
        if math.sqrt((e.path[1].x-e.x)^2 + (e.path[1].y-e.y)^2) < 15 then 
            table.remove(e.path, 1) 
        end
        
        if #e.path > 0 then
            local mx, my = e.path[1].x, e.path[1].y
            local ddx, ddy = mx - e.x, my - e.y
            local ddist = math.sqrt(ddx*ddx + ddy*ddy)
            
            if ddist > 0 then
                local cfg = ranged.config
                -- Warp Dash if cooldown is up and no LOS (only if not winding)
                if not hasSight and e.warpCooldown <= 0 and e.attackState == "none" then
                    e.attackState = "warping"
                    e.attackTimer = cfg.warpDuration
                    e.attackDirX = ddx / ddist
                    e.attackDirY = ddy / ddist
                else
                    local nx = e.x + (ddx/ddist) * e.speed * dt
                    local ny = e.y + (ddy/ddist) * e.speed * dt
                    local radius = e.size / 2
                    
                    if not enemyModule.isCircleColliding(nx, ny, radius, map) then
                        e.x, e.y = nx, ny
                    else
                        local nx1, ny1 = nx, e.y
                        local nx2, ny2 = e.x, ny
                        if not enemyModule.isCircleColliding(nx1, ny1, radius, map) then e.x, e.y = nx1, ny1
                        elseif not enemyModule.isCircleColliding(nx2, ny2, radius, map) then e.x, e.y = nx2, ny2
                        end
                    end
                end
            end
        end
    end
end

local function handleStrafing(e, dt, dx, dy, enemyModule, map, moveMult)
    e.strafeTimer = (e.strafeTimer or 0) - dt
    if e.strafeTimer <= 0 then
        e.strafeDir = (love.math.random() > 0.5 and 1 or -1)
        e.strafeTimer = love.math.random() * 1.0 + 0.5
    end
    
    local angle = math.atan2(dy, dx) + (math.pi/2 * e.strafeDir)
    local moveX = math.cos(angle) * (e.speed * 0.5 * moveMult) * dt
    local moveY = math.sin(angle) * (e.speed * 0.5 * moveMult) * dt
    local nx, ny = e.x + moveX, e.y + moveY
    local radius = e.size / 2
    
    if not enemyModule.isCircleColliding(nx, ny, radius, map) then
        e.x, e.y = nx, ny
    else
        if not enemyModule.isCircleColliding(e.x + moveX, e.y, radius, map) then e.x = e.x + moveX
        elseif not enemyModule.isCircleColliding(e.x, e.y + moveY, radius, map) then e.y = e.y + moveY
        else e.strafeDir = -e.strafeDir end
    end
end

local function handleStandardAI(e, dt, dist, dx, dy, px, py, hasSight, moveMult, enemyModule, map)
    local cfg = ranged.config
    
    if dist < cfg.fleeRange then
        handleFleeing(e, dt, dx, dy, enemyModule, map, moveMult)
    elseif dist > cfg.castRange or not hasSight then
        handleSeeking(e, dt, px, py, hasSight, enemyModule, map)
    elseif hasSight and dist >= cfg.fleeRange and dist <= cfg.castRange then
        handleStrafing(e, dt, dx, dy, enemyModule, map, moveMult)
    end
end

local function handleCastingAndWarping(e, dt, dist, dx, dy, hasSight, enemyModule, map)
    local cfg = ranged.config
    local radius = e.size / 2
    
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
            e.attackState = "none"
            e.attackCooldown = cfg.castCooldown
            if _G.game and _G.game.spawnEnemyProjectile then
                _G.game.spawnEnemyProjectile(e.x, e.y, e.attackDirX, e.attackDirY, {
                    speed = cfg.projSpeed,
                    color = cfg.color,
                    damage = cfg.damagePerHit
                })
            end
        end
        
    elseif e.attackState == "warping" then
        e.attackTimer = e.attackTimer - dt
        local nx = e.x + e.attackDirX * cfg.warpSpeed * dt
        local ny = e.y + e.attackDirY * cfg.warpSpeed * dt
        
        if not enemyModule.isCircleColliding(nx, ny, radius, map) then
            e.x, e.y = nx, ny
            if love.math.random() > 0.5 then
                enemyModule.addParticle(e.x, e.y, cfg.color)
            end
        else
            if not enemyModule.isCircleColliding(nx, e.y, radius, map) then e.x = nx
            elseif not enemyModule.isCircleColliding(e.x, ny, radius, map) then e.y = ny
            else e.attackTimer = 0 end
        end
        
        if e.attackTimer <= 0 then
            e.attackState = "none"
            e.warpCooldown = cfg.warpCooldown
        end
    end
end

-- ============================================================================
-- MAIN UPDATE
-- ============================================================================

function ranged.update(e, dt, player, enemyModule, map)
    local px, py = player.x + player.size/2, player.y + player.size/2
    local dx, dy = px - e.x, py - e.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if e.attackCooldown > 0 then e.attackCooldown = e.attackCooldown - dt end
    if e.warpCooldown and e.warpCooldown > 0 then e.warpCooldown = e.warpCooldown - dt end

    local hasSight = enemyModule.hasLOS(e.x, e.y, px, py, map)
    
    -- 1. High Priority: Emergency Escape
    if checkEmergencyEscape(e, dt, dist, dx, dy, enemyModule, map) then
        -- Skip standard AI if we just triggered emergency warp
        return
    end

    -- 2. Standard AI States
    if (e.attackState == "none" or e.attackState == "winding") and e.aggro then
        local moveMult = (e.attackState == "winding") and 0.4 or 1.0
        handleStandardAI(e, dt, dist, dx, dy, px, py, hasSight, moveMult, enemyModule, map)
    end
    
    -- 3. Casting / Warping Execution
    handleCastingAndWarping(e, dt, dist, dx, dy, hasSight, enemyModule, map)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

function ranged.draw(e)
    local cfg = ranged.config
    local cx, cy = e.x, e.y

    if e.hitFlash > 0 then 
        love.graphics.setColor(1, 1, 1, 1) -- White flash when hit
    elseif e.attackState == "winding" then
        local pulse = (math.sin(love.timer.getTime() * 20) + 1) / 2
        love.graphics.setColor(1, 1, 1, 0.5 + pulse * 0.5)
    elseif e.attackState == "warping" then
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.3)
    elseif e.aggro then 
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
    else 
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
    end

    love.graphics.circle("fill", cx, cy, e.size/2)

    if e.attackState == "winding" then
        local p = 1 - (e.attackTimer / cfg.castWindup)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.6)
        love.graphics.circle("line", cx + e.attackDirX * e.size, cy + e.attackDirY * e.size, p * 15)
    end
end

function ranged.globalDraw(player, enemyModule)
    if _G.game and _G.game.getLevelType and _G.game.getLevelType() ~= "dungeon" then return end

    for _, e in ipairs(enemyModule.list) do
        if e.type == "ranged" and e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 1, 0.2)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do 
                love.graphics.line(lx, ly, p.x, p.y) 
                lx, ly = p.x, p.y 
            end
        end
    end
end

return ranged
