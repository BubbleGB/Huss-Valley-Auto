-- Invoke in the connected Roblox client with the standalone script source.
-- Exercises real UI signals and input; leaves the panel loaded and stopped.
return function(source)
    local load = assert(loadstring(source))
    local a = load()
    local p = game.Players.LocalPlayer
    local gui = p.PlayerGui:FindFirstChild('HussAutoCrossUI')
    assert(gui and not a.Enabled, 'must load paused')
    assert(not gui.Panel:FindFirstChild('Mode') and not a.SetMode, 'role selection must be automatic with no mode setting')
    firesignal(gui.Panel.Start.Activated)
    task.wait(0.1)
    assert(a.Enabled, 'Start must enable the controller')
    firesignal(gui.Panel.Stop.Activated)
    task.wait(0.1)
    assert(not a.Enabled and not a.Target, 'Stop must disable the controller and clear pursuit')
    local h = p.Character and p.Character:FindFirstChildOfClass('Humanoid')
    local deadline=os.clock()+1.5
    repeat task.wait(0.05) until not h or not h.Parent or h.MoveDirection.Magnitude < 0.01 or os.clock()>deadline
    assert(not h or not h.Parent or h.MoveDirection.Magnitude < 0.01, 'Stop must release movement after native action recovery')
    local panel, input = gui.Panel, game:GetService('VirtualInputManager')
    local inset = game:GetService('GuiService'):GetGuiInset()
    local old = panel.AbsolutePosition
    local x,y = old.X+90, old.Y+20+inset.Y
    input:SendMouseMoveEvent(x,y,game)
    input:SendMouseButtonEvent(x,y,0,true,game,0)
    task.wait(0.1)
    input:SendMouseMoveEvent(x+50,y+30,game)
    task.wait(0.1)
    input:SendMouseButtonEvent(x+50,y+30,0,false,game,0)
    task.wait(0.1)
    assert((panel.AbsolutePosition-old).Magnitude > 20, 'title drag must move panel')
    firesignal(gui.Panel.Close.Activated)
    task.wait(0.1)
    assert(a.Destroyed and not gui.Parent and not getgenv().HussAutoCross, 'X must unload')
    a:Destroy()
    local b=load()
    local c=load()
    assert(b.Destroyed and not c.Enabled, 'reexecution must replace old controller')
    local count=0
    for _,v in ipairs(p.PlayerGui:GetChildren()) do
        if v.Name=='HussAutoCrossUI' then count=count+1 end
    end
    assert(count==1, 'reexecution must leave one panel')
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
    return {lifecycle='passed',drag='passed',replacement='passed',nativeDash='passed',enabled=c.Enabled}
end
