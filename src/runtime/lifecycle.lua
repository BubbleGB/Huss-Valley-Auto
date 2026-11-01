function runner.dashReady(character,now)
    return not pendingDash and boost.available(player)and character:GetAttribute('DashReady')==true
        and now>=(character:GetAttribute('DashCooldownUntil')or 0)and now>=nextDashRequest
end

-- At most two seconds of evidence per attempt; values contain no live Instances.
function runner.capture(character,root,nearby,hazards,now)
    local attempt=runner.stats.attempt
    if not api.Enabled or activeRole~='Runner'or not attempt or attempt.character~=character then return end
    now=now or os.clock()
    if attempt.lastSampleAt and now-attempt.lastSampleAt<.1 then return end
    local context=actionContext
    local diagnostic=api.Diagnostics
    local snapshot=Core.crossingSnapshot({now=now,position=root.Position,velocity=root.AssemblyLinearVelocity,direction=direction,
        nearby=nearby,hazards=hazards,waypoint=context and context.waypoint,routing=navigation and navigation.status,
        dashReady=runner.dashReady(character,now),
        dashDecision=api.DashDecision,secondsLeft=diagnostic and diagnostic.secondsLeft,
        urgency=context and context.policy and context.policy.urgency,planReason=api.LastPlanReason})
    local history=attempt.history or{}
    history[#history+1]=snapshot
    if #history>20 then table.remove(history,1)end
    attempt.history,attempt.lastSampleAt=history,now
end

function runner.observe(character,humanoid,root,ending)
    local active=gameState:FindFirstChild('ActiveMap')
    local mode=session:GetAttribute('AdminMatchMode')
    local previous=runner.stats.attempt
    local attempt,event=Core.crossingStep(previous,{enabled=api.Enabled,inMatch=player:GetAttribute('InMatch'),
        role=player:GetAttribute('GameRole'),state=player:GetAttribute('RunState'),health=humanoid and humanoid.Health or 100,
        character=character,ready=root~=nil and not ending,map=active and active.Value,run=session:GetAttribute('RunNumber'),
        now=workspace:GetServerTimeNow(),endsAt=session:GetAttribute('EndsAt'),dashes=api.Actions.Dash,
        special=mode=='PumpkinHunt'or mode=='BladeBall'or mode=='CrossyRoad'or mode=='DonkeyKong'or mode=='FFACatchers'})
    if attempt and attempt~=previous then runner.stats.started=runner.stats.started+1;api.DashDecision=nil end
    runner.stats.attempt=attempt
    if event then
        local history=previous.history or{}
        local age=#history>0 and math.max(0,os.clock()-history[#history].at)or nil
        event.evidence={history=history,sampleAge=age,fresh=age~=nil and age<=.5,
            interpretation='Observed context; catch cause is unconfirmed'}
        runner.stats[event.outcome]=runner.stats[event.outcome]+1
        event.map=typeof(event.map)=='Instance'and event.map.Name or tostring(event.map)
        runner.stats.recent[#runner.stats.recent+1]=event
        if #runner.stats.recent>30 then table.remove(runner.stats.recent,1)end
        if event.outcome=='safe'then api.Crossings=api.Crossings+1 end
    end
end
function api:CrossingReport()
    local stats=runner.stats
    local resolved=stats.safe+stats.caught+stats.timeout
    local recent={}
    for _,record in ipairs(stats.recent)do recent[#recent+1]=Core.copyEvidence(record)end
    return {started=stats.started,safe=stats.safe,caught=stats.caught,timeouts=stats.timeout,interrupted=stats.aborted,
        active=stats.attempt~=nil,resolved=resolved,successRate=resolved>0 and stats.safe/resolved or nil,recent=recent}
end

function api:Start()
    if self.Destroyed then return end
    self.Enabled = true
    if self.Settings.AntiAFK then antiStart()end
    elapsed = 1
    report('Waiting for an active round')
end
function api:Stop()
    self.Enabled = false
    local c=player.Character
    runner.observe(c,c and c:FindFirstChildOfClass('Humanoid'),c and c:FindFirstChild('HumanoidRootPart'))
    antiStop()
    release()
    huntTarget, self.Target = nil, nil
    self.Diagnostics = nil
    choiceRequest,voteRequest={},{}
    report('Stopped')
end
function api:Destroy()
    if self.Destroyed then return end
    self:Stop()
    self.Destroyed = true
    if movementProfiles.get==speedProfileGet then setProfileGetter(nativeProfileGet)end
    RunService:UnbindFromRenderStep(binding)
    RunService:UnbindFromRenderStep(binding..'_Facing')
    for _,c in ipairs(connections) do c:Disconnect() end
    for _,c in ipairs(characterTimingConnections)do c:Disconnect()end
    table.clear(characterTimingConnections)
    table.clear(connections)
    if runner.ui then runner.ui:Cleanup()end
    gui:Destroy()
    if env.HussAutoCross == self then env.HussAutoCross = nil end
end
