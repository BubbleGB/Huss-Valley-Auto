-- Runs before the game's movement model reads Humanoid.MoveDirection at Input+1.
RunService:BindToRenderStep(binding,Enum.RenderPriority.Input.Value,function(dt)
    if api.Destroyed then return end
    local ok, err = pcall(function()
        boostQueued=false -- the previous frame's request has already been consumed by the game
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local root = character and character:FindFirstChild('HumanoidRootPart')
        local runState = player:GetAttribute('RunState')
        local role = player:GetAttribute('GameRole')
        local allowed = role == 'Catcher' and Core.canHunt or Core.canRun
        local mode=session:GetAttribute('AdminMatchMode')
        if pumpkin.mode~=mode then
            release();target,huntTarget,api.Target=nil,nil,nil
            pumpkin.mode,pumpkin.target=mode,nil;table.clear(pumpkin.samples)
            wasActive,elapsed=false,1
        end
        local event=mode=='PumpkinHunt'
        local special=mode=='BladeBall'or mode=='CrossyRoad'or mode=='DonkeyKong'or mode=='FFACatchers'
        runner.observe(character,humanoid,root)
        local eventAllowed=not event or Core.pumpkinActive(mode,player:GetAttribute('InMatch'),player:GetAttribute('HuntOut'),runState)
        local canRun = eventAllowed and humanoid and root and humanoid.Health > 0 and not root.Anchored and not special
            and not humanoid.Sit and not humanoid.PlatformStand and allowed(api.Enabled and(role=='Catcher'and api.Settings.AutoChase or role~='Catcher'and api.Settings.AutoRun)and not player:GetAttribute('AFK'),
            player:GetAttribute('InMatch'),role,runState,character:GetAttribute('MovementLocked')
            or character:GetAttribute('Ragdolled') or controlGate.movementReason(player)
            or session:GetAttribute('GlobalPaused'),session:GetAttribute('MapChanging'))
        if not canRun then
            if not event and not special and runState=='Caught'then useConsumable(character,humanoid,root)end
            release()
            huntTarget,api.Target=nil,nil
            api.Diagnostics=nil
            if api.Enabled then
                report(event and player:GetAttribute('HuntOut')and'Pumpkin Hunt · eliminated; heads kept'or player:GetAttribute('AFK')and'AFK · waiting to rejoin'or special and'Waiting · '..mode
                    or runState == 'Safe' and 'Safe · waiting for next crossing' or 'Waiting · '..tostring(runState or 'loading'))
            end
            wasActive=false
            activeRole=nil
            elapsed=1
            return
        end
        if activeRole ~= role then
            release()
            target,huntTarget,api.Target=nil,nil,nil
            wasActive,elapsed=false,1
        end
        activeRole=role
        if huntTarget and not activeRunner(huntTarget) then
            release(true)
            huntTarget,api.Target=nil,nil
            elapsed=1
        end
        detours.guardCollection(root)
        if not wasActive then target=nil end
        wasActive=true
        elapsed=elapsed+dt
        actionElapsed=actionElapsed+dt
        if Core.planDue(elapsed,runner.replanReason)then
            local reason=runner.replanReason
            runner.replanReason=nil
            if reason then
                if navigation then navigation.nextAt=0 end
                api.ReactivePlans=(api.ReactivePlans or 0)+1
            end
            api.LastPlanReason=reason or 'scheduled'
            elapsed=reason and 0 or elapsed%.1
            local started=os.clock()
            if event then
                if smartState then smartState.untilAt=0 end
                api.SmartUntilAt=0
            else updateSmartSpeed(character,humanoid,root)end
            plan(character,humanoid,root)
            api.LastPlanMS=(os.clock()-started)*1000
            api.MaxPlanMS=math.max(api.MaxPlanMS or 0,api.LastPlanMS)
            api.Plans=(api.Plans or 0)+1
            api.TotalPlanMS=(api.TotalPlanMS or 0)+api.LastPlanMS
        end
        if actionElapsed>=1/30 then
            actionElapsed=actionElapsed%(1/30)
            checkActions(character,humanoid,root)
        end
        detours.guardCollection(root)
        if ownedHumanoid then
            humanoid:Move((character:GetAttribute('TackleActive')or detours.hold)and Vector3.zero or direction,false)
            if activeRole=='Runner'and direction.Magnitude>.1 and flat(root.AssemblyLinearVelocity).Magnitude>.2 then
                local now=os.clock()
                dashHistory[#dashHistory+1]={direction=direction,at=now,speed=math.min(flat(root.AssemblyLinearVelocity).Magnitude,movementProfiles.get('Runner',player).MaxSpeed)}
                while #dashHistory>40 or(#dashHistory>0 and now-dashHistory[1].at>.6)do table.remove(dashHistory,1)end
            end
        end
    end)
    if not ok then
        api:Stop()
        api.LastError = tostring(err)
        report('Stopped · movement error (see console)')
        warn('HussAutoCross: '..tostring(err))
    end
end)
connect(RunService.Heartbeat,function(dt)
    if api.Destroyed then return end
    local shown,showError=pcall(inspection.tick,dt)
    api.InspectionError=not shown and tostring(showError)or nil
    if not shown then inspection.hide()end
    tp.observe()
    local alive,aliveError=pcall(keepAliveTick)
    if not alive then finishTouch();api.AntiAFKError=tostring(aliveError)end
    promptElapsed=promptElapsed+dt
    if promptElapsed<0.2 then return end
    promptElapsed=0
    local ok,err=pcall(automaticPrompts)
    api.PromptError=not ok and tostring(err)or nil
    local now=workspace:GetServerTimeNow()
    for id,pending in pairs(pendingAbilities)do if now-pending.time>10 then pendingAbilities[id]=nil end end
    for id,position in pairs(projectilePositions)do if os.clock()-position.time>2 then projectilePositions[id]=nil end end
    for id,record in pairs(pendingActions)do
        local age=os.clock()-record.requestedClock
        if age>10 or record.replyMS and(record.activationMS or record.accepted==false)then
            pendingActions[id]=nil
            if pendingDive==record then pendingDive=nil end
            if pendingMelee==record then pendingMelee=nil end
        end
        if record.kind=='Dash'and age>.5 and not record.activationMS then
            record.noActivation=true;pendingActions[id]=nil
            if pendingDash==record then pendingDash=nil end
        end
    end
end)
-- Follow the target after the game camera update, and keep body yaw consistent at simulation.
RunService:BindToRenderStep(binding..'_Facing',Enum.RenderPriority.Camera.Value+2,function()
    local ok,err=pcall(faceTarget,true)
    if not ok then api:Stop(); api.LastError=tostring(err); report('Stopped · facing error') end
end)
connect(RunService.PreSimulation,function()
    if pendingDive and not pendingDive.activationMS and pendingDive.accepted~=false and player.Character
        and player.Character:GetAttribute('TacklePredictionId')==pendingDive.id and tackle.isActive(player.Character)then
        pendingDive.effectPhase='firstSimulation';activated(pendingDive)
    end
    local ok,err=pcall(faceTarget,false)
    if not ok then api:Stop(); api.LastError=tostring(err); report('Stopped · facing error') end
end)
