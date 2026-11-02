-- Checks native LightsOutKeep ownership; reports whether a real blackout is active.
return function(source)
    local p=game.Players.LocalPlayer
    local atParent={}
    local c=p.PlayerGui.ChildAdded:Connect(function(child)
        if child:IsA('ScreenGui')then atParent[child]=child:GetAttribute('LightsOutKeep')end
    end)
    local a
    local ok,result=pcall(function()
        a=assert(loadstring(source))()
        local root=assert(p.PlayerGui:FindFirstChild('HussAutoCrossUI'))
        local owned={root}
        for _,gui in ipairs(a.UI.OwnedGuis)do owned[#owned+1]=gui end
        local deadline=os.clock()+2
        repeat
            local observed=true
            for _,gui in ipairs(owned)do if atParent[gui]==nil then observed=false end end
            if observed then break end
            game:GetService('RunService').RenderStepped:Wait()
        until os.clock()>deadline
        local function visible()
            for _,gui in ipairs(owned)do
                assert(atParent[gui]==true,'every owned GUI must set LightsOutKeep before entering PlayerGui')
                assert(gui:GetAttribute('LightsOutKeep')==true and gui.Enabled,'every owned GUI must remain enabled')
            end
        end
        visible();assert(not a.Enabled,'load must retain paused state')
        a:SetSetting('AutoRun',false);a:SetSetting('AutoChase',false)
        a.UI.Controls.StopEverything:Set(false);assert(a.Enabled,'WindUI Start must enable controller');visible()
        a.UI.Controls.StopEverything:Set(true);assert(not a.Enabled,'WindUI Stop must pause controller');visible()
        a:Destroy()
        assert(a.Destroyed,'paused Destroy must unload')
        for _,gui in ipairs(owned)do assert(not gui.Parent,'Destroy must remove all owned GUIs')end
        return {exemptionBeforeParent='passed',ownedVisible='passed',startStopDestroy='passed',
            blackoutActive=game.ReplicatedStorage.ChickenOrHero.Game.Session:GetAttribute('LightsOut')==true}
    end)
    c:Disconnect()
    if a and not a.Destroyed then a:Destroy()end
    assert(ok,result)
    return result
end
