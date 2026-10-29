-- Prediction is deliberately short; later route segments carry soft uncertainty.
function Core.runnerPosition(enemy,at)
    at=math.clamp(at or 0,0,1.25)
    if at==0 then return enemy.position end
    if not enemy.burstFor or at<=enemy.burstFor then return enemy.position+enemy.velocity*at end
    local burst=math.max(0,enemy.burstFor)
    return enemy.position+enemy.velocity*burst+(enemy.afterVelocity or enemy.velocity)*(at-burst)
end

function Core.runnerEdge(a,b,t0,t1,enemies)
    t0,t1=t0 or 0,t1 or 0
    if t0>=1.25 or t1<=t0 then return true,math.huge end
    local duration=t1-t0
    local own=flat(b-a)/duration
    local horizon=math.min(duration,1.25-t0)
    local best=math.huge
    for _,enemy in ipairs(enemies)do
        if enemy.expires and enemy.expires<=t0 then continue end
        local radius=math.max(enemy.hardRadius or 0,(enemy.catchRadius or math.min(enemy.radius or 8,8))+1)+math.min(t0,1.25)*.8
        local clearance,_,initial,ending=Core.threatApproach(a,own,enemy,horizon,radius,t0)
        best=math.min(best,clearance)
        if clearance<0 and(initial>=0 or clearance<initial-.05 or ending<=initial+.05)then return false,best end
    end
    return true,best
end

function Core.runnerRisk(position,at,enemies,urgency)
    at=math.max(0,at or 0)
    local weight=math.max(.35,1-.65*math.clamp(urgency or 0,0,1))
    local penalty=0
    for _,enemy in ipairs(enemies)do
        if enemy.expires and enemy.expires<=at then continue end
        local center=Core.runnerPosition(enemy,at)
        if math.abs(center.Y-position.Y)>12 and not enemy.airborne then continue end
        local delta=flat(position-center)
        local distance=delta.Magnitude
        local inner=math.max(enemy.hardRadius or 0,(enemy.catchRadius or 8)+1)
        if distance<inner then penalty=penalty+60+(inner-distance)*10 end
        local outer=enemy.radius or inner+12
        if enemy.forward and not enemy.activeAbility then outer=inner+5 end
        outer=outer+math.min(at,1.25)*2+math.min(10,math.max(0,at-1.25)*4)
        if distance<outer+10 then penalty=penalty+4*math.clamp((outer+10-distance)/12,0,3)^2*weight end
        if enemy.forward and not enemy.activeAbility and(enemy.diveReadyIn or 0)<=at+.15 then
            local along=delta:Dot(enemy.forward)
            local lateral=(delta-enemy.forward*along).Magnitude
            local reach=(enemy.diveDistance or 15)+inner
            local width=(enemy.diveHalfWidth or 5)+math.min(at,1.25)*3
            if along>0 and along<reach and lateral<width+6 then
                penalty=penalty+12*math.clamp((width+6-lateral)/6,0,1)*weight
            end
        end
        if enemy.potentialAbility then
            local possible={position=center,velocity=enemy.potentialVelocity,expires=enemy.potentialFor}
            local gap=Core.threatApproach(position,Vector3.zero,possible,.5,enemy.potentialRadius or inner+3)
            if gap<10 then penalty=penalty+3*math.clamp((10-gap)/14,0,2)*weight end
        end
    end
    return penalty
end

function Core.keepRunnerLane(previous,new)
    return type(previous)=='number'and type(new)=='number'and previous<=new*1.12+3
end

function Core.dashTravel(config,speed,entrySpeed,at)
    local duration=config.Duration or .28
    local ratio=config.ScaleDistanceWithSpeed and math.clamp(entrySpeed/math.max(.01,speed),0,1)or 1
    local distance=config.Distance*ratio
    local t=math.clamp(at/duration,0,1)
    if config.Mode~='RunBoost'then return distance*t end
    local first=math.min(entrySpeed,speed)
    local exit=speed*ratio*(config.BoostExitSpeedRatio or .85)
    local lift=distance/duration-(first+exit)/2
    return duration*(first*t+(exit-first)*t*t/2+lift*(3*t*t-2*t*t*t))
end

