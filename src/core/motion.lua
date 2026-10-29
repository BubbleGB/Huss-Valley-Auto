function Core.observeMotion(previous,position,now,reported)
    local velocity=flat(reported or Vector3.zero)
    local acceleration=Vector3.zero
    if velocity.Magnitude>100 then velocity=Vector3.zero end
    if previous then
        local elapsed=now-previous.time
        if elapsed>=0.025 and elapsed<=0.5 then
            local measured=flat(position-previous.position)/elapsed
            if measured.Magnitude>100 then velocity=Vector3.zero
            else
                velocity=(previous.velocity or velocity):Lerp(measured,0.7)
                acceleration=(velocity-(previous.velocity or velocity))/elapsed
                if acceleration.Magnitude>120 then acceleration=acceleration.Unit*120 end
                acceleration=(previous.acceleration or Vector3.zero):Lerp(acceleration,0.4)
            end
        elseif elapsed<0.025 then return previous end
    end
    return {position=position,time=now,velocity=velocity,acceleration=acceleration}
end

function Core.distanceAt(time,currentSpeed,maxSpeed,acceleration,deceleration)
    time=math.max(0,time);maxSpeed=math.max(1,maxSpeed);currentSpeed=math.max(0,currentSpeed)
    acceleration=math.max(0.1,acceleration)
    if currentSpeed>maxSpeed then
        deceleration=math.max(0.1,deceleration or acceleration)
        local braking=(currentSpeed-maxSpeed)/deceleration
        local first=math.min(time,braking)
        return currentSpeed*first-0.5*deceleration*first*first+math.max(0,time-braking)*maxSpeed
    end
    local ramp=(maxSpeed-currentSpeed)/acceleration
    local first=math.min(time,ramp)
    return currentSpeed*first+0.5*acceleration*first*first+math.max(0,time-ramp)*maxSpeed
end

function Core.travelTime(distance,maxSpeed,acceleration,currentSpeed)
    distance=math.max(0,distance)
    local low,high=0,distance/math.max(1,maxSpeed)+math.max(1,maxSpeed)/math.max(0.1,acceleration)+2
    for _=1,20 do
        local middle=(low+high)/2
        if Core.distanceAt(middle,currentSpeed,maxSpeed,acceleration)>=distance then high=middle else low=middle end
    end
    return high
end

