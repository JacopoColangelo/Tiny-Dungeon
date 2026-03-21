-- skilltree.lua
-- Skill tree UI for Tiny Dungeon. Hub-only. Opened with I.
-- Left-click to purchase a node with souls. Tooltip on hover.
-- Inline "not enough souls" warning banner at base of panel.

-- TODO: Rename Skill Tree to Talent Tree
-- TODO: Can maybe combine with inventory as a separate tab? or maybe make a merchant point in the hub to buy talents?
-- TODO: Make the talent tree dynamic and not hardcoded so its easy to add more talents and have them automatically positioned in the grid.
-- TODO: Make the talent tree visually appealing.

local skills   = require("src.skills")
local hud      = require("src.hud")
local ui_audio = require("src.ui_audio")

local skilltree = {}

-- ── Layout constants ──────────────────────────────────────────────────────────

local COLS        = 3
local ROWS        = 2
local NODE_SIZE   = 56      -- px per skill node box
local NODE_GAP_X  = 70      -- horizontal gap between node centres
local NODE_GAP_Y  = 84      -- vertical gap between node centres
-- Instead of deriving from grid, hardcode to match inventory exactly
local PANEL_W = 308
local PANEL_H = 298

-- Calculate grid so we can centre the nodes within the matched panel
local GRID_W  = (COLS - 1) * NODE_GAP_X + NODE_SIZE
local GRID_H  = (ROWS - 1) * NODE_GAP_Y + NODE_SIZE

-- We'll adjust nodeRect to use dynamic padding to keep nodes centred
local PAD_X = math.floor((PANEL_W - GRID_W) / 2)
local PAD_Y = math.floor((PANEL_H - 42 - GRID_H) / 2)

local VIRTUAL_W = 1280
local VIRTUAL_H = 720

-- ── State ─────────────────────────────────────────────────────────────────────

local open          = false
local unlocked      = {}   -- set: unlocked[skillId] = true
local hoveredId     = nil  -- currently hovered skill id
local lastHoveredId = nil  -- for hover audio debounce

-- Warning banner state
local warningTimer  = 0
local warningAlpha  = 0
local WARNING_DUR   = 2.0

-- Panel origin (updated each draw)
local panelX, panelY = 0, 0

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function skilltree.init()
    unlocked    = {}
    open        = false
    hoveredId   = nil
    warningTimer = 0
    warningAlpha = 0
end

-- ── Open / Close ──────────────────────────────────────────────────────────────

function skilltree.toggle()
    open = not open
    if not open then
        hoveredId = nil
    end
end

function skilltree.close()
    open        = false
    hoveredId   = nil
end

function skilltree.isOpen()
    return open
end

-- ── Serialisation ─────────────────────────────────────────────────────────────

function skilltree.getUnlocked()
    local out = {}
    for id, _ in pairs(unlocked) do
        table.insert(out, id)
    end
    return out
end

-- Restore from save and re-apply all onUnlock effects.
function skilltree.setUnlocked(saved, player)
    unlocked = {}
    if not saved then return end
    for _, id in ipairs(saved) do
        local sk = skills.get(id)
        if sk then
            unlocked[id] = true
        end
    end
end

-- ── Node layout helpers ───────────────────────────────────────────────────────

local function nodeRect(sk)
    local gx = panelX + PAD_X + sk.col * NODE_GAP_X
    local gy = panelY + PAD_Y + 42 + sk.row * NODE_GAP_Y
    return gx, gy, NODE_SIZE, NODE_SIZE
end

local function nodeAtPoint(vx, vy)
    for _, sk in ipairs(skills.list) do
        local nx, ny, nw, nh = nodeRect(sk)
        if vx >= nx and vx <= nx + nw and vy >= ny and vy <= ny + nh then
            return sk
        end
    end
    return nil
end

-- ── Purchase logic ────────────────────────────────────────────────────────────

local function canAfford(sk, player)
    return (player.soulsTotal or 0) >= sk.cost
end

local function prereqMet(sk)
    if sk.requires == nil then return true end
    return unlocked[sk.requires] == true
end

