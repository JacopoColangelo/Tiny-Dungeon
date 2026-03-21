local pathfinding = require("src.gameplay.pathfinding")

--[[
============================================================================
ENEMY TYPE: MELEE (The "Grunt")
============================================================================
Design Intent: Swarm-based frontline combatant. Melee enemies use a slot-based 
positioning system to surround the player without overlapping, creating a 
"crowding" effect. Their primary threat is a high-speed, telegraphed lunge 
(Charge) that punishes stationary players and requires active dodging.
============================================================================
]]

local melee = {}

melee.config = {
    -- Stats
    displayName = "Grunt",
    maxHp = 100,
    level = 1,
    speed = 110,
    size = 20,
    color = {1.0, 0.2, 0.2},
    
    -- Damage
    damagePerHit = 0.6,
    
    -- UI
    hpBarOffset = -22,
    
    -- Melee Attack Logic
    chargeRange = 100,
    chargeSpeed = 650,
    chargeDuration = 0.3,
    chargeWindup = 0.4,
    chargeCooldown = 2.0,

    -- Slot Management
    numSlots = 8,
    slotRadius = 50,
    minSlotDist = 35,

    -- Perception
    perceptionRadius = 240,
    groupAggroRadius = 300,

    -- Rewards
    soulDropRate = 0.6,
    soulMinDrop = 2,
    soulMaxDrop = 4,

    -- Spawning & CR
    challengeRating = 1,
    spawnWeight = 10,

    -- Roaming
    roamSpeed = 40,
    roamWaitMin = 2,
    roamWaitMax = 5,
    roamRadius = 150,

    -- Visuals
    hitFlashDuration = 0.15,
    deathParticleCount = 15,
    deathParticleSpeed = 150,
    deathParticleLife = 0.5,
}

-- Private state for slot management
local slots = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function melee.init()
    melee.hitSound = love.audio.newSource("assets/audio/enemy_hit.wav", "static")
    melee.deathSound = love.audio.newSource("assets/audio/enemy_death.wav", "static")
    
    for i = 1, melee.config.numSlots do
        slots[i] = { x = 0, y = 0, baseX = 0, baseY = 0, occupied = false, valid = false }
    end
end

function melee.create(e)
    local cfg = melee.config
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
    e.hasDealtDamage = false
    e.slotId = nil
end

-- ============================================================================
-- SLOT MANAGEMENT HELPERS
-- ============================================================================

local function calculateSlotPositions(px, py, map, enemyModule)
    local cfg = melee.config
    local num = cfg.numSlots
    
    for i = 1, num do
        local baseAngle = ((i-1) / num) * math.pi * 2
        local foundValid, bestX, bestY = false, px, py
        
        -- Try slight angle variations if direct spot is blocked
        for angleOffset = 0, math.pi/4, 0.1 do
            for sign = 1, -1, -2 do
                local angle = baseAngle + angleOffset * (angleOffset == 0 and 0 or sign)
                local tx = px + math.cos(angle) * cfg.slotRadius
                local ty = py + math.sin(angle) * cfg.slotRadius
                
                if not enemyModule.isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, true
                    break
                end
                if angleOffset == 0 then break end
            end
            if foundValid then break end
        end
        
        -- Fallback: try closer distances along base angle
        if not foundValid then
            for d = 1, 10 do
                local dist = cfg.slotRadius * (1 - d/10)
                local tx = px + math.cos(baseAngle) * dist
                local ty = py + math.sin(baseAngle) * dist
                
                if not enemyModule.isPointInWall(tx, ty, map) then
                    bestX, bestY, foundValid = tx, ty, (dist > 20)
                    break
                end
            end
        end
        
        slots[i].x, slots[i].y = bestX, bestY
        slots[i].baseX = px + math.cos(baseAngle) * cfg.slotRadius
        slots[i].baseY = py + math.sin(baseAngle) * cfg.slotRadius
        
        if foundValid and not enemyModule.hasLOS(px, py, bestX, bestY, map) then 
            foundValid = false 
        end
        slots[i].valid = foundValid
    end
