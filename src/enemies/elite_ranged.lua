local pathfinding = require("src.gameplay.pathfinding")
local projectile = require("src.gameplay.projectile")

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
    displayName = "Sentinel",
    maxHp = 180,
    level = 1,
    speed = 130,
    size = 24,
    color = {1.0, 0.8, 0.1},
    
    -- Damage
    damagePerHit = 0.8,
    
    -- UI
    hpBarOffset = -30,

    -- Ranged Attack Logic
    castRange = 250,
    fleeRange = 120,
    castWindup = 1.2,
    castCooldown = 3.0,

    -- Burst Stats
    burstCount = 3,
    burstInterval = 0.15,
    spreadAngle = 0.25,
    homingStrength = 1.2,
    projSpeed = 300,

    -- Warp/Dash Logic
    warpSpeed = 700,
    warpDuration = 0.25,
    warpCooldown = 0.8,

    -- Perception
    perceptionRadius = 320,
    groupAggroRadius = 400,

    -- Rewards
    soulDropRate = 0.95,
    soulMinDrop = 8,
    soulMaxDrop = 15,

    -- Spawning & CR
    challengeRating = 4,
    spawnWeight = 2,

    -- Roaming
    roamSpeed = 30,
    roamWaitMin = 4,
    roamWaitMax = 10,
    roamRadius = 300,

    -- Visuals
    hitFlashDuration = 0.2,
    deathParticleCount = 20,
    deathParticleSpeed = 180,
    deathParticleLife = 0.6,
}

function elite.init()
    elite.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
    elite.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")
end

function elite.create(e)
    local cfg = elite.config
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
    e.burstTimer = 0
    e.burstsRemaining = 0
end

-- ============================================================================
-- MOVEMENT & BEHAVIOR HELPERS
-- ============================================================================

local function executeEmergencyWarp(e, dx, dy, enemyModule, map)
    local cfg = elite.config
    local radius = e.size / 2
    
    e.attackState = "warping"
    e.attackTimer = cfg.warpDuration
    
    local bestAngle = nil
    local baseAngle = math.atan2(dy, dx)
    
    local scanDistances = {100, 70, 40}
    for _, sDist in ipairs(scanDistances) do
        for i = 1, 8 do
            local testAngle = baseAngle + math.pi + (i-4.5) * (math.pi/4)
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
    local cfg = elite.config
    local radius = e.size / 2
    local isTrapped = false
    local isClipping = enemyModule.isCircleColliding(e.x, e.y, radius, map)
    
    if dist < cfg.fleeRange or isClipping or (e.path and #e.path > 0) then
        local angle = math.atan2(dy, dx)
        local moveMult = (e.attackState ~= "none") and 0.5 or 1.0
        local moveX = -math.cos(angle) * e.speed * dt * moveMult
        local moveY = -math.sin(angle) * e.speed * dt * moveMult
        
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
        
        if #e.path > 0 then
            local mx, my = e.path[1].x, e.path[1].y
            local ddx, ddy = mx - e.x, my - e.y
            local ddist = math.sqrt(ddx*ddx + ddy*ddy)
            
            if ddist > 0 then
                local cfg = elite.config
                if not hasSight and e.warpCooldown <= 0 and e.attackState == "none" then
                    e.attackState = "warping"
                    e.attackTimer = cfg.warpDuration
                    e.attackDirX, e.attackDirY = ddx/ddist, ddy/ddist
                else
                    local nx = e.x + (ddx/ddist) * e.speed * dt
                    local ny = e.y + (ddy/ddist) * e.speed * dt
                    local radius = e.size / 2
                    if not enemyModule.isCircleColliding(nx, ny, radius, map) then 
                        e.x, e.y = nx, ny 
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
        e.strafeTimer = love.math.random() * 1.5 + 0.5
    end
    
    local angle = math.atan2(dy, dx) + (math.pi/2 * e.strafeDir)
    local moveX = math.cos(angle) * (e.speed * 0.6 * moveMult) * dt
    local moveY = math.sin(angle) * (e.speed * 0.6 * moveMult) * dt
    local nx, ny = e.x + moveX, e.y + moveY
    local radius = e.size / 2
    
    if not enemyModule.isCircleColliding(nx, ny, radius, map) then
        e.x, e.y = nx, ny
    else
        e.strafeDir = -e.strafeDir
    end
end

local function handleStandardAI(e, dt, dist, dx, dy, px, py, hasSight, moveMult, enemyModule, map)
    local cfg = elite.config
    
    if dist < cfg.fleeRange then
        handleFleeing(e, dt, dx, dy, enemyModule, map, moveMult)
    elseif dist > cfg.castRange or not hasSight then
        handleSeeking(e, dt, px, py, hasSight, enemyModule, map)
    elseif hasSight and dist >= cfg.fleeRange and dist <= cfg.castRange then
        handleStrafing(e, dt, dx, dy, enemyModule, map, moveMult)
    end
end

local function handleAttackingAndWarping(e, dt, dist, dx, dy, hasSight, enemyModule, map)
    local cfg = elite.config
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
            
            projectile.spawn(e.x, e.y, ax, ay, {
                speed = cfg.projSpeed,
                homing = cfg.homingStrength,
                color = cfg.color,
                damage = cfg.damagePerHit
            })
            
            e.burstsRemaining = e.burstsRemaining - 1
            e.burstTimer = cfg.burstInterval
            
            if e.burstsRemaining <= 0 then
                e.attackState = "none"
                e.attackCooldown = cfg.castCooldown
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

function elite.update(e, dt, player, enemyModule, map)
    local px, py = player.x + player.size/2, player.y + player.size/2
    local dx, dy = px - e.x, py - e.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if e.attackCooldown > 0 then e.attackCooldown = e.attackCooldown - dt end
    if e.warpCooldown and e.warpCooldown > 0 then e.warpCooldown = e.warpCooldown - dt end

    local hasSight = enemyModule.hasLOS(e.x, e.y, px, py, map)
    
    -- 1. High Priority: Emergency Escape
    if checkEmergencyEscape(e, dt, dist, dx, dy, enemyModule, map) then
        return -- Skip standard AI this frame
    end

    -- 2. Standard AI States
    local isValidAIState = (e.attackState == "none" or e.attackState == "winding" or e.attackState == "bursting")
    if isValidAIState and e.aggro then
        local moveMult = (e.attackState ~= "none") and 0.5 or 1.0
        handleStandardAI(e, dt, dist, dx, dy, px, py, hasSight, moveMult, enemyModule, map)
    end
    
    -- 3. Casting / Bursting / Warping Execution
    handleAttackingAndWarping(e, dt, dist, dx, dy, hasSight, enemyModule, map)
end

-- ============================================================================
-- RENDERING
-- ============================================================================

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

    -- Draw body
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

function elite.globalDraw(player, enemyModule, levelType)
    if levelType ~= "dungeon" then return end
    
    for _, e in ipairs(enemyModule.list) do
        if e.type == "elite_ranged" and e.path and #e.path > 0 then
            love.graphics.setColor(1, 0.8, 0, 0.3)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do 
                love.graphics.line(lx, ly, p.x, p.y) 
                lx, ly = p.x, p.y 
            end
        end
    end
end

return elite
