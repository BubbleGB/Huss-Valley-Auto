-- Wire native menu jobs to touch/prompt input and ordinary lobby pathfinding.
local function lobbyEnabled()return api.Enabled and not api.Destroyed and not api.StopEverything and not env.HussAutoCrossTestHarness end
local lobbyInput=runner.createLobbyInput({playerGui=player.PlayerGui,coreGui=game:GetService('CoreGui'),input=Input,
    virtualInput=VirtualInput,guiService=GuiService,clock=os.clock,enabled=lobbyEnabled,
    camera=function()return workspace.CurrentCamera end,workspace=workspace})
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
    promptPosition=function(prompt)
        local parent=prompt.Parent
        if parent:IsA('Attachment')then return parent.WorldPosition end
        if parent:IsA('BasePart')then return parent.Position end
        if parent:IsA('Model')then return parent:GetPivot().Position end
    end,
    operation=function(text,action,target)runner.operation:Set('progression',text,3,action,target,'native-lobby')end,
    changed=function(job,active)
        if not active then haltLobbyMovement()end
        local view=api.UI
        if not view or view.Cleaned then return end
        if active then
            job.restoreWindow=not view.Minimized
            if job.restoreWindow then view:Minimize()end
        elseif job.restoreWindow and view.Minimized then view:Restore()end
    end})
runner.progression=progression
for _,entry in ipairs({{'journey',package.Progression:FindFirstChild('JourneyEvent')},
    {'spin',package:FindFirstChild('SpinWheelEvent')},{'crate',package.Crates:FindFirstChild('CrateEvent')},
    {'ghost',gameState:FindFirstChild('GhostTraderEvent')}})do
    if entry[2]then connect(entry[2].OnClientEvent,function(kind,state)progression:receive(entry[1],kind,state)end)end
end
connect(RunService.Heartbeat,function()
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
