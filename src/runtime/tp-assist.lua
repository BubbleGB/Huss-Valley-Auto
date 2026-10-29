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