local function tryPurchase(sk, player)
    if unlocked[sk.id] then return end           -- already owned

    if not prereqMet(sk) or not canAfford(sk, player) then
        warningTimer = WARNING_DUR               -- trigger warning banner
        ui_audio.playClick()                     -- feedback click
        return
    end

    player.soulsTotal = player.soulsTotal - sk.cost
    unlocked[sk.id]   = true
    sk.onUnlock(player)
    ui_audio.playClick()
end

-- ── Input ─────────────────────────────────────────────────────────────────────

function skilltree.keypressed(key, player)
    if key == "i" then
        skilltree.toggle()
        ui_audio.playClick()
    elseif key == "escape" and open then
        skilltree.close()
        ui_audio.playClick()
    end
end

function skilltree.mousemoved(vx, vy)
    if not open then return end
    local sk = nodeAtPoint(vx, vy)
    hoveredId = sk and sk.id or nil
end

function skilltree.mousepressed(vx, vy, button, player)
    if not open then return end
    if button ~= 1 then return end

    local sk = nodeAtPoint(vx, vy)
    if sk then
        tryPurchase(sk, player)
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function skilltree.update(dt, vx, vy)
    if not open then return end

    -- Warning fade
    if warningTimer > 0 then
        warningAlpha  = math.min(1, warningAlpha + dt * 6)
        warningTimer  = warningTimer - dt
    else
        warningAlpha = math.max(0, warningAlpha - dt * 3)
    end

    -- Hover sound
    local sk = nodeAtPoint(vx, vy)
    local newId = sk and sk.id or nil
    if newId ~= lastHoveredId then
        if newId then ui_audio.playHover() end
        lastHoveredId = newId
    end
    hoveredId = newId
end

-- ── Draw helpers ──────────────────────────────────────────────────────────────

local function drawPanel()
    panelX = math.floor(VIRTUAL_W / 2 - PANEL_W / 2)
    panelY = math.floor(VIRTUAL_H / 2 - PANEL_H / 2)

    -- Dim overlay
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, PANEL_W, PANEL_H, 5)

    -- Panel base
    love.graphics.setColor(0.09, 0.09, 0.09, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, PANEL_W, PANEL_H, 4)

    -- Top sheen
    love.graphics.setColor(0.7, 0.7, 0.65, 0.18)
    love.graphics.rectangle("fill", panelX + 4, panelY + 1, PANEL_W - 8, 2, 1)

    -- Outer border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.42, 0.40, 0.38, 0.85)
    love.graphics.rectangle("line", panelX, panelY, PANEL_W, PANEL_H, 4)

    -- Chipped corners
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.55, 0.53, 0.50, 0.6)
    local function chip(cx, cy, cw, ch)
        love.graphics.line(cx, cy + 3, cx + 3, cy)
        love.graphics.line(cx + cw - 3, cy, cx + cw, cy + 3)
        love.graphics.line(cx + cw, cy + ch - 3, cx + cw - 3, cy + ch)
        love.graphics.line(cx + 3, cy + ch, cx, cy + ch - 3)
    end
    chip(panelX, panelY, PANEL_W, PANEL_H)

    -- Inset border
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("line", panelX + 8, panelY + 8, PANEL_W - 16, PANEL_H - 16)

    -- Title
    local titleFont = hud.getFont("button")
    love.graphics.setFont(titleFont)
    local title = "Skill Tree"
    local tw    = titleFont:getWidth(title)

    -- Close hint
    local hintFont = hud.getFont("small")
    love.graphics.setFont(hintFont)
    local hint = "[I] Close"
    local hw   = hintFont:getWidth(hint)
    love.graphics.setColor(0.5, 0.5, 0.48, 0.6)
    love.graphics.print(hint, panelX + PANEL_W - hw - 12, panelY + 13)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(title, panelX + PANEL_W / 2 - tw / 2 + 1, panelY + 11)
    love.graphics.setColor(0.85, 0.85, 0.80, 0.9)
    love.graphics.print(title, panelX + PANEL_W / 2 - tw / 2, panelY + 10)

    -- Divider
    for i = 0, PANEL_W - 56 do
        local a = (1 - math.abs(i - (PANEL_W - 56) / 2) / ((PANEL_W - 56) / 2)) * 0.35
        love.graphics.setColor(0.7, 0.7, 0.65, a)
        love.graphics.points(panelX + 28 + i, panelY + 28 + 34)
    end

    -- Souls counter (bottom of panel)
    -- Drawn here so it's always visible; actual value passed into draw()
