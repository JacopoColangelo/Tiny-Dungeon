local pathfinding = require("src.pathfinding")

local ranged = {}

ranged.config = {
    maxHp = 70,
    speed = 160,             -- Base Speed
    size = 18,               -- Size
    color = {0.6, 0.2, 1.0}, -- Color
    
    -- Ranged Attack Logic
    castRange = 200,         -- Firing range
    fleeRange = 100,         -- Range at which they run away
    castWindup = 0.8,        -- Time standing still before firing
    castCooldown = 2.0,      -- Time between shots
    
    -- Warp/Dash Logic for seeking
    warpSpeed = 600,
    warpDuration = 0.2,
    warpCooldown = 1.0,
}

function ranged.create(e)
    local cfg = ranged.config
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
    
    if e.attackState == "none" and e.aggro then
        -- Fleeing
        if dist < cfg.fleeRange then
            local angle = math.atan2(dy, dx)
            local nx = e.x - math.cos(angle) * e.speed * dt
            local ny = e.y - math.sin(angle) * e.speed * dt
            if not enemyModule.isPointInWall(nx, ny, map) then
                e.x, e.y = nx, ny
            else
                local nx1 = e.x - math.cos(angle + 1.2) * e.speed * dt
                local ny1 = e.y - math.sin(angle + 1.2) * e.speed * dt
                if not enemyModule.isPointInWall(nx1, ny1, map) then
                    e.x, e.y = nx1, ny1
                else
                    local nx2 = e.x - math.cos(angle - 1.2) * e.speed * dt
                    local ny2 = e.y - math.sin(angle - 1.2) * e.speed * dt
                    if not enemyModule.isPointInWall(nx2, ny2, map) then e.x, e.y = nx2, ny2 end
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
                        -- Warp Dash if cooldown is up and no LOS
                        if not hasSight and e.warpCooldown <= 0 then
                            e.attackState = "warping"
                            e.attackTimer = cfg.warpDuration
                            e.attackDirX = ddx / ddist
                            e.attackDirY = ddy / ddist
                        else
                            local nx = e.x + (ddx/ddist) * e.speed * dt
                            local ny = e.y + (ddy/ddist) * e.speed * dt
                            if not enemyModule.isPointInWall(nx, ny, map) then
                                e.x = nx
                                e.y = ny
                            else
                                -- Try sliding
                                local nx1, ny1 = nx, e.y
                                local nx2, ny2 = e.x, ny
                                if not enemyModule.isPointInWall(nx1, ny1, map) then e.x, e.y = nx1, ny1
                                elseif not enemyModule.isPointInWall(nx2, ny2, map) then e.x, e.y = nx2, ny2
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
            local nx = e.x + math.cos(angle) * (e.speed * 0.5) * dt
            local ny = e.y + math.sin(angle) * (e.speed * 0.5) * dt
            if not enemyModule.isPointInWall(nx, ny, map) then
                e.x, e.y = nx, ny
            else
                e.strafeDir = -e.strafeDir
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
                _G.game.spawnEnemyProjectile(e.x, e.y, e.attackDirX, e.attackDirY)
            end
        end
    elseif e.attackState == "warping" then
        e.attackTimer = e.attackTimer - dt
        
        local nx = e.x + e.attackDirX * cfg.warpSpeed * dt
        local ny = e.y + e.attackDirY * cfg.warpSpeed * dt
        
        if not enemyModule.isPointInWall(nx, ny, map) then
            e.x, e.y = nx, ny
            
            -- Spawn warp trail particles
            if love.math.random() > 0.5 then
                enemyModule.addParticle(e.x, e.y, cfg.color)
            end
        else
            e.attackTimer = 0 -- Stop warp on wall
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

return ranged
