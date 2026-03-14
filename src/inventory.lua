-- inventory.lua
-- Manages the player's item inventory: state, stacking, and full UI rendering.
-- Open/close with Tab. Tooltip on hover. Right-click context menu for actions.

local items    = require("src.items")
local hud      = require("src.hud")
local ui_audio = require("src.ui_audio")

local inventory = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

local MAX_SLOTS  = 20   -- 5 cols × 4 rows
local COLS       = 5
local ROWS        = 4
local SLOT_SIZE  = 44   -- pixels per cell
local SLOT_GAP   = 8    -- gap between cells
local PANEL_PAD  = 28   -- inner padding of the panel

-- Panel dimensions derived from grid
local GRID_W = COLS * SLOT_SIZE + (COLS - 1) * SLOT_GAP
local GRID_H = ROWS * SLOT_SIZE + (ROWS - 1) * SLOT_GAP
local PANEL_W = GRID_W + PANEL_PAD * 2
local PANEL_H = GRID_H + PANEL_PAD * 2 + 42  -- 42 for title area

local VIRTUAL_W = 1280
local VIRTUAL_H = 720

-- ── State ─────────────────────────────────────────────────────────────────────

local open          = false
local slots         = {}   -- [i] = { itemId = string, count = number } or nil
local hoveredSlot   = nil  -- index 1..MAX_SLOTS or nil
local contextMenu   = nil  -- { slotIndex, x, y, actions = {{label, fn}, ...} }
local lastHoveredCtx = nil -- for hover audio on context menu buttons
local lastHoveredSlot = nil -- for hover audio on slots

