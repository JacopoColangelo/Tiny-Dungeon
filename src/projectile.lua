local map = require("src.map")
local shadows = require("src.shadows")

local projectile = {}

projectile.list = {}

function projectile.init()
    projectile.list = {}
end

function projectile.spawn(x, y, dirX, dirY, options)
    options = options or {}
    local p = {
        x = x,
        y = y,
        vx = dirX * (options.speed or 250),
        vy = dirY * (options.speed or 250),
        size = options.size or 8,
        damage = options.damage or 0.5,
        color = options.color or {0.6, 0.2, 1.0},
        life = options.life or 3.0,
        particles = {},
        particleTimer = 0
    }
    table.insert(projectile.list, p)
end

local function isPointInWall(x, y, currentMap)
    local tx = math.floor(x / currentMap.gridSize) + 1
    local ty = math.floor(y / currentMap.gridSize) + 1
    if tx < 1 or tx > currentMap.width or ty < 1 or ty > currentMap.height then return true end
    return currentMap.data[ty][tx] == 1
end

function projectile.update(dt, player, currentMap)
    for i = #projectile.list, 1, -1 do
        local p = projectile.list[i]
        p.life = p.life - dt
        
        -- Spawn trail particles
        p.particleTimer = p.particleTimer - dt
        if p.particleTimer <= 0 then
            table.insert(p.particles, {
                x = p.x + (math.random() * 4 - 2),
                y = p.y + (math.random() * 4 - 2),
                life = 0.3,
                maxLife = 0.3,
                size = p.size * 0.5
            })
            p.particleTimer = 0.05
        end

        for j = #p.particles, 1, -1 do
            local part = p.particles[j]
            part.life = part.life - dt
            if part.life <= 0 then
                table.remove(p.particles, j)
            end
        end

        local nx = p.x + p.vx * dt
        local ny = p.y + p.vy * dt

        local hitWall = isPointInWall(nx, ny, currentMap)
        
        local dx = nx - (player.x + player.size/2)
        local dy = ny - (player.y + player.size/2)
        local distSq = dx*dx + dy*dy
        local hitPlayer = distSq < ((p.size + player.size)/2)^2

        if hitPlayer then
            player.hp = player.hp - p.damage
            if _G.camera and _G.camera.addShake then _G.camera.addShake(8, 0.1) end
            table.remove(projectile.list, i)
        elseif hitWall or p.life <= 0 then
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
