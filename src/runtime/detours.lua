-- Optional goals use native visible gems and the normal rescue remote sequence.
local detours={retry={},used=0}
runner.detours=detours
function detours.load()
    if detours.rescueConfig and detours.gemConfig and detours.remote then return true end
    local ok,err=pcall(function()
        detours.rescueConfig=require(gameState.RescueConfig)
        detours.gemConfig=require(package.Collectibles.GemConfig)
        detours.remote=gameState.RescueEvent
        if not detours.listener then detours.listener=connect(detours.remote.OnClientEvent,detours.reply)end
    end)
    api.DetourError=not ok and tostring(err)or nil
    return ok
end
function detours.reply(kind,id)
    if kind=='Cancelled'and detours.hold and detours.hold.id==id then
        detours.retry[id]=os.clock()+2
        detours.hold=nil;detours.target=nil
        elapsed=1;navigation=nil
    end
end
function detours.cancel()
    local hold=detours.hold
    if hold and not hold.sent then
        detours.remote:FireServer('Cancel',hold.id)
        detours.retry[hold.id]=os.clock()+2
    end
    detours.hold=nil;detours.target=nil
end
function detours.reset()
    detours.cancel();table.clear(detours.retry);detours.used=0
end
function detours.phase()
    local phase=session:GetAttribute('Phase')
    return phase=='GroupRun'or phase=='HeroRun'or phase=='FinalRun'
end
function detours.valid(candidate)
    local c=candidate.character
    local root=c and c:FindFirstChild('HumanoidRootPart')
    local helper=c and c:GetAttribute('RescueHelperId')
    return c and c.Parent and root and candidate.actor.Character==c and c:GetAttribute('RescueAvailable')==true
        and c:GetAttribute('Ragdolled')==true and(not helper or helper==player.UserId)
end
function detours.gems(position,folder)
    local result={}
    folder=folder or workspace:FindFirstChild('LocalRunnerGems')
    if not folder then return result end
    for _,part in ipairs(folder:GetChildren())do
        local board=part:IsA('BasePart')and part:FindFirstChildWhichIsA('BillboardGui')
        local icon=board and board:FindFirstChild('Gem')
        if board and board.Enabled and icon and icon.Visible and flat(part.Position-position).Magnitude<=36 then
            local amount=board:FindFirstChild('Amount')
            result[#result+1]={kind='gem',id=part.Name,source=part,position=part.Position,
                value=amount and tonumber(amount.Text:match('%d+'))or 1}
        end
    end
    return result
end
function detours.select(root,finish,enemies,policy,geometry,secondsLeft)
    if not(api.AutoGemsEnabled or api.AutoReviveEnabled)or not detours.phase()or not detours.load()then
        detours.cancel();return nil
    end
    local candidates=api.AutoGemsEnabled and detours.gemConfig.Enabled and detours.gems(root.Position)or{}
    if api.AutoReviveEnabled and detours.rescueConfig.Enabled and detours.used<(detours.rescueConfig.MaxRescuesPerCrossing or 1)then
        for _,actor in ipairs(participants())do
            if actor.UserId==player.UserId then continue end
            local c=actor.Character
            local targetRoot=c and c:FindFirstChild('HumanoidRootPart')
            local candidate={kind='revive',id=actor.UserId,actor=actor,character=c,position=targetRoot and targetRoot.Position}
            if targetRoot and flat(targetRoot.Position-root.Position).Magnitude<=48 and detours.valid(candidate)
                and os.clock()>=(detours.retry[actor.UserId]or 0)then candidates[#candidates+1]=candidate end
        end
    end
    local selected=Core.detourGoal({position=root.Position,finish=finish,speed=movementProfiles.get('Runner',player).MaxSpeed,
        secondsLeft=secondsLeft,urgency=policy.urgency,priorities=api.Settings.Priorities,gems=api.AutoGemsEnabled,revives=api.AutoReviveEnabled,
        holdSeconds=detours.rescueConfig.HoldSeconds,enemies=enemies,geometry=geometry},candidates)
    local held=detours.hold
    if held and(not selected or selected.kind~='revive'or selected.id~=held.id)then detours.cancel()end
    detours.target=selected
    return selected
end
function detours.act(character,root,context,enemies,hazards,now)
    local target=detours.target
    if not api.Enabled or not api.AutoReviveEnabled or activeRole~='Runner'or context.pumpkin
        or not detours.phase()or not target or target.kind~='revive'then
        if detours.hold then detours.cancel()end
        return false
    end
    local config=detours.rescueConfig
    local targetRoot=target.character and target.character:FindFirstChild('HumanoidRootPart')
    local inRange=targetRoot and(root.Position-targetRoot.Position).Magnitude<=config.Range-.25
    local safe=detours.valid(target)and inRange and(context.policy and context.policy.urgency or 0)<.65
        and type(context.secondsLeft)=='number'and context.secondsLeft>config.HoldSeconds+1.5
        and Core.clearSegment(root.Position,targetRoot.Position,hazards)
        and context.geometryAllowed(root.Position,targetRoot.Position)
        and Core.detourHoldSafe(root.Position,config.HoldSeconds,enemies,function(a,b)
            return Core.clearSegment(a,b,hazards)and context.geometryAllowed(a,b)end)
    if not safe then
        if detours.hold then detours.cancel()end
        return false
    end
    if not detours.hold then
        if detours.used>=(config.MaxRescuesPerCrossing or 1)or now<(detours.retry[target.id]or 0)then return false end
        detours.remote:FireServer('Begin',target.id)
        detours.hold={id=target.id,started=now,character=character,targetCharacter=target.character}
    end
    local hold=detours.hold
    if hold.character~=character or hold.targetCharacter~=target.character then detours.cancel();return false end
    direction=Vector3.zero
    if not hold.sent and now-hold.started>=config.HoldSeconds then
        detours.remote:FireServer('Finish',hold.id);hold.sent=true;detours.used=detours.used+1
    end
    if hold.sent and now-hold.started>config.HoldSeconds+(config.FinishGrace or 1.5)then detours.cancel();return false end
    return true
end
function api:SetAutoGemsEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','Auto Gems requires true or false')
    self.AutoGemsEnabled=enabled and detours.load()or false
    if not self.AutoGemsEnabled and detours.target and detours.target.kind=='gem'then detours.cancel()end
    elapsed=1;navigation=nil
    return self.AutoGemsEnabled
end
function api:SetAutoReviveEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','Auto Revive requires true or false')
    self.AutoReviveEnabled=enabled and detours.load()or false
    if not self.AutoReviveEnabled and detours.target and detours.target.kind=='revive'then detours.cancel()end
    elapsed=1;navigation=nil
    return self.AutoReviveEnabled
end
api:SetAutoGemsEnabled(false);api:SetAutoReviveEnabled(false)