-- Panel top-left corner (computed each draw so we don't need to store state)
local panelX, panelY = 0, 0

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function inventory.load()
    items.load()
end

function inventory.init()
    slots = {}
    for i = 1, MAX_SLOTS do slots[i] = nil end
    open        = false
    hoveredSlot = nil
    contextMenu = nil
end

-- ── Data API ──────────────────────────────────────────────────────────────────

--- Add `count` of `itemId` to the inventory.
--- Stacks into existing slots first, then uses empty slots.
--- Returns the number of items that could NOT be added (0 = success).
function inventory.addItem(itemId, count)
    local def = items.get(itemId)
    if not def then return count end

    local remaining = count

    -- Pass 1: stack into existing slots that have the same item
    for i = 1, MAX_SLOTS do
        if remaining <= 0 then break end
        if slots[i] and slots[i].itemId == itemId then
            local space = def.maxStack - slots[i].count
            local add   = math.min(space, remaining)
            slots[i].count = slots[i].count + add
            remaining = remaining - add
        end
    end

    -- Pass 2: fill empty slots
    for i = 1, MAX_SLOTS do
        if remaining <= 0 then break end
        if slots[i] == nil then
            local add = math.min(def.maxStack, remaining)
            slots[i] = { itemId = itemId, count = add }
            remaining = remaining - add
        end
    end

    return remaining
end

--- Remove `count` items from `slotIndex`. Clears slot when count reaches 0.
function inventory.removeItem(slotIndex, count)
    local s = slots[slotIndex]
    if not s then return end
    s.count = s.count - (count or 1)
    if s.count <= 0 then slots[slotIndex] = nil end
end

--- Use the item in `slotIndex` (calls onUse with the player table).
function inventory.useItem(slotIndex, player)
    local s = slots[slotIndex]
    if not s then return end
    local def = items.get(s.itemId)
    if def and def.onUse then
        def.onUse(player)
        inventory.removeItem(slotIndex, 1)
    end
end

-- ── Open / Close ──────────────────────────────────────────────────────────────

function inventory.toggle()
    open = not open
    if not open then
        contextMenu  = nil
        hoveredSlot  = nil
        lastHoveredCtx = nil
        lastHoveredSlot = nil
    end
end

function inventory.isOpen()
    return open
end

-- ── Slot position helpers ─────────────────────────────────────────────────────

local function slotRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    local x = panelX + PANEL_PAD + col * (SLOT_SIZE + SLOT_GAP)
    local y = panelY + PANEL_PAD + 42 + row * (SLOT_SIZE + SLOT_GAP)
    return x, y, SLOT_SIZE, SLOT_SIZE
end

local function slotAtPoint(vx, vy)
    for i = 1, MAX_SLOTS do
        local sx, sy, sw, sh = slotRect(i)
        if vx >= sx and vx <= sx + sw and vy >= sy and vy <= sy + sh then
            return i
        end
    end
    return nil
end

-- ── Input ─────────────────────────────────────────────────────────────────────

function inventory.keypressed(key)
    if key == "tab" then
        -- Tab always toggles
        inventory.toggle()
        ui_audio.playClick()
    elseif key == "escape" and open then
        -- Escape only closes (never opens)
        inventory.toggle()
        ui_audio.playClick()
    end
end

--- Returns a plain serialisable representation of inventory slots.
function inventory.getSlots()
    local out = {}
    for i = 1, MAX_SLOTS do
        if slots[i] then
            out[i] = { itemId = slots[i].itemId, count = slots[i].count }
        end
    end
    return out
end

--- Restores inventory from a previously saved slots table.
function inventory.setSlots(saved)
    slots = {}
    for i = 1, MAX_SLOTS do slots[i] = nil end
    if not saved then return end
    for i, entry in pairs(saved) do
        local idx = tonumber(i)
        if idx and entry.itemId and entry.count then
            slots[idx] = { itemId = entry.itemId, count = entry.count }
        end
    end
end

function inventory.mousemoved(vx, vy)
    if not open then return end
    -- Only update hover when no context menu is active
    if not contextMenu then
        hoveredSlot = slotAtPoint(vx, vy)
    end
end

function inventory.mousepressed(vx, vy, button, player)
    if not open then return end

    -- If context menu is visible, check its buttons first
    if contextMenu then
        local cm = contextMenu
        local bw, bh = 110, 34
        local hitAny = false
        for i, action in ipairs(cm.actions) do
            local bx = cm.x
            local by = cm.y + (i - 1) * (bh + 4)
            if vx >= bx and vx <= bx + bw and vy >= by and vy <= by + bh then
                ui_audio.playClick()
                action.fn()
                contextMenu = nil
                lastHoveredCtx = nil
                hitAny = true
                break
            end
        end
        if not hitAny then
            -- Click outside context menu: dismiss
            contextMenu  = nil
            lastHoveredCtx = nil
            hoveredSlot = slotAtPoint(vx, vy)
        end
        return
    end

    -- Left / right click on slots
    local idx = slotAtPoint(vx, vy)
    if not idx then return end

    if button == 2 and slots[idx] then
        -- Right-click: open context menu
        ui_audio.playClick()
        hoveredSlot = nil

        -- Offset so the menu appears just below–right of the cursor
        local cmX = math.min(vx + 6, VIRTUAL_W - 130)
        local cmY = math.min(vy + 6, VIRTUAL_H - 100)
        local def = items.get(slots[idx].itemId)

        local actions = {}
        if def and def.onUse then
            table.insert(actions, {
                label = "Use",
                fn    = function()
                    inventory.useItem(idx, player)
                end
            })
        end
        table.insert(actions, {
            label = "Discard",
            fn    = function()
                slots[idx] = nil
            end
        })

        contextMenu = {
            slotIndex = idx,
            x = cmX,
            y = cmY,
            actions = actions,
        }
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function inventory.update(dt, vx, vy)
    if not open then return end

    -- Hover audio for context menu buttons
    if contextMenu then
        local cm = contextMenu
        local bw, bh = 110, 34
        local hovId = nil
        for i, action in ipairs(cm.actions) do
            local bx = cm.x
            local by = cm.y + (i - 1) * (bh + 4)
            if vx >= bx and vx <= bx + bw and vy >= by and vy <= by + bh then
                hovId = "ctx_" .. i
                break
            end
        end
        if hovId ~= lastHoveredCtx then
            if hovId then ui_audio.playHover() end
            lastHoveredCtx = hovId
        end

    else
        -- Hover audio for slots
        local newHov = slotAtPoint(vx, vy)
        if newHov ~= lastHoveredSlot then
            if newHov then
                ui_audio.playHover()
            end
            lastHoveredSlot = newHov
        end
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

local function drawPanel()
    local w, h = VIRTUAL_W, VIRTUAL_H
    panelX = math.floor(w / 2 - PANEL_W / 2)
    panelY = math.floor(h / 2 - PANEL_H / 2)

    -- Dim overlay
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, PANEL_W, PANEL_H, 5)

    -- Panel base (stone slate)
    love.graphics.setColor(0.09, 0.09, 0.09, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, PANEL_W, PANEL_H, 4)

    -- Top highlight (ivory sheen)
    love.graphics.setColor(0.7, 0.7, 0.65, 0.18)
    love.graphics.rectangle("fill", panelX + 4, panelY + 1, PANEL_W - 8, 2, 1)

    -- Outer border (weathered stone)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.42, 0.40, 0.38, 0.85)
    love.graphics.rectangle("line", panelX, panelY, PANEL_W, PANEL_H, 4)

    -- Chipped corner accents
    local function chip(cx, cy, cw, ch)
        love.graphics.line(cx, cy + 3, cx + 3, cy)
        love.graphics.line(cx + cw - 3, cy, cx + cw, cy + 3)
        love.graphics.line(cx + cw, cy + ch - 3, cx + cw - 3, cy + ch)
        love.graphics.line(cx + 3, cy + ch, cx, cy + ch - 3)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.55, 0.53, 0.50, 0.6)
    chip(panelX, panelY, PANEL_W, PANEL_H)

    -- Inset border line
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("line", panelX + 8, panelY + 8, PANEL_W - 16, PANEL_H - 16)

    -- Title
    local titleFont = hud.getFont("button")
    love.graphics.setFont(titleFont)
    local title = "Inventory"
    local tw = titleFont:getWidth(title)

    -- Tab hint (right-aligned)
    local hintFont = hud.getFont("small")
    love.graphics.setFont(hintFont)
    local hint = "[Tab] Close"
    local hw = hintFont:getWidth(hint)
    love.graphics.setColor(0.5, 0.5, 0.48, 0.6)
    love.graphics.print(hint, panelX + PANEL_W - hw - 12, panelY + 13)

    -- Title text
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(title, panelX + PANEL_W / 2 - tw / 2 + 1, panelY + 11)
    love.graphics.setColor(0.85, 0.85, 0.80, 0.9)
    love.graphics.print(title, panelX + PANEL_W / 2 - tw / 2, panelY + 10)

    -- Divider under title
    for i = 0, PANEL_W - PANEL_PAD * 2 do
        local a = (1 - math.abs(i - (PANEL_W - PANEL_PAD * 2) / 2) / ((PANEL_W - PANEL_PAD * 2) / 2)) * 0.35
        love.graphics.setColor(0.7, 0.7, 0.65, a)
        love.graphics.points(panelX + PANEL_PAD + i, panelY + PANEL_PAD + 34)
    end
