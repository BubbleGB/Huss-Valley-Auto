-- Uses the game's native LightsOutKeep opt-out; sends no game remotes.
return function(source)
    local p=game.Players.LocalPlayer
    local attributeAtParent
    local c=p.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name=='HussAutoCrossUI'then attributeAtParent=child:GetAttribute('LightsOutKeep')end
    end)
    local ok,a=pcall(assert(loadstring(source)))
    task.wait(.25)
    c:Disconnect()
    assert(ok,a)
    local gui=assert(p.PlayerGui:FindFirstChild('HussAutoCrossUI'))
    assert(attributeAtParent==true,'blackout exemption must be set before the GUI enters PlayerGui')
    assert(gui.Enabled and gui.Panel.Visible,'native blackout must keep the panel visible')
    assert(not a.Enabled,'load must retain paused state')
    firesignal(gui.Panel.Start.Activated);task.wait(.05)
    assert(a.Enabled and gui.Enabled,'Start must work during blackout')
    firesignal(gui.Panel.Stop.Activated);task.wait(.05)
    assert(not a.Enabled and gui.Enabled,'Stop must keep controls visible during blackout')
    firesignal(gui.Panel.Close.Activated);task.wait(.05)
    assert(a.Destroyed and not gui.Parent,'X must unload during blackout')
    return {exemptionBeforeParent='passed',visible='passed',startStopClose='passed',
        blackout=game.ReplicatedStorage.ChickenOrHero.Game.Session:GetAttribute('LightsOut')==true}
end