end

local function drawConnectors()
    -- Draw lines from parent node bottom-centre to child node top-centre
    for _, sk in ipairs(skills.list) do
        if sk.requires then
            local parent = skills.get(sk.requires)
            if parent then
                local px2, py2, pw2, ph2 = nodeRect(parent)
                local cx2, cy2, cw2, ch2 = nodeRect(sk)

                local x1 = px2 + pw2 / 2
                local y1 = py2 + ph2
                local x2 = cx2 + cw2 / 2
                local y2 = cy2

                local bothUnlocked = unlocked[parent.id] and unlocked[sk.id]
                local parentUnlocked = unlocked[parent.id]

                love.graphics.setLineWidth(2)
                if bothUnlocked then
                    love.graphics.setColor(0, 0.85, 0.7, 0.6)
                elseif parentUnlocked then
                    love.graphics.setColor(0.5, 0.5, 0.45, 0.5)
                else
                    love.graphics.setColor(0.25, 0.25, 0.23, 0.4)
                end
                -- Elbow connector: vertical then horizontal
                local midY = (y1 + y2) / 2
                love.graphics.line(x1, y1, x1, midY)
                love.graphics.line(x1, midY, x2, midY)
                love.graphics.line(x2, midY, x2, y2)
            end
        end
    end
    love.graphics.setLineWidth(1)
end

local function drawNodes(vx, vy, animTimer)
    local smallFont  = hud.getFont("small")
    local buttonFont = hud.getFont("button")

    for _, sk in ipairs(skills.list) do
        local nx, ny, nw, nh = nodeRect(sk)
        local isUnlocked  = unlocked[sk.id]
        local isHover     = hoveredId == sk.id
        local prereq      = prereqMet(sk)
        local isAvailable = prereq and not isUnlocked -- purchaseable (prereq met, not yet bought)

        -- Node base fill
        if isUnlocked then
            love.graphics.setColor(0.04, 0.14, 0.12, 1)
        elseif isAvailable then
            love.graphics.setColor(0.05, 0.05, 0.05, 1)
        else
            love.graphics.setColor(0.04, 0.04, 0.04, 1)
        end
        love.graphics.rectangle("fill", nx, ny, nw, nh, 3)

        -- Border
        love.graphics.setLineWidth(1)
        if isUnlocked then
            love.graphics.setColor(0, 0.85, 0.7, 0.9)
        elseif isHover and isAvailable then
            love.graphics.setColor(1, 0.9, 0.8, 1)
        elseif isAvailable then
            love.graphics.setColor(0.6, 0.6, 0.55, 0.5)
        else
            love.graphics.setColor(0.3, 0.3, 0.28, 0.3)
        end
        love.graphics.rectangle("line", nx, ny, nw, nh, 3)

        -- Unlocked glow (additive cyan)
        if isUnlocked then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0, 0.6, 0.5, 0.18)
            love.graphics.rectangle("fill", nx, ny, nw, nh, 3)
            love.graphics.setBlendMode("alpha")
        elseif isHover and isAvailable then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0, 0.5, 0.8, 0.14)
            love.graphics.rectangle("fill", nx, ny, nw, nh, 3)
            love.graphics.setBlendMode("alpha")
        end

        -- Icon: stylised rune (using primitive geometry, no images)
        local cx, cy = nx + nw / 2, ny + nh / 2
        love.graphics.setLineWidth(1.5)
        if isUnlocked then
            love.graphics.setColor(0, 1, 0.8, 0.9)
        elseif isAvailable then
            love.graphics.setColor(0.7, 0.7, 0.65, isHover and 0.9 or 0.5)
        else
            love.graphics.setColor(0.35, 0.35, 0.33, 0.3)
        end

        -- Draw a different simple icon shape per skill column
        local half = 10
        if sk.col == 0 then
            -- Survival
            if sk.id == "vitality_1" then
                love.graphics.rectangle("fill", cx - 2, cy - half, 5, half * 2, 2)
            else
                love.graphics.rectangle("fill", cx - 7, cy - half, 5, half * 2, 2)
                love.graphics.rectangle("fill", cx + 2, cy - half, 5, half * 2, 2)
            end
        elseif sk.col == 1 then
            -- Slash (combat)
            love.graphics.line(cx - half, cy + half, cx + half, cy - half)
            love.graphics.line(cx - half + 4, cy + half, cx + half + 4, cy - half)
        elseif sk.col == 2 then
            -- Flame / torch (utility)
            love.graphics.ellipse("line", cx, cy + 3, 4, 7)
            love.graphics.line(cx, cy - 4, cx - 4, cy + 2)
            love.graphics.line(cx, cy - 4, cx + 4, cy + 2)
        end
        love.graphics.setLineWidth(1)

        -- Cost badge (bottom-right of node)
        love.graphics.setFont(smallFont)
        local costStr = isUnlocked and "✓" or (tostring(sk.cost) .. "s")
        local cw      = smallFont:getWidth(costStr)
        local badgeX  = nx + nw - cw - 4
        local badgeY  = ny + nh - smallFont:getHeight() - 2

        if isUnlocked then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(costStr, badgeX + 1, badgeY + 1)
            love.graphics.setColor(0, 1, 0.8, 0.9)
        elseif not prereq then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.print(costStr, badgeX + 1, badgeY + 1)
            love.graphics.setColor(0.4, 0.4, 0.38, 0.5)
        else
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(costStr, badgeX + 1, badgeY + 1)
            love.graphics.setColor(0.85, 0.80, 0.55, 0.9)
        end
        love.graphics.print(costStr, badgeX, badgeY)
    end