end

local function drawSlots(vx, vy, animTimer)
    local smallFont = hud.getFont("small")

    for i = 1, MAX_SLOTS do
        local sx, sy, sw, sh = slotRect(i)
        local isHover = (hoveredSlot == i) and (contextMenu == nil)

        -- Slot base
        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.rectangle("fill", sx, sy, sw, sh, 2)

        -- Slot border
        love.graphics.setLineWidth(1)
        if isHover then
            love.graphics.setColor(1, 0.9, 0.8, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.55, 0.4)
        end
        love.graphics.rectangle("line", sx, sy, sw, sh, 2)

        -- Hover glow (additive)
        if isHover then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0, 0.5, 0.8, 0.15)
            love.graphics.rectangle("fill", sx, sy, sw, sh, 2)
            love.graphics.setBlendMode("alpha")
        end

        -- Item contents
        if slots[i] then
            local def = items.get(slots[i].itemId)
            if def then
                local icon = items.getIcon(slots[i].itemId)
                if icon then
                    local iw, ih = icon:getDimensions()
                    local scale  = math.min((sw - 6) / iw, (sh - 6) / ih)
                    local ix = sx + sw / 2 - (iw * scale) / 2
                    local iy = sy + sh / 2 - (ih * scale) / 2
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(icon, ix, iy, 0, scale, scale)
                end

                -- Stack count badge (bottom-right)
                if slots[i].count > 1 then
                    love.graphics.setFont(smallFont)
                    local numStr = tostring(slots[i].count)
                    local nw = smallFont:getWidth(numStr)
                    -- Shadow
                    love.graphics.setColor(0, 0, 0, 0.9)
                    love.graphics.print(numStr, sx + sw - nw - 3 + 1, sy + sh - smallFont:getHeight() - 1 + 1)
                    -- Face
                    love.graphics.setColor(0.95, 0.90, 0.75, 1)
                    love.graphics.print(numStr, sx + sw - nw - 3, sy + sh - smallFont:getHeight() - 1)
                end
            end
        end
    end
