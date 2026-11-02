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
        api.DashDecision=nil
        nearby=context.pumpkin and pumpkin.threats()or threats(now)
        hazards=collectHazards(root.Position,'Runner')
        local changed=Core.dangerChange(root.Position,context.nearby or{},nearby,context.hazards or{},hazards,now-context.at)
        if changed then runner.replanReason=runner.replanReason or changed end
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
            local safe=context.timedRunner and Core.runnerEdge(root.Position,destination,0,
                flat(destination-root.Position).Magnitude/math.max(1,movementProfiles.get('Runner',player).MaxSpeed),nearby)
                or not context.timedRunner and Core.clearSegment(root.Position,destination,zones)
            return safe and Core.clearSegment(root.Position,destination,hazards)and context.geometryAllowed(root.Position,destination)
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
        local blocked=direction.Magnitude>.01 and not allowed(direction)
        if blocked then runner.replanReason=runner.replanReason or 'blocked' end
        if imminent or blocked then
            local previous=direction
            direction=Core.choose(root.Position,context.waypoint or context.finish,movement.MaxSpeed,steering,allowed,direction,
                context.policy and context.policy.urgency or 0,context.timedRunner and{runner=true,
                    risk=function(p,t)return Core.runnerRisk(p,t,nearby,context.policy and context.policy.urgency or 0)end}or nil)
            if flat(direction-previous).Magnitude>.1 then api.EvasiveAdjustments=(api.EvasiveAdjustments or 0)+1 end
        end
        api.ThreatDiagnostics={chasers=#nearby,projectiles=#incoming-#nearby,hitETA=soonest,
            evasions=api.EvasiveAdjustments or 0,updatedAt=now}
        nearby=incoming
    end
    if activeRole=='Runner'and detours.act(character,root,context,nearby,hazards,now)then
        runner.capture(character,root,nearby,hazards,now);return
    end
    if activeRole=='Catcher'and not context.pumpkin then
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
    if not context.pumpkin then
        if useConsumable(character,humanoid,root,context,nearby,hazards,allowed,pursuit)then return end
        if useAbility(character,humanoid,root,pursuit,candidates,nearby,context.policy,context.finish,
            allowed,hazards,context.field,context.castAllowed)then runner.capture(character,root,nearby,hazards,now);return end
        if tp.try(character,humanoid,root,context,nearby,hazards,allowed,pursuit)then runner.capture(character,root,nearby,hazards,now);return end
    end
    if activeRole=='Runner'then
        local movement=movementProfiles.get('Runner',player)
        local velocity=flat(root.AssemblyLinearVelocity)
        local ready=api.Settings.AutoDash and runner.dashReady(character,now)
        local aim,entrySpeed
        if ready then aim,entrySpeed=Core.dashPreview(direction,dashHistory,now,movement.Dash)end
        local dashAllowed=aim and not context.timedRunner and allowed(aim,movement.Dash.Distance+2)
        if aim and context.timedRunner then
            local reason
            dashAllowed,reason=Core.runnerDash({position=root.Position,walk=direction,aim=aim,goal=context.finish,
                speed=movement.MaxSpeed,entrySpeed=entrySpeed or velocity.Magnitude,config=movement.Dash,enemies=nearby,
                geometry=function(a,b)return Core.clearSegment(a,b,hazards)and context.geometryAllowed(a,b)end})
            api.DashDecision=reason
        end
        if aim and velocity.Magnitude>=12 and flat(context.finish-root.Position).Magnitude>6 and dashAllowed then
            local clock,serverAt=os.clock(),workspace:GetServerTimeNow()
            pendingDash=actionRequest('Dash',Http:GenerateGUID(false),clock,serverAt)
            pendingDash.previousCount=character:GetAttribute('DashCount')or 0
            pendingDash.expectedDistance=context.timedRunner and Core.dashTravel(movement.Dash,movement.MaxSpeed,entrySpeed or velocity.Magnitude,movement.Dash.Duration)or movement.Dash.Distance
            boost.request(false);boostQueued=true;nextDashRequest=now+.25
            api.Actions.Dash=api.Actions.Dash+1;api.LastAction='Dash'
        end
        runner.capture(character,root,nearby,hazards,now)
    end
end
