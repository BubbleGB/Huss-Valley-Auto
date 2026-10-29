connect(start.Activated, function() api:Start() end)
connect(stop.Activated, function() api:Stop() end)
connect(close.Activated, function() api:Destroy() end)
connect(Input.TouchStarted,function(input)anti.touches[input]=true end)
connect(Input.TouchEnded,function(input)anti.touches[input]=nil end)
connect(gui.Destroying, function() if not api.Destroyed then api:Destroy() end end)
connect(player.PlayerGui.DescendantAdded,lockAFKButton)
connect(player.PlayerGui.DescendantRemoving,function(object)
    local record=anti.buttons[object]
    if record then
        for _,connection in ipairs(record.connections)do connection:Disconnect()end
        object.Interactable=record.interactable;object.Selectable=record.selectable
        anti.buttons[object]=nil
    end
end)
connect(player.Idled,function()
    if not api.Enabled then return end
    anti.nextTouch=0
    local ok,err=pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(1,1),workspace.CurrentCamera.CFrame)
    end)
    api.IdleGuardFires=(api.IdleGuardFires or 0)+1
    if not ok then api.AntiAFKError=tostring(err)end
end)
connect(package.Weapons.ArmoryEvent.OnClientEvent,function(kind,state)
    if kind=='State'and type(state)=='table'then
        armory=state
        api.EquippedAbilities=state.equippedAbilities
    end
end)
connect(package.Gear.GearEvent.OnClientEvent,function(kind,data)
    if type(data)~='table'then return end
    if kind=='PredictionResult'then actionReply(data.requestId,data.accepted,data)end
    if kind=='BowlingPosition'and type(data.requestId)=='string'and typeof(data.cf)=='CFrame'then
        projectilePositions[data.requestId]={position=data.cf.Position,time=os.clock()}
    elseif kind=='PredictionResult'and pendingAbilities[data.requestId]then
        local pending=pendingAbilities[data.requestId]
        pendingAbilities[data.requestId]=nil
        if data.accepted then
            api.AbilitiesAccepted=(api.AbilitiesAccepted or 0)+1
            abilityFailures[pending.id]=nil
        else
            local failures=abilityFailures[pending.id]or{count=0}
            failures.count=failures.count+1
            failures.untilAt=workspace:GetServerTimeNow()+math.min(15,2^math.min(failures.count,4))
            abilityFailures[pending.id]=failures
            api.AbilitiesRejected=(api.AbilitiesRejected or 0)+1
        end
    end
end)
connect(gameState.MeleeEvent.OnClientEvent,function(id,accepted,data)actionReply(id,accepted,data)end)
connect(gameState.GameAction.OnClientEvent,function(kind,id,accepted,data)
    if kind=='TackleResult'then actionReply(id,accepted,data)end
end)
local function observeActionCharacter(character)
    for _,connection in ipairs(characterTimingConnections)do connection:Disconnect()end
    table.clear(characterTimingConnections)
    pendingDash,pendingDive,pendingMelee=nil,nil,nil
    if not character then return end
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('DashCount'):Connect(function()
        local count=character:GetAttribute('DashCount')or 0
        if pendingDash and count>pendingDash.previousCount then
            predicted(pendingDash);activated(pendingDash)
            pendingDash.localActivation=true;pendingActions[pendingDash.id]=nil;pendingDash=nil
            table.clear(dashHistory)
        end
    end)
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('LocalMeleePhase'):Connect(function()
        if pendingMelee and character:GetAttribute('LocalMeleePhase')=='Active'then activated(pendingMelee)end
    end)
    characterTimingConnections[#characterTimingConnections+1]=character:GetAttributeChangedSignal('HitShielded'):Connect(function()
        if not character:GetAttribute('HitShielded')then return end
        for _,record in pairs(pendingActions)do
            if record.item=='OneHitShield'then record.effectPhase='replicatedShield';activated(record)end
        end
    end)
end
connect(player.CharacterAdded,observeActionCharacter)
observeActionCharacter(player.Character)
connect(Collection:GetInstanceAddedSignal('PredictedGearVisual'),function(instance)
    local id=instance:GetAttribute('GearRequestId')
    local record=id and pendingActions[id]
    if record and record.item then record.effectPhase='replicatedVisual';activated(record)end
end)
package.Weapons.ArmoryEvent:FireServer('Get')

local dragInput, dragOrigin, panelOrigin
connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragInput, dragOrigin, panelOrigin = input, input.Position, panel.AbsolutePosition
    end
end)
connect(Input.InputEnded, function(input)
    if input == dragInput then dragInput = nil end
end)
connect(Input.InputChanged, function(input)
    if not dragInput then return end
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragOrigin
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920,1080)
        local inset = game:GetService('GuiService'):GetGuiInset()
        panel.Position = UDim2.fromOffset(
            math.clamp(panelOrigin.X+delta.X,0,math.max(0,viewport.X-panel.AbsoluteSize.X)),
            math.clamp(panelOrigin.Y+delta.Y,0,math.max(0,viewport.Y-inset.Y-panel.AbsoluteSize.Y)))
    end
end)
connect(player.CharacterRemoving, function(character)
    runner.observe(character,character:FindFirstChildOfClass('Humanoid'),character:FindFirstChild('HumanoidRootPart'),true)
    release()
    wasActive=false
    huntTarget, api.Target, target = nil, nil, nil
end)