end

--- Draw tooltip to the LEFT of the cursor for the hovered slot.
local function drawTooltip(vx, vy)
    if not hoveredSlot or contextMenu then return end
    local s = slots[hoveredSlot]
    if not s then return end
    local def = items.get(s.itemId)
    if not def then return end

    local buttonFont = hud.getFont("button")
    local smallFont  = hud.getFont("small")

    local ttW   = 200
    local nameH = buttonFont:getHeight()
    -- Wrap description
    local descLines = {}
    local words = {}
    for word in (def.description .. " "):gmatch("([^ ]+) ") do
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

    local descH = #descLines * smallFont:getHeight()
    local ttH   = 14 + nameH + 6 + descH + 10

    -- Position: left of cursor, clamped to screen
    local ttX = vx - ttW - 14
    local ttY = vy - ttH / 2
    ttX = math.max(4, math.min(ttX, VIRTUAL_W - ttW - 4))
    ttY = math.max(4, math.min(ttY, VIRTUAL_H - ttH - 4))

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", ttX + 4, ttY + 4, ttW, ttH, 3)

    -- Slate bg
    love.graphics.setColor(0.09, 0.09, 0.09, 0.96)
    love.graphics.rectangle("fill", ttX, ttY, ttW, ttH, 3)

    -- Border
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.42, 0.40, 0.38, 0.85)
    love.graphics.rectangle("line", ttX, ttY, ttW, ttH, 3)

    -- Item name
    love.graphics.setFont(buttonFont)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(def.name, ttX + 9, ttY + 8)
    love.graphics.setColor(0.85, 0.85, 0.80, 1)
    love.graphics.print(def.name, ttX + 8, ttY + 7)

    -- Divider
    love.graphics.setColor(0.42, 0.40, 0.38, 0.4)
    love.graphics.line(ttX + 8, ttY + 8 + nameH + 3, ttX + ttW - 8, ttY + 8 + nameH + 3)

    -- Description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.72, 0.70, 0.65, 0.9)
    for j, dl in ipairs(descLines) do
        love.graphics.print(dl, ttX + 8, ttY + 8 + nameH + 6 + (j - 1) * smallFont:getHeight())
    end
end

--- Draw the right-click context menu.
local function drawContextMenu(vx, vy)
    if not contextMenu then return end
    local cm = contextMenu
    local bw, bh = 110, 34
    local menuH = #cm.actions * (bh + 4) - 4
    local menuW = bw + 16
    local menuX = cm.x - 8
    local menuY = cm.y - 8

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", menuX + 4, menuY + 4, menuW, menuH + 16, 3)

    -- Background
    love.graphics.setColor(0.10, 0.10, 0.10, 0.97)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH + 16, 3)

    -- Border
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.42, 0.40, 0.38, 0.85)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH + 16, 3)

    for i, action in ipairs(cm.actions) do
        local bx = cm.x
        local by = cm.y + (i - 1) * (bh + 4)
        local isHov = vx >= bx and vx <= bx + bw and vy >= by and vy <= by + bh
        hud.drawStoneTablet(bx, by, bw, bh, action.label, isHov, false)
    end
end

function inventory.draw(vx, vy)
    if not open then return end

    local animTimer = hud and hud.animTimer or 0

    drawPanel()
    drawSlots(vx, vy, animTimer)
    drawTooltip(vx, vy)
    drawContextMenu(vx, vy)

    -- Reset font so nothing downstream breaks
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    hud.resetFont()
end

return inventory
