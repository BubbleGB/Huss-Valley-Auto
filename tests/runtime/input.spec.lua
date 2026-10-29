-- Verifies keepalive never injects input into an active non-button overlay.
return function(source)
    local a=assert(loadstring(source))()
    local p=game.Players.LocalPlayer
    local overlay=Instance.new('ScreenGui')
    overlay.Name='HussAuditTouchBlocker';overlay.IgnoreGuiInset=true
    overlay:SetAttribute('LightsOutKeep',true);overlay.DisplayOrder=2000
    local frame=Instance.new('Frame');frame.Size=UDim2.fromScale(1,1)
    frame.BackgroundTransparency=1;frame.Active=true;frame.Parent=overlay
    local touches=0
    local connection=frame.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch then touches=touches+1 end
    end)
    overlay.Parent=p.PlayerGui
    local ok,err=pcall(function()
        -- Parenting and input hit-test registration happen on different engine phases.
        local deadline=os.clock()+2
        local ready=false
        repeat
            task.wait()
            local v=workspace.CurrentCamera.ViewportSize
            ready=true
            for _,point in ipairs({{.55,.88},{.65,.30},{.80,.42},{.48,.68},{.72,.58}})do
                local found=false
                for _,object in ipairs(p.PlayerGui:GetGuiObjectsAtPosition(math.floor(v.X*point[1]),math.floor(v.Y*point[2])))do
                    if object==frame then found=true;break end
                end
                ready=ready and found
            end
        until ready or os.clock()>=deadline
        assert(ready,'active-overlay fixture must be registered for hit testing before the test begins')
        a:Start()
        local pulses=a.TouchPulses or 0
        task.wait(1.8)
        assert((a.TouchPulses or 0)==pulses and touches==0,string.format(
            'keepalive must defer instead of touching an active Frame (before=%d after=%d hits=%d enabled=%s active=%s size=%s)',
            pulses,a.TouchPulses or 0,touches,tostring(overlay.Enabled),tostring(frame.Active),tostring(frame.AbsoluteSize)))
        assert(not a.AntiAFKError,'hit testing must not raise runtime errors')
    end)
    a:Stop();connection:Disconnect();overlay:Destroy()
    assert(ok,err)
    a:Start();local pulses=a.TouchPulses or 0
    task.wait(1.8)
    assert((a.TouchPulses or 0)>pulses,'keepalive must resume after the interactive overlay closes')
    a:Stop()
    return {activeFrameAvoided='passed',deferAndResume='passed',cleanup='passed'}
end
