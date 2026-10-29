function Core.closeCharge(relative,allowed)
    local delta=flat(relative)
    if math.abs(relative.Y)>3 or delta.Magnitude<.1 or delta.Magnitude>12 then return nil end
    local aim=delta.Unit
    return allowed(aim,delta.Magnitude)and aim or nil
end

function Core.strategyThreat(enemy,urgency)
    local result=table.clone(enemy)
    local inner=enemy.catchRadius or math.min(enemy.radius,8)
    result.radius=math.max(enemy.hardRadius or 0,inner+(enemy.radius-inner)*(1-math.clamp(urgency,0,1)))
    return result
end

-- Finite committed motion followed by ordinary travel; returns clearance and first contact.
function Core.threatApproach(position,ownVelocity,enemy,horizon,radius,offset)
    offset=offset or 0
    local velocity,after=enemy.velocity,enemy.afterVelocity or enemy.velocity
    local first=enemy.burstFor and math.min(offset,math.max(0,enemy.burstFor))or offset
    local tail=offset-first
    local y=enemy.position.Y+velocity.Y*first+after.Y*tail
    if math.abs(y-position.Y)>12 and not enemy.airborne then return math.huge,math.huge end
    local requested=math.max(0,horizon)
    horizon=math.max(0,math.min(requested,enemy.expires and enemy.expires-offset or requested))
    local burst=enemy.burstFor and math.clamp(enemy.burstFor-offset,0,horizon)or horizon
    local current=enemy.burstFor and offset>=enemy.burstFor and after or velocity
    local x=enemy.position.X-position.X+velocity.X*first+after.X*tail
    local z=enemy.position.Z-position.Z+velocity.Z*first+after.Z*tail
    local initial=x*x+z*z
    local best,eta=math.huge,math.huge
    for part=1,2 do
        local duration=part==1 and burst or horizon-burst
        if part==2 and duration<=0 then break end
        local travel=part==1 and current or after
        local vx,vz=travel.X-ownVelocity.X,travel.Z-ownVelocity.Z
        local square=vx*vx+vz*vz
        local dot=x*vx+z*vz
        local at=square>.0001 and math.clamp(-dot/square,0,duration)or 0
        local dx,dz=x+vx*at,z+vz*at
        best=math.min(best,dx*dx+dz*dz)
        local c=x*x+z*z-radius*radius
        local start=part==1 and 0 or burst
        if c<=0 then eta=math.min(eta,start)
        elseif square>.0001 then
            local b=2*dot
            local disc=b*b-4*square*c
            if disc>=0 then
                local contact=(-b-math.sqrt(disc))/(2*square)
                if contact>=0 and contact<=duration then eta=math.min(eta,start+contact)end
            end
        end
        x=x+vx*duration;z=z+vz*duration
    end
    local clearance=math.sqrt(best)-radius
    if clearance<0 then
        local ending=offset+requested
        local phase=enemy.burstFor and math.min(ending,math.max(0,enemy.burstFor))or ending
        local tail=ending-phase
        local ex=enemy.position.X-position.X+velocity.X*phase+after.X*tail-ownVelocity.X*requested
        local ez=enemy.position.Z-position.Z+velocity.Z*phase+after.Z*tail-ownVelocity.Z*requested
        return clearance,eta,math.sqrt(initial)-radius,math.sqrt(ex*ex+ez*ez)-radius
    end
    return clearance,eta
end

