function Core.dynamicIntercept(position,targetPosition,velocity,profile,ownVelocity,targetProfile,acceleration,reach,horizon)
    local delta=flat(targetPosition-position)
    velocity=flat(velocity)
    if delta.Magnitude<=reach then return targetPosition,0 end
    local current=math.max(0,flat(ownVelocity):Dot(delta.Unit))
    acceleration=flat(acceleration or Vector3.zero)
    local limit=targetProfile.Acceleration or 60
    if acceleration.Magnitude>limit then acceleration=acceleration.Unit*limit end
    acceleration=acceleration*0.5
    local maxSpeed=math.max(1,targetProfile.MaxSpeed or velocity.Magnitude)
    local point,time
    local count=math.max(1,math.ceil(horizon/0.05))
    for i=1,count do
        time=horizon*i/count
        if velocity.Magnitude>maxSpeed then
            local burst=math.min(time,targetProfile.BurstRemaining or 0)
            local distance=velocity.Magnitude*burst+Core.distanceAt(time-burst,velocity.Magnitude,maxSpeed,
                targetProfile.Acceleration or 60,targetProfile.Deceleration or 66)
            point=targetPosition+flat(velocity).Unit*distance
        else
            local future=flat(velocity)+acceleration*time
            if future.Magnitude>maxSpeed then future=future.Unit*maxSpeed end
            point=targetPosition+(flat(velocity)+future)*(time*0.5)
        end
        local travel=Core.distanceAt(time,current,profile.MaxSpeed,profile.Acceleration,profile.Deceleration)
        if flat(point-position).Magnitude<=travel+reach then return point,time end
    end
    return point,time
end

