function runner.observe(character,humanoid,root,ending)
    local active=gameState:FindFirstChild('ActiveMap')
    local mode=session:GetAttribute('AdminMatchMode')
    local previous=runner.stats.attempt
    local attempt,event=Core.crossingStep(previous,{enabled=api.Enabled,inMatch=player:GetAttribute('InMatch'),
        role=player:GetAttribute('GameRole'),state=player:GetAttribute('RunState'),health=humanoid and humanoid.Health or 100,
        character=character,ready=root~=nil and not ending,map=active and active.Value,run=session:GetAttribute('RunNumber'),
        now=workspace:GetServerTimeNow(),endsAt=session:GetAttribute('EndsAt'),dashes=api.Actions.Dash,
        special=mode=='PumpkinHunt'or mode=='BladeBall'or mode=='CrossyRoad'or mode=='DonkeyKong'or mode=='FFACatchers'})
    if attempt and attempt~=previous then runner.stats.started=runner.stats.started+1 end
    runner.stats.attempt=attempt
    if event then
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
    for _,record in ipairs(stats.recent)do recent[#recent+1]=table.clone(record)end
    return {started=stats.started,safe=stats.safe,caught=stats.caught,timeouts=stats.timeout,interrupted=stats.aborted,
        active=stats.attempt~=nil,resolved=resolved,successRate=resolved>0 and stats.safe/resolved or nil,recent=recent}
end

function api:Start()
    if self.Destroyed then return end
    self.Enabled = true
    antiStart()
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
    gui:Destroy()
    if env.HussAutoCross == self then env.HussAutoCross = nil end
end
