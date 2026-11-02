-- Supply the standalone script and a table of test filename -> source text.
-- Runs current native fixtures and restores settings, running state and window placement.
return function(source,tests)
    assert(type(source)=='string'and type(tests)=='table','source and test source table are required')
    assert(loadstring(source)) -- compile the actual executable before test-only startup suppression
    local count
    source,count=source:gsub('runner.preferences:Boot%(%)','api.Preferences.suspended=true;api.StopEverything=true')
    assert(count==1,'exactly one startup preference boot required')
    local loadController=assert(loadstring(source))
    local marker=assert(source:find('-- Runtime',1,true))
    local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
    local env=getgenv()
    local p=game.Players.LocalPlayer
    local old=env.HussAutoCross
    local saved={settings=old and type(old.GetSettings)=='function'and old:GetSettings(),enabled=old and old.Enabled,speed=old and old.SpeedMultiplier,smart=old and old.SmartSpeedEnabled,
        tp=old and(old.TPAssistEnabled or old.TPDodgeEnabled),inspection=old and old.InspectionEnabled,gems=old and old.AutoGemsEnabled,revives=old and old.AutoReviveEnabled,
        position=old and old.UI and old.UI.Window and old.UI.Window.UIElements.Main.Position}
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
        {'huss-reactions.spec.lua','core'},
        {'huss-detours.spec.lua','core'},
        {'huss-settings.spec.lua','core'},
        {'huss-progression.spec.lua','core'},
        {'huss-preferences-runtime.spec.lua','runtime'},
        {'huss-progression-runtime.spec.lua','runtime'},
        {'huss-settings-api-runtime.spec.lua','runtime'},
        {'huss-server-status-runtime.spec.lua','runtime'},
        {'huss-user-status-runtime.spec.lua','runtime'},
        {'huss-operation-runtime.spec.lua','runtime'},
        {'huss-wind-ui-runtime.spec.lua','runtime'},
        {'huss-camera-ownership-runtime.spec.lua','runtime'},
        {'huss-wind-input-runtime.spec.lua','runtime'},
        {'huss-prompt-runtime.spec.lua','heartbeat'},
        {'huss-auto-cross-runtime.spec.lua','runtime'},
        {'huss-speed-runtime.spec.lua','runtime'},
        {'huss-smart-runtime.spec.lua','runtime'},
        {'huss-action-runtime.spec.lua','runtime'},
        {'huss-threats-runtime.spec.lua','runtime'},
        {'huss-tp-runtime.spec.lua','runtime'},
        {'huss-dive-runtime.spec.lua','runtime'},
        {'huss-pumpkin-runtime.spec.lua','runtime'},
        {'huss-crossing-runtime.spec.lua','runtime'},
        {'huss-reactions-runtime.spec.lua','runtime'},
        {'huss-inspection-runtime.spec.lua','runtime'},
        {'huss-detours-runtime.spec.lua','runtime'},
        {'huss-collection-runtime.spec.lua','runtime'},
        {'huss-performance-runtime.spec.lua','runtime'},
        {'huss-blackout-runtime.spec.lua','runtime'},
        {'huss-startup-runtime.spec.lua','runtime'},
        {'huss-input-runtime.spec.lua','runtime'},
        {'huss-afk-reporter-runtime.spec.lua','runtime'},
        {'huss-antiafk-runtime.spec.lua','runtime'},
    }
    for _,case in ipairs(cases)do
        local name,kind=case[1],case[2]
        local started=os.clock()
        local ok,result=pcall(function()
            local test=assert(loadstring(assert(tests[name],'missing '..name)))()
            if kind=='core'or kind=='heartbeat'then return test(Core)end
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
        if saved.settings then
            for key,value in pairs(saved.settings)do
                if key=='Priorities'then a:SetPriorities(value)else a:SetSetting(key,value)end
            end
        end
        if saved.speed then a:SetSpeedMultiplier(saved.speed)end
        if type(saved.smart)=='boolean'then a:SetSmartSpeedEnabled(saved.smart)end
        if type(saved.tp)=='boolean'then a:SetTPAssistEnabled(saved.tp)end
        if type(saved.inspection)=='boolean'then a:SetInspectionEnabled(saved.inspection)end
        if type(saved.gems)=='boolean'then a:SetAutoGemsEnabled(saved.gems)end
        if type(saved.revives)=='boolean'then a:SetAutoReviveEnabled(saved.revives)end
        if saved.position then a.UI.Window.UIElements.Main.Position=saved.position end
        a.UI:Refresh()
        if saved.enabled then a:Start()end
        report.restored={enabled=a.Enabled,multiplier=a.SpeedMultiplier,smart=a.SmartSpeedEnabled,tp=a.TPDodgeEnabled,visible=a.UI.Window.UIElements.Main.Visible}
    end)
    if not restored then report.failed=report.failed+1;report.restoreError=tostring(err)end
    return report
end
