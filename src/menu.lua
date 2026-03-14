local hud = require("src.hud")

local menu = {}

-- ── Animated Particles (drifting embers) ─────────────────────────────────────

local particles = {}
local maxParticles = 60

local function spawnParticle(w, h)
    return {
        x = math.random() * w,
        y = h + math.random() * 20,
        vx = (math.random() - 0.5) * 15,
        vy = -(10 + math.random() * 25),
        life = 3 + math.random() * 4,
        maxLife = 0,
        size = 1 + math.random() * 2,
        color = math.random() > 0.6
            and {1.0, 0.5, 0.15}   -- orange ember
            or  {0.8, 0.35, 0.1}   -- dim ember
    }
end

-- ── Popup State ──────────────────────────────────────────────────────────────

local popup = {
    visible = false,
    text = "Start a new game?\nThis will reset your current progress.",
    buttons = {
        {id = "yes", text = "YES", w = 120, h = 40},
        {id = "no",  text = "NO",  w = 120, h = 40}
    },
    rects = {} -- screen hitboxes for popup buttons
}

-- ── Button Definitions ───────────────────────────────────────────────────────

local buttons = {
    {id = "loadgame", text = "Continue",  w = 240, h = 48, disabled = false},
    {id = "newgame",  text = "New Game",  w = 240, h = 48, disabled = false},
    {id = "options",  text = "Options",   w = 240, h = 48, disabled = false},
    {id = "quit",     text = "Quit",      w = 240, h = 48, disabled = false},
}

-- Runtime button positions (computed in draw)
local buttonRects = {}

-- Pending result from a click
local pendingAction = nil

-- ── Public API ───────────────────────────────────────────────────────────────

function menu.load(hasSave)
    -- Seed initial particles
    local w, h = 1280, 720
    if #particles == 0 then
        for i = 1, maxParticles do
            local p = spawnParticle(w, h)
            p.y = math.random() * h          -- scatter vertically
            p.life = math.random() * p.life  -- stagger lifetimes
            p.maxLife = p.life
            table.insert(particles, p)
        end
    end

    -- Define buttons based on save state
    if hasSave then
        buttons = {
            {id = "loadgame", text = "Continue",  w = 240, h = 48, disabled = false},
            {id = "newgame",  text = "New Game",  w = 240, h = 48, disabled = false},
            {id = "options",  text = "Options",   w = 240, h = 48, disabled = false},
            {id = "quit",     text = "Quit",      w = 240, h = 48, disabled = false},
        }
    else
        buttons = {
            {id = "newgame",  text = "New Game",  w = 240, h = 48, disabled = false},
            {id = "options",  text = "Options",   w = 240, h = 48, disabled = false},
            {id = "quit",     text = "Quit",      w = 240, h = 48, disabled = false},
        }
    end
end

function menu.update(dt, vx, vy)
    menu.lastVX, menu.lastVY = vx, vy
    local w, h = 1280, 720

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end

    -- Respawn
    while #particles < maxParticles do
        local p = spawnParticle(w, h)
        p.maxLife = p.life
        table.insert(particles, p)
    end

    if pendingAction then
        local action = pendingAction
        
        -- Logic: If they click "newgame" but a save exists, show the popup.
        if action == "newgame" and not popup.visible then
            local hasSave = false
            for _, b in ipairs(buttons) do
                if b.id == "loadgame" then hasSave = true break end
            end
            
            if hasSave then
                popup.visible = true
                pendingAction = nil
                return nil
            end
        end

        -- Handle popup buttons
        if popup.visible then
            if action == "yes" then
                popup.visible = false
                pendingAction = nil
                return "newgame"
            elseif action == "no" then
                popup.visible = false
                pendingAction = nil
                return nil
            end
            -- Block other actions while popup is visible
            pendingAction = nil
            return nil
        end

        return action
    end

    return nil
end

