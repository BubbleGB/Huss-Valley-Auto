-- Invoke in the connected Roblox client with the standalone script source.
-- Controller lifecycle and isolated native dash integration; loads paused.
return function(source)
    local load = assert(loadstring(source))
    local a = load()
    local p = game.Players.LocalPlayer
    local gui = p.PlayerGui:FindFirstChild('HussAutoCrossUI')
    assert(gui and not a.Enabled, 'must load paused')
    assert(not gui:FindFirstChild('Panel') and not a.SetMode, 'legacy panel and mode setting must be absent')
    a:SetSetting('AutoRun',false);a:SetSetting('AutoChase',false)
    a:Start()
    task.wait(0.1)
    assert(a.Enabled, 'Start must enable the controller')
    a:Stop()
    task.wait(0.1)
    assert(not a.Enabled and not a.Target, 'Stop must disable the controller and clear pursuit')
    local h = p.Character and p.Character:FindFirstChildOfClass('Humanoid')
    local deadline=os.clock()+1.5
    repeat task.wait(0.05) until not h or not h.Parent or h.MoveDirection.Magnitude < 0.01 or os.clock()>deadline
    assert(not h or not h.Parent or h.MoveDirection.Magnitude < 0.01, 'Stop must release movement after native action recovery')
    local identity=getthreadidentity and getthreadidentity()
    local unloaded,unloadError=pcall(function()
        if identity and setthreadidentity then setthreadidentity(2)end
        a:Destroy()
    end)
    if identity and setthreadidentity then setthreadidentity(identity)end
    assert(unloaded,unloadError)
    assert(a.Destroyed and not gui.Parent and not getgenv().HussAutoCross, 'Destroy must unload')
    a:Destroy()
    local b=load()
    local c=load()
    assert(b.Destroyed and not c.Enabled, 'reexecution must replace old controller')
    local count=0
    for _,v in ipairs(p.PlayerGui:GetChildren()) do
        if v.Name=='HussAutoCrossUI' then count=count+1 end
    end
    assert(count==1, 'reexecution must leave one owned root UI')
    local windCount=0
    for _,v in ipairs(p.PlayerGui:GetChildren())do
        if v:IsA('ScreenGui')and v.Name:find('HussAutoCrossWindUI_',1,true)==1 then windCount=windCount+1 end
    end
    assert(windCount==#c.UI.OwnedGuis,'reexecution must leave exactly one WindUI owned GUI set')
    assert(not p.PlayerGui.HussAutoCrossUI:FindFirstChild('Panel'),'reexecution must not recreate legacy widgets')
    local package=game.ReplicatedStorage.ChickenOrHero
    local model=require(package.Movement.MovementModel)
    local profile=require(package.Movement.MovementProfiles).get('Runner',p)
    local state=model.new()
    local forward=Vector3.zAxis
    for _=1,60 do
        model.step(state,forward,30,1/60,profile,true,Vector3.zero,1,false,forward*30,false)
    end
    local boost=require(package.Movement.BoostInput)
    boost.request(false)
    local requested,touch=boost.consume()
    model.step(state,Vector3.xAxis,30,1/60,profile,true,Vector3.zero,1,requested,forward*30,touch)
    assert(state.dashRemaining>0, 'dash request must activate the native movement model on a running turn')
    return {lifecycle='passed',replacement='passed',nativeDash='passed',enabled=c.Enabled}
end
