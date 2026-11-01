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

