local camera = { 
    x = 0, y = 0, 
    lerpSpeed = 5,
    shakeTimer = 0,
    shakeIntensity = 0
}

function camera.addShake(intensity, duration)
    camera.shakeIntensity = math.max(camera.shakeIntensity, intensity)
    camera.shakeTimer = math.max(camera.shakeTimer, duration)
end

function camera.follow(player, dt)
    local targetX = player.x + player.size/2 - 1280/2
    local targetY = player.y + player.size/2 - 720/2
    camera.x = camera.x + (targetX - camera.x) * camera.lerpSpeed * dt
    camera.y = camera.y + (targetY - camera.y) * camera.lerpSpeed * dt
end

function camera.updateShake(dt)
    if camera.shakeTimer > 0 then
        camera.shakeTimer = camera.shakeTimer - dt
        if camera.shakeTimer <= 0 then
            camera.shakeIntensity = 0
        end
    end
end

function camera.getShakeOffset()
    if camera.shakeTimer > 0 then
        local sx = (love.math.random() * 2 - 1) * camera.shakeIntensity
        local sy = (love.math.random() * 2 - 1) * camera.shakeIntensity
        return sx, sy
    end
    return 0, 0
end

function camera.snapTo(player)
    camera.x = player.x + player.size/2 - 1280/2
    camera.y = player.y + player.size/2 - 720/2
end

-- Expose globally so player.lua can reference it for screen feedback
_G.camera = camera

return camera
