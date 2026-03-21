local soul = {}

soul.list = {}

-- Visual settings
-- Visual settings
local SOUL_ATTRACTION_RADIUS = 65
local SOUL_ATTRACTION_SPEED = 900
local SOUL_COLLECTION_RADIUS = 24
local SOUL_MAX_SPEED = 1200

local soulImage

function soul.load()
    soulImage = love.graphics.newImage("assets/sprites/soul_icon.png")
end

function soul.init()
    soul.list = {}
end

function soul.spawn(x, y, amount)
    -- Random eject physics
    local angle = math.random() * math.pi * 2
    local force = math.random(150, 300)
    
    table.insert(soul.list, {
        x = x,
        y = y,
        amount = amount or 1,
        vx = math.cos(angle) * force,
        vy = math.sin(angle) * force,
        friction = 0.92,
        timer = 0,
        attractionDelay = 0.6, -- 0.6s delay before attraction starts
        collected = false
    })
end

local function isPointInWall(x, y, map)
    if not map or not map.data then return false end
    local tx = math.floor(x / map.gridSize) + 1
    local ty = math.floor(y / map.gridSize) + 1
    if tx < 1 or tx > map.width or ty < 1 or ty > map.height then return true end
    return map.data[ty][tx] == 1
end

function soul.update(dt, player, map)
    local px = player.x + player.size/2
    local py = player.y + player.size/2

    for i = #soul.list, 1, -1 do
        local s = soul.list[i]
        
        -- Movement logic with wall bouncing
        local nextX = s.x + s.vx * dt
        local nextY = s.y + s.vy * dt
        
        -- Check X collision
        if isPointInWall(nextX, s.y, map) then
            s.vx = -s.vx * 0.6 -- Bounce with friction
            s.vx = s.vx + (math.random() - 0.5) * 50 -- Add a bit of randomness to break stuck states
        else
            s.x = nextX
        end
        
        -- Check Y collision
        if isPointInWall(s.x, nextY, map) then
            s.vy = -s.vy * 0.6 -- Bounce with friction
            s.vy = s.vy + (math.random() - 0.5) * 50
        else
            s.y = nextY
        end
        
        -- Attraction delay
        if s.attractionDelay > 0 then
            s.attractionDelay = s.attractionDelay - dt
        end

        -- Proximity suck logic
        local dx = px - s.x
        local dy = py - s.y
        local distSq = dx*dx + dy*dy
        
        if s.attractionDelay <= 0 and distSq < SOUL_ATTRACTION_RADIUS * SOUL_ATTRACTION_RADIUS then
            local dist = math.sqrt(distSq)
            if dist > 0 then
                -- Direct acceleration towards player
                local ax = (dx / dist) * SOUL_ATTRACTION_SPEED
                local ay = (dy / dist) * SOUL_ATTRACTION_SPEED
                
                s.vx = s.vx + ax * dt * 5 -- High acceleration multiplier for snappiness
                s.vy = s.vy + ay * dt * 5
                
                -- Smoothing / Damping to prevent jitter/orbiting
                s.vx = s.vx * 0.95
                s.vy = s.vy * 0.95
            end
            
            -- Collection collision
            if dist < SOUL_COLLECTION_RADIUS then
                player.soulsRun = (player.soulsRun or 0) + s.amount
                table.remove(soul.list, i)
            end
        else
            -- Normal friction when not attracted
            s.vx = s.vx * s.friction
            s.vy = s.vy * s.friction
        end
        
        -- Speed cap
        local speedSq = s.vx*s.vx + s.vy*s.vy
        if speedSq > SOUL_MAX_SPEED * SOUL_MAX_SPEED then
            local speed = math.sqrt(speedSq)
            s.vx = (s.vx / speed) * SOUL_MAX_SPEED
            s.vy = (s.vy / speed) * SOUL_MAX_SPEED
        end

        s.timer = s.timer + dt
    end
end

function soul.draw()
    if not soulImage then return end
    local t = love.timer.getTime()
    
    love.graphics.setBlendMode("add")
    local imgW, imgH = soulImage:getDimensions()
    local targetSize = 38 -- Smaller size for world particles
    local baseScale = targetSize / imgW
    
    for _, s in ipairs(soul.list) do
        local bob = math.sin(t * 12 + s.x) * 3
        local flicker = math.sin(t * 20 + s.y) * 0.2 + 0.8
        
        -- Outer soft glow layers
        for i = 2, 1, -1 do
            local gS = baseScale * (1.0 + i * 0.5)
            love.graphics.setColor(0.5, 0.8, 1, (0.08 / i) * flicker)
            love.graphics.draw(soulImage, s.x, s.y + bob, 0, gS, gS, imgW/2, imgH/2)
        end
        
        -- Core image
        love.graphics.setColor(1, 1, 1, 0.9 * flicker)
        love.graphics.draw(soulImage, s.x, s.y + bob, 0, baseScale, baseScale, imgW/2, imgH/2)
    end
    love.graphics.setBlendMode("alpha")
end

return soul