end

local function applySlotRepulsion(enemyModule, map)
    local cfg = melee.config
    local num = cfg.numSlots
    
    for pass = 1, 3 do
        for i = 1, num do
            if slots[i].valid then
                for j = i + 1, num do
                    if slots[j].valid then
                        local dx, dy = slots[j].x - slots[i].x, slots[j].y - slots[i].y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        
                        if dist < cfg.minSlotDist and dist > 0 then
                            local push = (cfg.minSlotDist - dist) / 2
                            local nx, ny = (dx/dist) * push, (dy/dist) * push
                            
                            if not enemyModule.isPointInWall(slots[j].x + nx, slots[j].y + ny, map) then
                                slots[j].x, slots[j].y = slots[j].x + nx, slots[j].y + ny
                            end
                            if not enemyModule.isPointInWall(slots[i].x - nx, slots[i].y - ny, map) then
                                slots[i].x, slots[i].y = slots[i].x - nx, slots[i].y - ny
                            end
                        end
                    end
                end
            end
        end
    end
end

local function updateSlots(px, py, map, enemyModule)
    calculateSlotPositions(px, py, map, enemyModule)
    applySlotRepulsion(enemyModule, map)
end

local function assignEnemyToSlot(e, py, px)
    local bestAngleDiff, bestId = 999, nil
    
    for i = 1, melee.config.numSlots do
        local s = slots[i]
        if s.valid and not s.occupied then
            local slotAngle = math.atan2(s.y - py, s.x - px)
            local diff = math.abs(e.currentAngle - slotAngle)
            
            if diff > math.pi then diff = math.pi * 2 - diff end
            if diff < bestAngleDiff then 
                bestAngleDiff, bestId = diff, i 
            end
        end
    end
    
    return bestId
end

local function handleEnemyMovementToSlot(e, dt, map, enemyModule)
    if not e.slotId then return end
    
    slots[e.slotId].occupied = true
    local tx, ty = slots[e.slotId].x, slots[e.slotId].y
    e.pathTimer = e.pathTimer - dt
    
    -- Pathfinding logic
    local oldSlotId = e.slotId
    if enemyModule.hasLOS(e.x, e.y, tx, ty, map) then 
        e.path = nil
    elseif not e.path or e.slotId ~= oldSlotId or e.pathTimer <= 0 then
        e.path = pathfinding.findPath(e.x, e.y, tx, ty, map)
        e.pathTimer = 0.5 
    end
    
    -- Waypoint logic
    local mx, my = tx, ty
    if e.path and #e.path > 0 then
        while #e.path > 1 and enemyModule.hasLOS(e.x, e.y, e.path[2].x, e.path[2].y, map) do 
            table.remove(e.path, 1) 
        end
        if math.sqrt((e.path[1].x - e.x)^2 + (e.path[1].y - e.y)^2) < 15 then 
            table.remove(e.path, 1) 
        end
        if #e.path > 0 then 
            mx, my = e.path[1].x, e.path[1].y 
        end
    end
    
    -- Apply movement
    local ddx, ddy = mx - e.x, my - e.y
    local ddist = math.sqrt(ddx*ddx + ddy*ddy)
    
    if ddist > 5 then
        local nx = e.x + (ddx/ddist) * e.speed * dt
        local ny = e.y + (ddy/ddist) * e.speed * dt
        
        if not enemyModule.isPointInWall(nx, ny, map) then 
            e.x, e.y = nx, ny
        else
            -- Wall sliding
            if not enemyModule.isPointInWall(nx, e.y, map) then e.x = nx
            elseif not enemyModule.isPointInWall(e.x, ny, map) then e.y = ny end
        end
    end
end

-- ============================================================================
-- BEHAVIOR LOGIC
-- ============================================================================

