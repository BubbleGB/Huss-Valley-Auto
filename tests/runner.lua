-- Supply the standalone script and a table of test filename -> source text.
-- Runs in the real Roblox client and restores running state, speed, and panel position.
return function(source,tests)
    assert(type(source)=='string'and type(tests)=='table','source and test source table are required')
    local loadController=assert(loadstring(source))
    local marker=assert(source:find('-- Runtime',1,true))
    local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
    local env=getgenv()
    local p=game.Players.LocalPlayer
    local old=env.HussAutoCross
    local gui=p.PlayerGui:FindFirstChild('HussAutoCrossUI')
    local saved={enabled=old and old.Enabled,speed=old and old.SpeedMultiplier,smart=old and old.SmartSpeedEnabled,
        tp=old and(old.TPAssistEnabled or old.TPDodgeEnabled),
        position=gui and gui.Panel.Position}
    local report={passed=0,failed=0,decisionChecks=0,suites={}}
    local profiles=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles)
    if old then old:Destroy()end
    local native=profiles.get
    local function recover()
        local a=env.HussAutoCross
        if a and type(a.Destroy)=='function'then pcall(a.Destroy,a)end
        env.HussAutoCross=nil
        local readonly=isreadonly(profiles)
        setreadonly(profiles,false);profiles.get=native;setreadonly(profiles,readonly)
        for _,v in ipairs(p.PlayerGui:GetChildren())do
            if v.Name=='HussAutoCrossUI'then v:Destroy()end
        end
    end
    local cases={
        {'huss-auto-cross.spec.lua','core'},
        {'huss-routing.spec.lua','core'},
        {'huss-advanced.spec.lua','core'},
        {'huss-strategy.spec.lua','core'},
        {'huss-abilities.spec.lua','core'},
        {'huss-speed.spec.lua','core'},
        {'huss-audit.spec.lua','core'},
        {'huss-smart-policy.spec.lua','core'},
        {'huss-action-policy.spec.lua','core'},
        {'huss-threats.spec.lua','core'},
        {'huss-tp.spec.lua','core'},
        {'huss-dive.spec.lua','core'},
        {'huss-pumpkin.spec.lua','core'},
        {'huss-crossing.spec.lua','core'},
        {'huss-prompt-runtime.spec.lua','heartbeat'},
        {'huss-auto-cross-runtime.spec.lua','runtime'},
        {'huss-speed-runtime.spec.lua','runtime'},
        {'huss-speed-slider-runtime.spec.lua','runtime'},
        {'huss-smart-runtime.spec.lua','runtime'},
        {'huss-action-runtime.spec.lua','runtime'},
        {'huss-threats-runtime.spec.lua','runtime'},
        {'huss-tp-runtime.spec.lua','runtime'},
        {'huss-dive-runtime.spec.lua','runtime'},
        {'huss-pumpkin-runtime.spec.lua','runtime'},
        {'huss-crossing-runtime.spec.lua','runtime'},
        {'huss-blackout-runtime.spec.lua','runtime'},
        {'huss-startup-runtime.spec.lua','runtime'},
        {'huss-input-runtime.spec.lua','runtime'},
        {'huss-afk-reporter-runtime.spec.lua','runtime'},
        {'huss-antiafk-runtime.spec.lua','loaded'},
    }
    for _,case in ipairs(cases)do
        local name,kind=case[1],case[2]
        local started=os.clock()
        local ok,result=pcall(function()
            local test=assert(loadstring(assert(tests[name],'missing '..name)))()
            if kind=='core'or kind=='heartbeat'then return test(Core)end
            if kind=='loaded'then
                if not env.HussAutoCross then loadController()end
                return test()
            end
            return test(source)
        end)
        report.suites[#report.suites+1]={name=name,passed=ok,seconds=os.clock()-started,
            result=ok and result or tostring(result)}
        if ok then
            report.passed=report.passed+1
            if kind=='core'then report.decisionChecks=report.decisionChecks+(result.passed or 0)end
        else
            report.failed=report.failed+1
            recover()
        end
    end
    recover()
    local restored,err=pcall(function()
        local a=loadController()
        if saved.speed then a:SetSpeedMultiplier(saved.speed)end
        if type(saved.smart)=='boolean'then a:SetSmartSpeedEnabled(saved.smart)end
        if type(saved.tp)=='boolean'then a:SetTPAssistEnabled(saved.tp)end
        if saved.position then p.PlayerGui.HussAutoCrossUI.Panel.Position=saved.position end
        if saved.enabled then a:Start()end
        report.restored={enabled=a.Enabled,multiplier=a.SpeedMultiplier,smart=a.SmartSpeedEnabled,tp=a.TPDodgeEnabled,visible=p.PlayerGui.HussAutoCrossUI.Enabled}
    end)
    if not restored then report.failed=report.failed+1;report.restoreError=tostring(err)end
    return report
end
