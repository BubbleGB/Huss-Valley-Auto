-- Reuse fresh action snapshots; no extra world scans or event connections.
function Core.dangerChange(position,before,after,oldHazards,hazards,age)
    local function close(point,airborne)
        local dx,dz=point.X-position.X,point.Z-position.Z
        return dx*dx+dz*dz<=8100 and(airborne or math.abs(point.Y-position.Y)<=12)
    end
    for index,enemy in ipairs(after)do
        if not close(enemy.position,enemy.airborne)then continue end
        local previous
        for i,old in ipairs(before)do
            if enemy.actor~=nil and old.actor==enemy.actor or enemy.actor==nil and old.actor==nil and i==index then previous=old;break end
        end
        if not previous then return 'arrival' end
        if enemy.kind~=previous.kind or enemy.activeAbility~=previous.activeAbility or enemy.reaching~=previous.reaching then return 'ability' end
        if flat(enemy.position-Core.runnerPosition(previous,age)).Magnitude>6 then return 'motion' end
    end
    for _,hazard in ipairs(hazards)do
        if hazard.projectionOf or not close(hazard.position)then continue end
        local found=false
        for _,old in ipairs(oldHazards)do
            if hazard.kind==old.kind and(hazard.source~=nil and hazard.source==old.source
                or hazard.source==nil and old.source==nil and flat(hazard.position-old.position).Magnitude<1)
                and math.abs((hazard.radius or 0)-(old.radius or 0))<.5 then found=true;break end
        end
        if not found then return 'hazard' end
    end
end

function Core.planDue(elapsed,reason)
    return elapsed>=.1 or reason~=nil and elapsed>=1/30
end

function Core.copyEvidence(value)
    if type(value)~='table'then return value end
    local copy={}
    for key,item in pairs(value)do copy[key]=Core.copyEvidence(item)end
    return copy
end

function Core.crossingSnapshot(context)
    local function nearest(items)
        local result={}
        for _,item in ipairs(items or{})do
            if item.projectionOf then continue end
            local distance=flat(item.position-context.position).Magnitude
            local index=#result+1
            for i,record in ipairs(result)do if distance<record.distance then index=i;break end end
            if index<=4 then
                table.insert(result,index,{position=item.position,distance=distance,kind=item.kind,
                    activeAbility=item.activeAbility or false,reaching=item.reaching or false,radius=item.radius,
                    id=item.actor and item.actor.UserId or nil})
                if #result>4 then result[5]=nil end
            end
        end
        return result
    end
    return {at=context.now,position=context.position,velocity=context.velocity,direction=context.direction,
        waypoint=context.waypoint,routing=context.routing,dashReady=context.dashReady,dashDecision=context.dashDecision,
        secondsLeft=context.secondsLeft,urgency=context.urgency,planReason=context.planReason,
        nearby=nearest(context.nearby),hazards=nearest(context.hazards),
        chasers=#(context.nearby or{}),hazardCount=#(context.hazards or{})}
end
