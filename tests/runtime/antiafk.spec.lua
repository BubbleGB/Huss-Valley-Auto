-- Real input and AFK control cleanup; leaves the controller running.
return function()
    local a=assert(getgenv().HussAutoCross)
    local p=game.Players.LocalPlayer
    local navigation=require(game.ReplicatedStorage.ChickenOrHero.Presentation.HudNavigation)
    a:Stop()
    local original=navigation.handlers.AFK
    local buttons={}
    for _,button in ipairs(p.PlayerGui:GetDescendants())do
        if button:IsA('GuiButton')and(button.Name=='AFKButton'or button.Name=='AFKToggle')then
            buttons[button]={interactable=button.Interactable,selectable=button.Selectable}
        end
    end
    local reporters={}
    if getconnections then
        for _,c in ipairs(getconnections(p.Idled))do
            local fn=c.Function
            local ok,owner=pcall(function()return type(fn)=='function'and getfenv(fn).script end)
            if ok and owner==p.PlayerScripts:FindFirstChild('IdleReportClient')then reporters[c]=c.Enabled end
        end
    end
    a:Start()
    for c,enabled in pairs(reporters)do if enabled then assert(not c.Enabled,'running controller must block the real idle reporter')end end
    assert(navigation.handlers.AFK~=original,'Start must block the AFK navigation action')
    for button in pairs(buttons)do
        assert(not button.Interactable and not button.Selectable,'Start must lock AFK buttons')
        button.Interactable=true
        task.wait()
        assert(not button.Interactable,'AFK button lock must survive UI refreshes')
    end
    local began,ended=0,0
    local input=game:GetService('UserInputService')
    local c1=input.TouchStarted:Connect(function()began=began+1 end)
    local c2=input.TouchEnded:Connect(function()ended=ended+1 end)
    local pulses=a.TouchPulses or 0
    local keys=a.KeyPulses or 0
    task.wait(2)
    c1:Disconnect();c2:Disconnect()
    assert((a.TouchPulses or 0)>pulses and began>0 and ended>0,'must emit and release a real virtual touch')
    assert((a.KeyPulses or 0)>keys,'must emit the independent neutral-key keepalive')
    assert(not a.KeyKeepAliveError,'neutral input must succeed in the actual executor')
    assert(not a.AntiAFKError,'anti-AFK must run without runtime errors')
    a:Stop()
    for c,enabled in pairs(reporters)do assert(c.Enabled==enabled,'Stop must restore real native reporter state')end
    assert(navigation.handlers.AFK==original,'Stop must restore the exact AFK handler')
    for button,record in pairs(buttons)do
        if button.Parent then
            assert(button.Interactable==record.interactable and button.Selectable==record.selectable,'Stop must restore button properties')
        end
    end
    local stopped=a.TouchPulses
    task.wait(1.2)
    assert(a.TouchPulses==stopped,'Stop must suppress virtual input')
    a:Start()
    return {controls='passed',restoration='passed',touchBegin=began,touchEnd=ended,stop='passed'}
end
