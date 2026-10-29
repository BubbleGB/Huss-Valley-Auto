function Core.speedMultiplier(value)
    return 1+math.floor((math.clamp(value,1,2)-1)*20+.5)/20
end

function Core.scaleSpeedProfile(profile,multiplier,instant)
    local scaled=table.clone(profile)
    scaled.MaxSpeed=profile.MaxSpeed*multiplier
    if instant then
        scaled.Acceleration=1000000
        scaled.StallSpeedCap=scaled.MaxSpeed
    end
    return table.freeze(scaled)
end