function Core.runnerDash(context)
    local config=context.config
    local position,walk,aim=context.position,context.walk,context.aim
    local speed,enemies=context.speed,context.enemies
    local duration=config.Duration or .28
    local recovery=config.RecoveryDuration or .2
    local entry=context.entrySpeed or speed
    local distance=Core.dashTravel(config,speed,entry,duration)
    local endpoint=position+aim*distance
    if context.geometry and not context.geometry(position,endpoint)then return false,'blocked dash' end
    local previous,elapsed,gap=position,0,math.huge
    local count=math.max(1,math.ceil(duration*30))
    for i=1,count do
        local at=duration*i/count
        local nextPosition=position+aim*Core.dashTravel(config,speed,entry,at)
        local clear,clearance=Core.runnerEdge(previous,nextPosition,elapsed,at,enemies)
        if not clear then return false,'unsafe dash' end
        gap=math.min(gap,clearance);previous,elapsed=nextPosition,at
    end
    local recovered=endpoint+walk*speed*(config.RecoverySpeedRatio or .8)*recovery
    if context.geometry and not context.geometry(endpoint,recovered)then return false,'blocked recovery' end
    local safe,recoveryGap=Core.runnerEdge(endpoint,recovered,duration,duration+recovery,enemies)
    if not safe then return false,'unsafe recovery' end
    local horizon=math.max(.8,duration+recovery)
    local after=recovered+walk*speed*(horizon-duration-recovery)
    if context.geometry and not context.geometry(recovered,after)then return false,'blocked exit' end
    local exitClear,exitGap=Core.runnerEdge(recovered,after,duration+recovery,horizon,enemies)
    if not exitClear then return false,'unsafe exit' end
    gap=math.min(gap,recoveryGap,exitGap)
    local _,walkingGap=Core.runnerEdge(position,position+walk*speed*horizon,0,horizon,enemies)
    local walkingRisk=Core.runnerRisk(position+walk*speed*.5,.5,enemies,0)
    local dashAtHalf
    if duration>=.5 then dashAtHalf=position+aim*Core.dashTravel(config,speed,entry,.5)
    else
        dashAtHalf=endpoint+walk*speed*(config.RecoverySpeedRatio or .8)*math.min(recovery,.5-duration)
            +walk*speed*math.max(0,.5-duration-recovery)
    end
    local dashRisk=Core.runnerRisk(dashAtHalf,.5,enemies,0)
    if (walkingGap<2 or walkingRisk>=6)and(gap>walkingGap+1.5 or walkingRisk>dashRisk+3)then return true,'escape' end
    local goal=flat(context.goal-position)
    if goal.Magnitude<.01 then return false,'already at finish' end
    local progress=aim:Dot(goal.Unit)*distance
    local ordinary=walk:Dot(goal.Unit)*speed*duration
    local gain=progress-ordinary-speed*(1-(config.RecoverySpeedRatio or .8))*recovery
    if gain<.75 then return false,'save dash' end
    local readyAgain=math.max(duration+recovery,config.Cooldown or 1.1)+.15
    for _,enemy in ipairs(enemies)do
        local _,eta=Core.threatApproach(position,walk*speed,enemy,math.min(2,readyAgain),enemy.catchRadius or 8)
        if eta<readyAgain then return false,'reserve for closing threat' end
    end
    return true,'progress'
end

function Core.crossingStep(previous,context)
    local eligible=context.enabled and context.inMatch and context.role=='Runner'and context.state=='Active'
        and context.health>0 and context.ready~=false and not context.special and context.character~=nil and context.map~=nil
    local event
    if previous then
        local changed=previous.character~=context.character or previous.map~=context.map or previous.run~=context.run
        if not changed and eligible and type(context.endsAt)=='number'then previous.endsAt=context.endsAt end
        local expired=type(previous.endsAt)=='number'and context.now>=previous.endsAt
        local outcome
        if context.state=='Safe'and not changed then outcome='safe'
        elseif not changed and(context.state=='Caught'or context.health<=0)then outcome='caught'
        elseif context.role=='Catcher'and context.inMatch and not changed and not expired then outcome='caught'
        elseif not eligible or changed then
            outcome=not context.enabled and'aborted'or expired and not context.special and'timeout'or'aborted'
        end
        if outcome then
            event={outcome=outcome,seconds=math.max(0,context.now-previous.startedAt),map=previous.map,run=previous.run,
                dashes=math.max(0,(context.dashes or 0)-previous.dashes)}
            previous=nil
        end
    end
    if not previous and eligible then
        previous={startedAt=context.now,endsAt=context.endsAt,character=context.character,map=context.map,run=context.run,dashes=context.dashes or 0}
    end
    return previous,event
end