function menu.draw(screenCanvas, vx, vy)
    local w, h = 1280, 720

    love.graphics.setCanvas(screenCanvas)
    love.graphics.clear(0, 0, 0, 1)

    -- Background vignette
    love.graphics.setBlendMode("alpha")
    for i = 1, 8 do
        local a = (1 - i/8) * 0.04
        love.graphics.setColor(0.06, 0.04, 0.02, a)
        love.graphics.ellipse("fill", w/2, h/2, w/2 * (i/8), h/2 * (i/8))
    end

    -- Particles (embers)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(particles) do
        local alpha = math.min(1, p.life / (p.maxLife * 0.3))
        alpha = alpha * math.min(1, (p.maxLife - p.life) / 0.5) -- fade in
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.6)
        love.graphics.rectangle("fill",
            math.floor(p.x) - math.floor(p.x) % 2,
            math.floor(p.y) - math.floor(p.y) % 2,
            p.size, p.size)
    end
    love.graphics.setBlendMode("alpha")

    -- Title: "Tiny Dungeon"
    local titleFont = hud.getFont("title")
    love.graphics.setFont(titleFont)
    local title = "Tiny Dungeon"
    local tw = titleFont:getWidth(title)
    local th = titleFont:getHeight()
    local tx = w/2 - tw/2
    local ty = h * 0.15

    -- Title shadow (Deep Cold Slate)
    love.graphics.setColor(0.05, 0.05, 0.08, 1)
    love.graphics.print(title, tx + 3, ty + 3)
    
    -- Title face (Original Crimson)
    local baseColor = {0.6, 0.12, 0.08, 1}
    love.graphics.setColor(baseColor)
    love.graphics.print(title, tx, ty)

    -- --- ANIMATION: Ultra-Soft Highlight Sweep (Refined: Softer & Slower) ---
    local time = love.timer.getTime()
    local period = 7.0 -- Frequency
    local dashTime = time % period
    local sweepDuration = 5.0 -- Even slower sweep
    
    if dashTime < sweepDuration then
        local p = dashTime / sweepDuration
        local totalRange = tw + 1000
        local centerX = tx - 500 + p * totalRange
        
        -- High-fidelity 3-layer soft-edge shine
        local layers = {
            {w = 800, a = 0.02}, -- Extremely broad base
            {w = 400, a = 0.03}, -- Middle diffusion
            {w = 150, a = 0.05}  -- Core glint
        }
        
        for _, l in ipairs(layers) do
            local sweepX = centerX - l.w/2
            love.graphics.setScissor(sweepX, ty, l.w, th)
            love.graphics.setColor(1, 1, 1, l.a) 
            love.graphics.print(title, tx, ty)
        end
        love.graphics.setScissor()
    end

    -- Ornate divider
    local divY = ty + titleFont:getHeight() + 15
    local divW = tw + 100
    local ivory = {0.85, 0.85, 0.8}

    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.2, 0.2, 0.25, 0.1) -- Neutral glow
    love.graphics.ellipse("fill", w/2, divY, divW/2, 8)
    love.graphics.setBlendMode("alpha")

    love.graphics.setLineWidth(1)
    for i = 0, divW do
        local a = (1 - math.abs(i - divW/2) / (divW/2)) * 0.35
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], a)
        love.graphics.points(w/2 - divW/2 + i, divY)
    end

    -- Flourish knots
    local function drawKnot(fx, fy)
        love.graphics.setColor(ivory[1], ivory[2], ivory[3], 0.4)
        love.graphics.rectangle("line", fx-5, fy-5, 10, 10, 2)
        love.graphics.rectangle("fill", fx-2, fy-2, 4, 4)
    end
    drawKnot(w/2 - divW/2, divY)
    drawKnot(w/2 + divW/2, divY)
    drawKnot(w/2, divY)

    -- Buttons
    local vx, vy = menu.lastVX or 0, menu.lastVY or 0

    local btnSpacing = 12
    local totalBtnH = 0
    for _, b in ipairs(buttons) do totalBtnH = totalBtnH + b.h end
    totalBtnH = totalBtnH + btnSpacing * (#buttons - 1)

    local startY = divY + 50
    buttonRects = {}

    for i, b in ipairs(buttons) do
        local bx = w/2 - b.w/2
        local by = startY + (i-1) * (b.h + btnSpacing)

        buttonRects[i] = {x = bx, y = by, w = b.w, h = b.h, id = b.id, disabled = b.disabled}

        local isHover = not popup.visible and not b.disabled and
            vx >= bx and vx <= bx + b.w and
            vy >= by and vy <= by + b.h

        hud.drawStoneTablet(bx, by, b.w, b.h, b.text, isHover, b.disabled)
    end

    -- ── Confirmation Popup Pass ────────────────────────────────────────────────
    if popup.visible then
        menu.drawPopup(w, h, vx, vy)
    end

    -- Finish screen
    love.graphics.setCanvas()
end

function menu.drawPopup(w, h, vx, vy)
    -- Darkened background overlay (More neutral)
    love.graphics.setColor(0.02, 0.02, 0.02, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local pw, ph = 500, 240
    local px, py = w/2 - pw/2, h/2 - ph/2

    -- Neutral Shadow underneath
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse("fill", w/2, h/2 + 10, pw/2 + 20, ph/2 + 20)

    -- Stone Slate Dialog Box
    love.graphics.setColor(0.1, 0.1, 0.1, 0.98)
    love.graphics.rectangle("fill", px, py, pw, ph, 4)
    
    -- Subtle top highlight (Ivory-ish)
    love.graphics.setColor(0.7, 0.7, 0.65, 0.2)
    love.graphics.line(px + 4, py + 1, px + pw - 4, py + 1)
    
    -- Weathered stone border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.35, 0.35, 0.33, 0.8)
    love.graphics.rectangle("line", px, py, pw, ph, 4)

    -- Muted Warning Icon (Rusty/Dried Blood)
    love.graphics.setColor(0.5, 0.15, 0.1, 0.8)
    local itx, ity = w/2, py + 45
    love.graphics.polygon("fill", itx, ity-15, itx-15, ity+10, itx+15, ity+10)
    love.graphics.setColor(0.7, 0.7, 0.65, 0.9) -- Ivory inner
    love.graphics.rectangle("fill", itx-2, ity-6, 4, 8)
    love.graphics.rectangle("fill", itx-2, ity+5, 4, 2)

    -- Message Text (Faded Ivory)
    love.graphics.setFont(hud.getFont("button"))
    love.graphics.setColor(0.85, 0.85, 0.8, 0.9)
    love.graphics.printf(popup.text, px + 20, py + 80, pw - 40, "center")

    -- Popup Buttons (Yes / No)
    popup.rects = {}
    local btnY = py + ph - 70
    local gap = 30
    local totalBtnW = 0
    for _, b in ipairs(popup.buttons) do totalBtnW = totalBtnW + b.w end
    totalBtnW = totalBtnW + gap * (#popup.buttons - 1)
    
    local startBtnX = w/2 - totalBtnW/2

    for i, b in ipairs(popup.buttons) do
        local bx = startBtnX + (i-1) * (b.w + gap)
        local isHover = vx >= bx and vx <= bx + b.w and vy >= btnY and vy <= btnY + b.h
        
        popup.rects[i] = {x = bx, y = btnY, w = b.w, h = b.h, id = b.id}

        if isHover then
            -- Muted button highlights (Dusty Red / Steel Grey)
            if b.id == "yes" then
                love.graphics.setColor(0.4, 0.1, 0.1, 1)
            else
                love.graphics.setColor(0.3, 0.28, 0.25, 0.95) -- Standard Stone Hover
            end
            love.graphics.rectangle("fill", bx, btnY, b.w, b.h, 2)
            
            -- Keep the outline visible on hover! (Synced with hud.lua)
            love.graphics.setColor(1, 0.9, 0.8, 1) 
            love.graphics.rectangle("line", bx, btnY, b.w, b.h, 2)
            
            love.graphics.setColor(1, 1, 0.9, 0.85) -- Synced text color
        else
            love.graphics.setColor(0.12, 0.12, 0.12, 0.8)
            love.graphics.rectangle("fill", bx, btnY, b.w, b.h, 2)
            
            love.graphics.setColor(0.7, 0.7, 0.65, 0.8) -- Synced idle border
            love.graphics.rectangle("line", bx, btnY, b.w, b.h, 2)
            
            love.graphics.setColor(0.85, 0.85, 0.8, 0.65) -- Synced idle text
        end
        
        love.graphics.printf(b.text, bx, btnY + 8, b.w, "center")
    end
end

function menu.keypressed(key)
    if key == "return" then
        pendingAction = "newgame"
    end
end

function menu.mousepressed(vx, vy, button)
    if button ~= 1 then return end
    
    if popup.visible then
        for _, rect in ipairs(popup.rects) do
            if vx >= rect.x and vx <= rect.x + rect.w and
               vy >= rect.y and vy <= rect.y + rect.h then
                pendingAction = rect.id
                return
            end
        end
        return -- Block main buttons
    end

    for _, rect in ipairs(buttonRects) do
        if not rect.disabled and
           vx >= rect.x and vx <= rect.x + rect.w and
           vy >= rect.y and vy <= rect.y + rect.h then
            pendingAction = rect.id
            return
        end
    end
end

function menu.resetAction()
    pendingAction = nil
end

return menu