end

local function drawColumnLabels()
    local labels = { "Survival", "Combat", "Utility" }
    local smallFont = hud.getFont("small")
    love.graphics.setFont(smallFont)

    for col = 0, COLS - 1 do
        local label = labels[col + 1]
        local lw    = smallFont:getWidth(label)
        -- x-centre of column
        local cx    = panelX + PAD_X + col * NODE_GAP_X + NODE_SIZE / 2
        -- Raise the text label up further from the nodes
        local ly    = panelY + PAD_Y + 16

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(label, cx - lw / 2 + 1, ly + 1)
        love.graphics.setColor(0.55, 0.55, 0.50, 0.6)
        love.graphics.print(label, cx - lw / 2, ly)
    end
end

local function drawSoulsBar(player)
    local smallFont  = hud.getFont("small")
    local buttonFont = hud.getFont("button")
    love.graphics.setFont(smallFont)

    local soulsText = "Souls: " .. tostring(player.soulsTotal or 0)
    local sw        = smallFont:getWidth(soulsText)
    local sx        = panelX + PANEL_W / 2 - sw / 2
    local sy        = panelY + PANEL_H - 22

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(soulsText, sx + 1, sy + 1)
    love.graphics.setColor(0.5, 1, 1, 0.85)
    love.graphics.print(soulsText, sx, sy)
end

