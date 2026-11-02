local function lobbyEnabled()return api.Enabled and not api.Destroyed and not api.StopEverything and not env.HussAutoCrossTestHarness end
local lobbyInput=runner.createLobbyInput({playerGui=player.PlayerGui,coreGui=game:GetService('CoreGui'),input=Input,
    virtualInput=VirtualInput,guiService=GuiService,clock=os.clock,enabled=lobbyEnabled,
    touchesBusy=function(x,y)
        for object in pairs(anti.touches)do
            local state=object.UserInputState
            if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then anti.touches[object]=nil
            elseif(Vector2.new(object.Position.X,object.Position.Y)-Vector2.new(x,y)).Magnitude<24 then return true end
        end
        return false
    end,
    onTouchBegin=function(x,y)
        local inset=GuiService:GetGuiInset()
        local token={position=Vector2.new(x-inset.X,y-inset.Y),inputs={}}
        anti.nativeTouch=token
        return token
    end,
    onTouchEnd=function(token)
        if not token then return end
        if anti.nativeTouch==token then anti.nativeTouch=nil end
        for object in pairs(token.inputs)do anti.touches[object]=nil end
    end,
    camera=function()return workspace.CurrentCamera end,workspace=workspace})
local windowLease=runner.createWindowLease(function()return api.UI end)
runner.promptInputs=runner.createPromptInputs({playerGui=player.PlayerGui,input=lobbyInput,enabled=lobbyEnabled,clock=os.clock,
    voteExpanded=function()return player:GetAttribute('MapVoteOpen')==true end,
    prepare=function()return windowLease:Acquire('prompt')end,
    finish=function()windowLease:Release('prompt')end})
local lobbyNavigation=runner.createLobbyNavigation({pathfinding=game:GetService('PathfindingService'),clock=os.clock,
    canWalk=function(character,humanoid,root)
        return lobbyEnabled()and player:GetAttribute('InMatch')~=true
            and not root.Anchored and not humanoid.Sit and not humanoid.PlatformStand
            and not character:GetAttribute('MovementLocked')and not character:GetAttribute('Ragdolled')
            and not controlGate.movementReason(player)
    end})
local function haltLobbyMovement()
    local humanoid=runner.lobbyHumanoid;runner.lobbyHumanoid=nil
    if humanoid and humanoid.Parent then humanoid:Move(Vector3.zero,false)end
end
local progression=runner.createNativeProgression({api=api,Core=Core,player=player,session=session,clock=os.clock,enabled=lobbyEnabled,
    serverTime=function()return workspace:GetServerTimeNow()end,inputService=Input,guiService=GuiService,
    input=lobbyInput,navigation=lobbyNavigation,armory=function()return armory end,gearItems=gearItems,gearCatalog=gearCatalog,
    crateCatalog=require(package.Crates.CrateCatalog),journeyConfig=require(package.Progression.JourneyConfig),
    makeUI=function(state)return runner.createLobbyUI({player=player,playerGui=player.PlayerGui,workspace=workspace,
        input=lobbyInput,clock=os.clock,serverTime=function()return workspace:GetServerTimeNow()end,
        states=function()return state end,armory=function()return armory end,gearCatalog=gearCatalog,
        journeyClaimable=function(value)return Core.journeyClaimable(value,require(package.Progression.JourneyConfig))end,
        random=function(count)return random:NextInteger(1,count)end})end,
    makeWorkflow=runner.createLobbyWorkflow,
    approachDirection=function()local camera=workspace.CurrentCamera;return camera and camera.CFrame.LookVector end,
    stationApproach=function(prompt,job)
        if job.kind~='ghost'then return nil end
        local parent=prompt.Parent
        local model=parent and parent:FindFirstAncestor('GhostTrader')
        local stand=model and model:FindFirstChild('StandSpot',true)
        return stand and stand:IsA('Attachment')and stand.WorldPosition or nil
    end,
    promptOnScreen=function(prompt)
        local camera=workspace.CurrentCamera;local parent=prompt.Parent
        if not camera or not parent then return false end
        local position=parent:IsA('Attachment')and parent.WorldPosition or parent:IsA('BasePart')and parent.Position
        if not position then return false end
        local point,shown=camera:WorldToScreenPoint(position)
        local viewport=camera.ViewportSize
        return shown and point.Z>0 and point.X>70 and point.Y>70 and point.X<viewport.X-70 and point.Y<viewport.Y-70
    end,
    promptPosition=function(prompt)
        local parent=prompt.Parent
        if parent:IsA('Attachment')then return parent.WorldPosition end
        if parent:IsA('BasePart')then return parent.Position end
        if parent:IsA('Model')then return parent:GetPivot().Position end
    end,
    operation=function(text,action,target)runner.operation:Set('progression',text,3,action,target,'native-lobby')end,
    changed=function(job,active)
        if not active then haltLobbyMovement()end
        if active then windowLease:Acquire('progression')else windowLease:Release('progression')end
    end})
runner.progression=progression
for _,entry in ipairs({{'quest',package.Quests:FindFirstChild('QuestEvent')},{'journey',package.Progression:FindFirstChild('JourneyEvent')},
    {'spin',package:FindFirstChild('SpinWheelEvent')},{'crate',package.Crates:FindFirstChild('CrateEvent')},
    {'ghost',gameState:FindFirstChild('GhostTraderEvent')}})do
    if entry[2]then connect(entry[2].OnClientEvent,function(kind,state)progression:receive(entry[1],kind,state)end)end
end
connect(RunService.Heartbeat,function()
    runner.promptInputs:Tick()
    local ok,err=pcall(progression.Tick,progression)
    if not ok then progression:Cancel();api.ProgressionError=tostring(err)end
end)
function api:LobbyReport()return progression:Report()end
function api:GhostTraderReport()
    local state=progression.ghost and progression.ghost.value
    local report=progression:Report()
    return {status=report.kind=='ghost'and report.status or self.Settings.AutoGhostTrader and'Waiting for native Ghost Trader'or'Ghost Trader off',
        keys=state and state.keys,phase=report.kind=='ghost'and report.phase or nil}
end
