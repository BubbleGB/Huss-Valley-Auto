return function(source)
    local old=getgenv().HussAutoCross
    if old then old:Destroy()end
    local p=game.Players.LocalPlayer
    local profiles=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles)
    local native=profiles.get
    local load=assert(loadstring(source))
    local a=load()
    a:SetSmartSpeedEnabled(false)
    local role=p:GetAttribute('GameRole')
    local normal=native(role,p)
    assert(profiles.get(role,p)==normal,'loading paused must retain native speed')
    assert(a.SpeedMultiplier==1.05,'default must use the tested conservative multiplier')
    a:Start()
    assert(math.abs(profiles.get(role,p).MaxSpeed/normal.MaxSpeed-1.05)<1e-8,'default must apply 1.05x')
    assert(profiles.get(role,p).Acceleration>=100000 and profiles.get(role,p).Dash==normal.Dash,'enabled movement must accelerate instantly while preserving native dash')
    a:SetSpeedMultiplier(1)
    assert(profiles.get(role,p).MaxSpeed==normal.MaxSpeed and profiles.get(role,p).Acceleration>=100000,'1x must retain native cap with instant acceleration')
    a:SetSpeedMultiplier(1.25)
    for _=1,200 do
        assert(math.abs(profiles.get(role,p).MaxSpeed/native(role,p).MaxSpeed-1.25)<1e-8,'multiplier must never compound')
    end
    assert(profiles.get('Runner',nil)==native('Runner',nil),'must not change unrelated actors/default profiles')
    for _,actor in ipairs(game.Players:GetPlayers())do
        if actor~=p then
            assert(profiles.get(actor:GetAttribute('GameRole'),actor)==native(actor:GetAttribute('GameRole'),actor),'must not modify another player')
        end
    end
    local report=a:SpeedReport()
    assert(math.abs(report.applied/report.normal-1.25)<1e-8,'must report native and applied speed')
    -- No yields while temporarily exercising real native modifier branches.
    for _,sample in ipairs({{'GearSlow',true},{'GearBoost',true},{'FartBoost',true},
        {'CrossingRunnerSpeedScale',1.15},{'CrossingCatcherSpeedScale',.92},{'TrollSpeed',1.3}})do
        local key,value=sample[1],sample[2]
        local previous=p:GetAttribute(key)
        local ok,err=pcall(function()
            p:SetAttribute(key,value)
            for _,r in ipairs({'Runner','Catcher'})do
                local expected=native(r,p)
                local applied=profiles.get(r,p)
                assert(math.abs(applied.MaxSpeed/expected.MaxSpeed-1.25)<1e-8,'must recompute after '..key)
            end
        end)
        p:SetAttribute(key,previous)
        assert(ok,err)
    end
    a:Stop()
    assert(profiles.get(role,p)==native(role,p),'Stop must restore native profile')
    a:Destroy()
    assert(profiles.get==native,'X must remove the speed wrapper')
    local b=load();b:Start();b:SetSpeedMultiplier(1.25)
    local c=load();c:Start();c:SetSpeedMultiplier(1.25)
    assert(b.Destroyed and math.abs(profiles.get(role,p).MaxSpeed/native(role,p).MaxSpeed-1.25)<1e-8,'reexecution must not stack multipliers')
    c:SetSpeedMultiplier(1.05)
    task.wait(.8)
    assert(not c.LastError,'must run through native movement without errors')
    return {lifecycle='passed',noCompounding='passed',modifiers='passed',localPlayerOnly='passed',speed=c:SpeedReport()}
end