function melee.update(e, dt, player, enemyModule, map)
    local cfg = melee.config
    local px, py = player.x + player.size/2, player.y + player.size/2
    local dx, dy = px - e.x, py - e.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if e.attackCooldown > 0 then
        e.attackCooldown = e.attackCooldown - dt
    end

    -- 1. Trigger Charge Windup
    if e.attackState == "none" and e.attackCooldown <= 0 and dist < cfg.chargeRange and e.aggro then
        e.attackState = "winding"
        e.attackTimer = cfg.chargeWindup
        local angle = math.atan2(dy, dx)
        e.attackDirX, e.attackDirY = math.cos(angle), math.sin(angle)
    
    -- 2. Execute Windup
    elseif e.attackState == "winding" then
        e.attackTimer = e.attackTimer - dt
        if e.attackTimer <= 0 then
            e.attackState = "charging"
            e.attackTimer = cfg.chargeDuration
            e.hasDealtDamage = false
        end
    
    -- 3. Execute Dash
    elseif e.attackState == "charging" then
        e.attackTimer = e.attackTimer - dt
        local nx = e.x + e.attackDirX * cfg.chargeSpeed * dt
        local ny = e.y + e.attackDirY * cfg.chargeSpeed * dt
        
        -- Dash collision with walls (with sliding)
        if not enemyModule.isPointInWall(nx, ny, map) then
            e.x, e.y = nx, ny
        else
            if not enemyModule.isPointInWall(nx, e.y, map) then e.x = nx
            elseif not enemyModule.isPointInWall(e.x, ny, map) then e.y = ny
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

function melee.globalUpdate(dt, player, enemyModule, map)
    local px, py = player.x + player.size/2, player.y + player.size/2
    updateSlots(px, py, map, enemyModule)
    
    for i = 1, melee.config.numSlots do 
        slots[i].occupied = false 
    end
    
    -- Sort enemies by angle relative to player for optimal slot assignment
    local sortedMelee = {}
    for _, e in ipairs(enemyModule.list) do
        if e.type == "melee" and e.aggro and e.state ~= "dying" and e.attackState == "none" then
            e.currentAngle = math.atan2(e.y - py, e.x - px)
            table.insert(sortedMelee, e)
        end
    end
    table.sort(sortedMelee, function(a, b) return a.currentAngle < b.currentAngle end)
    
    -- Assign slots and apply movement
    for _, e in ipairs(sortedMelee) do
        e.slotId = assignEnemyToSlot(e, py, px)
        handleEnemyMovementToSlot(e, dt, map, enemyModule)
    end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

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

function melee.globalDraw(player, enemyModule)
    -- Only draw slots in the dungeon to avoid lines to (0,0) in the hub
    if _G.game and _G.game.getLevelType and _G.game.getLevelType() ~= "dungeon" then return end

    local px, py = player.x + player.size/2, player.y + player.size/2
    local cfg = melee.config
    
    -- Draw slots and connections
    for i = 1, cfg.numSlots do
        local s = slots[i]
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.line(px, py, s.baseX, s.baseY)
        love.graphics.line(s.baseX, s.baseY, s.x, s.y)
        
        if s.valid then
            love.graphics.setColor(s.occupied and {0, 0.8, 1, 0.6} or {0, 1, 0, 0.5})
            love.graphics.circle("line", s.x, s.y, 8)
            
            -- Draw slot number
            local angle = math.atan2(s.y - py, s.x - px)
            local tx = s.x + math.cos(angle) * 16
            local ty = s.y + math.sin(angle) * 16
            
            local smallFont = _G.hud and _G.hud.getFont and _G.hud.getFont("small")
            if smallFont then love.graphics.setFont(smallFont) end
            love.graphics.print(tostring(i), tx - 4, ty - 7)
        else
            love.graphics.setColor(1, 0, 0, 0.4)
            love.graphics.print("X", s.x - 4, s.y - 7)
        end
    end
    
    -- Draw paths for melee enemies
    for _, e in ipairs(enemyModule.list) do
        if e.type == "melee" and e.path and #e.path > 0 then
            love.graphics.setColor(1, 1, 1, 0.2)
            local lx, ly = e.x, e.y
            for _, p in ipairs(e.path) do 
                love.graphics.line(lx, ly, p.x, p.y) 
                lx, ly = p.x, p.y 
            end
        end
    end
end

return melee
