local function lobbyEnabled()return api.Enabled and not api.Destroyed and not api.StopEverything and not env.HussAutoCrossTestHarness end
local uiObstructions=runner.createUIObstructions({clock=os.clock,coreGui=game:GetService('CoreGui'),starter=game:GetService('StarterGui')})
runner.uiObstructions=uiObstructions
local lobbyInput=runner.createLobbyInput({playerGui=player.PlayerGui,coreGui=game:GetService('CoreGui'),input=Input,
    identityGet=getthreadidentity,identitySet=setthreadidentity,obstructions=uiObstructions,virtualInput=VirtualInput,guiService=GuiService,clock=os.clock,enabled=lobbyEnabled,
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
    halloweenConfig=require(gameState.HalloweenShopConfig),crateCatalog=require(package.Crates.CrateCatalog),journeyConfig=require(package.Progression.JourneyConfig),
    makeUI=function(state)return runner.createLobbyUI({emotesEnabled=require(package.Emotes.EmoteCatalog).ComingSoon~=true,player=player,playerGui=player.PlayerGui,workspace=workspace,
        input=lobbyInput,clock=os.clock,serverTime=function()return workspace:GetServerTimeNow()end,
        stationBlocked=function(prompt)return state:IsStationBlocked(prompt)end,states=function()return state end,armory=function()return armory end,gearCatalog=gearCatalog,
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
for _,entry in ipairs({{'pumpkins',gameState:FindFirstChild('PumpkinEvent')},{'halloween',gameState:FindFirstChild('HalloweenShopEvent')},{'quest',package.Quests:FindFirstChild('QuestEvent')},{'journey',package.Progression:FindFirstChild('JourneyEvent')},
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

local bossNavigation=runner.createLobbyNavigation({pathfinding=game:GetService('PathfindingService'),clock=os.clock})
runner.fallenKing=runner.createFallenKing({Core=Core,world=workspace,player=player,session=session,clock=os.clock,
    config=require(gameState.FallenKingBossConfig),enabled=lobbyEnabled,navigation=bossNavigation,
    blocked=function()return Input:GetFocusedTextBox()or GuiService.MenuIsOpen or controlGate.movementReason(player)end,
    clear=function(a,b,character,aim)
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={character};params.RespectCanCollide=true
        local hit=workspace:Raycast(a+Vector3.new(0,1,0),b-a,params)
        if not hit then
            if aim then return true end
            local ground=workspace:Raycast(b+Vector3.new(0,3,0),Vector3.new(0,-14,0),params)
            return ground~=nil and ground.Normal.Y>.6
        end
        return aim and(hit.Instance:FindFirstAncestor('FallenKing')~=nil or hit.Instance:FindFirstAncestor('Shrine')~=nil)or false
    end,
    meleeReach=math.min(7,require(gameState.FallenKingBossConfig).Strike.Reach),
    meleeCooldown=meleeConfig.Windup+meleeConfig.ActiveDuration+meleeConfig.Recovery,
    meleeAimed=function(aim)
        local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        local delta=flat(aim)
        return root and delta.Magnitude>.01 and flat(root.CFrame.LookVector):Dot(delta.Unit)>.98
    end,
    melee=function()
        if not windowLease:Acquire('boss')then return false end
        local hud=player.PlayerGui:FindFirstChild('HUD')
        local button=hud and hud:FindFirstChild('MeleeButton')
        if button and lobbyInput:Tap(button)then api.Actions.Melee=api.Actions.Melee+1;return true end
        return false
    end,
    aimed=function(aim)
        local camera=workspace.CurrentCamera
        return camera and aim.Magnitude>.1 and camera.CFrame.LookVector:Dot(aim.Unit)>.998
    end,
    throw=function()
        if not windowLease:Acquire('boss')then return false end
        local screen=player.PlayerGui:FindFirstChild('FallenKingBombCard')
        local button=screen and screen:FindFirstChild('Throw')
        return button and lobbyInput:Tap(button)==true or false
    end,
    finish=function()windowLease:Release('boss')end,
    operation=function(text)runner.operation:Set('combat',text,.5,'boss','Fallen King')end})
local fallenEvent=gameState:FindFirstChild('FallenKingEvent')
if fallenEvent then connect(fallenEvent.OnClientEvent,function(kind,data)runner.fallenKing:Receive(kind,data)end)end
function api:FallenKingReport()return runner.fallenKing:Report()end