local function drawTooltip(vx, vy)
    if not hoveredId then return end
    local sk = skills.get(hoveredId)
    if not sk then return end

    local buttonFont = hud.getFont("button")
    local smallFont  = hud.getFont("small")

    local ttW    = 210
    local nameH  = buttonFont:getHeight()

    -- Wrap description
    local descLines = {}
    local words     = {}
    for word in (sk.description .. " "):gmatch("([^ ]+) ") do
        table.insert(words, word)
    end
    local line = ""
    for _, w in ipairs(words) do
        local test = line == "" and w or (line .. " " .. w)
        if smallFont:getWidth(test) > ttW - 16 then
            if line ~= "" then table.insert(descLines, line) end
            line = w
        else
            line = test
        end
    end
    if line ~= "" then table.insert(descLines, line) end

    local costLine = "Cost: " .. tostring(sk.cost) .. " souls"
    local prereqLine = sk.requires and ("Requires: " .. (skills.get(sk.requires) and skills.get(sk.requires).name or sk.requires)) or nil

    local descH = (#descLines + 1 + (prereqLine and 1 or 0)) * smallFont:getHeight()
    local ttH   = 14 + nameH + 6 + descH + 10

    local ttX = vx - ttW - 14
    local ttY = vy - ttH / 2
    ttX = math.max(4, math.min(ttX, VIRTUAL_W - ttW - 4))
    ttY = math.max(4, math.min(ttY, VIRTUAL_H - ttH - 4))

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", ttX + 4, ttY + 4, ttW, ttH, 3)
    -- BG
    love.graphics.setColor(0.09, 0.09, 0.09, 0.96)
    love.graphics.rectangle("fill", ttX, ttY, ttW, ttH, 3)
    -- Border
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.42, 0.40, 0.38, 0.85)
    love.graphics.rectangle("line", ttX, ttY, ttW, ttH, 3)

    -- Name
    love.graphics.setFont(buttonFont)
    if unlocked[sk.id] then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.print(sk.name, ttX + 9, ttY + 8)
        love.graphics.setColor(0, 1, 0.8, 1)
    else
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.print(sk.name, ttX + 9, ttY + 8)
        love.graphics.setColor(0.85, 0.85, 0.80, 1)
    end
    love.graphics.print(sk.name, ttX + 8, ttY + 7)

    -- Divider
    love.graphics.setColor(0.42, 0.40, 0.38, 0.4)
    love.graphics.line(ttX + 8, ttY + 8 + nameH + 3, ttX + ttW - 8, ttY + 8 + nameH + 3)

    -- Description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.72, 0.70, 0.65, 0.9)
    for j, dl in ipairs(descLines) do
        love.graphics.print(dl, ttX + 8, ttY + 8 + nameH + 6 + (j - 1) * smallFont:getHeight())
    end

    local extraY = ttY + 8 + nameH + 6 + #descLines * smallFont:getHeight()

    -- Cost line
    if unlocked[sk.id] then
        love.graphics.setColor(0, 0.8, 0.6, 0.8)
        love.graphics.print("Unlocked", ttX + 8, extraY)
    else
        love.graphics.setColor(0.85, 0.80, 0.45, 0.9)
        love.graphics.print(costLine, ttX + 8, extraY)
    end

    -- Prereq line
    if prereqLine then
        local metColor = prereqMet(sk) and {0, 0.8, 0.6, 0.7} or {0.8, 0.3, 0.3, 0.8}
        love.graphics.setColor(metColor[1], metColor[2], metColor[3], metColor[4])
        love.graphics.print(prereqLine, ttX + 8, extraY + smallFont:getHeight())
    end
end

local function drawWarningBanner()
    if warningAlpha <= 0.01 then return end

    local bw   = PANEL_W - PAD_X * 2
    local bh   = 22
    local bx   = panelX + PAD_X
    local by   = panelY + PANEL_H - 44

    -- Banner background
    love.graphics.setColor(0.4, 0.04, 0.04, 0.85 * warningAlpha)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.8, 0.2, 0.2, 0.7 * warningAlpha)
    love.graphics.rectangle("line", bx, by, bw, bh, 3)

    local smallFont = hud.getFont("small")
    love.graphics.setFont(smallFont)
    local msg  = "Not enough souls!"
    local mw   = smallFont:getWidth(msg)
    local mh   = smallFont:getHeight()
    love.graphics.setColor(0, 0, 0, 0.6 * warningAlpha)
    love.graphics.print(msg, bx + bw / 2 - mw / 2 + 1, by + bh / 2 - mh / 2 + 1)
    love.graphics.setColor(1, 0.6, 0.6, warningAlpha)
    love.graphics.print(msg, bx + bw / 2 - mw / 2, by + bh / 2 - mh / 2)
end

-- ── Public draw ───────────────────────────────────────────────────────────────

function skilltree.draw(vx, vy, player)
    if not open then return end

    local animTimer = hud and hud.animTimer or 0

    drawPanel()
    drawColumnLabels()
    drawConnectors()
    drawNodes(vx, vy, animTimer)
    drawSoulsBar(player)
    drawTooltip(vx, vy)
    drawWarningBanner()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    hud.resetFont()
end

return skilltree
