local map = require("src.dungeons.map")
local shadows = require("src.lighting.shadows")
local camera = require("src.gameplay.camera")

local projectile = {}

projectile.list = {}
projectile.pool = {}
projectile.trailPool = {}

local function acquireProjectile()
    local n = #projectile.pool
    if n > 0 then
        local p = projectile.pool[n]
        projectile.pool[n] = nil
        return p
    end
    return { particles = {} }
end

local function releaseTrailParticle(part)
    projectile.trailPool[#projectile.trailPool + 1] = part
end

local function acquireTrailParticle()
    local n = #projectile.trailPool
    if n > 0 then
        local part = projectile.trailPool[n]
        projectile.trailPool[n] = nil
        return part
    end
    return {}
end

local function releaseProjectile(p)
    -- Return all trail particles to their pool first.
    for i = #p.particles, 1, -1 do
        releaseTrailParticle(p.particles[i])
        p.particles[i] = nil
    end
    p.color = nil
    projectile.pool[#projectile.pool + 1] = p
end

function projectile.init()
    for i = #projectile.list, 1, -1 do
        releaseProjectile(projectile.list[i])
    end
    projectile.list = {}
end

function projectile.spawn(x, y, dirX, dirY, options)
    options = options or {}
    local speed = options.speed or 250
    local p = acquireProjectile()
    p.x = x
    p.y = y
    p.vx = dirX * speed
    p.vy = dirY * speed
    p.speed = speed
    p.homing = options.homing or 0 -- 0 = no homing, > 0 = steering force strength
    p.size = options.size or 8
    p.damage = options.damage or 0.5
    p.color = options.color or {0.6, 0.2, 1.0}
    p.life = options.life or 3.0
    p.particleTimer = 0
    table.insert(projectile.list, p)
end

local function isPointInWall(x, y, currentMap)
    local tx = math.floor(x / currentMap.gridSize) + 1
    local ty = math.floor(y / currentMap.gridSize) + 1
    if tx < 1 or tx > currentMap.width or ty < 1 or ty > currentMap.height then return true end
    return currentMap.data[ty][tx] == 1
end

function projectile.update(dt, player, currentMap)
    local px, py = player.x + player.size/2, player.y + player.size/2
    
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        p.life = p.life - dt
        
        -- Homing Logic (Steering)
        if p.homing > 0 then
            local dx, dy = px - p.x, py - p.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 10 then
                -- Desired velocity at current speed
                local targetVx = (dx / dist) * p.speed
                local targetVy = (dy / dist) * p.speed
                
                -- Steer current velocity towards target velocity
                p.vx = p.vx + (targetVx - p.vx) * p.homing * dt
                p.vy = p.vy + (targetVy - p.vy) * p.homing * dt
                
                -- Normalize and re-apply speed to maintain constant velocity magnitude
                local currentV = math.sqrt(p.vx*p.vx + p.vy*p.vy)
                if currentV > 0 then
                    p.vx = (p.vx / currentV) * p.speed
                    p.vy = (p.vy / currentV) * p.speed
                end
            end
        end

        -- Spawn trail particles
        p.particleTimer = p.particleTimer - dt
        if p.particleTimer <= 0 then
            local part = acquireTrailParticle()
            part.x = p.x + (math.random() * 4 - 2)
            part.y = p.y + (math.random() * 4 - 2)
            part.life = 0.3
            part.maxLife = 0.3
            part.size = p.size * 0.5
            p.particles[#p.particles + 1] = part
            p.particleTimer = 0.05
        end

        for j = #p.particles, 1, -1 do
            local part = p.particles[j]
            part.life = part.life - dt
            if part.life <= 0 then
                releaseTrailParticle(part)
                table.remove(p.particles, j)
            end
        end

        local nx = p.x + p.vx * dt
        local ny = p.y + p.vy * dt

        local hitWall = isPointInWall(nx, ny, currentMap)
        
        local dPlayerX = nx - px
        local dPlayerY = ny - py
        local distSq = dPlayerX*dPlayerX + dPlayerY*dPlayerY
        local hitPlayer = distSq < ((p.size + player.size)/2)^2

        if hitPlayer then
            player.hp = player.hp - p.damage
            if camera and camera.addShake then camera.addShake(8, 0.1) end
            releaseProjectile(p)
            table.remove(projectile.list, i)
        elseif hitWall or p.life <= 0 then
            releaseProjectile(p)
            table.remove(projectile.list, i)
        else
            p.x, p.y = nx, ny
        end
    end
end

function projectile.draw()
    for _, p in ipairs(projectile.list) do
        -- Trail
        for _, part in ipairs(p.particles) do
            local alpha = part.life / part.maxLife
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.6)
            love.graphics.circle("fill", part.x, part.y, part.size)
        end

        -- Core additive glow
        love.graphics.setBlendMode("add")
        for j = 5, 1, -1 do
            local r, a = p.size + j * 2, (1 - (j / 5)) * 0.3
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
            love.graphics.circle("fill", p.x, p.y, r)
        end
        love.graphics.setBlendMode("alpha")

        -- Solid center
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", p.x, p.y, p.size * 0.6)
    end
end

return projectile
