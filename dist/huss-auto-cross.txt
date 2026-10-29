-- Huss Valley automatic crossing and chasing. Execute directly; starts paused.
-- getgenv().HussAutoCross:Start(), :Stop(), or :Destroy().
local Core = {}
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

function Core.canRun(enabled, inMatch, role, state, locked, mapChanging)
    return enabled and inMatch == true and role == 'Runner' and state == 'Active'
        and not locked and not mapChanging
end

function Core.canHunt(enabled, inMatch, role, state, locked, mapChanging)
    return enabled and inMatch == true and role == 'Catcher' and state == 'Active'
        and not locked and not mapChanging
end

function Core.isRunner(inMatch, role, state, health, locked,bot,anchored)
    return inMatch == true and role == 'Runner' and state == 'Active' and health > 0
        and not anchored and not(bot and locked)
end

-- Hysteresis keeps a pursuit stable. Require both a 35% and 4-stud advantage.
function Core.selectRunner(candidates, currentId, position)
    local hidden=false
    for _,candidate in ipairs(candidates)do if candidate.invisible then hidden=true;break end end
    local held, heldDistance, nearest, nearestDistance
    for _,candidate in ipairs(candidates) do
        if hidden and not candidate.invisible then continue end
        local distance = flat(candidate.position-position).Magnitude
        if candidate.id == currentId then held,heldDistance=candidate,distance end
        if not nearestDistance or distance < nearestDistance then nearest,nearestDistance=candidate,distance end
    end
    if held then
        if nearest.id ~= held.id and nearestDistance < heldDistance*0.65 and heldDistance-nearestDistance >= 4 then
            return nearest
        end
        return held
    end
    return nearest
end

