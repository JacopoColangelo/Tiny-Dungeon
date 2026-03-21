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
    displayName = "Skirmisher", -- Display Name
    maxHp = 70,                 -- Health
    level = 1,                  -- Starting Level
    speed = 160,                -- Speed
    size = 18,                  -- Size
    color = {0.6, 0.2, 1.0},    -- Color = Purple
    
    -- Damage
    damagePerHit = 0.5,         -- Damage dealt per projectile
    
    -- UI
    hpBarOffset = -20,          -- Offset for the HP bar (less = higher)
    
    -- Ranged Attack Logic
    castRange = 200,            -- Firing range
    fleeRange = 100,            -- Range at which they run away
    castWindup = 0.8,           -- Time standing still before firing
    castCooldown = 2.0,         -- Time between shots
    
    -- Warp/Dash Logic
    warpSpeed = 600,            -- Speed of the warp
    warpDuration = 0.2,         -- Duration of the warp
    warpCooldown = 1.0,         -- Time between warps

    -- Projectile
    projSpeed = 400,            -- Speed of the projectile

    -- Perception
    perceptionRadius = 260,     -- Radius to detect the player
    groupAggroRadius = 350,     -- Radius to alert other enemies

    -- Rewards
    soulDropRate = 0.65,        -- Probability to drop souls
    soulMinDrop = 3,            -- Minimum number of souls to drop
    soulMaxDrop = 5,            -- Maximum number of souls to drop

    -- Spawning & CR
    challengeRating = 2,        -- CR cost
    spawnWeight = 4,            -- Relative spawn frequency

    -- Roaming
    roamSpeed = 60,             -- Speed when roaming
    roamWaitMin = 3,            -- Min wait time at a spot
    roamWaitMax = 7,            -- Max wait time at a spot
    roamRadius = 200,           -- How far it can roam from spawn/current spot

    -- Visuals (Decentralized from enemy.lua)
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
end

function ranged.update(e, dt, player, enemyModule, map)
    local cfg = ranged.config
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
    -- HIGH PRIORITY: EMERGENCY ESCAPE & CLIPPING RESET
    -- ========================================================================
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

    -- Emergency reset if clipped 
    if isClipping and (e.warpCooldown or 0) <= 0 then isTrapped = true end

    if isTrapped and (e.warpCooldown or 0) <= 0 and e.attackState ~= "warping" then
        -- Trigger EMERGENCY WARP (Cancels everything else)
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
        return -- Skip standard AI for this frame
    end

    -- ========================================================================
    -- STANDARD AI STATES
    -- ========================================================================
    if (e.attackState == "none" or e.attackState == "winding") and e.aggro then
        -- Allow slight movement even during windup
        local moveMult = (e.attackState == "winding") and 0.4 or 1.0
        
        -- Fleeing
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
        -- Seeking (no LOS or out of range)
        elseif dist > cfg.castRange or not hasSight then
            e.pathTimer = e.pathTimer - dt
            if not e.path or e.pathTimer <= 0 then
                e.path = pathfinding.findPath(e.x, e.y, px, py, map)
                e.pathTimer = 0.5 
            end
            if e.path and #e.path > 0 then
                while #e.path > 1 and enemyModule.hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do table.remove(e.path, 1) end
                if math.sqrt((e.path[1].x-e.x)^2 + (e.path[1].y-e.y)^2) < 15 then table.remove(e.path, 1) end
                
                if #e.path > 0 then
                    local mx, my = e.path[1].x, e.path[1].y
                    local ddx, ddy = mx - e.x, my - e.y
                    local ddist = math.sqrt(ddx*ddx + ddy*ddy)
                    
                    if ddist > 0 then
                        -- Warp Dash if cooldown is up and no LOS (only if not winding)
                        if not hasSight and e.warpCooldown <= 0 and e.attackState == "none" then
                            e.attackState = "warping"
                            e.attackTimer = cfg.warpDuration
                            e.attackDirX = ddx / ddist
                            e.attackDirY = ddy / ddist
                        else
                            local nx = e.x + (ddx/ddist) * e.speed * dt
                            local ny = e.y + (ddy/ddist) * e.speed * dt
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
        -- Strafing (has LOS and in nice range)
        elseif hasSight and dist >= cfg.fleeRange and dist <= cfg.castRange then
            e.strafeTimer = (e.strafeTimer or 0) - dt
            if e.strafeTimer <= 0 then
                e.strafeDir = (love.math.random() > 0.5 and 1 or -1)
                e.strafeTimer = love.math.random() * 1.0 + 0.5
            end
            local angle = math.atan2(dy, dx) + (math.pi/2 * e.strafeDir)
            local moveX = math.cos(angle) * (e.speed * 0.5 * moveMult) * dt
            local moveY = math.sin(angle) * (e.speed * 0.5 * moveMult) * dt
            local nx, ny = e.x + moveX, e.y + moveY
            if not enemyModule.isCircleColliding(nx, ny, radius, map) then
                e.x, e.y = nx, ny
            else
                if not enemyModule.isCircleColliding(e.x + moveX, e.y, radius, map) then e.x = e.x + moveX
                elseif not enemyModule.isCircleColliding(e.x, e.y + moveY, radius, map) then e.y = e.y + moveY
                else e.strafeDir = -e.strafeDir end
            end
        end
    end
    
    -- Casting / Warping Execution
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
        
        -- Radius-aware warp movement
        if not enemyModule.isCircleColliding(nx, ny, radius, map) then
            e.x, e.y = nx, ny
            if love.math.random() > 0.5 then
                enemyModule.addParticle(e.x, e.y, cfg.color)
            end
        else
            -- Axis sliding even during warp to prevent sudden stops on slight corner snags
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

function ranged.draw(e)
    local cfg = ranged.config
    local cx, cy = e.x, e.y

    if e.hitFlash > 0 then 
        love.graphics.setColor(1, 1, 1, 1) -- White flash when hit
    elseif e.attackState == "winding" then
        -- Pulsing white for ranged casting
        local pulse = (math.sin(love.timer.getTime() * 20) + 1) / 2
        love.graphics.setColor(1, 1, 1, 0.5 + pulse * 0.5)
    elseif e.attackState == "warping" then
        -- Faded and stretched during warp dash
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.3)
    elseif e.aggro then 
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
    else 
        love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Dull grey when idle
    end

    love.graphics.circle("fill", cx, cy, e.size/2)

    if e.attackState == "winding" then
        local p = 1 - (e.attackTimer / cfg.castWindup)
        love.graphics.setLineWidth(2)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], 0.6)
        -- Draw a growing circle to indicate casting
        love.graphics.circle("line", cx + e.attackDirX * (e.size), cy + e.attackDirY * (e.size), p * 15)
    end
end

function ranged.globalDraw(player, enemyModule)
    -- Only draw debug info in the dungeon
    if _G.game and _G.game.getLevelType and _G.game.getLevelType() ~= "dungeon" then return end

    -- Draw paths for ranged enemies
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
