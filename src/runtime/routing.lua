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

function runner.pathScore(position,path,index,timing,allowed,cost)
    local previous,elapsed,score=position,0,0
    for i=index,#path do
        local length=flat(path[i]-previous).Magnitude
        local nextAt=elapsed+length/timing.speed
        if not allowed(previous,path[i],elapsed,nextAt)then return nil end
        score=score+length*(1+Core.segmentRisk(previous,path[i],cost,elapsed,nextAt))
        previous,elapsed=path[i],nextAt
    end
    return score
end

local function routeWaypoint(position,goals,edgeAllowed,cost,map,key,signature,fast,timing)
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
        local direct=not stalled and Core.directSafe(position,goals[1],edgeAllowed,cost,timing)
        if direct then path={position,goals[1]}
        else path,step=Core.planRoute(position,goals,edgeAllowed,cost,now<fineUntil,timing)end
        if not path then
            for _,goal in ipairs(goals)do
                if Core.directSafe(position,goal,edgeAllowed,cost,timing)then path={position,goal};break end
            end
        end
        local index,retained=2,false
        if timing and same and previous.path and not stalled then
            local oldScore=runner.pathScore(position,previous.path,previous.index,timing,edgeAllowed,cost)
            local newScore=path and runner.pathScore(position,path,2,timing,edgeAllowed,cost)
            if oldScore and(not newScore or Core.keepRunnerLane(oldScore,newScore))then
                path,index,step=previous.path,previous.index,previous.step
                direct=previous.status=='direct';retained=true
            end
        end
        navigation={map=map,key=key,signature=signature,requested=goals[1],path=path,index=index,retained=retained,
            nextAt=now+(fast and 0.25 or timing and .35 or 0.65),status=path and(direct and'direct'or'planned')or'blocked',step=step,
            progressPosition=progressPosition,progressAt=progressAt,fineUntil=fineUntil}
    end
    navigation.progressPosition,navigation.progressAt=progressPosition,progressAt
    local path=navigation.path
    if not path then return goals[1],goals[1]end
    local index=Core.smoothWaypoint(position,path,navigation.index,edgeAllowed,cost,timing)
    navigation.index=index
    return path[index],path[#path]
end