function Core.abilityThreat(actor,character,root,velocity,now,config)
    local function attr(name)
        local a,b=actor:GetAttribute(name),character:GetAttribute(name)
        if type(a)=='number'and type(b)=='number'then return math.max(a,b)end
        return a~=nil and a or b
    end
    local function remaining(name)return math.max(0,(tonumber(attr(name))or 0)-now)end
    local speed=flat(velocity).Magnitude
    local forward=flat(root.CFrame.LookVector)
    forward=forward.Magnitude>.01 and forward.Unit or Vector3.zAxis
    local travel=speed>3 and flat(velocity).Unit or forward
    local normal=config.maxSpeed or 35
    local radius,catch=config.radius,config.catchRadius
    local result={position=root.Position,velocity=flat(velocity),radius=radius,catchRadius=catch,actor=actor,
        forward=forward,diveReadyIn=remaining('TackleReadyAt'),diveDistance=config.diveDistance or 15,diveHalfWidth=config.diveHalfWidth or 4.5,
        diving=attr('TackleActive')==true,reaching=attr('ReachPhase')=='Windup'or attr('ReachPhase')=='Active'}
    local rocket,cannon,step=remaining('RocketUntil'),remaining('CannonUntil'),remaining('StepOverUntil')
    local skin=attr('EquippedKnife')or attr('DaggerSkin')
    local cannonConfig=config.cannon or{Distance=15,Flight=.7,MaxMomentum=32,CarrySeconds=.5}
    local stepConfig=config.stepOver or{BigDistance=12,BigTime=.36,FakeTime=.42,CarrySeconds=.6}
    if rocket>0 or attr('GearMotion')==true then
        result.kind='Rocket';result.velocity=travel*math.max(64,speed)
        result.burstFor=math.min(rocket>0 and rocket or .42,1.02)
    elseif cannon>0 then
        result.kind='Cannon';result.airborne=true
        result.velocity=travel*math.max(speed,cannonConfig.Distance/cannonConfig.Flight+math.min(normal,cannonConfig.MaxMomentum))
        result.burstFor=math.min(cannon,cannonConfig.Flight+cannonConfig.CarrySeconds)
    elseif step>0 then
        result.kind='StepOver';result.lateralRadius=stepConfig.BigDistance+2
        result.velocity=flat(velocity);result.burstFor=math.min(step,stepConfig.FakeTime+stepConfig.BigTime+stepConfig.CarrySeconds)
    elseif result.diving then
        local aim=attr('TackleDirection')
        if typeof(aim)=='Vector3'and flat(aim).Magnitude>.01 then travel=flat(aim).Unit end
        local duration=tonumber(attr('TackleDuration'))or .35
        local started=tonumber(attr('TackleStartedAt'))or now
        result.kind='Dive';result.velocity=travel*math.max(speed,40)
        result.burstFor=math.clamp(started+duration-now,.03,.6)
    elseif speed>math.max(45,normal*1.25)or remaining('DashUntil')>0 then
        result.kind='Burst';result.velocity=flat(velocity)
        result.burstFor=math.min(math.max(remaining('DashUntil'),.25),.8)
    end
    if result.kind then
        result.activeAbility=true;result.hardRadius=catch+2+(result.lateralRadius or 0)
        result.radius=result.hardRadius
        result.afterVelocity=travel*math.min(speed,normal)
    elseif config.ready and not config.knifeBlocked and skin=='AlbiesCutlass'and remaining('CannonReadyAt')<=0 then
        result.potentialAbility='Cannon'
        result.potentialVelocity=travel*(cannonConfig.Distance/cannonConfig.Flight+math.min(normal,cannonConfig.MaxMomentum))
        result.potentialFor=cannonConfig.Flight
    elseif config.ready and not config.knifeBlocked and skin=='Futbol'and remaining('StepOverReadyAt')<=0 then
        result.potentialAbility='StepOver';result.potentialVelocity=travel*normal;result.potentialFor=.6
        result.potentialRadius=catch+stepConfig.BigDistance
    elseif config.ready and remaining('AbilityReadyAt')<=0 and skin~='AlbiesCutlass'and skin~='Futbol'then
        -- Equipped gear is generally private. This is a possible lane, never an active-attack assertion.
        result.potentialAbility='UnknownGear';result.potentialVelocity=travel*64;result.potentialFor=.42
    end
    return result
end

function Core.threatZones(enemy,urgency)
    local adjusted=Core.strategyThreat(enemy,urgency or 0)
    local zones={adjusted}
    local duration=enemy.activeAbility and math.min(enemy.burstFor or .5,.7)or .25
    local radius=adjusted.radius
    local count=math.clamp(math.ceil(flat(enemy.velocity).Magnitude*duration/math.max(4,radius)),1,12)
    for i=1,count do
        zones[#zones+1]={position=enemy.position+enemy.velocity*(duration*i/count),radius=radius}
    end
    return zones,adjusted
end

function Core.projectileThreats(hazards)
    local result={}
    for _,h in ipairs(hazards)do
        if h.source and(h.kind=='BowlingBall'or h.kind=='RufusLeash')and h.velocity.Magnitude>1 then
            result[#result+1]={position=h.position,velocity=h.velocity,radius=h.radius,catchRadius=h.radius,
                hardRadius=h.radius,activeAbility=true,kind=h.kind,expires=h.remaining or .8}
        end
    end
    return result
end

