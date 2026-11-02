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
        detours.reset()
        runnerProgress=nil
        runnerStrategy=nil
        ownHistory={}
        lastMap,lastRun=map,run
    end
    local movement=movementProfiles.get(activeRole,player)
    local hazards,hazardSignature=collectHazards(root.Position,activeRole)
    local observedSpeed=flat(root.AssemblyLinearVelocity).Magnitude
    local speed=math.clamp(Core.distanceAt(0.6,observedSpeed,movement.MaxSpeed,movement.Acceleration,movement.Deceleration)/0.6,1,120)
    local goal, nearby, targetName, pursuit, goals, interceptTime,policy,secondsLeft,allCandidates,targetCluster,crossingForward
    if session:GetAttribute('AdminMatchMode')=='PumpkinHunt'then
        nearby=pumpkin.threats()
        targetName='Pumpkin Hunt'
        local endsAt=session:GetAttribute('EndsAt')
        secondsLeft=type(endsAt)=='number'and endsAt-workspace:GetServerTimeNow()or nil
        policy={urgency=0,riskWeight=1,mode='pumpkin',chasers=#nearby}
    elseif activeRole == 'Catcher' then
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
            report('Waiting for active runners','waiting')
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
        crossingForward=flat(target.Position-(target==a and b.Position or a.Position)).Unit
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
    local timedRunner=activeRole=='Runner'and policy and policy.mode~='pumpkin'
    local timing=timedRunner and{speed=math.max(1,speed)}or nil
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
    local directAvoidance
    local function geometryAllowed(a,b)
        if not Core.clearSegment(a,b,hazards)then
            if a==root.Position and b==goal then directAvoidance='Avoiding '..(runner.blockingHazard(a,b,hazards)or'hazard')end
            return false
        end
        local key=string.format('%.1f:%.1f:%.1f:%.1f',a.X,a.Z,b.X,b.Z)
        if edgeCache[key]~=nil then return edgeCache[key]end
        local offset=flat(b-a)
        if offset.Magnitude>0.01 and workspace:Blockcast(CFrame.new(a+Vector3.new(0,0.5,0)),Vector3.new(3,3,3),offset,params)then
            if a==root.Position and b==goal then directAvoidance='Avoiding an obstacle'end
            edgeCache[key]=false;return false
        end
        local samples=math.max(1,math.ceil(offset.Magnitude/4))
        for i=1,samples do
            local p = a+offset*(i/samples)
            local hit = workspace:Raycast(p+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
            if not hit or hit.Normal.Y < 0.55 or math.abs(hit.Position.Y-a.Y) > 6 then
                if a==root.Position and b==goal then directAvoidance='Avoiding unsafe ground'end
                edgeCache[key]=false;return false
            end
        end
        edgeCache[key]=true
        return true
    end
    local function edgeAllowed(a,b,t0,t1)
        if timedRunner then
            t0=t0 or flat(a-root.Position).Magnitude/timing.speed
            t1=t1 or t0+flat(b-a).Magnitude/timing.speed
            return geometryAllowed(a,b)and Core.runnerEdge(a,b,t0,t1,nearby)
        end
        return Core.clearSegment(a,b,dangerZones)and geometryAllowed(a,b)
    end
    local function risk(position,at)
        if timedRunner then return Core.runnerRisk(position,at or flat(position-root.Position).Magnitude/timing.speed,nearby,policy.urgency)end
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
    if policy and policy.mode=='pumpkin'then
        goal,pumpkin.target=Core.pumpkinGoal(root.Position,nearby,pumpkin.target,player:GetAttribute('HuntHits'),
            secondsLeft,geometryAllowed,risk)
        if not goal then
            -- Endpoint safety allows the existing A* planner to find a detour.
            goal,pumpkin.target=Core.pumpkinGoal(root.Position,nearby,pumpkin.target,player:GetAttribute('HuntHits'),
                secondsLeft,function(_,point)return geometryAllowed(point,point)end,risk)
        end
        if not goal then
            release();api.Target=nil
            api.Diagnostics={role=activeRole,mode='PumpkinHunt',pumpkins=#nearby,heads=player:GetAttribute('HuntHeads')or 0}
            report(#nearby==0 and'Pumpkin Hunt · waiting for pumpkins'or'Pumpkin Hunt · no clear bait position')
            return
        end
        goals={goal};api.Target=pumpkin.target
    end
    local detour
    if timedRunner then
        detour=detours.select(root,goal,nearby,policy,geometryAllowed,secondsLeft,crossingForward)
        if detour then
            if detour.kind~='revive'then
                local normalGeometry=geometryAllowed
                geometryAllowed=function(a,b)return Core.collectionStep(a,b,detour.forward)and normalGeometry(a,b)end
            end
            goal=Vector3.new(detour.position.X,root.Position.Y,detour.position.Z)
            goals={goal};targetName=detour.kind..':'..tostring(detour.id)
        end
    elseif detours.target then detours.cancel()end
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
        activeRole..':'..targetName,hazardSignature..':'..tostring(policy and math.floor(policy.urgency*5)or 0),activeRole=='Catcher',timing)
    if navigation.status=='planned'and directAvoidance then
        runner.operation:Set('avoidance',directAvoidance,.4,'avoiding')
    end
    local routingMS=(os.clock()-plannedAt)*1000
    api.MaxRoutingMS=math.max(api.MaxRoutingMS or 0,routingMS)
    local lookahead = Core.probeDistance(flat(waypoint-root.Position).Magnitude,speed)
    local function allowed(d,distance)
        return edgeAllowed(root.Position,root.Position+d*(distance or lookahead))
    end
    local charge=pursuit and Core.closeCharge(pursuit.position-root.Position,allowed)
    direction = charge or Core.choose(root.Position,waypoint,speed,steeringThreats,allowed,direction,policy and policy.urgency or 0,
        timedRunner and{runner=true,risk=risk}or nil)
    ownedHumanoid = humanoid
    local fresh=not actionContext
    actionContext={character=character,role=activeRole,pursuit=pursuit,candidates=allCandidates,nearby=nearby,waypoint=waypoint,
        policy=policy,secondsLeft=secondsLeft,finish=finish,allowed=allowed,hazards=hazards,field=field,at=os.clock(),
        geometryAllowed=geometryAllowed,lookahead=lookahead,collisionParams=params,groundParams=groundParams,
        pumpkin=policy and policy.mode=='pumpkin',timedRunner=timedRunner,
        collection=detour and detour.kind~='revive'and detour or nil,
        castAllowed=function(d,distance)return geometryAllowed(root.Position,root.Position+d*distance)end}
    if fresh then actionElapsed=math.max(actionElapsed,1/30)end
    api.Diagnostics = {chasers=#nearby,hazards=#hazards,position=root.Position,goal=finish,waypoint=waypoint,direction=direction,
        map=map.Name,target=targetName,run=run,role=activeRole,routing=navigation.status,
        routeNodes=navigation.path and #navigation.path or 0,routingMS=routingMS,gridStep=navigation.step,
        interceptTime=interceptTime,invisibleTarget=pursuit and pursuit.invisible or false}
    api.Diagnostics.detour=detour and detour.kind
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
    api.Diagnostics.arrivalRouting=timedRunner or false
    api.Diagnostics.laneRetained=navigation.retained or false
    if policy and policy.mode=='pumpkin'then
        api.Diagnostics.mode='PumpkinHunt'
        api.Diagnostics.heads=player:GetAttribute('HuntHeads')or 0
        api.Diagnostics.hits=player:GetAttribute('HuntHits')or 0
        report('Hunting pumpkin enemies','hunting')
    elseif activeRole == 'Catcher' then
        report((direction.Magnitude>0 and'Chasing 'or'Waiting for a safe path to ')..targetName,
            direction.Magnitude>0 and'chasing'or'waiting',targetName)
    else
        local label,action,subject='Crossing','crossing',nil
        if detour then
            if detour.kind=='revive'then
                subject=detour.actor.Name or tostring(detour.id);label='Reviving '..subject;action='reviving'
            else subject=detour.kind=='candy'and'Candy Corn'or'gems';label='Collecting '..subject;action='collecting'end
        end
        if direction.Magnitude<=.01 then label,action='Waiting for a safe route','waiting'end
        report(label,action,subject)
    end
end