function Core.selectChaseTarget(candidates,currentId,position)
    local close={}
    for _,candidate in ipairs(candidates)do
        local relative=candidate.position-position
        local threshold=candidate.id==currentId and 14 or 12
        if candidate.closeClear~=false and math.abs(relative.Y)<=3 and flat(relative).Magnitude<=threshold then close[#close+1]=candidate end
    end
    local pool=#close>0 and close or candidates
    local hidden=false
    for _,candidate in ipairs(pool)do if candidate.invisible then hidden=true;break end end
    local scores={}
    local held,best,nearest
    for _,candidate in ipairs(pool)do
        if hidden and not candidate.invisible then continue end
        local predicted=candidate.position+flat(candidate.velocity or Vector3.zero)*.25
        local weight,count=0,1
        for _,other in ipairs(candidates)do
            if other.id~=candidate.id then
                local point=other.position+flat(other.velocity or Vector3.zero)*.25
                local distance=flat(point-predicted).Magnitude
                if math.abs(point.Y-predicted.Y)<=4 and distance<14 then
                    weight=weight+1-distance/14;count=count+1
                end
            end
        end
        local distance=flat(candidate.position-position).Magnitude
        local score={distance=distance,cost=distance/(1+math.min(.75,.35*weight)),weight=weight,count=count,
            tier=#close>0 and'close'or'normal'}
        scores[candidate.id]=score
        if candidate.id==currentId then held=candidate end
        if not best or score.cost<scores[best.id].cost then best=candidate end
        if not nearest or distance<scores[nearest.id].distance then nearest=candidate end
    end
    if held then
        local current=scores[held.id]
        local near=nearest and scores[nearest.id]
        if nearest.id~=held.id and near.distance<current.distance*.65 and current.distance-near.distance>=4 then
            return nearest,near
        end
        local better=scores[best.id]
        if best.id~=held.id and better.weight>current.weight+.4 and better.cost<current.cost*.8 and current.cost-better.cost>=3 then
            return best,better
        end
        return held,current
    end
    return best,best and scores[best.id]
end

function Core.isInvisible(actor,character,now)
    for _,source in ipairs({actor,character})do
        if source then
            if source:GetAttribute('Cloaked')==true or source:GetAttribute('CloakActive')==true
                or source:GetAttribute('Invisible')==true then return true end
            for _,name in ipairs({'CloakUntil','CloakedUntil','InvisibleUntil'})do
                local untilAt=source:GetAttribute(name)
                if type(untilAt)=='number'and untilAt>now then return true end
            end
        end
    end
    if not character then return false end
    local torso=character:FindFirstChild('Torso')or character:FindFirstChild('UpperTorso')
    local head=character:FindFirstChild('Head')
    return torso and head and (torso.Transparency+head.Transparency)/2>=0.65 or false
end

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

function Core.runnerPolicy(seconds,distance,maxSpeed,acceleration,currentSpeed,chasers,runners,density,stalled,previousUrgency,elapsed,raceUrgency)
    local eta=Core.travelTime(distance,maxSpeed,acceleration,currentSpeed)
    local deadline=0
    if type(seconds)=='number'then deadline=1-math.clamp((seconds-eta-1)/math.max(eta*0.75,4),0,1)end
    local pressure=math.clamp((chasers/math.max(1,runners)-0.5)/2.5,0,1)*0.45
    local crowded=math.clamp(density/4,0,1)*0.35
    local delayed=math.clamp((stalled-1)/5,0,0.8)
    local urgency=math.max(deadline,pressure,crowded,delayed,raceUrgency or 0)
    if previousUrgency then urgency=math.max(urgency,previousUrgency-math.max(0,elapsed or 0)*0.15)end
    return {eta=eta,urgency=urgency,riskWeight=1-0.97*urgency,
        mode=urgency>=0.8 and'sprint'or urgency>=0.3 and'push'or'safe'}
end

function Core.racePressure(ownEta,competitors)
    local total,ahead,safe=1,0,0
    for _,runner in ipairs(competitors)do
        if runner.state=='Active'or runner.state=='Waiting'or runner.state=='Safe'then
            total=total+1
            if runner.state=='Safe'then safe=safe+1;ahead=ahead+1
            elseif runner.state=='Active'and type(runner.eta)=='number'and runner.eta<ownEta-.2 then ahead=ahead+1 end
        end
    end
    local quota=math.ceil(total/2)
    local urgency=total>1 and .25 or 0
    if total>1 and ahead>=quota then urgency=.9
    elseif ahead>=math.max(1,quota-1)then urgency=.65 end
    if safe>=quota then urgency=1 end
    return {total=total,projectedPlace=ahead+1,targetPlace=quota,safe=safe,urgency=urgency}
end

Core.SMART_POLICY='short-110-040-12-v1'
Core.SMART_PEAK=1.10

function Core.smartLimit(learned,jobId)
    if type(learned)=='table'and learned.jobId==jobId and learned.policy==Core.SMART_POLICY
        and type(learned.cap)=='number'and learned.cap==learned.cap then
        return math.clamp(learned.cap,1,Core.SMART_PEAK)
    end
    return Core.SMART_PEAK
end

function Core.smartSpeedStep(previous,now,enabled,eligible,nearest,epoch,corrected)
    local state=previous and previous.epoch==epoch and table.clone(previous)
        or{epoch=epoch,untilAt=0,readyAt=previous and previous.readyAt or 0,armed=true,watchUntil=0}
    if now>=state.untilAt then state.untilAt=0 end
    if nearest>=20 then state.armed=true end
    if corrected then
        state.untilAt=0;state.watchUntil=0;state.readyAt=math.max(state.readyAt,now+15);state.armed=false
        return state
    end
    if not enabled or not eligible then state.untilAt=0;return state end
    if state.untilAt==0 and state.armed and nearest<=12 and now>=state.readyAt then
        state.untilAt=now+.4;state.readyAt=now+12;state.watchUntil=now+4.4;state.armed=false
    end
    return state
end

function Core.effectiveSpeed(manual,enabled,state,now,limit)
    return enabled and state and state.untilAt>now and math.max(manual,math.clamp(limit or Core.SMART_PEAK,1,Core.SMART_PEAK))or manual
end

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

Core.TP_POLICY='short-234-12-2-v1'
function Core.tpChoice(context,candidates)
    if not context.enabled or not context.running or not context.eligible or context.blocked
        or context.now<(context.readyAt or 0)or(context.uses or 0)>=2 then return nil end
    local best,score
    for _,candidate in ipairs(candidates)do
        local attack=(context.attackETA or math.huge)<=.25 and not context.walkSafe and(candidate.attackETA or 0)>=.4
        local bypass=(context.stuck or 0)>=1.1 and(candidate.gain or 0)>=1
            and(candidate.hazardBlocked or candidate.pathBlocked and candidate.thinObstacle)
        local chase=context.role=='Catcher'and context.chaseReady and not context.currentCatch
            and candidate.catchOpportunity and(candidate.chaseGain or 0)>=1.5
        if candidate.distance>=1.9 and candidate.distance<=4 and candidate.landingSafe and candidate.exitSafe
            and(candidate.clearance or -math.huge)>=1.5 and(candidate.attackETA or 0)>=.4
            and(not candidate.pathBlocked or candidate.thinObstacle)and(attack or bypass or chase)then
            local value=-candidate.distance*10+math.min(3,candidate.clearance)*.2+math.min(3,candidate.gain or 0)*.1
            if not score or value>score then best,score=candidate,value end
        end
    end
    return best
end

function Core.tpObservation(watch,now,observed)
    if not watch then return 'idle'end
    if not observed.valid or observed.epoch~=watch.epoch or observed.phase~=watch.phase then return 'interrupted'end
    if observed.reset~=watch.reset then return 'corrected'end
    local dt=now-watch.at
    if dt>.15 then return 'uncertain'end
    if now>watch.untilAt then return 'complete'end
    if dt>0 and dt<=.15 then
        local expected=(flat(watch.velocity)+flat(observed.velocity))*(dt*.5)
        local residual=flat(observed.position-watch.position)-expected
        if residual.Magnitude>math.max(1.25,watch.distance*.55)then return 'corrected'end
    end
    return 'watching'
end

function Core.abilityState(actor,character,now)
    local function flag(name)return actor:GetAttribute(name)==true or character:GetAttribute(name)==true end
    local function untilAt(name)
        local a,b=actor:GetAttribute(name),character:GetAttribute(name)
        return math.max(type(a)=='number'and a or 0,type(b)=='number'and b or 0)
    end
    local function timer(name)return untilAt(name)>now end
    local burrowing=character:GetAttribute('Burrowing')
    if type(burrowing)=='number'then burrowing=burrowing>now else burrowing=burrowing~=nil and burrowing~=false end
    return {protected=timer('GhostImmuneUntil')or flag('Ghosted')or flag('FFAInvincible')or flag('Invulnerable')or burrowing,
        shielded=flag('HitShielded')or timer('OneHitShieldUntil'),
        evasive=timer('DashUntil')or timer('RocketUntil')or flag('GearMotion'),
        burstFor=math.clamp(math.max(untilAt('DashUntil'),untilAt('RocketUntil'))-now,0,1.25),
        boosted=flag('GearBoost')or flag('FartBoost'),slowed=flag('GearSlow')}
end

function Core.keepAliveDue(enabled,now,nextAt,busy)
    return enabled and now>=nextAt and not busy
end

function Core.blocksTouch(object)
    local blocked=false
    while object do
        if object:IsA('LayerCollector')and not object.Enabled then return false end
        if object:IsA('GuiObject')then
            if not object.Visible then return false end
            blocked=blocked or object.Active or object:IsA('GuiButton')or object:IsA('TextBox')or object:IsA('ScrollingFrame')
        end
        object=object.Parent
    end
    return blocked
end

function Core.soulContext(serialized,records,userId,position,range)
    local count=0
    for token in string.gmatch(type(serialized)=='string'and serialized or'','[^,]+')do
        if tonumber(token)then count=count+1 end
    end
    local nearby=false
    for _,record in ipairs(records)do
        local victim,body=record:GetAttribute('Victim'),record:GetAttribute('Body')
        if type(victim)=='number'and victim~=userId and not record:GetAttribute('TakeBy')
            and typeof(body)=='Vector3'and(body-position).Magnitude<=range then nearby=true;break end
    end
    return {souls=count,soulsNearby=nearby}
end

function Core.trapAim(relative,velocity,range,armTime,triggerRadius)
    relative,velocity=flat(relative),flat(velocity)
    if relative.Magnitude<0.1 then return nil end
    local a=velocity:Dot(velocity)
    if a<4 then
        if math.abs(relative.Magnitude-range)<=triggerRadius*0.8 then return relative.Unit,armTime+0.1 end
        return nil
    end
    local b=2*relative:Dot(velocity)
    local c=relative:Dot(relative)-range*range
    local discriminant=b*b-4*a*c
    if discriminant<0 then return nil end
    local best
    for _,time in ipairs({(-b-math.sqrt(discriminant))/(2*a),(-b+math.sqrt(discriminant))/(2*a)})do
        if time>=armTime+0.05 and time<=2.25 and(not best or time<best)then best=time end
    end
    if not best then return nil end
    return (relative+velocity*best).Unit,best
end

function Core.clusterTrapAim(candidates,origin,range,armTime,radius,allowed)
    local best,bestTime,bestCount,bestScore,selected
    for _,candidate in ipairs(candidates)do
        if candidate.shielded or candidate.protected then continue end
        local aim,time=Core.trapAim(candidate.position-origin,candidate.velocity,range,armTime,radius)
        if aim and allowed(aim,range)then
            local landing=origin+aim*range
            local count=0
            for _,other in ipairs(candidates)do
                local point=other.position+other.velocity*time
                if not other.shielded and not other.protected and math.abs(point.Y-landing.Y)<=3
                    and flat(point-landing).Magnitude<=radius+.9 then count=count+1 end
            end
            local score=count-time*.1
            if not bestScore or score>bestScore then best,bestTime,bestCount,bestScore,selected=aim,time,count,score,candidate end
        end
    end
    return best,bestTime,bestCount,selected
end

function Core.projectileAim(relative,velocity,speed,range,delay)
    relative=flat(relative)+flat(velocity)*(delay or 0)
    velocity=flat(velocity)
    local a=velocity:Dot(velocity)-speed*speed
    local b=2*relative:Dot(velocity)
    local c=relative:Dot(relative)
    local time
    if math.abs(a)<1e-6 then if b<0 then time=-c/b end
    else
        local discriminant=b*b-4*a*c
        if discriminant>=0 then
            for _,t in ipairs({(-b-math.sqrt(discriminant))/(2*a),(-b+math.sqrt(discriminant))/(2*a)})do
                if t>0 and(not time or t<time)then time=t end
            end
        end
    end
    if not time or time>range/speed then return nil end
    local point=relative+velocity*time
    return point.Magnitude>.01 and point.Unit or nil,time
end

function Core.abilityUseful(id,role,context,items)
    local item=items[id]
    if not item or item.Kind~='Ability'or(item.UseRole and item.UseRole~=role)
        or not context.ready or not context.owned or not context.active or context.blocked or context.charges==0 then return false end
    if role=='Runner'then
        if id=='OneHitShield'then return context.imminent and not context.ownShielded end
        if id=='EmergencyAirhorn'then return (context.nearest or math.huge)<=14 end
        if id=='TimeWarp'then return context.pressured and context.rewindSafe end
        if id=='SoulReap'then return context.soulsNearby and(context.souls or 0)<(item.Cap or 3)end
        if id=='Burrow'then return context.pressured and context.safeLanding and(context.goalDistance or 0)>12 end
        if id=='PocketDoor'then return context.pressured and context.doorBehind and context.castClear end
        if id=='Cloak'then return context.pressured and not context.ownCloaked and(context.goalDistance or 0)>8 end
        if id=='InflatableDecoy'or id=='PumpkinBomb'or id=='FartCloud'then
            return context.pressured and context.safeForward and(context.goalDistance or 0)>8
        end
        return false
    end
    if context.targetProtected or context.targetShielded then return false end
    local distance=context.targetDistance or math.huge
    if id=='BearTrap'then return context.trapOpportunity and context.castClear end
    if id=='BigDagger'then return not context.ownBigDagger and distance>5 and distance<=10 end
    if id=='RocketShoes'then return distance>=18 and distance<=65 and context.safeBurst and not context.ownBurst end
    if id=='RufusLeash'then return distance>4 and distance<=15 and context.castClear end
    if id=='BowlingBall'then return distance>=8 and distance<=40 and context.castClear end
    if id=='KingsDemise'then return distance<=12 and(context.targetCrossing or(context.runnersNearby or 0)>=2)end
    if id=='SpringBox'then return context.blastOpportunity and context.castClear end
    if id=='BrokenVow'then return distance<=8 end
    if id=='PumpkinBombChaser'then return distance<=20 and context.castClear end
    return false
end

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

function Core.intercept(position,targetPosition,velocity,speed,reach,horizon)
    local delta=flat(targetPosition-position)
    velocity=flat(velocity)
    if delta.Magnitude<=reach then return targetPosition,0 end
    speed=math.max(speed,1)
    local a=velocity:Dot(velocity)-speed*speed
    local b=2*(delta:Dot(velocity)-speed*reach)
    local c=delta:Dot(delta)-reach*reach
    local time
    if math.abs(a)<0.001 then
        if b<0 then time=-c/b end
    else
        local discriminant=b*b-4*a*c
        if discriminant>=0 then
            local root=math.sqrt(discriminant)
            for _,value in ipairs({(-b-root)/(2*a),(-b+root)/(2*a)})do
                if value>=0 and(not time or value<time)then time=value end
            end
        end
    end
    time=math.clamp(time or delta.Magnitude/speed,0,horizon)
    return targetPosition+velocity*time,time
end

function Core.choiceAction(state,candidates,index)
    if not state.enabled or state.afk or not state.inMatch or state.paused
        or type(state.endsAt)~='number'or state.now>=state.endsAt then return nil end
    if state.phase=='HeroChoice'and state.role=='Runner'and state.selectedId==state.id then
        return 'HeroChoice',type(state.chasers)=='number'and state.chasers<=5 and'Hero'or'Chicken'
    end
    if state.phase=='SelectHero'and state.role=='Catcher'and state.leadId==state.id and #candidates>0 then
        return 'SelectHero',candidates[math.clamp(index,1,#candidates)].id
    end
    return nil
end

function Core.voteChoice(vote,id,now,index)
    if type(vote)~='table'or vote.phase~='Voting'or type(vote.token)~='string'or vote.token==''
        or type(vote.endsAt)~='number'or now>=vote.endsAt or type(vote.options)~='table'then return nil end
    if type(vote.votes)=='table'and(vote.votes[tostring(id)]or vote.votes[id])then return nil end
    local options={}
    for _,option in ipairs(vote.options)do
        if type(option)=='table'and type(option.id)=='string'and option.id~=''then options[#options+1]=option.id end
    end
    if #options==0 then return nil end
    return options[math.clamp(index,1,#options)]
end

function Core.requestDue(now,nextAt,attempts)
    if now<nextAt or attempts>=3 then return false,attempts end
    return true,attempts+1
end

function Core.promptStep(state,key,value,now,enabled)
    if not enabled then return {},false end
    if state.key~=key then state={key=key,attempts=0,nextAt=0}end
    if value==nil then return state,false end
    local due,attempts=Core.requestDue(now,state.nextAt or 0,state.attempts or 0)
    if due then state.value,state.attempts,state.nextAt=value,attempts,now+1 end
    return state,due
end

function Core.zoneGoal(cf, size, position)
    local p = cf:PointToObjectSpace(position)
    local x = math.max(0, size.X / 2 - 4)
    local z = math.max(0, size.Z / 2 - 4)
    local goal = cf:PointToWorldSpace(Vector3.new(math.clamp(p.X, -x, x), 0, math.clamp(p.Z, -z, z)))
    return Vector3.new(goal.X, position.Y, goal.Z)
end

function Core.probeDistance(distance, speed)
    return math.min(distance, math.clamp(speed*0.4,8,20))
end

function Core.predictContact(relative,targetVelocity,ownVelocity,aim,box,windup,active,sweep,travel,targetPath)
    local function own(at)return travel and aim*travel(at)or flat(ownVelocity)*at end
    local count=math.max(1,math.ceil(active*30))
    local start=windup
    for i=1,count do
        local finish=windup+active*i/count
        local a,b=own(start),own(finish)
        local p=targetPath and targetPath(start)or relative+flat(targetVelocity)*start
        local q=targetPath and targetPath(finish)or relative+flat(targetVelocity)*finish
        local hit,attacker,victim=sweep(a,b,p,q,aim,box)
        if hit then
            local span=b-a
            local fraction=span:Dot(span)>1e-8 and(attacker-a):Dot(span)/span:Dot(span)or 0
            if span:Dot(span)<=1e-8 and(q-p):Dot(q-p)>1e-8 then fraction=(victim-p):Dot(q-p)/(q-p):Dot(q-p)end
            return true,start+(finish-start)*math.clamp(fraction,0,1)
        end
        start=finish
    end
    return false
end

function Core.diveRetry(profile,style)
    return math.max(profile.Cooldown or 0,(profile.Duration or 0)+(profile.Recovery or 0))+(style=='close'and .15 or .35)
end

function Core.predictedDive(relative,targetVelocity,distance,duration,options)
    if not options.sweep or not options.diveBox or not options.diveTravel then return nil end
    local stable=options.directionStableFor~=nil and options.directionStableFor or options.stableFor or 0
    local close=options.closeDive and flat(relative).Magnitude<=8 and stable>=.14
    local wider=options.farDive~=false and stable>=.25
    if not close and not wider then return nil end
    local horizon=math.min(math.max(0,duration-.01),wider and .3 or .22)
    local box=table.clone(options.diveBox)
    box.width=box.width*.85;box.far=math.max(box.near,box.far-.35)
    if flat(relative).Magnitude>distance+box.far then return nil end
    local acceleration=flat(options.acceleration or Vector3.zero)
    if acceleration.Magnitude>60 then acceleration=acceleration.Unit*60 end
    local function target(at)return relative+flat(targetVelocity)*at+acceleration*(.5*at*at)end
    local best,bestScore
    for i=0,8 do
        local lead=horizon*i/8
        local future=flat(target(lead))
        if future.Magnitude<.01 then continue end
        local aim=future.Unit
        local hit,at=Core.predictContact(relative,targetVelocity,Vector3.zero,aim,box,0,horizon,
            options.sweep,options.diveTravel,target)
        if hit then
            local contact=flat(target(at))-aim*options.diveTravel(at)
            local lateral=(contact-aim*contact:Dot(aim)).Magnitude
            if lateral<=box.width*.35 and(not options.diveClear or options.diveClear(aim,distance))then
                local score=at+lateral*.035
                if not bestScore or score<bestScore then
                    best={aim=aim,at=at,style=close and at<=.22 and'close'or'predicted'};bestScore=score
                end
            end
        end
    end
    if best then return 'Dive',best.aim,best.style,best.at end
end

function Core.dashPreview(intent,history,now,config)
    if flat(intent).Magnitude<.01 then return nil end
    intent=flat(intent).Unit
    local minimum=math.cos(math.rad(config.MinIntentAngle or config.MinTurnAngle or 90))
    for i=#history,1,-1 do
        local sample=history[i]
        if now-sample.at<=(config.TurnInputGrace or .38)then
            local previous=flat(sample.direction)
            if previous.Magnitude>.01 then
                previous=previous.Unit
                local dot=previous:Dot(intent)
                local redirected=intent-previous*math.max(0,dot)
                if dot<=minimum+.00001 and redirected.Magnitude>.01 then return redirected.Unit end
            end
        end
    end
end

function Core.combatAction(relative, targetVelocity, ownVelocity, diveDistance, duration, reach, meleeRange, meleeReady, diveReady, clear,options)
    options=options or {}
    if options.protected or options.shielded then return nil end
    if math.abs(relative.Y) > 3 then return nil end
    local delta = flat(relative)
    if delta.Magnitude < 0.01 then return nil end
    local windup=(options.windup or .12)+(options.delay or 0)
    local future = delta+flat(targetVelocity-ownVelocity)*windup
    local aim = future.Magnitude > 0.01 and future.Unit or delta.Unit
    local geometry=options.sweep and options.meleeBox
    if geometry and meleeReady then
        local hit,at=Core.predictContact(relative,targetVelocity,ownVelocity,aim,options.meleeBox,windup,
            options.active or .18,options.sweep)
        if hit then return 'Melee',aim,'predicted',at end
    end
    if geometry and options.stableFor~=nil then
        if options.evasive or not diveReady or not clear then return nil,aim end
        local action,diveAim,style,at=Core.predictedDive(relative,targetVelocity,diveDistance,duration,options)
        return action,diveAim or aim,style,at
    end
    if not geometry and meleeReady and future.Magnitude <= meleeRange and delta.Magnitude <= meleeRange+2 then
        return 'Melee',aim
    end
    -- Every dive must come from the native swept-contact prediction above.
    return nil,aim
end

function Core.canCommitDive(now, readyAt, stableFor)
    return now >= readyAt and stableFor >= 0.45
end

function Core.trackMotion(history,id,velocity,now)
    local same=history and history.id==id and now-history.seenAt<=.25
    local heading=same and(history.heading or history.baseline)or velocity
    local old,new=flat(heading),flat(velocity)
    local aligned=old.Magnitude<3 and new.Magnitude<3 or old.Magnitude>=3 and new.Magnitude>=3
        and old.Unit:Dot(new.Unit)>=math.cos(math.rad(12))
    local directionSince=same and aligned and(history.directionSince or history.stableSince)or now
    if not same or not aligned then heading=velocity end
    if not same or(velocity-history.baseline).Magnitude>6 then
        return {id=id,baseline=velocity,stableSince=now,seenAt=now,heading=heading,directionSince=directionSince}
    end
    history.seenAt=now;history.heading=heading;history.directionSince=directionSince
    return history
end

function Core.shouldDash(direction, velocity, goalDistance, ready, clear)
    local travel = flat(velocity)
    return ready and clear and goalDistance > 6 and travel.Magnitude >= 12
        and direction.Magnitude > 0.5 and direction.Unit:Dot(travel.Unit) <= math.cos(math.rad(35))
end

function Core.combatReady(now, localReadyAt, serverStartedAt, duration, predictionRemaining)
    return now >= math.max(localReadyAt,serverStartedAt+duration) and predictionRemaining <= 0
end

function Core.chaserRadius(maxDiveDistance,catchReach,cooldown,active)
    return catchReach+3+((active or cooldown<=0.35)and maxDiveDistance or 0)
end

function Core.hazardSnapshot(instance,role,items,now,kind)
    kind=kind or instance:GetAttribute('GearVisualKind') or instance.Name
    if kind:find('BearTrap',1,true)then kind='BearTrap' end
    if kind:find('BananaPeel',1,true)then kind='BananaPeel' end
    if kind:find('SpringBox',1,true)then kind='SpringBox' end
    local config=items[kind] or {}
    local runnerOnly=kind=='BearTrap' or kind=='SpringBox' or kind=='GraveRise'or kind=='BowlingBall'or kind=='RufusLeash'
    if runnerOnly and role~='Runner' then return nil end
    if kind=='FartCloud'and role~='Catcher'then return nil end
    if not runnerOnly and kind~='BananaPeel'and kind~='FartCloud'and not(config.TriggerRadius or config.BurstRadius)then return nil end
    local spawned,duration=instance:GetAttribute('GearSpawnedAt'),instance:GetAttribute('GearDuration')
    local expires=type(spawned)=='number'and type(duration)=='number'and spawned+duration or nil
    if kind=='SpringBox' then expires=instance:GetAttribute('PopAt')or expires end
    if kind=='GraveRise' then
        local sink=instance:GetAttribute('SinkAt')
        if type(sink)=='number'then expires=sink+(instance:GetAttribute('Sink')or 0.45)end
    end
    if expires and now>expires+0.25 then return nil end
    local position=instance:GetAttribute('GearLanding')or instance:GetAttribute('Landing')
    if typeof(position)=='CFrame'then position=position.Position end
    if typeof(position)~='Vector3'then
        if instance:IsA('Model')or instance:IsA('BasePart')then position=instance:GetPivot().Position else return nil end
    end
    local radius=(config.TriggerRadius or config.BurstRadius or 2.5)+3.5
    if kind=='FartCloud'then radius=(instance:IsA('BasePart')and instance.Size.X/1.6 or config.Radius or 9)+3.5 end
    if kind=='BowlingBall'then radius=6 end
    if kind=='RufusLeash'then radius=6 end
    if kind=='GraveRise'then
        local size=instance:IsA('BasePart')and instance.Size or Vector3.new(5,8,5)
        if instance:IsA('Model')then local _,bounds=instance:GetBoundingBox();size=bounds end
        radius=Vector2.new(size.X,size.Z).Magnitude/2+2.5
    end
    local direction,speed=instance:GetAttribute('GearDirection'),instance:GetAttribute('GearSpeed')
    if kind=='BowlingBall'or kind=='RufusLeash'then speed=type(speed)=='number'and speed or(kind=='BowlingBall'and 42 or 65)end
    local velocity=typeof(direction)=='Vector3'and type(speed)=='number'and flat(direction)*math.clamp(speed,0,100)or Vector3.zero
    return {position=position,radius=radius,kind=kind,source=instance,velocity=velocity,
        remaining=expires and math.max(0,expires-now)or nil}
end

function Core.segmentRisk(a,b,cost)
    local risk=0
    local count=math.max(1,math.ceil(flat(b-a).Magnitude/6))
    for i=0,count do risk=math.max(risk,cost(a+(b-a)*(i/count)))end
    return risk
end

function Core.directSafe(position,goal,allowed,cost)
    return Core.segmentRisk(position,goal,cost)<=0.6 and allowed(position,goal)
end

function Core.smoothWaypoint(position,path,index,allowed,cost)
    local chosen,prefixRisk=index,0
    local previous=position
    for i=index,math.min(#path,index+5)do
        prefixRisk=math.max(prefixRisk,Core.segmentRisk(previous,path[i],cost))
        if Core.segmentRisk(position,path[i],cost)<=prefixRisk+0.05 and allowed(position,path[i])then chosen=i end
        previous=path[i]
    end
    return chosen
end

-- Static hazard circles also cover noncolliding trigger areas.
function Core.clearSegment(a,b,zones)
    local span=flat(b-a)
    local length2=span:Dot(span)
    for _,zone in ipairs(zones) do
        if math.abs(a.Y-zone.position.Y)<10 or math.abs(b.Y-zone.position.Y)<10 then
            local relative=flat(a-zone.position)
            local t=length2>0.001 and math.clamp(-relative:Dot(span)/length2,0,1) or 0
            local closest=(relative+span*t).Magnitude
            if relative.Magnitude < zone.radius then
                if closest < relative.Magnitude-0.01 or flat(b-zone.position).Magnitude <= relative.Magnitude+0.01 then return false end
            elseif closest < zone.radius then return false end
        end
    end
    return true
end

-- Bounded A* with lazy collision probes; distance plus risk chooses short safe detours.
function Core.route(start,goals,step,allowed,cost,maxNodes)
    if #goals==0 then return nil end
    local riskSamples={}
    local function sampledCost(position)
        local risk=riskSamples[position]
        if risk==nil then risk=cost(position);riskSamples[position]=risk end
        return risk
    end
    local function heuristic(p)
        local best=math.huge
        for _,g in ipairs(goals)do best=math.min(best,flat(g-p).Magnitude/step)end
        return best
    end
    local heap={}
    local function push(node)
        local i=#heap+1
        while i>1 do
            local parent=math.floor(i/2)
            if heap[parent].f<=node.f then break end
            heap[i]=heap[parent];i=parent
        end
        heap[i]=node
    end
    local function pop()
        local root=heap[1]
        local last=table.remove(heap)
        if #heap>0 then
            local i=1
            while i*2<=#heap do
                local child=i*2
                if child<#heap and heap[child+1].f<heap[child].f then child=child+1 end
                if last.f<=heap[child].f then break end
                heap[i]=heap[child];i=child
            end
            heap[i]=last
        end
        return root
    end
    local first={x=0,z=0,position=start,g=0,f=heuristic(start),key='0:0'}
    local best={['0:0']=0}
    local closed={}
    push(first)
    local expanded=0
    while #heap>0 and expanded<(maxNodes or 450)do
        local node=pop()
        if not closed[node.key] and node.g==best[node.key] then
            if node.goal then
                local path={}
                local cursor=node
                while cursor do table.insert(path,1,cursor.position);cursor=cursor.parent end
                return path
            end
            closed[node.key]=true
            expanded=expanded+1
            for index,goal in ipairs(goals)do
                if flat(goal-node.position).Magnitude<=step*1.5 and allowed(node.position,goal)then
                    local g=node.g+flat(goal-node.position).Magnitude/step*(1+math.max(0,Core.segmentRisk(node.position,goal,sampledCost)))
                    local key='goal:'..index
                    if not best[key]or g<best[key]then
                        best[key]=g
                        push({position=goal,g=g,f=g,key=key,parent=node,goal=true})
                    end
                end
            end
            for dx=-1,1 do for dz=-1,1 do if dx~=0 or dz~=0 then
                local x,z=node.x+dx,node.z+dz
                local key=x..':'..z
                if not closed[key]then
                    local position=start+Vector3.new(x*step,0,z*step)
                    local length=math.sqrt(dx*dx+dz*dz)
                    local g=node.g+length*(1+math.max(0,Core.segmentRisk(node.position,position,sampledCost)))
                    if (not best[key]or g<best[key])and allowed(node.position,position)then
                        best[key]=g
                        push({x=x,z=z,key=key,position=position,g=g,f=g+heuristic(position),parent=node})
                    end
                end
            end end end
        end
    end
    return nil
end

function Core.planRoute(start,goals,allowed,cost,fine)
    local path
    if not fine then path=Core.route(start,goals,12,allowed,cost,450)end
    if path then return path,12 end
    return Core.route(start,goals,6,allowed,cost,600),6
end

-- Relative motion predicts closest approach, including enemies crossing our path.
function Core.choose(position, goal, speed, threats, allowed, previous,urgency)
    urgency=math.clamp(urgency or 0,0,1)
    local delta = flat(goal - position)
    if delta.Magnitude < 1 then return Vector3.zero end
    local forward = delta.Unit
    local candidates = {forward, Vector3.zero}
    for i=0,23 do
        local a = i * math.pi / 12
        candidates[#candidates+1] = Vector3.new(math.cos(a), 0, math.sin(a))
    end
    local best, bestScore = Vector3.zero, -math.huge
    for _,direction in ipairs(candidates) do
        if direction.Magnitude == 0 or allowed(direction) then
            local score = direction:Dot(forward)*(5+5*urgency) + direction:Dot(previous)*0.4
            if direction.Magnitude == 0 then score = -6-6*urgency end
            for _,enemy in ipairs(threats) do
                local radius = enemy.radius or 10
                local clearance,eta=Core.threatApproach(position,direction*speed,enemy,.9,radius)
                if clearance<0 then
                    local weight=enemy.activeAbility and 1 or(1-0.65*urgency)
                    score=score-(150-clearance*20)*weight
                    if enemy.activeAbility then score=score-600-math.max(0,.9-eta)*250 end
                elseif clearance<18 then
                    score=score-28*((18-clearance)/18)^2*(1-0.8*urgency)
                end
                if enemy.potentialAbility then
                    local potential={position=enemy.position,velocity=enemy.potentialVelocity,burstFor=enemy.potentialFor,
                        afterVelocity=enemy.velocity,expires=enemy.potentialFor}
                    local gap=Core.threatApproach(position,direction*speed,potential,.8,enemy.potentialRadius or enemy.catchRadius+3)
                    if gap<8 then score=score-20*math.clamp((8-gap)/16,0,2)*(1-.6*urgency)end
                end
            end
            if score > bestScore then best, bestScore = direction, score end
        end
    end
    return best
end

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

-- Runtime
assert(game.PlaceId == 107535308163741, 'This script is for Huss Valley')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Input = game:GetService('UserInputService')
local Http = game:GetService('HttpService')
local Collection = game:GetService('CollectionService')
local ContextActions=game:GetService('ContextActionService')
local GuiService=game:GetService('GuiService')
local VirtualInput=game:GetService('VirtualInputManager')
local VirtualUser=game:GetService('VirtualUser')
local player = Players.LocalPlayer
local package = game:GetService('ReplicatedStorage'):WaitForChild('ChickenOrHero', 10)
assert(package, 'Game is still loading; try again shortly')
local gameState = package:WaitForChild('Game', 10)
assert(gameState, 'Game state unavailable')
local session = gameState:WaitForChild('Session', 10)
assert(session, 'Session unavailable')
local boost = require(package.Movement.BoostInput)
local tackle = require(gameState.TacklePrediction)
local tackleProfile = require(gameState.TackleProfile)
local tackleConfig = require(gameState.GameConfig).Tackle
local hitReplay=require(gameState.HitReplayMath)
local tackleMotion=require(gameState.TackleMotion)
local movementProfiles = require(package.Movement.MovementProfiles)
local gearCatalog=require(package.Gear.GearCatalog)
local gearItems=gearCatalog.Items
local gearPrediction=require(package.Gear.GearPredictionClient)
local abilityRules=require(gameState.AbilityRule)
local hudNavigation=require(package.Presentation.HudNavigation)
local meleeConfig = require(gameState.ContactCatchConfig)
local knifeAbilities=require(package.Weapons.KnifeAbilities)
local combat = require(gameState.CombatPrediction)
local controlGate = require(package.Movement.ControlGate)
local participantDirectory = require(package.Presentation.ParticipantDirectory)
local env = getgenv and getgenv() or _G
if env.HussAutoCross and type(env.HussAutoCross.Destroy)=='function'then env.HussAutoCross:Destroy()end
env.HussAutoCross=nil
local startupCleanup
local function initialize()
local api = {Enabled=false, Destroyed=false, Status='Stopped', Crossings=0, Target=nil,SpeedMultiplier=1.05,SmartSpeedEnabled=true,
    TPDodgeEnabled=false,TPAssistEnabled=false,Actions={Dive=0,Melee=0,Dash=0,TPDodge=0,TPAssist=0},ActionTiming={},ActionTimeline={}}
local tp={nextCheck=0}
tp.state=env.HussTPDodgeState
if type(tp.state)~='table'or tp.state.jobId~=game.JobId or tp.state.policy~=Core.TP_POLICY then
    tp.state={jobId=game.JobId,policy=Core.TP_POLICY,readyAt=0,uses=0}
    env.HussTPDodgeState=tp.state
end
local learned=env.HussSmartSpeedLimit
api.SmartCap=Core.smartLimit(learned,game.JobId)
local smartState,smartContext,smartEpoch=nil,nil,0
local nativeProfileGet=movementProfiles.get
local speedProfiles=setmetatable({},{__mode='k'})
local function speedProfileGet(role,actor)
    local native=nativeProfileGet(role,actor)
    if not api.Enabled or api.Destroyed or actor~=player then return native end
    local multiplier=Core.effectiveSpeed(api.SpeedMultiplier,api.SmartSpeedEnabled,smartState,workspace:GetServerTimeNow(),api.SmartCap)
    local variants=speedProfiles[native]
    if not variants then variants={};speedProfiles[native]=variants end
    local scaled=variants[multiplier]
    if not scaled then scaled=Core.scaleSpeedProfile(native,multiplier,true);variants[multiplier]=scaled end
    return scaled
end
local function setProfileGetter(getter)
    local readonly=isreadonly(movementProfiles)
    setreadonly(movementProfiles,false)
    movementProfiles.get=getter
    setreadonly(movementProfiles,readonly)
end
function api:SpeedReport()
    local role=player:GetAttribute('GameRole')
    local native=nativeProfileGet(role,player)
    local applied=movementProfiles.get(role,player)
    local now=workspace:GetServerTimeNow()
    local active=self.Enabled and self.SmartSpeedEnabled and smartState and smartState.untilAt>now or false
    return {role=role,normal=native.MaxSpeed,applied=applied.MaxSpeed,
        multiplier=applied.MaxSpeed/math.max(.001,native.MaxSpeed),baseMultiplier=self.SpeedMultiplier,
        smartEnabled=self.SmartSpeedEnabled,smartActive=active,smartLimit=self.SmartCap,smartSecondsLeft=active and smartState.untilAt-now or 0,
        smartDuration=.4,smartCooldown=12,
        instantAcceleration=self.Enabled and not self.Destroyed,
        acceleration=applied.Acceleration,deceleration=applied.Deceleration}
end
local connections, samples = {}, setmetatable({}, {__mode='k'})
local characterTimingConnections={}
local binding = 'HussAutoCross_'..Http:GenerateGUID(false)
local gui
startupCleanup=function()
    if type(api.Stop)=='function'then pcall(api.Stop,api)end
    api.Enabled=false;api.Destroyed=true
    if movementProfiles.get==speedProfileGet then setProfileGetter(nativeProfileGet)end
    RunService:UnbindFromRenderStep(binding)
    RunService:UnbindFromRenderStep(binding..'_Facing')
    for _,connection in ipairs(connections)do connection:Disconnect()end
    for _,connection in ipairs(characterTimingConnections)do connection:Disconnect()end
    table.clear(connections)
    if gui then gui:Destroy()end
    if env.HussAutoCross==api then env.HussAutoCross=nil end
end
local direction, ownedHumanoid = Vector3.zero, nil
local elapsed, wasActive, lastMap, target, lastRun = 1, false, nil, nil, nil
local huntTarget, activeRole
local facingHumanoid, previousAutoRotate, boostQueued
local nextMelee, nextDashRequest = 0, 0
local nextDive, pursuitHistory = 0, nil
local nextCloseDive,runnerProgress,runnerStrategy=0,nil,nil
local navigation
local actionContext,actionElapsed,combatFacing,lastActionClock=nil,0,nil,nil
local dashHistory={}
local pendingActions={}
local pendingDash,pendingDive,pendingMelee
local actorCache={}
local random=Random.new()
local choiceRequest,voteRequest={},{}
local promptElapsed=1
local armory={abilities={},loaded=false}
local nextAbilityAt,nextCombatAt=0,0
local pendingAbilities,abilityFailures,projectilePositions={},{},{}
local ownHistory={}
local anti={nextTouch=math.huge,nextAFK=0,buttons={},touches={}}
local function participants()
    local result,current={},{}
    for _,source in ipairs(participantDirectory.list())do
        if type(source)=='table'and type(source.UserId)=='number'then
            local actor=actorCache[source.UserId]
            if not actor then
                actor={UserId=source.UserId,IsBot=true}
                function actor:GetAttribute(name)return self.source:GetAttribute(name)end
                setmetatable(actor,{__index=function(t,k)return t.source[k]end})
            end
            actor.source=source
            current[source.UserId]=actor
            result[#result+1]=actor
        elseif typeof(source)=='Instance'and source:IsA('Player')then result[#result+1]=source end
    end
    actorCache=current
    return result
end
local function motion(actor,now)
    local model=actor.Character
    local root=model and model:FindFirstChild('HumanoidRootPart')
    if not root then return nil end
    local reported=root.AssemblyLinearVelocity
    if type(actor)=='table'and type(actor.source.pose)=='function'then
        local _,_,velocity=actor.source:pose()
        if typeof(velocity)=='Vector3' then reported=velocity end
    end
    local sample=Core.observeMotion(samples[model],root.Position,now,reported)
    samples[model]=sample
    return sample
end
local function connect(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections+1] = c
    return c
end
local function timingSample(kind,name,value)
    local stats=api.ActionTiming[kind]or{requests=0,accepted=0,rejected=0}
    api.ActionTiming[kind]=stats
    local sample=stats[name]or{count=0,min=value,max=value,mean=0}
    sample.count=sample.count+1;sample.min=math.min(sample.min,value);sample.max=math.max(sample.max,value)
    sample.mean=sample.mean+(value-sample.mean)/sample.count;sample.last=value
    stats[name]=sample
end
local function actionRequest(kind,id,clock,serverAt)
    local stats=api.ActionTiming[kind]or{requests=0,accepted=0,rejected=0}
    api.ActionTiming[kind]=stats;stats.requests=stats.requests+1
    local record={kind=kind,id=id,requestedClock=clock,requestedAt=serverAt,source='script'}
    pendingActions[id]=record
    api.ActionTimeline[#api.ActionTimeline+1]=record
    if #api.ActionTimeline>32 then table.remove(api.ActionTimeline,1)end
    return record
end
local function predicted(record)
    record.predictionMS=(os.clock()-record.requestedClock)*1000
    timingSample(record.kind,'predictionMS',record.predictionMS)
end
local function activated(record)
    if not record or record.activationMS then return end
    record.activationMS=(os.clock()-record.requestedClock)*1000
    timingSample(record.kind,'activationMS',record.activationMS)
end
local function actionReply(id,accepted,data)
    local record=pendingActions[id]
    if not record or record.replyMS then return end
    record.replyMS=(os.clock()-record.requestedClock)*1000;record.accepted=accepted==true
    timingSample(record.kind,'replyMS',record.replyMS)
    local stats=api.ActionTiming[record.kind]
    local field=record.accepted and'accepted'or'rejected';stats[field]=stats[field]+1
    if type(data)=='table'then
        record.reason=type(data.reason)=='string'and data.reason or nil
        if type(data.startedAt)=='number'then
            record.serverStartMS=(data.startedAt-record.requestedAt)*1000
            timingSample(record.kind,'serverStartMS',record.serverStartMS)
        end
    end
    if record.kind=='Melee'and not accepted then
        nextMelee=math.min(nextMelee,workspace:GetServerTimeNow()+.2)
        combatFacing=nil
    end
    if not accepted and pendingDive==record then pendingDive=nil end
end
local function release(preserveSmart)
    direction = Vector3.zero
    if not preserveSmart then
        if smartState then smartState.untilAt=0 end
        api.SmartUntilAt=0
    end
    if ownedHumanoid and ownedHumanoid.Parent then ownedHumanoid:Move(Vector3.zero, false) end
    ownedHumanoid = nil
    actionContext=nil;actionElapsed=0;table.clear(dashHistory)
    lastActionClock=nil
    pendingDash=nil
    if not preserveSmart then combatFacing=nil end
    if boostQueued then boost.clear(); boostQueued=false end
    if facingHumanoid and facingHumanoid.Parent then facingHumanoid.AutoRotate=previousAutoRotate end
    facingHumanoid,previousAutoRotate=nil,nil
    navigation=nil
    runnerProgress=nil
    runnerStrategy=nil
end

function tp.epoch(character)
    local active=gameState:FindFirstChild('ActiveMap')
    return table.concat({tostring(active and active.Value),tostring(session:GetAttribute('RunNumber')),
        tostring(player:GetAttribute('GameRole')),tostring(character and character:GetAttribute('CombatLife'))},':')
end
function tp.eligible(character,humanoid,root,observing)
    local now=workspace:GetServerTimeNow()
    for _,name in ipairs({'CannonUntil','StepOverUntil','TruckUntil'})do
        if math.max(tonumber(player:GetAttribute(name))or 0,tonumber(character:GetAttribute(name))or 0)>now then return false end
    end
    return character==player.Character and humanoid.Health>0 and not root.Anchored and not humanoid.Sit
        and not humanoid.PlatformStand and humanoid.FloorMaterial~=Enum.Material.Air
        and player:GetAttribute('InMatch')==true and player:GetAttribute('RunState')=='Active'
        and not player:GetAttribute('AFK')and not session:GetAttribute('MapChanging')and not session:GetAttribute('GlobalPaused')
        and session:GetAttribute('AdminMatchMode')==nil and not controlGate.reason(player)
        and not character:GetAttribute('TackleActive')and not character:GetAttribute('GearMotion')
        and not character:GetAttribute('Burrowing')and not character:GetAttribute('Ragdolled')and not character:GetAttribute('MovementLocked')
        and not Core.abilityState(player,character,now).evasive and(observing or combat.meleeRemaining()<=0)
end
function tp.observe()
    local watch=tp.state.watch
    if not watch then return end
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    local now=os.clock()
    local observed={position=root and root.Position or Vector3.zero,velocity=root and root.AssemblyLinearVelocity or Vector3.zero,
        epoch=tp.epoch(character),phase=session:GetAttribute('Phase'),reset=character and character:GetAttribute('MovementReset'),
        valid=character==watch.character and root~=nil and humanoid~=nil and tp.eligible(character,humanoid,root,true)}
    local outcome=Core.tpObservation(watch,now,observed)
    api.TPLastObservation=outcome
    if outcome=='watching'then
        watch.position,watch.velocity,watch.at=observed.position,observed.velocity,now
    else
        tp.state.watch=nil
        if outcome=='corrected'or outcome=='uncertain'then
            tp.state.blocked=true;api.TPDodgeEnabled=false;api.TPAssistEnabled=false
            tp.state.reason=outcome=='corrected'and'correction'or'observation gap'
            if outcome=='corrected'then api.TPCorrections=(api.TPCorrections or 0)+1
            else api.TPObservationGaps=(api.TPObservationGaps or 0)+1 end
        elseif outcome=='complete'then api.TPCleanWatches=(api.TPCleanWatches or 0)+1 end
    end
end
function tp.probe(character,root,field,point,params,groundParams)
    local delta=flat(point-root.Position)
    if delta.Magnitude<1.9 or delta.Magnitude>4.001 or math.abs(point.Y-root.Position.Y)>.1 then return nil end
    local body=Vector3.new(math.max(3.2,root.Size.X+1),math.max(4.5,root.Size.Y+2),math.max(3.2,root.Size.Z+1))
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={character}
    overlap.RespectCanCollide=true;overlap.CollisionGroup=root.CollisionGroup
    local function free(p)
        return #workspace:GetPartBoundsInBox(CFrame.new(p+Vector3.new(0,.25,0)),body,overlap)==0
    end
    local ground=workspace:Raycast(root.Position+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
    if not ground then return nil end
    local function supported(p)
        local hit=workspace:Raycast(p+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
        return hit and hit.Normal.Y>.7 and math.abs(hit.Position.Y-ground.Position.Y)<=.75
            and p.Y-hit.Position.Y>=1.5 and p.Y-hit.Position.Y<=5.5
    end
    local exit=point+delta.Unit*2
    if not free(point)or not supported(point)or not free(exit)or not supported(exit)then return nil end
    local blocked=workspace:Blockcast(CFrame.new(root.Position+Vector3.new(0,.25,0)),body,delta,params)
    local thin=false
    if blocked then
        local part=blocked.Instance
        local name=(part.Name..' '..part.Parent.Name):lower()
        if name:find('safe',1,true)or name:find('zone',1,true)or name:find('barrier',1,true)
            or name:find('boundary',1,true)or name:find('spawn',1,true)or name:find('finish',1,true)
            or not part:IsA('BasePart')or not part.Anchored then return nil end
        local front=workspace:Raycast(root.Position,delta,params)
        local back=workspace:Raycast(point,-delta,params)
        thin=front and back and front.Instance==part and back.Instance==part
            and(front.Position-back.Position).Magnitude<=1.25
        if not thin then return nil end
        local remaining=RaycastParams.new()
        remaining.FilterType=Enum.RaycastFilterType.Exclude
        local excluded=table.clone(params.FilterDescendantsInstances);excluded[#excluded+1]=part
        remaining.FilterDescendantsInstances=excluded;remaining.RespectCanCollide=true
        remaining.CollisionGroup=root.CollisionGroup
        if workspace:Blockcast(CFrame.new(root.Position+Vector3.new(0,.25,0)),body,delta,remaining)then return nil end
    elseif not supported(root.Position+delta*.5)then return nil end
    return {point=point,distance=delta.Magnitude,landingSafe=true,exitSafe=true,pathBlocked=blocked~=nil,
        thinObstacle=thin,exitPoint=exit}
end
function tp.commit(character,root,candidate,epoch)
    local now=os.clock()
    local humanoid=character:FindFirstChildOfClass('Humanoid')
    if not api.Enabled or not api.TPDodgeEnabled or not humanoid or not tp.eligible(character,humanoid,root)
        or tp.state.blocked or tp.state.watch or now<tp.state.readyAt then return false end
    if tp.state.epoch~=epoch then tp.state.epoch=epoch;tp.state.uses=0 end
    if tp.state.uses>=2 then return false end
    local from,velocity=root.Position,root.AssemblyLinearVelocity
    local delta=candidate.point-from
    if delta.Magnitude>4.001 then return false end
    tp.state.readyAt=now+12;tp.state.uses=tp.state.uses+1
    tp.state.watch={character=character,epoch=epoch,phase=session:GetAttribute('Phase'),reset=character:GetAttribute('MovementReset'),
        position=candidate.point,velocity=velocity,at=now,untilAt=now+1.5,distance=delta.Magnitude}
    character:PivotTo(character:GetPivot()+delta)
    root.AssemblyLinearVelocity=velocity
    direction=flat(delta).Unit
    api.Actions.TPDodge=api.Actions.TPDodge+1;api.Actions.TPAssist=api.Actions.TPAssist+1;api.LastAction='TP Assist'
    api.TPLast={from=from,to=candidate.point,distance=delta.Magnitude,at=now,kind=candidate.kind}
    table.clear(dashHistory);table.clear(ownHistory);samples[character]=nil
    navigation=nil;runnerProgress=nil;actionContext=nil;elapsed=1
    if boostQueued then boost.clear();boostQueued=false end
    pendingDash=nil
    return true
end

local function finishTouch()
    local touch=anti.touch
    anti.touch=nil
    if touch then pcall(function()VirtualInput:SendTouchEvent(touch.id,2,touch.x,touch.y)end)end
end
local function lockAFKButton(button)
    if not api.Enabled or not button:IsA('GuiButton')or(button.Name~='AFKButton'and button.Name~='AFKToggle')or anti.buttons[button]then return end
    local record={interactable=button.Interactable,selectable=button.Selectable,connections={}}
    anti.buttons[button]=record
    local function enforce()
        if api.Enabled and button.Parent then button.Interactable=false;button.Selectable=false end
    end
    record.connections={button:GetPropertyChangedSignal('Interactable'):Connect(enforce),button:GetPropertyChangedSignal('Selectable'):Connect(enforce)}
    enforce()
end
local function restoreAFKButtons()
    for button,record in pairs(anti.buttons)do
        for _,connection in ipairs(record.connections)do connection:Disconnect()end
        if button.Parent then button.Interactable=record.interactable;button.Selectable=record.selectable end
    end
    anti.buttons={}
end
local function antiStop()
    finishTouch()
    ContextActions:UnbindAction(binding..'_AFK')
    if anti.guard and hudNavigation.handlers.AFK==anti.guard then hudNavigation.handlers.AFK=anti.original end
    anti.guard,anti.original=nil,nil
    restoreAFKButtons()
end
local function antiStart()
    antiStop()
    anti.nextTouch=os.clock()+1
    anti.nextAFK=0
    anti.original=hudNavigation.handlers.AFK
    anti.guard=function()end
    hudNavigation.handlers.AFK=anti.guard
    ContextActions:BindActionAtPriority(binding..'_AFK',function()
        return Input:GetFocusedTextBox()and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+100,Enum.KeyCode.K)
    for _,v in ipairs(player.PlayerGui:GetDescendants())do lockAFKButton(v)end
end
local function safeTouchPoint()
    local camera=workspace.CurrentCamera
    if not camera then return nil end
    local viewport=camera.ViewportSize
    if viewport.X<80 or viewport.Y<80 then return nil end
    local points={{.55,.88},{.65,.30},{.80,.42},{.48,.68},{.72,.58}}
    local offset=random:NextInteger(0,#points-1)
    for i=1,#points do
        local point=points[(i+offset-1)%#points+1]
        local x=math.clamp(math.floor(viewport.X*point[1])+random:NextInteger(-3,3),32,viewport.X-32)
        local y=math.clamp(math.floor(viewport.Y*point[2])+random:NextInteger(-3,3),32,viewport.Y-32)
        local blocked=false
        for _,root in ipairs({player.PlayerGui,game:GetService('CoreGui')})do
            local ok,objects=pcall(root.GetGuiObjectsAtPosition,root,x,y)
            if ok then for _,object in ipairs(objects)do
                if Core.blocksTouch(object)then blocked=true;break end
            end end
        end
        if not blocked then return x,y end
    end
end
local function keepAliveTick()
    if not api.Enabled then return end
    local now=os.clock()
    if player:GetAttribute('AFK')and not player:GetAttribute('InMatch')and now>=anti.nextAFK then
        anti.nextAFK=now+2
        gameState.PlayerPreferences:FireServer('SetAFK',false)
    end
    if anti.touch then
        local touch=anti.touch
        if now>=touch.ends then
            finishTouch()
            api.TouchPulses=(api.TouchPulses or 0)+1
        elseif not touch.moved and now>=touch.moves then
            touch.moved=true
            touch.x,touch.y=touch.x+random:NextInteger(1,2),touch.y+random:NextInteger(0,1)
            VirtualInput:SendTouchEvent(touch.id,1,touch.x,touch.y)
        end
        return
    end
    local busy=GuiService.MenuIsOpen or Input:GetFocusedTextBox()~=nil or next(anti.touches)~=nil
    if not Core.keepAliveDue(api.Enabled,now,anti.nextTouch,busy)then return end
    local x,y=safeTouchPoint()
    if not x then anti.nextTouch=now+5;return end
    anti.nextTouch=now+60
    anti.touch={id=random:NextInteger(100000,9999999),x=x,y=y,moves=now+.04,ends=now+random:NextNumber(.09,.15)}
    VirtualInput:SendTouchEvent(anti.touch.id,0,x,y)
end

gui = Instance.new('ScreenGui')
gui.Name = 'HussAutoCrossUI'
gui:SetAttribute('LightsOutKeep',true)
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild('PlayerGui')
local panel = Instance.new('Frame')
panel.Name = 'Panel'
panel.Size = UDim2.fromOffset(294, 286)
panel.Position = UDim2.new(0, 24, 0.35, 0)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
panel.Active = true
panel.Parent = gui
local corner = Instance.new('UICorner', panel)
corner.CornerRadius = UDim.new(0, 10)
local function label(name, text, position, size)
    local v = Instance.new('TextLabel')
    v.Name, v.Text = name, text
    v.Position, v.Size = position, size
    v.BackgroundTransparency = 1
    v.TextColor3 = Color3.fromRGB(230, 235, 245)
    v.Font = Enum.Font.Gotham
    v.TextSize = 13
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.Parent = panel
    return v
end
local title = label('DragHandle', 'HUSS  /  AUTO PLAY', UDim2.fromOffset(14, 0), UDim2.new(1,-60,0,40))
title.Active = true
title.Font = Enum.Font.GothamBold
local status = label('Status', 'Stopped', UDim2.fromOffset(14,44), UDim2.new(1,-28,0,38))
status.TextWrapped = true
local function button(name, text, position, size, color)
    local b = Instance.new('TextButton')
    b.Name, b.Text = name, text
    b.Position, b.Size = position, size
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Font, b.TextSize = Enum.Font.GothamBold, 14
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new('UICorner', b).CornerRadius = UDim.new(0,6)
    return b
end
local speedLabel=label('SpeedLabel','Dynamic speed  1.05x',UDim2.fromOffset(14,88),UDim2.new(1,-28,0,24))
local speedSlider=button('SpeedSlider','',UDim2.fromOffset(14,116),UDim2.fromOffset(266,28),Color3.fromRGB(37,42,53))
speedSlider.AutoButtonColor=false
local speedFill=Instance.new('Frame')
speedFill.Name='Fill';speedFill.BorderSizePixel=0;speedFill.BackgroundColor3=Color3.fromRGB(30,145,103)
speedFill.Position=UDim2.fromOffset(8,11);speedFill.Size=UDim2.new(.25,-4,0,6);speedFill.Parent=speedSlider
Instance.new('UICorner',speedFill).CornerRadius=UDim.new(1,0)
local speedKnob=Instance.new('Frame')
speedKnob.Name='Knob';speedKnob.AnchorPoint=Vector2.new(.5,.5)
speedKnob.Size=UDim2.fromOffset(16,16);speedKnob.BackgroundColor3=Color3.fromRGB(230,235,245)
speedKnob.BorderSizePixel=0;speedKnob.Parent=speedSlider
Instance.new('UICorner',speedKnob).CornerRadius=UDim.new(1,0)
function api:SetSpeedMultiplier(value)
    if self.Destroyed then return end
    assert(type(value)=='number'and value==value,'Speed multiplier must be a number')
    local multiplier=Core.speedMultiplier(value)
    if multiplier~=self.SpeedMultiplier then
        self.SpeedMultiplier=multiplier
        table.clear(speedProfiles)
        navigation=nil
        elapsed=1
    end
    local fraction=multiplier-1
    speedLabel.Text=string.format('Dynamic speed  %.2fx',multiplier)
    speedKnob.Position=UDim2.new(fraction,8-16*fraction,.5,0)
    speedFill.Size=UDim2.new(fraction,-16*fraction,0,6)
    return multiplier
end
api:SetSpeedMultiplier(api.SpeedMultiplier)
local sliderInput
local function slide(input)
    local inset=GuiService:GetGuiInset()
    local fraction=(input.Position.X-inset.X-speedSlider.AbsolutePosition.X-8)/math.max(1,speedSlider.AbsoluteSize.X-16)
    api:SetSpeedMultiplier(1+fraction)
end
connect(speedSlider.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        sliderInput=input;slide(input)
    end
end)
connect(Input.InputChanged,function(input)
    if sliderInput and(input==sliderInput or(sliderInput.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement))then slide(input)end
end)
connect(Input.InputEnded,function(input)if input==sliderInput then sliderInput=nil end end)
connect(Input.WindowFocusReleased,function()sliderInput=nil end)
local smartButton=button('SmartSpeed','Smart speed: ON',UDim2.fromOffset(14,154),UDim2.fromOffset(266,30),Color3.fromRGB(35,104,118))
local function refreshSmartButton()
    local now=workspace:GetServerTimeNow()
    local active=api.Enabled and api.SmartSpeedEnabled and smartState and smartState.untilAt>now
    smartButton.Text=not api.SmartSpeedEnabled and'Smart speed: OFF'or active
        and string.format('Smart speed: ON  /  %.1fs',smartState.untilAt-now)
        or api.SmartCap<Core.SMART_PEAK and string.format('Smart speed: ON  /  limit %.2fx',api.SmartCap)or'Smart speed: ON'
    smartButton.BackgroundColor3=api.SmartSpeedEnabled and Color3.fromRGB(35,104,118)or Color3.fromRGB(65,70,83)
end
function api:SetSmartSpeedEnabled(enabled)
    if self.Destroyed then return end
    assert(type(enabled)=='boolean','Smart speed requires true or false')
    self.SmartSpeedEnabled=enabled
    if not enabled and smartState then smartState.untilAt=0;self.SmartUntilAt=0 end
    navigation=nil;elapsed=1
    refreshSmartButton()
end
connect(smartButton.Activated,function()api:SetSmartSpeedEnabled(not api.SmartSpeedEnabled)end)
local tpButton=button('TPAssist','TP Assist: OFF',UDim2.fromOffset(14,194),UDim2.fromOffset(266,30),Color3.fromRGB(65,70,83))
function tp.refresh()
    local seconds=math.max(0,tp.state.readyAt-os.clock())
    tpButton.Text=tp.state.blocked and('TP Assist: BLOCKED / '..(tp.state.reason or'correction'))or not api.TPDodgeEnabled and'TP Assist: OFF'
        or tp.state.watch and'TP Assist: ON / observing'or seconds>0 and string.format('TP Assist: ON / %.0fs',seconds)or'TP Assist: ON'
    tpButton.BackgroundColor3=api.TPDodgeEnabled and Color3.fromRGB(83,75,140)or Color3.fromRGB(65,70,83)
end
function api:SetTPAssistEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','TP Assist requires true or false')
    self.TPDodgeEnabled=enabled and not tp.state.blocked
    self.TPAssistEnabled=self.TPDodgeEnabled
    tp.refresh()
    return self.TPDodgeEnabled
end
function api:SetTPDodgeEnabled(enabled)return self:SetTPAssistEnabled(enabled)end
function api:TPReport()
    return {enabled=self.TPDodgeEnabled,blocked=tp.state.blocked==true,blockReason=tp.state.reason,cooldown=math.max(0,tp.state.readyAt-os.clock()),
        usesThisRound=tp.state.uses,maxDistance=4,cooldownSeconds=12,maxUsesPerRound=2,
        watching=tp.state.watch~=nil,last=self.TPLast,observation=self.TPLastObservation,corrections=self.TPCorrections or 0}
end
connect(tpButton.Activated,function()api:SetTPAssistEnabled(not api.TPAssistEnabled)end)
tp.refresh()
local start = button('Start','Start',UDim2.fromOffset(14,236),UDim2.fromOffset(128,36),Color3.fromRGB(30,145,103))
local stop = button('Stop','Stop',UDim2.fromOffset(152,236),UDim2.fromOffset(128,36),Color3.fromRGB(155,65,75))
local close = button('Close','X',UDim2.new(1,-38,0,7),UDim2.fromOffset(30,28),Color3.fromRGB(65,70,83))
local function report(message)
    api.Status = message
    status.Text = message
end
function api:Start()
    if self.Destroyed then return end
    self.Enabled = true
    antiStart()
    elapsed = 1
    report('Waiting for an active round')
end
function api:Stop()
    self.Enabled = false
    antiStop()
    release()
    huntTarget, self.Target = nil, nil
    self.Diagnostics = nil
    choiceRequest,voteRequest={},{}
    report('Stopped')
end
function api:Destroy()
    if self.Destroyed then return end
    self:Stop()
    self.Destroyed = true
    if movementProfiles.get==speedProfileGet then setProfileGetter(nativeProfileGet)end
    RunService:UnbindFromRenderStep(binding)
    RunService:UnbindFromRenderStep(binding..'_Facing')
    for _,c in ipairs(connections) do c:Disconnect() end
    for _,c in ipairs(characterTimingConnections)do c:Disconnect()end
    table.clear(characterTimingConnections)
    table.clear(connections)
    gui:Destroy()
    if env.HussAutoCross == self then env.HussAutoCross = nil end
end
connect(start.Activated, function() api:Start() end)
connect(stop.Activated, function() api:Stop() end)
connect(close.Activated, function() api:Destroy() end)
connect(Input.TouchStarted,function(input)anti.touches[input]=true end)
connect(Input.TouchEnded,function(input)anti.touches[input]=nil end)
connect(gui.Destroying, function() if not api.Destroyed then api:Destroy() end end)
connect(player.PlayerGui.DescendantAdded,lockAFKButton)
connect(player.PlayerGui.DescendantRemoving,function(object)
    local record=anti.buttons[object]
    if record then
        for _,connection in ipairs(record.connections)do connection:Disconnect()end
        object.Interactable=record.interactable;object.Selectable=record.selectable
        anti.buttons[object]=nil
    end
end)
connect(player.Idled,function()
    if not api.Enabled then return end
    anti.nextTouch=0
    local ok,err=pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(1,1),workspace.CurrentCamera.CFrame)
    end)
    api.IdleGuardFires=(api.IdleGuardFires or 0)+1
    if not ok then api.AntiAFKError=tostring(err)end
end)
connect(package.Weapons.ArmoryEvent.OnClientEvent,function(kind,state)
    if kind=='State'and type(state)=='table'then
        armory=state
        api.EquippedAbilities=state.equippedAbilities
    end
end)
connect(package.Gear.GearEvent.OnClientEvent,function(kind,data)
    if type(data)~='table'then return end
    if kind=='PredictionResult'then actionReply(data.requestId,data.accepted,data)end
    if kind=='BowlingPosition'and type(data.requestId)=='string'and typeof(data.cf)=='CFrame'then
        projectilePositions[data.requestId]={position=data.cf.Position,time=os.clock()}
    elseif kind=='PredictionResult'and pendingAbilities[data.requestId]then
        local pending=pendingAbilities[data.requestId]
        pendingAbilities[data.requestId]=nil
        if data.accepted then
            api.AbilitiesAccepted=(api.AbilitiesAccepted or 0)+1
            abilityFailures[pending.id]=nil
        else
            local failures=abilityFailures[pending.id]or{count=0}
            failures.count=failures.count+1
            failures.untilAt=workspace:GetServerTimeNow()+math.min(15,2^math.min(failures.count,4))
            abilityFailures[pending.id]=failures
            api.AbilitiesRejected=(api.AbilitiesRejected or 0)+1
        end
    end
end)
connect(gameState.MeleeEvent.OnClientEvent,function(id,accepted,data)actionReply(id,accepted,data)end)
connect(gameState.GameAction.OnClientEvent,function(kind,id,accepted,data)
    if kind=='TackleResult'then actionReply(id,accepted,data)end
end)
local function observeActionCharacter(character)
    for _,connection in ipairs(characterTimingConnections)do connection:Disconnect()end
    table.clear(characterTimingConnections)
    pendingDash,pendingDive,pendingMelee=nil,nil,nil
    if not character then return end
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('DashCount'):Connect(function()
        local count=character:GetAttribute('DashCount')or 0
        if pendingDash and count>pendingDash.previousCount then
            predicted(pendingDash);activated(pendingDash)
            pendingDash.localActivation=true;pendingActions[pendingDash.id]=nil;pendingDash=nil
            table.clear(dashHistory)
        end
    end)
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('LocalMeleePhase'):Connect(function()
        if pendingMelee and character:GetAttribute('LocalMeleePhase')=='Active'then activated(pendingMelee)end
    end)
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('HitShielded'):Connect(function()
        if not character:GetAttribute('HitShielded')then return end
        for _,record in pairs(pendingActions)do
            if record.item=='OneHitShield'then record.effectPhase='replicatedShield';activated(record)end
        end
    end)
end
connect(player.CharacterAdded,observeActionCharacter)
observeActionCharacter(player.Character)
connect(Collection:GetInstanceAddedSignal('PredictedGearVisual'),function(instance)
    local id=instance:GetAttribute('GearRequestId')
    local record=id and pendingActions[id]
    if record and record.item then record.effectPhase='replicatedVisual';activated(record)end
end)
package.Weapons.ArmoryEvent:FireServer('Get')

local dragInput, dragOrigin, panelOrigin
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragInput, dragOrigin, panelOrigin = input, input.Position, panel.AbsolutePosition
    end
end)
connect(Input.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)
connect(Input.InputChanged, function(input)
    if not dragInput then return end
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragOrigin
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920,1080)
        local inset = game:GetService('GuiService'):GetGuiInset()
        panel.Position = UDim2.fromOffset(
            math.clamp(panelOrigin.X+delta.X,0,math.max(0,viewport.X-panel.AbsoluteSize.X)),
            math.clamp(panelOrigin.Y+delta.Y,0,math.max(0,viewport.Y-inset.Y-panel.AbsoluteSize.Y)))
    end
end)
connect(player.CharacterRemoving, function()
    release()
    wasActive=false
    huntTarget, api.Target, target = nil, nil, nil
end)

local function activeRunner(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass('Humanoid')
    local r = c and c:FindFirstChild('HumanoidRootPart')
    local present=type(p)=='table'and actorCache[p.UserId]==p or typeof(p)=='Instance'and p.Parent==Players
    if not present or p.UserId==player.UserId or not c or not c:IsDescendantOf(workspace)or not r then return false end
    if type(p)=='table'and(p:GetAttribute('Hidden')or p:GetAttribute('FadeOutAt'))then return false end
    if Core.abilityState(p,c,workspace:GetServerTimeNow()).protected then return false end
    return Core.isRunner(p:GetAttribute('InMatch'),p:GetAttribute('GameRole'),p:GetAttribute('RunState'),
        h and h.Health or c:GetAttribute('Health')or 100,c:GetAttribute('MovementLocked'),type(p)=='table',r.Anchored)
end

local function updateSmartSpeed(character,humanoid,root)
    local now=workspace:GetServerTimeNow()
    local round,phase=session:GetAttribute('RunNumber'),session:GetAttribute('Phase')
    local reset=character:GetAttribute('MovementReset')
    local same=smartContext and smartContext.character==character and smartContext.round==round and smartContext.role==activeRole
    if not same then smartEpoch=smartEpoch+1 end
    local eligible=not character:GetAttribute('TackleActive')and not character:GetAttribute('GearMotion')
        and not character:GetAttribute('Burrowing')and not controlGate.reason(player)
        and humanoid.FloorMaterial~=Enum.Material.Air
    local corrected=same and smartContext.phase==phase and smartContext.reset~=reset
        and smartState and (smartState.watchUntil or 0)>now and api.SmartCap>api.SpeedMultiplier
    local nearest,visible=math.huge,math.huge
    if api.SmartSpeedEnabled and eligible then
        for _,actor in ipairs(participants())do
            local opposite=activeRole=='Runner'and'Catcher'or'Runner'
            if actor.UserId~=player.UserId and actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')==opposite
                and actor:GetAttribute('RunState')=='Active'and(activeRole=='Runner'or activeRunner(actor))then
                local c=actor.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
                local h=c and c:FindFirstChildOfClass('Humanoid')
                if r and not r.Anchored and(not h or h.Health>0)then
                    local offset=r.Position-root.Position
                    nearest=math.min(nearest,offset.Magnitude)
                    if offset.Magnitude<=12 then
                        local params=RaycastParams.new()
                        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character,c}
                        params.RespectCanCollide=true;params.CollisionGroup=root.CollisionGroup
                        if not workspace:Raycast(root.Position,offset,params)then visible=math.min(visible,offset.Magnitude)end
                    end
                end
            end
        end
    end
    local distance=19
    if api.SmartSpeedEnabled and eligible then distance=visible<=12 and visible or nearest>=20 and nearest or 19 end
    smartState=Core.smartSpeedStep(smartState,now,api.SmartSpeedEnabled,eligible,distance,smartEpoch,corrected)
    smartContext={character=character,round=round,role=activeRole,phase=phase,reset=reset}
    api.SmartNearest=nearest;api.SmartUntilAt=smartState.untilAt;api.SmartReadyAt=smartState.readyAt
    api.SmartWatchUntil=smartState.watchUntil
    if corrected then
        api.SmartCorrections=(api.SmartCorrections or 0)+1
        api.SmartCap=math.min(api.SmartCap,1.05)
        env.HussSmartSpeedLimit={jobId=game.JobId,cap=api.SmartCap,policy=Core.SMART_POLICY}
    end
end

local function automaticPrompts()
    if not api.Enabled or api.Destroyed or player:GetAttribute('AFK')then return end
    local now=workspace:GetServerTimeNow()
    local phase=session:GetAttribute('Phase')
    local state={enabled=api.Enabled,afk=player:GetAttribute('AFK'),inMatch=player:GetAttribute('InMatch'),
        role=player:GetAttribute('GameRole'),phase=phase,id=player.UserId,leadId=session:GetAttribute('LeadUserId'),
        selectedId=session:GetAttribute('SelectedUserId'),now=now,endsAt=session:GetAttribute('EndsAt'),
        paused=session:GetAttribute('GlobalPaused')or session:GetAttribute('MapChanging')}
    local candidates={}
    if phase=='HeroChoice'and state.selectedId==state.id then
        state.chasers=0
        for _,actor in ipairs(participants())do
            if actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')=='Catcher'
                and actor:GetAttribute('RunState')~='Lobby'and not actor:GetAttribute('AFK')then state.chasers=state.chasers+1 end
        end
    end
    if phase=='SelectHero'and state.leadId==state.id then
        for _,actor in ipairs(participants())do
            local run=actor:GetAttribute('RunState')
            if actor.UserId~=player.UserId and actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')=='Runner'
                and run~='Caught'and run~='Lobby'and not actor:GetAttribute('AFK')then candidates[#candidates+1]={id=actor.UserId}end
        end
    end
    local key=table.concat({tostring(phase),tostring(session:GetAttribute('RunNumber')),tostring(state.endsAt),tostring(state.leadId),tostring(state.selectedId)},':')
    if choiceRequest.key~=key then choiceRequest={key=key,attempts=0,nextAt=0}end
    local index=random:NextInteger(1,math.max(1,#candidates))
    if choiceRequest.value then
        for i,candidate in ipairs(candidates)do if candidate.id==choiceRequest.value then index=i;break end end
    end
    local action,value=Core.choiceAction(state,candidates,index)
    local due
    choiceRequest,due=Core.promptStep(choiceRequest,key,value,now,api.Enabled)
    if action and due then
        gameState.GameAction:FireServer(action,value)
        api.ChoicesSent=(api.ChoicesSent or 0)+1
        api.LastChoice={action=action,value=value,chasers=state.chasers}
    end
    local eligible=player:GetAttribute('ClientReady')and player:GetAttribute('InitialLoadingComplete')
        and not player:GetAttribute('InMatch')and not state.paused
    for _,name in ipairs({'TutorialSession','TutorialRouting','TutorialActive','TutorialFinishing','AdminTransferring','ServerBrowserTransferring'})do
        if player:GetAttribute(name)then eligible=false end
    end
    local snapshot=gameState:FindFirstChild('MapVoteState')
    if not eligible or not snapshot then return end
    local ok,vote=pcall(Http.JSONDecode,Http,snapshot.Value)
    if not ok or type(vote)~='table'then return end
    if voteRequest.key~=vote.token then voteRequest={key=vote.token,attempts=0,nextAt=0}end
    local count=type(vote.options)=='table'and #vote.options or 0
    index=random:NextInteger(1,math.max(1,count))
    if voteRequest.value and type(vote.options)=='table'then
        for i,option in ipairs(vote.options)do if type(option)=='table'and option.id==voteRequest.value then index=i;break end end
    end
    value=Core.voteChoice(vote,player.UserId,now,index)
    voteRequest,due=Core.promptStep(voteRequest,vote.token,value,now,api.Enabled)
    if value and due then
        gameState.MapVoteEvent:FireServer('Vote',value,vote.token)
        api.VotesSent=(api.VotesSent or 0)+1
        api.LastVote=value
    end
end

local function faceToward(character, humanoid, root, aim, updateCamera)
    if aim.Magnitude < 0.01 or character:GetAttribute('TackleActive') or character:GetAttribute('GearMotion')
        or root.Anchored or humanoid.Sit or humanoid.PlatformStand then return end
    if facingHumanoid ~= humanoid then
        facingHumanoid,previousAutoRotate=humanoid,humanoid.AutoRotate
    end
    humanoid.AutoRotate=false
    aim=flat(aim).Unit
    root.CFrame=CFrame.lookAt(root.Position,root.Position+aim)
    local camera=workspace.CurrentCamera
    if updateCamera and camera and camera.CameraType ~= Enum.CameraType.Scriptable and camera.CameraSubject == humanoid then
        local pitch=math.clamp(camera.CFrame.LookVector.Y,-0.65,0.35)
        local view=aim*math.sqrt(1-pitch*pitch)+Vector3.new(0,pitch,0)
        local focus=root.Position+Vector3.new(0,1.5,0)
        local zoom=math.clamp((camera.CFrame.Position-camera.Focus.Position).Magnitude,6,18)
        camera.CFrame=CFrame.lookAt(focus-view*zoom,focus)
        camera.Focus=CFrame.new(focus)
    end
end

local function faceTarget(updateCamera)
    if not api.Enabled or activeRole ~= 'Catcher' or not ownedHumanoid or not huntTarget or not activeRunner(huntTarget) then return end
    local c=player.Character
    local h=c and c:FindFirstChildOfClass('Humanoid')
    local root=c and c:FindFirstChild('HumanoidRootPart')
    if not h or not root or c:GetAttribute('MovementLocked') or c:GetAttribute('Ragdolled') then return end
    local targetRoot=huntTarget.Character.HumanoidRootPart
    local aim=combatFacing and combatFacing.character==c and workspace:GetServerTimeNow()<combatFacing.untilAt
        and combatFacing.aim or flat(targetRoot.Position-root.Position)
    faceToward(c,h,root,aim,updateCamera)
end

local function useCombat(character,humanoid,root,pursuit,allowed)
    if not pursuit or not activeRunner(pursuit.player) or character:GetAttribute('TackleActive')
        or character:GetAttribute('GearMotion') or humanoid.FloorMaterial == Enum.Material.Air
        or controlGate.reason(player) or session:GetAttribute('GlobalPaused')
        or session:GetAttribute('AdminMatchMode') == 'BladeBall'
        or (character:GetAttribute('DaggerEquipped') and character:GetAttribute('DaggerState') ~= 'Held') then return end
    local now=workspace:GetServerTimeNow()
    if now<nextCombatAt then return end
    local velocity=flat(root.AssemblyLinearVelocity)
    local profile=tackleProfile.select(tackleConfig,velocity.Magnitude,movementProfiles.get('Catcher',player).MaxSpeed)
    local total=meleeConfig.Windup+meleeConfig.ActiveDuration+meleeConfig.Recovery
    local started=character:GetAttribute('ReachStartedAt') or 0
    local attackReady=Core.combatReady(now,nextMelee,started,total,combat.meleeRemaining())
    local meleeReady=meleeConfig.Enabled and attackReady
    local stableFor=pursuitHistory and os.clock()-pursuitHistory.stableSince or 0
    local directionStableFor=pursuitHistory and os.clock()-(pursuitHistory.directionSince or pursuitHistory.stableSince)or 0
    local nativeReady=attackReady and tackle.remaining() <= 0.02 and not tackle.isActive(character)
    local normalDive=nativeReady and now>=nextDive and directionStableFor>=.25
    local closeDive=nativeReady and now>=nextCloseDive and directionStableFor>=.14
    local abilities=Core.abilityState(pursuit.player,pursuit.player.Character,now)
    local meleeRange=meleeConfig.CommitDistance*(character:GetAttribute('BigDaggerActive')and 2 or 1)
    local relative=pursuit.position-root.Position
    local measured=api.ActionTiming.Melee and api.ActionTiming.Melee.serverStartMS
    local delay=measured and math.clamp(measured.mean/1000,0,.06)or 0
    local action,aim,style,contactAt=Core.combatAction(relative,pursuit.velocity,velocity,profile.Distance,
        profile.Duration,profile.Reach,meleeRange,meleeReady,normalDive or closeDive,true,
        {closeDive=closeDive,farDive=normalDive,shielded=abilities.shielded,protected=abilities.protected,evasive=abilities.evasive,
            stableFor=stableFor,directionStableFor=directionStableFor,acceleration=pursuit.acceleration,
            diveClear=function(d,distance)return allowed(d,math.max(.1,distance))end,
            sweep=hitReplay.sweep,meleeBox=combat.meleeBox(character),diveBox=hitReplay.bounds('Tackle',profile),
            windup=meleeConfig.Windup,active=meleeConfig.ActiveDuration,delay=delay,
            diveTravel=function(at)return tackleMotion.distance(profile,at)end})
    if not action then return end
    local distance=action == 'Dive' and profile.Distance or flat(relative).Magnitude
    if not allowed(aim,math.max(0.1,distance)) then return end
    faceToward(character,humanoid,root,aim,false)
    local clock=os.clock()
    if action == 'Dive' then
        if type(contactAt)~='number'or contactAt~=contactAt or contactAt<0 or contactAt>profile.Duration then return end
        if tackle.request() then
            local id=character:GetAttribute('TacklePredictionId')or Http:GenerateGUID(false)
            pendingDive=actionRequest('Dive',id,clock,now)
            pendingDive.activeDuration=profile.Duration;pendingDive.recovery=profile.Recovery
            pendingDive.predictedContact=contactAt;predicted(pendingDive)
            nextDive=now+Core.diveRetry(profile,style)
            nextCloseDive=nextDive
            direction=Vector3.zero
            api.Actions.Dive=api.Actions.Dive+1
            api.LastAction='Dive'
            api.LastDiveStyle=style
            return true
        end
        nextDive=now+.25;nextCloseDive=nextDive
    else
        local id=Http:GenerateGUID(false)
        nextMelee=now+total
        pendingMelee=actionRequest('Melee',id,clock,now)
        pendingMelee.windup=meleeConfig.Windup;pendingMelee.activeDuration=meleeConfig.ActiveDuration
        pendingMelee.predictedContact=contactAt
        combatFacing={character=character,aim=aim,untilAt=now+meleeConfig.Windup+meleeConfig.ActiveDuration}
        gameState.MeleeEvent:FireServer({id=id,at=now,direction=aim,position=root.Position})
        local prediction=combat.begin({id=id,kind='Melee',character=character,predicted=true,startedAt=now,
            starts=now+meleeConfig.Windup,ends=now+meleeConfig.Windup+meleeConfig.ActiveDuration,
            direction=aim,box=combat.meleeBox(character)})
        if prediction then predicted(pendingMelee)end
        api.Actions.Melee=api.Actions.Melee+1
        api.LastAction='Melee'
        return true
    end
end

local function useAbility(character,humanoid,root,pursuit,candidates,nearby,policy,finish,allowed,hazards,field,castAllowed)
    local now=workspace:GetServerTimeNow()
    if now<nextAbilityAt or now<(player:GetAttribute('AbilityReadyAt')or 0)or not armory.loaded
        or tackle.isActive(character)or character:GetAttribute('TackleActive')or character:GetAttribute('GearMotion')
        or character:GetAttribute('Ragdolled')or character:GetAttribute('MovementLocked')or controlGate.reason(player)then return end
    local meleeDuration=meleeConfig.Windup+meleeConfig.ActiveDuration+meleeConfig.Recovery
    if now<nextMelee or combat.meleeRemaining()>0.02
        or now<(character:GetAttribute('ReachStartedAt')or 0)+meleeDuration then return end
    local id=gearCatalog.equippedForRole(armory,activeRole)
    local item=gearCatalog.get(id)
    if not item or item.Kind~='Ability'then return end
    local failure=abilityFailures[id]
    if failure and now<failure.untilAt or not armory.abilities or armory.abilities[id]~=true
        or player:GetAttribute('AbilityCharges')==0 or abilityRules.blocked(player)then return end
    local own=Core.abilityState(player,character,now)
    local context={ready=now>=(player:GetAttribute('AbilityReadyAt')or 0)and(not failure or now>=failure.untilAt),
        owned=armory.abilities and armory.abilities[id]==true,active=api.Enabled and player:GetAttribute('RunState')=='Active',
        blocked=abilityRules.blocked(player)or session:GetAttribute('GlobalPaused')or session:GetAttribute('MapChanging'),
        charges=player:GetAttribute('AbilityCharges'),ownShielded=own.shielded,ownCloaked=Core.isInvisible(player,character,now),
        ownBigDagger=character:GetAttribute('BigDaggerActive'),ownBurst=own.evasive,
        goalDistance=flat(finish-root.Position).Magnitude,nearest=math.huge,hitETA=math.huge}
    local aim=direction.Magnitude>0.1 and direction or flat(root.CFrame.LookVector)
    local velocity=flat(root.AssemblyLinearVelocity)
    local function destinationSafe(point)
        if not Core.clearSegment(point,point,hazards)then return false end
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={field}
        params.RespectCanCollide=true;params.CollisionGroup=root.CollisionGroup
        local hit=workspace:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-10,0),params)
        return hit and hit.Normal.Y>0.6
    end
    if activeRole=='Runner'then
        local nearestEnemy
        for _,enemy in ipairs(nearby)do
            local delta=flat(enemy.position-root.Position)
            local distance=delta.Magnitude
            if distance<context.nearest then context.nearest=distance;nearestEnemy=enemy end
            local _,eta=Core.threatApproach(root.Position,velocity,enemy,.8,enemy.catchRadius or 8)
            if enemy.reaching and distance<11 and math.abs(enemy.position.Y-root.Position.Y)<5 then eta=math.min(eta,0.12)end
            context.hitETA=math.min(context.hitETA,eta)
        end
        context.imminent=context.hitETA<=0.55
        context.pressured=context.nearest<28 or(policy and policy.urgency>0.5 and context.nearest<45)
        context.safeForward=aim.Magnitude>0.1 and allowed(aim,12)
        context.safeLanding=aim.Magnitude>0.1 and allowed(aim,25)
        if id=='SoulReap'then
            local souls=gameState:FindFirstChild('SoulReapSouls')
            local state=Core.soulContext(player:GetAttribute('SoulReapFrom'),souls and souls:GetChildren()or{},
                player.UserId,root.Position,item.Range or 35)
            context.souls,context.soulsNearby=state.souls,state.soulsNearby
        end
        local stamp=os.clock()
        ownHistory[#ownHistory+1]={time=stamp,position=root.Position}
        while #ownHistory>40 or(#ownHistory>0 and stamp-ownHistory[1].time>3)do table.remove(ownHistory,1)end
        local previous
        for _,sample in ipairs(ownHistory)do if sample.time<=stamp-2 then previous=sample end end
        if previous and context.goalDistance>8 and flat(previous.position-root.Position).Magnitude>8 and destinationSafe(previous.position)then
            local distance=math.huge
            for _,enemy in ipairs(nearby)do distance=math.min(distance,flat(previous.position-enemy.position).Magnitude)end
            context.rewindSafe=distance>10 and distance>context.nearest+6
        end
        if id=='PocketDoor'and nearestEnemy and aim.Magnitude>0.1 then
            local behind=flat(nearestEnemy.position-root.Position)
            context.doorBehind=behind.Magnitude<22 and behind.Magnitude>0.1 and aim:Dot(behind.Unit)<-0.4
            aim=-aim
            context.castClear=castAllowed(aim,6)
        end
    else
        if not pursuit or not activeRunner(pursuit.player)then return end
        local target=pursuit.player.Character
        local abilities=Core.abilityState(pursuit.player,target,now)
        context.targetProtected,context.targetShielded=abilities.protected,abilities.shielded
        local delta=flat(pursuit.position-root.Position)
        context.targetDistance=delta.Magnitude
        aim=delta.Magnitude>0.1 and delta.Unit or aim
        context.targetCrossing=delta.Magnitude>0.1 and pursuit.velocity:Dot(delta.Unit)<-4
        context.runnersNearby=0
        for _,candidate in ipairs(candidates or{})do if flat(candidate.position-root.Position).Magnitude<18 then context.runnersNearby=context.runnersNearby+1 end end
        if id=='BearTrap'then
            local chosen,bestTime,count,trapTarget=Core.clusterTrapAim(candidates or{pursuit},root.Position,
                item.ThrowRange or 10,.9,item.TriggerRadius or 2,allowed)
            if chosen then
                aim=chosen;api.LastTrapCoverage=count
                context.targetShielded,context.targetProtected=trapTarget.shielded,trapTarget.protected
            end
            context.trapOpportunity=bestTime~=nil
        elseif id=='SpringBox'then
            local future=delta+pursuit.velocity*2.9
            if future.Magnitude>0.1 then aim=future.Unit end
            context.blastOpportunity=context.targetDistance<65 and math.abs(future.Magnitude-(item.ThrowRange or 13))<(item.BurstRadius or 12)*0.75
        elseif id=='BowlingBall'or id=='RufusLeash'then
            local speed=id=='BowlingBall'and 42 or 65
            local stats=api.ActionTiming['Ability:'..id]
            local delay=stats and stats.replyMS and math.clamp(stats.replyMS.mean/2000,0,.08)or 0
            local lead,flight=Core.projectileAim(delta,pursuit.velocity,speed,item.ThrowRange or 84,delay)
            if not lead then return end
            aim=lead;context.castDistance=speed*flight
        end
        context.castClear=aim.Magnitude>0.1 and allowed(aim,context.castDistance or item.ThrowRange or math.min(context.targetDistance+2,40))
        context.safeBurst=aim.Magnitude>0.1 and allowed(aim,50)
    end
    if not Core.abilityUseful(id,activeRole,context,gearItems)then return end
    if humanoid.FloorMaterial==Enum.Material.Air and(id=='BearTrap'or id=='SpringBox'or id=='RocketShoes'or id=='PocketDoor')then return end
    local original
    if activeRole=='Catcher'then faceToward(character,humanoid,root,aim,false)
    elseif id=='PocketDoor'then original=root.CFrame;root.CFrame=CFrame.lookAt(root.Position,root.Position+aim)end
    local clock,dispatchedAt=os.clock(),workspace:GetServerTimeNow()
    local ok,requestId=pcall(gearPrediction.request,id,aim,'UseAbility')
    if original and root.Parent then root.CFrame=CFrame.new(root.Position)*original.Rotation end
    nextAbilityAt=now+(ok and requestId and 0.65 or 0.3)
    if not ok then api.AbilityError=tostring(requestId);return end
    if requestId then
        local record=actionRequest('Ability:'..id,requestId,clock,dispatchedAt)
        record.item=id
        record.dispatchMS=(os.clock()-clock)*1000
        timingSample(record.kind,'dispatchMS',record.dispatchMS)
        pendingAbilities[requestId]={id=id,time=now}
        api.Actions.Ability=(api.Actions.Ability or 0)+1
        api.LastAbility=id
        api.AbilityError=nil
        nextCombatAt=now+(id=='RocketShoes'and 0.7 or 0.18)
        return true
    end
end

local function collectHazards(position,role)
    local result,seen,signature={},{},{}
    local now=workspace:GetServerTimeNow()
    local function add(instance,kind)
        if seen[instance]or not instance:IsDescendantOf(workspace)then return end
        if kind=='GraveRise'and type(instance:GetAttribute('RiseAt'))~='number'then return end
        local hazard=Core.hazardSnapshot(instance,role,gearItems,now,kind)
        if hazard and flat(hazard.position-position).Magnitude<450 then
            seen[instance]=true
            local update=projectilePositions[instance:GetAttribute('GearRequestId')]
            if update and os.clock()-update.time<0.5 then hazard.position=update.position end
            result[#result+1]=hazard
            signature[#signature+1]=hazard.kind..':'..math.floor(hazard.position.X*2)..':'..math.floor(hazard.position.Z*2)..':'..hazard.radius
            if hazard.velocity and hazard.velocity.Magnitude>1 and(hazard.kind=='BowlingBall'or hazard.kind=='RufusLeash')then
                local horizon=math.min(.8,hazard.remaining or .8)
                local count=math.clamp(math.ceil(hazard.velocity.Magnitude*horizon/math.max(4,hazard.radius)),1,12)
                for i=1,count do
                    local point=hazard.position+hazard.velocity*(horizon*i/count)
                    result[#result+1]={position=point,radius=hazard.radius,kind=hazard.kind}
                    signature[#signature+1]=hazard.kind..':'..math.floor(point.X*2)..':'..math.floor(point.Z*2)
                end
            end
        end
    end
    local folder=workspace:FindFirstChild('ValleyGearTraps')
    if folder then for _,v in ipairs(folder:GetChildren())do add(v)end end
    local effects=workspace:FindFirstChild('LocalGearEffects')
    if effects then for _,v in ipairs(effects:GetChildren())do if v.Name=='FartCloud'then add(v,'FartCloud')end end end
    for _,tag in ipairs({'PredictedGearVisual','SpringBoxShake','GraveRise'})do
        for _,v in ipairs(Collection:GetTagged(tag))do add(v,tag~='PredictedGearVisual'and(tag=='SpringBoxShake'and'SpringBox'or tag)or nil)end
    end
    table.sort(signature)
    return result,table.concat(signature,';')
end

local function threats(now)
    local result = {}
    local serverNow=workspace:GetServerTimeNow()
    local function add(model,actor)
        local root = model and model:FindFirstChild('HumanoidRootPart')
        local humanoid=model and model:FindFirstChildOfClass('Humanoid')
        if not root or (humanoid and humanoid.Health<=0)then return end
        local sample=motion(actor,now)
        local velocity=sample and sample.velocity or Vector3.zero
        local reach=math.max(meleeConfig.CommitDistance,tackleConfig.HumanBox and tackleConfig.HumanBox.Reach['Long Dive']or tackleConfig.Reach)
        if model:GetAttribute('BigDaggerActive')then reach=math.max(reach,meleeConfig.CommitDistance*2)end
        local cooldown=math.max(0,((actor or model):GetAttribute('TackleReadyAt')or 0)-serverNow)
        local radius=Core.chaserRadius(tackleConfig.MaxDistance or 15,reach,cooldown,model:GetAttribute('TackleActive'))
        if velocity.Magnitude>50 then radius=math.max(radius,velocity.Magnitude*0.42+reach+3)end
        result[#result+1]=Core.abilityThreat(actor,model,root,velocity,serverNow,
            {radius=radius,catchRadius=reach+1.5,maxSpeed=movementProfiles.get('Catcher',actor).MaxSpeed,
                cannon=knifeAbilities.Cannon,stepOver=knifeAbilities.StepOver,
                ready=not abilityRules.blocked(actor),knifeBlocked=abilityRules.knifeBlocked(actor)})
    end
    for _,p in ipairs(participants()) do
        if p ~= player and p:GetAttribute('InMatch') == true and p:GetAttribute('GameRole') == 'Catcher'
            and p:GetAttribute('RunState')=='Active' then
            add(p.Character,p)
        end
    end
    return result
end

local function finishPoints(zone,position)
    local goals={Core.zoneGoal(zone.CFrame,zone.Size,position)}
    local base=zone.CFrame:PointToObjectSpace(goals[1])
    local wideX=zone.Size.X>=zone.Size.Z
    local half=math.max(0,(wideX and zone.Size.X or zone.Size.Z)/2-4)
    for _,fraction in ipairs({-0.8,-0.4,0,0.4,0.8})do
        local p=zone.CFrame:PointToWorldSpace(Vector3.new(wideX and half*fraction or base.X,0,wideX and base.Z or half*fraction))
        goals[#goals+1]=Vector3.new(p.X,position.Y,p.Z)
    end
    table.sort(goals,function(a,b)return flat(a-position).Magnitude<flat(b-position).Magnitude end)
    return goals
end

local function routeWaypoint(position,goals,edgeAllowed,cost,map,key,signature,fast)
    local now=os.clock()
    local previous=navigation
    local same=previous and previous.map==map and previous.key==key
    local progressPosition=same and previous.progressPosition or position
    local progressAt=same and previous.progressAt or now
    local fineUntil=same and previous.fineUntil or 0
    if flat(position-progressPosition).Magnitude>2 then progressPosition,progressAt=position,now end
    local stalled=same and previous.path and direction.Magnitude>0.1 and now-progressAt>1.1
    if stalled then
        fineUntil,progressAt=now+2,now
        api.Recoveries=(api.Recoveries or 0)+1
    end
    local dirty=not navigation or navigation.map~=map or navigation.key~=key
        or navigation.signature~=signature or now>=navigation.nextAt
        or flat(navigation.requested-goals[1]).Magnitude>(fast and 4 or 18)or stalled
    if not dirty and navigation.path then
        local path=navigation.path
        while navigation.index<#path and flat(path[navigation.index]-position).Magnitude<6 do navigation.index=navigation.index+1 end
        if not edgeAllowed(position,path[navigation.index])then dirty=true end
    end
    if dirty then
        local path,step
        local direct=not stalled and Core.directSafe(position,goals[1],edgeAllowed,cost)
        if direct then path={position,goals[1]}
        else path,step=Core.planRoute(position,goals,edgeAllowed,cost,now<fineUntil)end
        if not path then
            for _,goal in ipairs(goals)do
                if Core.directSafe(position,goal,edgeAllowed,cost)then path={position,goal};break end
            end
        end
        navigation={map=map,key=key,signature=signature,requested=goals[1],path=path,index=2,
            nextAt=now+(fast and 0.25 or 0.65),status=path and(direct and'direct'or'planned')or'blocked',step=step,
            progressPosition=progressPosition,progressAt=progressAt,fineUntil=fineUntil}
    end
    navigation.progressPosition,navigation.progressAt=progressPosition,progressAt
    local path=navigation.path
    if not path then return goals[1],goals[1]end
    local index=Core.smoothWaypoint(position,path,navigation.index,edgeAllowed,cost)
    navigation.index=index
    return path[index],path[#path]
end

local function plan(character, humanoid, root)
    local active = gameState:FindFirstChild('ActiveMap')
    local map = active and active.Value
    if not map or not map:IsDescendantOf(workspace) then release(); report('Waiting for map'); return end
    local field = map:FindFirstChild('Field')
    if not field then release(); report('Waiting for field'); return end
    local run = session:GetAttribute('RunNumber')
    if map ~= lastMap or run ~= lastRun then
        target,huntTarget,api.Target=nil,nil,nil
        navigation=nil
        runnerProgress=nil
        runnerStrategy=nil
        ownHistory={}
        lastMap,lastRun=map,run
    end
    local movement=movementProfiles.get(activeRole,player)
    local hazards,hazardSignature=collectHazards(root.Position,activeRole)
    local observedSpeed=flat(root.AssemblyLinearVelocity).Magnitude
    local speed=math.clamp(Core.distanceAt(0.6,observedSpeed,movement.MaxSpeed,movement.Acceleration,movement.Deceleration)/0.6,1,120)
    local goal, nearby, targetName, pursuit, goals, interceptTime,policy,secondsLeft,allCandidates,targetCluster
    if activeRole == 'Catcher' then
        local candidates = {}
        local observedAt=os.clock()
        local actors=participants()
        local excluded={character}
        for _,actor in ipairs(actors)do if actor.Character then excluded[#excluded+1]=actor.Character end end
        local closeParams=RaycastParams.new()
        closeParams.FilterType=Enum.RaycastFilterType.Exclude;closeParams.FilterDescendantsInstances=excluded
        closeParams.RespectCanCollide=true;closeParams.CollisionGroup=root.CollisionGroup
        for _,p in ipairs(actors) do
            if activeRunner(p) then
                local r = p.Character.HumanoidRootPart
                local sample=motion(p,observedAt)
                local delta=flat(r.Position-root.Position)
                local closeClear
                if delta.Magnitude<=14 then
                    closeClear=Core.clearSegment(root.Position,r.Position,hazards)and(delta.Magnitude<.01 or not workspace:Blockcast(
                        CFrame.new(root.Position+Vector3.new(0,.5,0)),Vector3.new(3,3,3),delta,closeParams))
                end
                candidates[#candidates+1] = {id=p.UserId,player=p,position=r.Position,velocity=sample.velocity,
                    acceleration=sample.acceleration or Vector3.zero,
                    invisible=Core.isInvisible(p,p.Character,workspace:GetServerTimeNow()),closeClear=closeClear}
            end
        end
        local chosen,cluster=Core.selectChaseTarget(candidates,huntTarget and huntTarget.UserId,root.Position)
        targetCluster=cluster
        allCandidates=candidates
        if not chosen then
            huntTarget,api.Target=nil,nil
            release()
            api.Diagnostics=nil
            report('Chaser · waiting for active runners')
            return
        end
        pursuitHistory=Core.trackMotion(huntTarget and huntTarget.UserId==chosen.id and pursuitHistory or nil,
            chosen.id,chosen.velocity,observedAt)
        huntTarget, api.Target = chosen.player, chosen.player.Name
        pursuit=chosen
        targetName = api.Target
        local targetProfile=movementProfiles.get('Runner',chosen.player)
        local abilities=Core.abilityState(chosen.player,chosen.player.Character,workspace:GetServerTimeNow())
        if abilities.burstFor>0 then
            targetProfile={MaxSpeed=targetProfile.MaxSpeed,Acceleration=targetProfile.Acceleration,
                Deceleration=targetProfile.Deceleration,BurstRemaining=abilities.burstFor}
        end
        if flat(chosen.position-root.Position).Magnitude<=12 and math.abs(chosen.position.Y-root.Position.Y)<=3 then
            goal,interceptTime=chosen.position,0
        else
            goal,interceptTime=Core.dynamicIntercept(root.Position,chosen.position,chosen.velocity,movement,
                flat(root.AssemblyLinearVelocity),targetProfile,chosen.acceleration,3,1.25)
        end
        nearby = {}
        goals={goal}
    else
        local a = field:FindFirstChild('SafezoneASide')
        local b = field:FindFirstChild('SafezoneBSide')
        if not (a and b and a:IsA('BasePart') and b:IsA('BasePart')) then
            release(); report('Waiting for crossing zones'); return
        end
        if not target or not target.Parent then
            local side = session:GetAttribute('StartSide')
            if side == 'A' then target=b elseif side == 'B' then target=a
            else target=(root.Position-a.Position).Magnitude < (root.Position-b.Position).Magnitude and b or a end
        end
        goal = Core.zoneGoal(target.CFrame,target.Size,root.Position)
        goals=finishPoints(target,root.Position)
        targetName = target.Name
        nearby = threats(os.clock())
        local stamp=os.clock()
        if not runnerProgress or flat(root.Position-runnerProgress.position).Magnitude>3 then
            runnerProgress={position=root.Position,at=stamp}
        end
        local count=0
        local competitors={}
        for _,actor in ipairs(participants())do
            if actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')=='Runner'then
                local state=actor:GetAttribute('RunState')
                if state=='Active'then count=count+1 end
                if actor.UserId~=player.UserId then
                    local c=actor.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
                    local eta
                    if r and state=='Active'then
                        local profile=movementProfiles.get('Runner',actor)
                        local finish=Core.zoneGoal(target.CFrame,target.Size,r.Position)
                        eta=Core.travelTime(flat(finish-r.Position).Magnitude,profile.MaxSpeed,profile.Acceleration,
                            flat(r.AssemblyLinearVelocity).Magnitude)
                    end
                    competitors[#competitors+1]={state=state,eta=eta}
                end
            end
        end
        local span=flat(goal-root.Position)
        local square=span:Dot(span)
        local density=0
        for _,enemy in ipairs(nearby)do
            local relative=flat(enemy.position-root.Position)
            local t=square>0 and math.clamp(relative:Dot(span)/square,0,1)or 0
            if (relative-span*t).Magnitude<45 then density=density+1 end
        end
        local distance=span.Magnitude
        if navigation and navigation.path and navigation.map==map then
            local last=root.Position
            distance=0
            for i=navigation.index,#navigation.path do
                distance=distance+flat(navigation.path[i]-last).Magnitude
                last=navigation.path[i]
            end
        end
        local endsAt=session:GetAttribute('EndsAt')
        secondsLeft=type(endsAt)=='number'and endsAt-workspace:GetServerTimeNow()or nil
        local race=Core.racePressure(Core.travelTime(distance,movement.MaxSpeed,movement.Acceleration,observedSpeed),competitors)
        policy=Core.runnerPolicy(secondsLeft,distance,movement.MaxSpeed,movement.Acceleration,observedSpeed,
            #nearby,count,density,stamp-runnerProgress.at,runnerStrategy and runnerStrategy.urgency,
            runnerStrategy and stamp-runnerStrategy.at or 0,race.urgency)
        runnerStrategy={urgency=policy.urgency,at=stamp}
        policy.runners,policy.chasers,policy.density=count,#nearby,density
        policy.race=race
    end
    local dangerZones={}
    local steeringThreats={}
    for _,enemy in ipairs(nearby)do
        local zones,adjusted=Core.threatZones(enemy,policy and policy.urgency or 0)
        steeringThreats[#steeringThreats+1]=adjusted
        for _,zone in ipairs(zones)do dangerZones[#dangerZones+1]=zone end
    end
    for _,projectile in ipairs(Core.projectileThreats(hazards))do steeringThreats[#steeringThreats+1]=projectile end
    local excluded={character}
    for _,p in ipairs(Players:GetPlayers())do if p.Character and p.Character~=character then excluded[#excluded+1]=p.Character end end
    for _,name in ipairs({'ClientBots','LobbyBots','LocalLocomotionRigs','AbilityClones'})do
        local f=workspace:FindFirstChild(name)
        if f then excluded[#excluded+1]=f end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excluded
    params.RespectCanCollide = true
    params.CollisionGroup = root.CollisionGroup
    local groundParams = RaycastParams.new()
    groundParams.FilterType = Enum.RaycastFilterType.Include
    groundParams.FilterDescendantsInstances = {field}
    groundParams.RespectCanCollide = true
    groundParams.CollisionGroup = root.CollisionGroup
    local edgeCache={}
    local function geometryAllowed(a,b)
        if not Core.clearSegment(a,b,hazards)then return false end
        local key=string.format('%.1f:%.1f:%.1f:%.1f',a.X,a.Z,b.X,b.Z)
        if edgeCache[key]~=nil then return edgeCache[key]end
        local offset=flat(b-a)
        if offset.Magnitude>0.01 and workspace:Blockcast(CFrame.new(a+Vector3.new(0,0.5,0)),Vector3.new(3,3,3),offset,params)then
            edgeCache[key]=false;return false
        end
        local samples=math.max(1,math.ceil(offset.Magnitude/4))
        for i=1,samples do
            local p = a+offset*(i/samples)
            local hit = workspace:Raycast(p+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
            if not hit or hit.Normal.Y < 0.55 or math.abs(hit.Position.Y-a.Y) > 6 then edgeCache[key]=false;return false end
        end
        edgeCache[key]=true
        return true
    end
    local function edgeAllowed(a,b)
        return Core.clearSegment(a,b,dangerZones)and geometryAllowed(a,b)
    end
    local function risk(position)
        local penalty=0
        for _,enemy in ipairs(nearby)do
            local distance=flat(position-enemy.position-enemy.velocity*0.25).Magnitude
            if distance<enemy.radius+14 then penalty=penalty+4*((enemy.radius+14-distance)/14)^2*(policy and policy.riskWeight or 1)end
            if enemy.potentialAbility then
                local possible={position=enemy.position,velocity=enemy.potentialVelocity,expires=enemy.potentialFor}
                local gap=Core.threatApproach(position,Vector3.zero,possible,.7,enemy.potentialRadius or enemy.catchRadius+3)
                if gap<10 then penalty=penalty+2*math.clamp((10-gap)/14,0,2)*(policy and policy.riskWeight or 1)end
            end
        end
        return penalty
    end
    local plannedAt=os.clock()
    if pursuit and interceptTime>0 and not edgeAllowed(pursuit.position,goal)then
        local proposed=goal
        goal=pursuit.position
        for _,fraction in ipairs({0.6,0.3})do
            local shorter=pursuit.position+(proposed-pursuit.position)*fraction
            if edgeAllowed(pursuit.position,shorter)then goal=shorter;interceptTime=interceptTime*fraction;break end
        end
        goals={goal}
    end
    local waypoint,finish=routeWaypoint(root.Position,goals,edgeAllowed,risk,map,
        activeRole..':'..targetName,hazardSignature..':'..tostring(policy and math.floor(policy.urgency*5)or 0),activeRole=='Catcher')
    local routingMS=(os.clock()-plannedAt)*1000
    api.MaxRoutingMS=math.max(api.MaxRoutingMS or 0,routingMS)
    local lookahead = Core.probeDistance(flat(waypoint-root.Position).Magnitude,speed)
    local function allowed(d,distance)
        return edgeAllowed(root.Position,root.Position+d*(distance or lookahead))
    end
    local charge=pursuit and Core.closeCharge(pursuit.position-root.Position,allowed)
    direction = charge or Core.choose(root.Position,waypoint,speed,steeringThreats,allowed,direction,policy and policy.urgency or 0)
    ownedHumanoid = humanoid
    local fresh=not actionContext
    actionContext={character=character,role=activeRole,pursuit=pursuit,candidates=allCandidates,nearby=nearby,waypoint=waypoint,
        policy=policy,finish=finish,allowed=allowed,hazards=hazards,field=field,at=os.clock(),
        geometryAllowed=geometryAllowed,lookahead=lookahead,collisionParams=params,groundParams=groundParams,
        castAllowed=function(d,distance)return geometryAllowed(root.Position,root.Position+d*distance)end}
    if fresh then actionElapsed=math.max(actionElapsed,1/30)end
    api.Diagnostics = {chasers=#nearby,hazards=#hazards,position=root.Position,goal=finish,waypoint=waypoint,direction=direction,
        map=map.Name,target=targetName,run=run,role=activeRole,routing=navigation.status,
        routeNodes=navigation.path and #navigation.path or 0,routingMS=routingMS,gridStep=navigation.step,
        interceptTime=interceptTime,invisibleTarget=pursuit and pursuit.invisible or false}
    api.Diagnostics.secondsLeft=secondsLeft
    api.Diagnostics.estimatedSeconds=policy and policy.eta
    api.Diagnostics.strategy=policy and policy.mode
    api.Diagnostics.urgency=policy and policy.urgency
    api.Diagnostics.runnerCount=policy and policy.runners
    api.Diagnostics.chaserDensity=policy and policy.density
    api.Diagnostics.maxSpeed=movement.MaxSpeed
    api.Diagnostics.acceleration=movement.Acceleration
    api.Diagnostics.closeCharge=charge~=nil
    api.Diagnostics.race=policy and policy.race
    api.Diagnostics.smartActive=api.SmartSpeedEnabled and smartState and smartState.untilAt>workspace:GetServerTimeNow()or false
    api.Diagnostics.targetCluster=targetCluster
    if activeRole == 'Catcher' then
        report((direction.Magnitude > 0 and 'Hunting ' or 'Blocked · ')..targetName)
    else
        local label=policy and policy.mode=='sprint'and'Sprint to safety'or policy and policy.mode=='push'and'Pushing crossing'or'Crossing'
        report((direction.Magnitude > 0 and label or 'Waiting for a gap')..' · '..#nearby..' chasers')
    end
end

function tp.try(character,humanoid,root,context,nearby,hazards,allowed,pursuit)
    local now=os.clock()
    if not api.Enabled or not api.TPDodgeEnabled or tp.state.blocked or tp.state.watch or now<tp.state.readyAt
        or now<tp.nextCheck or not context.collisionParams or not context.groundParams
        or not tp.eligible(character,humanoid,root)then return false end
    tp.nextCheck=now+.2
    local own=Core.abilityState(player,character,workspace:GetServerTimeNow())
    if own.shielded or own.protected then return false end
    local epoch=tp.epoch(character)
    if tp.state.epoch~=epoch then tp.state.epoch=epoch;tp.state.uses=0 end
    if tp.state.uses>=2 then return false end
    local attackETA,walkingETA=math.huge,math.huge
    local movement=movementProfiles.get(activeRole,player)
    local velocity=root.AssemblyLinearVelocity
    local chaseReady,currentCatch=false,false
    local meleeAt
    if activeRole=='Catcher'and pursuit and activeRunner(pursuit.player)then
        local state=Core.abilityState(pursuit.player,pursuit.player.Character,workspace:GetServerTimeNow())
        local serverNow=workspace:GetServerTimeNow()
        local duration=meleeConfig.Windup+meleeConfig.ActiveDuration+meleeConfig.Recovery
        local stable=pursuitHistory and pursuitHistory.id==pursuit.id and now-pursuitHistory.stableSince>=.25
        chaseReady=stable and not state.protected and not state.shielded and not state.evasive
            and meleeConfig.Enabled and serverNow>=nextCombatAt
            and Core.combatReady(serverNow,nextMelee,character:GetAttribute('ReachStartedAt')or 0,duration,combat.meleeRemaining())
            and not(character:GetAttribute('DaggerEquipped')and character:GetAttribute('DaggerState')~='Held')
            and flat(pursuit.position-root.Position).Magnitude<=14
        local box=combat.meleeBox(character)
        meleeAt=function(point)
            local relative=pursuit.position-point
            local aim=flat(relative)+flat(pursuit.velocity-velocity)*meleeConfig.Windup
            if aim.Magnitude<.01 or math.abs(relative.Y)>3 then return false end
            local hit,at=Core.predictContact(relative,pursuit.velocity,velocity,aim.Unit,box,
                meleeConfig.Windup,meleeConfig.ActiveDuration,hitReplay.sweep)
            return hit,aim.Unit,at
        end
        currentCatch=chaseReady and meleeAt(root.Position)or false
    end
    for _,enemy in ipairs(nearby)do
        local _,eta=Core.threatApproach(root.Position,velocity,enemy,.4,enemy.catchRadius or 8)
        local _,walking=Core.threatApproach(root.Position,direction*movement.MaxSpeed,enemy,.4,enemy.catchRadius or 8)
        attackETA=math.min(attackETA,eta);walkingETA=math.min(walkingETA,walking)
    end
    local progress=runnerProgress and runnerProgress.at or navigation and navigation.progressAt or now
    local stuck=math.max(0,now-progress)
    if attackETA>.25 and stuck<1.1 and not(chaseReady and not currentCatch)then return false end
    local walkSafe=direction.Magnitude>.1 and allowed(direction,3)and walkingETA==math.huge
    local policy={enabled=true,running=true,eligible=true,now=now,readyAt=tp.state.readyAt,uses=tp.state.uses,
        attackETA=attackETA,walkSafe=walkSafe,stuck=stuck,role=activeRole,chaseReady=chaseReady,currentCatch=currentCatch}
    local waypoint=context.waypoint or context.finish
    local forward=flat(waypoint-root.Position)
    if forward.Magnitude<.1 then return false end
    forward=forward.Unit
    local candidates={}
    local actors=participants()
    for _,distance in ipairs({2,3,4})do
        for i=0,11 do
            local aim=CFrame.Angles(0,i*math.pi/6,0):VectorToWorldSpace(forward)
            local point=root.Position+aim*distance
            if not Core.clearSegment(point,point,hazards)then continue end
            local facts=tp.probe(character,root,context.field,point,context.collisionParams,context.groundParams)
            if not facts or not Core.clearSegment(point,facts.exitPoint,hazards)then continue end
            local clearance,eta=math.huge,math.huge
            for _,enemy in ipairs(nearby)do
                local gap,contact=Core.threatApproach(point,Vector3.zero,enemy,.4,enemy.catchRadius or 8)
                local exitGap,exitContact=Core.threatApproach(point,aim*movement.MaxSpeed,enemy,.4,enemy.catchRadius or 8)
                clearance=math.min(clearance,gap,exitGap);eta=math.min(eta,contact,exitContact)
            end
            for _,actor in ipairs(actors)do
                local other=actor.Character;local body=other and other:FindFirstChild('HumanoidRootPart')
                if actor.UserId~=player.UserId and body and(body.Position-point).Magnitude<4 then clearance=-1;break end
            end
            facts.clearance,facts.attackETA=clearance,eta
            facts.hazardBlocked=not Core.clearSegment(root.Position,point,hazards)
            facts.gain=flat(waypoint-root.Position).Magnitude-flat(waypoint-point).Magnitude
            if chaseReady and not currentCatch then
                local hit,catchAim,at=meleeAt(point)
                local targetAt=pursuit.position+pursuit.velocity*(at or meleeConfig.Windup)
                local span=flat(targetAt-point)
                facts.catchOpportunity=hit and Core.clearSegment(point,targetAt,hazards)and(span.Magnitude<.01 or not workspace:Blockcast(
                    CFrame.new(point),Vector3.new(1.2,2,1.2),span,context.collisionParams))
                facts.chaseGain=flat(pursuit.position-root.Position).Magnitude-flat(pursuit.position-point).Magnitude
                facts.catchAim=catchAim;facts.catchETA=at
            end
            facts.kind=facts.catchOpportunity and'chase'or attackETA<=.25 and'attack'or facts.hazardBlocked and'trap'or'obstacle'
            candidates[#candidates+1]=facts
        end
    end
    local chosen=Core.tpChoice(policy,candidates)
    if chosen and tp.commit(character,root,chosen,epoch)then
        if chosen.kind=='chase'and pursuit then
            faceToward(character,humanoid,root,chosen.catchAim,false)
            api.TPLast.target=pursuit.player.Name;api.TPLast.predictedContact=chosen.catchETA
        end
        return true
    end
    return false
end

local function checkActions(character,humanoid,root)
    local context=actionContext
    local now=os.clock()
    if not context or context.character~=character or context.role~=activeRole or now-context.at>.25 then return end
    api.ActionChecks=(api.ActionChecks or 0)+1
    if lastActionClock then api.MaxActionCheckGapMS=math.max(api.MaxActionCheckGapMS or 0,(now-lastActionClock)*1000)end
    lastActionClock=now
    local pursuit=context.pursuit
    local candidates=context.candidates
    local nearby,hazards,allowed=context.nearby,context.hazards,context.allowed
    if activeRole=='Runner'then
        nearby=threats(now)
        hazards=collectHazards(root.Position,'Runner')
        local zones,steering,incoming={},{},{}
        for _,enemy in ipairs(nearby)do
            local enemyZones,adjusted=Core.threatZones(enemy,context.policy and context.policy.urgency or 0)
            steering[#steering+1]=adjusted;incoming[#incoming+1]=enemy
            for _,zone in ipairs(enemyZones)do zones[#zones+1]=zone end
        end
        for _,projectile in ipairs(Core.projectileThreats(hazards))do
            steering[#steering+1]=projectile;incoming[#incoming+1]=projectile
        end
        allowed=function(d,distance)
            local destination=root.Position+d*(distance or context.lookahead or 12)
            return Core.clearSegment(root.Position,destination,hazards)and Core.clearSegment(root.Position,destination,zones)
                and context.geometryAllowed(root.Position,destination)
        end
        local movement=movementProfiles.get('Runner',player)
        local imminent=false
        local soonest=math.huge
        for _,enemy in ipairs(steering)do
            local gap,eta=Core.threatApproach(root.Position,direction*movement.MaxSpeed,enemy,.8,enemy.radius)
            soonest=math.min(soonest,eta)
            if gap<0 then imminent=true end
            if enemy.potentialAbility then
                local possible={position=enemy.position,velocity=enemy.potentialVelocity,expires=enemy.potentialFor}
                local possibleGap=Core.threatApproach(root.Position,direction*movement.MaxSpeed,possible,.8,
                    enemy.potentialRadius or enemy.catchRadius+3)
                if possibleGap<8 then imminent=true end
            end
        end
        if imminent or direction.Magnitude>.01 and not allowed(direction)then
            local previous=direction
            direction=Core.choose(root.Position,context.waypoint or context.finish,movement.MaxSpeed,steering,allowed,direction,
                context.policy and context.policy.urgency or 0)
            if flat(direction-previous).Magnitude>.1 then api.EvasiveAdjustments=(api.EvasiveAdjustments or 0)+1 end
        end
        api.ThreatDiagnostics={chasers=#nearby,projectiles=#incoming-#nearby,hitETA=soonest,
            evasions=api.EvasiveAdjustments or 0,updatedAt=now}
        nearby=incoming
    end
    if activeRole=='Catcher'then
        local fresh={}
        pursuit=nil
        for _,candidate in ipairs(candidates or{})do
            if activeRunner(candidate.player)then
                local r=candidate.player.Character.HumanoidRootPart
                local sample=motion(candidate.player,now)
                local current=table.clone(candidate)
                current.position=r.Position;current.velocity=sample.velocity;current.acceleration=sample.acceleration or Vector3.zero
                local state=Core.abilityState(candidate.player,candidate.player.Character,workspace:GetServerTimeNow())
                current.shielded,current.protected=state.shielded,state.protected
                fresh[#fresh+1]=current
                if huntTarget and current.id==huntTarget.UserId then pursuit=current end
            end
        end
        candidates=fresh
        if pursuit then
            pursuitHistory=Core.trackMotion(pursuitHistory,pursuit.id,pursuit.velocity,now)
            if useCombat(character,humanoid,root,pursuit,context.allowed)then return end
        end
    end
    if useAbility(character,humanoid,root,pursuit,candidates,nearby,context.policy,context.finish,
        allowed,hazards,context.field,context.castAllowed)then return end
    if tp.try(character,humanoid,root,context,nearby,hazards,allowed,pursuit)then return end
    if activeRole=='Runner'then
        local movement=movementProfiles.get('Runner',player)
        local velocity=flat(root.AssemblyLinearVelocity)
        local ready=not pendingDash and boost.available(player)and character:GetAttribute('DashReady')==true
            and now>=(character:GetAttribute('DashCooldownUntil')or 0)and now>=nextDashRequest
        local aim=ready and Core.dashPreview(direction,dashHistory,now,movement.Dash)
        if aim and velocity.Magnitude>=12 and flat(context.finish-root.Position).Magnitude>6
            and allowed(aim,movement.Dash.Distance+2)then
            local clock,serverAt=os.clock(),workspace:GetServerTimeNow()
            pendingDash=actionRequest('Dash',Http:GenerateGUID(false),clock,serverAt)
            pendingDash.previousCount=character:GetAttribute('DashCount')or 0
            pendingDash.expectedDistance=movement.Dash.Distance
            boost.request(false);boostQueued=true;nextDashRequest=now+.25
            api.Actions.Dash=api.Actions.Dash+1;api.LastAction='Dash'
        end
    end
end

-- Runs before the game's movement model reads Humanoid.MoveDirection at Input+1.
RunService:BindToRenderStep(binding,Enum.RenderPriority.Input.Value,function(dt)
    if api.Destroyed then return end
    local ok, err = pcall(function()
        boostQueued=false -- the previous frame's request has already been consumed by the game
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local root = character and character:FindFirstChild('HumanoidRootPart')
        local runState = player:GetAttribute('RunState')
        local role = player:GetAttribute('GameRole')
        local allowed = role == 'Catcher' and Core.canHunt or Core.canRun
        local mode=session:GetAttribute('AdminMatchMode')
        local special=mode=='BladeBall'or mode=='CrossyRoad'or mode=='DonkeyKong'or mode=='FFACatchers'
        local canRun = humanoid and root and humanoid.Health > 0 and not root.Anchored and not special
            and not humanoid.Sit and not humanoid.PlatformStand and allowed(api.Enabled and not player:GetAttribute('AFK'),
            player:GetAttribute('InMatch'),role,runState,character:GetAttribute('MovementLocked')
            or character:GetAttribute('Ragdolled') or controlGate.movementReason(player)
            or session:GetAttribute('GlobalPaused'),session:GetAttribute('MapChanging'))
        if not canRun then
            release()
            huntTarget,api.Target=nil,nil
            api.Diagnostics=nil
            if wasActive and activeRole == 'Runner' and runState == 'Safe' then api.Crossings = api.Crossings+1 end
            if api.Enabled then
                report(player:GetAttribute('AFK')and'AFK · waiting to rejoin'or special and'Waiting · '..mode
                    or runState == 'Safe' and 'Safe · waiting for next crossing' or 'Waiting · '..tostring(runState or 'loading'))
            end
            wasActive=false
            activeRole=nil
            elapsed=1
            return
        end
        if activeRole ~= role then
            release()
            target,huntTarget,api.Target=nil,nil,nil
            wasActive,elapsed=false,1
        end
        activeRole=role
        if huntTarget and not activeRunner(huntTarget) then
            release(true)
            huntTarget,api.Target=nil,nil
            elapsed=1
        end
        if not wasActive then target=nil end
        wasActive=true
        elapsed=elapsed+dt
        actionElapsed=actionElapsed+dt
        if elapsed >= 0.1 then
            elapsed=elapsed%0.1
            local started=os.clock()
            updateSmartSpeed(character,humanoid,root)
            plan(character,humanoid,root)
            api.LastPlanMS=(os.clock()-started)*1000
            api.MaxPlanMS=math.max(api.MaxPlanMS or 0,api.LastPlanMS)
            api.Plans=(api.Plans or 0)+1
            api.TotalPlanMS=(api.TotalPlanMS or 0)+api.LastPlanMS
        end
        if actionElapsed>=1/30 then
            actionElapsed=actionElapsed%(1/30)
            checkActions(character,humanoid,root)
        end
        if ownedHumanoid then
            humanoid:Move(character:GetAttribute('TackleActive') and Vector3.zero or direction,false)
            if activeRole=='Runner'and direction.Magnitude>.1 and flat(root.AssemblyLinearVelocity).Magnitude>.2 then
                local now=os.clock()
                dashHistory[#dashHistory+1]={direction=direction,at=now}
                while #dashHistory>40 or(#dashHistory>0 and now-dashHistory[1].at>.6)do table.remove(dashHistory,1)end
            end
        end
    end)
    if not ok then
        api:Stop()
        api.LastError = tostring(err)
        report('Stopped · movement error (see console)')
        warn('HussAutoCross: '..tostring(err))
    end
end)
connect(RunService.Heartbeat,function(dt)
    if api.Destroyed then return end
    tp.observe();tp.refresh()
    refreshSmartButton()
    local alive,aliveError=pcall(keepAliveTick)
    if not alive then finishTouch();api.AntiAFKError=tostring(aliveError)end
    promptElapsed=promptElapsed+dt
    if promptElapsed<0.2 then return end
    promptElapsed=0
    local ok,err=pcall(automaticPrompts)
    api.PromptError=not ok and tostring(err)or nil
    local now=workspace:GetServerTimeNow()
    for id,pending in pairs(pendingAbilities)do if now-pending.time>10 then pendingAbilities[id]=nil end end
    for id,position in pairs(projectilePositions)do if os.clock()-position.time>2 then projectilePositions[id]=nil end end
    for id,record in pairs(pendingActions)do
        local age=os.clock()-record.requestedClock
        if age>10 or record.replyMS and(record.activationMS or record.accepted==false)then
            pendingActions[id]=nil
            if pendingDive==record then pendingDive=nil end
            if pendingMelee==record then pendingMelee=nil end
        end
        if record.kind=='Dash'and age>.5 and not record.activationMS then
            record.noActivation=true;pendingActions[id]=nil
            if pendingDash==record then pendingDash=nil end
        end
    end
end)
-- Follow the target after the game camera update, and keep body yaw consistent at simulation.
RunService:BindToRenderStep(binding..'_Facing',Enum.RenderPriority.Camera.Value+2,function()
    local ok,err=pcall(faceTarget,true)
    if not ok then api:Stop(); api.LastError=tostring(err); report('Stopped · facing error') end
end)
connect(RunService.PreSimulation,function()
    if pendingDive and not pendingDive.activationMS and pendingDive.accepted~=false and player.Character
        and player.Character:GetAttribute('TacklePredictionId')==pendingDive.id and tackle.isActive(player.Character)then
        pendingDive.effectPhase='firstSimulation';activated(pendingDive)
    end
    local ok,err=pcall(faceTarget,false)
    if not ok then api:Stop(); api.LastError=tostring(err); report('Stopped · facing error') end
end)
setProfileGetter(speedProfileGet)
env.HussAutoCross=api
return api
end
local ready,result=xpcall(initialize,function(err)return debug.traceback(tostring(err),2)end)
if not ready then
    if startupCleanup then pcall(startupCleanup)end
    error(result,0)
end
return result
