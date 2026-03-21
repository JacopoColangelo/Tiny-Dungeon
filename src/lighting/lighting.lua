local lighting = {}

-- Adjustable intensity for the portal's mystical glow (Default: 2.5)
lighting.portalIntensity = 2.5

-- Canvases and shaders (created in lighting.load)
local lightCanvas
local blurCanvas
local blurShader

function lighting.load()
    local w, h = 1280, 720
    lightCanvas = love.graphics.newCanvas(w, h)
    blurCanvas  = love.graphics.newCanvas(w, h)
    blurShader  = love.graphics.newShader("assets/shaders/blur.glsl")
end

-- ── Steps 2–4: Light mask, stencil, torch rings, blur passes ─────────────────
-- Draws onto the provided screenCanvas using multiply blend.

function lighting.drawLightMask(screenCanvas, player, camera, sx, sy, portalX, portalY, portalShadowPolygon)
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
        for i = 50, 1, -1 do
            local radius = currentTorch * (i / 50)
            local fraction = i / 50
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

        love.graphics.setStencilTest()

        -- 2b. DRAW PORTAL LIGHT (Vibrant Light Purple with Shadows)
        -- Draw outside player stencil so it acts as an independent light source
        if portalX and portalY and portalShadowPolygon then
            
            -- stencil for portal (illuminated area = 1)
            local function drawPortalStencil()
                -- 1. Fill illuminated area from walls
                if #portalShadowPolygon > 2 then
                    for i = 1, #portalShadowPolygon - 1 do
                        local p1 = portalShadowPolygon[i]
                        local p2 = portalShadowPolygon[i+1]
                        love.graphics.polygon("fill", portalX, portalY, p1.x, p1.y, p2.x, p2.y)
                    end
                    local p1 = portalShadowPolygon[#portalShadowPolygon]
                    local p2 = portalShadowPolygon[1]
                    love.graphics.polygon("fill", portalX, portalY, p1.x, p1.y, p2.x, p2.y)
                end
            end
            
            -- Set stencil to 1 where light hits
            love.graphics.stencil(drawPortalStencil, "replace", 1)
            
            -- 2. Subtract player's dynamic shadow from the portal stencil
            -- We draw a polygon extending from the player away from the portal, setting stencil to 0
            local function carvePlayerShadow()
                local dx = px - portalX
                local dy = py - portalY
                local distMap = math.sqrt(dx*dx + dy*dy)
                if distMap < 400 and distMap > 10 then -- Only cast if within light range
                    local angle = math.atan2(dy, dx)
                    local perp = angle + math.pi/2
                    local w = player.size * 0.45 -- shadow width
                    
                    local p1x = px + math.cos(perp) * w
                    local p1y = py + math.sin(perp) * w
                    local p2x = px - math.cos(perp) * w
                    local p2y = py - math.sin(perp) * w
                    
                    local rayLen = 500
                    local p3x = p2x + math.cos(angle) * rayLen
                    local p3y = p2y + math.sin(angle) * rayLen
                    local p4x = p1x + math.cos(angle) * rayLen
                    local p4y = p1y + math.sin(angle) * rayLen
                    
                    love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
                end
            end
            
            -- "replace" with 0 effectively removes the light where the player's shadow falls
            love.graphics.stencil(carvePlayerShadow, "replace", 0, true) -- true = keep previous stencil values everywhere else

            love.graphics.setStencilTest("greater", 0)

            love.graphics.setBlendMode("add")
            local pRadius = 320 -- Much stronger, larger glow
            for i = 120, 1, -1 do
                local radius = pRadius * (i / 120)
                local lerp = 1.0 - i / 120
                local pIntensity = lighting.portalIntensity

                local r = 0.2 * lerp * pIntensity -- Less deep purple
                local g = 0.02 * lerp * pIntensity -- Adding cyan/green
                local b = 0.3 * lerp * pIntensity -- Bright blue

                love.graphics.setColor(r, g, b, 1)
                love.graphics.circle("fill", portalX, portalY, radius)
            end
            love.graphics.setStencilTest()
        end

        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
    love.graphics.setCanvas()

    -- 3. HORIZONTAL BLUR PASS (Render to blurCanvas)
    love.graphics.setCanvas(blurCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(blurShader)

    -- 20.0 is the blur radius strength (scaled for 720p)
    blurShader:send("direction", {1.0 / 1280, 0.0})
    blurShader:send("radius", 20.0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(lightCanvas)

    love.graphics.setCanvas()

    -- 4. VERTICAL BLUR PASS & APPLY TO SCREEN CANVAS
    love.graphics.setCanvas(screenCanvas)
    love.graphics.setShader(blurShader)
    blurShader:send("direction", {0.0, 1.0 / 720})
    blurShader:send("radius", 20.0)

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
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

function lighting.drawPortalBloom(portalX, portalY, camera)
    if not portalX or not portalY then return end
    
    love.graphics.push()
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    love.graphics.setBlendMode("add")

    -- Mystical cyan/purple bloom
    for i = 150, 1, -1 do
        local r = 620 * (i / 150)
        local a = (1 - (i / 150)) * 0.01
        -- Cyan to purple gradient
        love.graphics.setColor(0.5, 0.5, 1, a)
        love.graphics.circle("fill", portalX, portalY, r)
        
        love.graphics.setColor(0.7, 0.4, 0.9, a * 0.5)
        love.graphics.circle("fill", portalX, portalY, r * 0.1)
    end
    
    -- Bright core
    love.graphics.setColor(0.8, 0.9, 1.0, 0.7)
    love.graphics.circle("fill", portalX, portalY, 1)

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return lighting
