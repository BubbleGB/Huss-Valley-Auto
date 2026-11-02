local function useAbility(character,humanoid,root,pursuit,candidates,nearby,policy,finish,allowed,hazards,field,castAllowed)
    if not api.Settings.UseAbilities then return end
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
    local clock,dispatchedAt=os.clock(),workspace:GetServerTimeNow()
    local ok,requestId=pcall(gearPrediction.request,id,aim,'UseAbility')
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


-- Consumables share native prediction, owned counts and reply backoff with abilities.
local function useConsumable(character,humanoid,root,context,nearby,hazards,allowed,pursuit)
    local now=workspace:GetServerTimeNow()
    if not api.Enabled or api.StopEverything or not api.Settings.UseConsumables or not armory.loaded
        or not character or not root or not humanoid or humanoid.Health<=0 or session:GetAttribute('GlobalPaused')
        or session:GetAttribute('MapChanging')or abilityRules.blocked(player)or now<nextAbilityAt
        or now<(player:GetAttribute('GearReadyAt')or 0)or tackle.isActive(character)
        or character:GetAttribute('GearMotion')or character:GetAttribute('MovementLocked')then return end
    local id=armory.equippedGear
    local item=gearCatalog.get(id)
    local role=player:GetAttribute('GameRole')
    local caught=player:GetAttribute('RunState')=='Caught'
    if not item or item.Kind=='Ability'or(item.UseRole and item.UseRole~=role)
        or(tonumber((armory.gear or{})[id])or 0)<=0 or player:GetAttribute('InMatch')~=true then return end
    local failure=abilityFailures[id]
    if failure and now<failure.untilAt then return end
    local gate=controlGate.reason(player)
    if gate and not(id=='RescueKit'and caught and gate=='Spectating')then return end
    local c={active=player:GetAttribute('RunState')=='Active',caught=caught,
        rescue=character:GetAttribute('RescueAvailable')==true,vow=character:GetAttribute('VowMarked')==true,
        soulReap=gearCatalog.equippedForRole(armory,'Runner')=='SoulReap',boss=player:GetAttribute('BossHearts')~=nil,
        grounded=humanoid.FloorMaterial~=Enum.Material.Air,boosted=Core.abilityState(player,character,now).boosted,
        goalDistance=context and flat(context.finish-root.Position).Magnitude or 0,
        targetDistance=pursuit and flat(pursuit.position-root.Position).Magnitude or 0}
    local aim=direction.Magnitude>.1 and direction.Unit or flat(root.CFrame.LookVector)
    c.safeForward=allowed and allowed(aim,18)or false
    local nearest=math.huge
    for _,enemy in ipairs(nearby or{})do
        local delta=flat(enemy.position-root.Position)
        nearest=math.min(nearest,delta.Magnitude)
        if delta.Magnitude<24 and delta.Magnitude>.1 and aim:Dot(delta.Unit)<-.5 then c.enemyBehind=true end
    end
    c.pressured=nearest<28 or context and context.policy and context.policy.urgency>.65
    if id=='BananaPeel'and allowed and c.grounded then
        if role=='Catcher'and pursuit then
            local lead=Core.trapAim(pursuit.position-root.Position,pursuit.velocity,10,.9,2)
            if lead then aim=lead;c.trapOpportunity=true end
        elseif c.enemyBehind then aim=-aim end
        -- Native throw preview uses current facing; skip rather than turning the body for it.
        c.castClear=flat(root.CFrame.LookVector):Dot(aim)>.95 and allowed(aim,12)
    elseif id=='Lifeline'and allowed then
        for _,actor in ipairs(participants())do
            local body=actor.Character
            local r=body and body:FindFirstChild('HumanoidRootPart')
            if actor.UserId~=player.UserId and actor:GetAttribute('GameRole')=='Runner'and body
                and body:GetAttribute('RescueAvailable')and r then
                local delta=flat(r.Position-root.Position)
                if delta.Magnitude>1 and delta.Magnitude<=(item.Range or 30)and allowed(delta.Unit,delta.Magnitude)then
                    aim=delta.Unit;c.lifelineTarget=true;c.castClear=true;break
                end
            end
        end
    end
    if not Core.consumableUseful(id,role,c)then return end
    local clock=os.clock()
    local ok,requestId=pcall(gearPrediction.request,id,aim,'Use')
    nextAbilityAt=now+(ok and requestId and 1 or .5)
    if not ok then api.AbilityError=tostring(requestId);return end
    if requestId then
        local record=actionRequest('Consumable:'..id,requestId,clock,now);record.item=id
        pendingAbilities[requestId]={id=id,time=now}
        api.Actions.Consumable=(api.Actions.Consumable or 0)+1
        api.LastConsumable=id
        return true
    end
end
