local lighting = {}

-- Canvases and shaders (created in lighting.load)
local lightCanvas
local blurCanvas
local blurShader

function lighting.load()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    lightCanvas = love.graphics.newCanvas(w, h)
    blurCanvas  = love.graphics.newCanvas(w, h)
    blurShader  = love.graphics.newShader("assets/shaders/blur.glsl")
end

-- ── Steps 2–4: Light mask, stencil, torch rings, blur passes ─────────────────
-- Draws onto the provided screenCanvas using multiply blend.

function lighting.drawLightMask(screenCanvas, player, camera, sx, sy)
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2
    local torchSize = player.torchSize

    -- 2. DRAW SHARP LIGHT MASK
    love.graphics.setCanvas({lightCanvas, stencil=true})
        -- Clear with pleasant dim dungeon ambient (0.35 brightness = 65% dark)
        love.graphics.clear(0.35, 0.35, 0.40, 1)

        love.graphics.push()
        love.graphics.translate(-math.floor(camera.x) + sx, -math.floor(camera.y) + sy)

        local function drawStencil()
            if player.shadowPolygon and #player.shadowPolygon > 2 then
                for i = 1, #player.shadowPolygon - 1 do
                    local p1 = player.shadowPolygon[i]
                    local p2 = player.shadowPolygon[i+1]
                    love.graphics.polygon("fill", px, py, p1.x, p1.y, p2.x, p2.y)
                end
                local p1 = player.shadowPolygon[#player.shadowPolygon]
                local p2 = player.shadowPolygon[1]
                love.graphics.polygon("fill", px, py, p1.x, p1.y, p2.x, p2.y)
            end
        end

        love.graphics.stencil(drawStencil, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        local flicker = math.sin(love.timer.getTime() * 6) * 15
        local currentTorch = torchSize + flicker

        -- Replace blend clears the ambient grey to the pure radial lighting brightness
        love.graphics.setBlendMode("replace")
        for i = 15, 1, -1 do
            local radius = currentTorch * (i / 15)
            local fraction = i / 15
            local lerp = 1.0 - fraction
            local torchIntensity = 1.4

            -- Tint light to warm vibrant orange/yellow torch hue, fading perfectly into the 35% light ambient
            local r = 0.35 + (1.0 - 0.35) * lerp * torchIntensity
            local g = 0.35 + (0.80 - 0.35) * lerp * torchIntensity
            local b = 0.40 + (0.50 - 0.40) * lerp * torchIntensity

            love.graphics.setColor(r, g, b, 1)
            love.graphics.circle("fill", px, py, radius)
        end

        love.graphics.setStencilTest()
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    love.graphics.setCanvas()

    -- 3. HORIZONTAL BLUR PASS (Render to blurCanvas)
    love.graphics.setCanvas(blurCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(blurShader)

    -- 16.0 is the blur radius strength
    blurShader:send("direction", {1.0 / love.graphics.getWidth(), 0.0})
    blurShader:send("radius", 16.0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(lightCanvas)

    love.graphics.setCanvas()

    -- 4. VERTICAL BLUR PASS & APPLY TO SCREEN CANVAS
    love.graphics.setCanvas(screenCanvas)
    love.graphics.setShader(blurShader)
    blurShader:send("direction", {0.0, 1.0 / love.graphics.getHeight()})
    blurShader:send("radius", 16.0)

    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(blurCanvas)

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
end

-- ── Step 5: Emissive player bloom ────────────────────────────────────────────

function lighting.drawBloom(player, camera)
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    love.graphics.setBlendMode("add")
    local px = player.x + player.size / 2
    local py = player.y + player.size / 2

    -- Warm torch bloom (circles)
    for i = 20, 1, -1 do
        local r = 50 * (i / 20)
        local a = (1 - (i / 20)) * 0.06
        love.graphics.setColor(1.0, 0.6, 0.2, a)
        love.graphics.circle("fill", px, py, r)
    end
    -- Solid white hot spark at center
    love.graphics.setColor(1, 1, 0.8, 0.8)
    love.graphics.circle("fill", px, py, 6)

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return lighting
