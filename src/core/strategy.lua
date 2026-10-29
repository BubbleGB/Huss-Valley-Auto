function Core.runnerPolicy(seconds,distance,maxSpeed,acceleration,currentSpeed,chasers,runners,density,stalled,previousUrgency,elapsed,raceUrgency)
    local eta=Core.travelTime(distance,maxSpeed,acceleration,currentSpeed)
    local deadline=0
    if type(seconds)=='number'then deadline=1-math.clamp((seconds-eta-1)/math.max(eta*0.75,4),0,1)end
    local pressure=math.clamp((chasers/math.max(1,runners)-0.5)/2.5,0,1)*0.45
    local crowded=math.clamp(density/4,0,1)*0.35
    local delayed=math.clamp((stalled-1)/5,0,0.8)
    local urgency=math.max(deadline,pressure,crowded,delayed,raceUrgency or 0)
    if previousUrgency then urgency=math.max(urgency,previousUrgency-math.max(0,elapsed or 0)*0.15)end
    return {eta=eta,urgency=urgency,riskWeight=math.max(.35,1-0.65*urgency),
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

