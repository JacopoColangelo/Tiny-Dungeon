local ui_audio = {}

local clickSound
local hoverSound
local hoverCooldown = 0
local COOLDOWN_TIME = 0.07 -- Prevent "spam" sounds when hovering fast
local UI_VOL_SCALE = 0.7    -- Standard volume for UI sounds

function ui_audio.load()
    clickSound = love.audio.newSource("assets/audio/button_click.wav", "static")
    hoverSound = love.audio.newSource("assets/audio/button_hover.wav", "static")
    
    clickSound:setVolume(UI_VOL_SCALE)
    hoverSound:setVolume(UI_VOL_SCALE)
end

function ui_audio.update(dt)
    if hoverCooldown > 0 then
        hoverCooldown = hoverCooldown - dt
    end
end

function ui_audio.playClick()
    if clickSound then
        clickSound:stop()
        clickSound:play()
    end
end

function ui_audio.playHover()
    if hoverSound and hoverCooldown <= 0 then
        hoverSound:stop()
        hoverSound:play()
        hoverCooldown = COOLDOWN_TIME
    end
end

return ui_audio
