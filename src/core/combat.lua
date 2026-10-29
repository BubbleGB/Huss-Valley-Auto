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
    local latency=math.clamp(tonumber(options.diveLatency)or .05,0,.12)
    local offset=flat(targetVelocity)*latency
    if offset.Magnitude>2 then offset=offset.Unit*2 end
    local robustBox=table.clone(options.diveBox)
    robustBox.width=robustBox.width*.95
    robustBox.far=math.max(robustBox.near,robustBox.far-.2)
    local robustHorizon=math.min(horizon,.26)
    local function confident(aim)
        local side=Vector3.new(-aim.Z,0,aim.X)
        local worst=0
        -- The chosen direction must still catch both plausible lateral changes,
        -- with the replicated position ahead of or behind the observed position.
        for _,along in ipairs({-1,1})do
            for _,across in ipairs({-1,1})do
                local function path(at)
                    return target(at)+offset*along+side*(across*(.35+8*at+20*at*at))
                end
                local hit,at=Core.predictContact(path(0),targetVelocity,Vector3.zero,aim,robustBox,0,robustHorizon,
                    options.sweep,options.diveTravel,path)
                if not hit then return nil end
                worst=math.max(worst,at)
            end
        end
        return worst
    end
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
                local worst=confident(aim)
                if not worst then continue end
                local score=worst+lateral*.035
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
                if dot<=minimum+.00001 and redirected.Magnitude>.01 then return redirected.Unit,sample.speed end
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

function Core.combatReady(now, localReadyAt, serverStartedAt, duration, predictionRemaining)
    return now >= math.max(localReadyAt,serverStartedAt+duration) and predictionRemaining <= 0
end

function Core.chaserRadius(maxDiveDistance,catchReach,cooldown,active)
    return catchReach+3+((active or cooldown<=0.35)and maxDiveDistance or 0)
end

