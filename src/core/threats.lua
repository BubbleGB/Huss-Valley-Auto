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
function Core.threatApproach(position,ownVelocity,enemy,horizon,radius)
    if math.abs(enemy.position.Y-position.Y)>12 and not enemy.airborne then return math.huge,math.huge end
    horizon=math.max(0,math.min(horizon,enemy.expires or horizon))
    local burst=math.clamp(enemy.burstFor or horizon,0,horizon)
    local relative=flat(enemy.position-position)
    local best,eta=math.huge,math.huge
    local function segment(start,duration,travel)
        local velocity=flat(travel-ownVelocity)
        local square=velocity:Dot(velocity)
        local at=square>.0001 and math.clamp(-relative:Dot(velocity)/square,0,duration)or 0
        best=math.min(best,(relative+velocity*at).Magnitude-radius)
        local c=relative:Dot(relative)-radius*radius
        if c<=0 then eta=math.min(eta,start)
        elseif square>.0001 then
            local b=2*relative:Dot(velocity)
            local disc=b*b-4*square*c
            if disc>=0 then
                local contact=(-b-math.sqrt(disc))/(2*square)
                if contact>=0 and contact<=duration then eta=math.min(eta,start+contact)end
            end
        end
        relative=relative+velocity*duration
    end
    segment(0,burst,enemy.velocity)
    if burst<horizon then segment(burst,horizon-burst,enemy.afterVelocity or enemy.velocity)end
    return best,eta
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

