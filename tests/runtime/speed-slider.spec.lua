return function(source)
    local a=assert(loadstring(source))()
    a:SetSmartSpeedEnabled(false)
    local panel=game.Players.LocalPlayer.PlayerGui.HussAutoCrossUI.Panel
    local slider=panel.SpeedSlider
    local function check(value)
        assert(math.abs(a.SpeedMultiplier-value)<1e-8,'incorrect slider step: '..a.SpeedMultiplier..' expected '..value)
        -- Query the enabled profile without letting real frames run at test slider values.
        local enabled=a.Enabled
        a.Enabled=true
        local report=a:SpeedReport()
        a.Enabled=enabled
        assert(math.abs(report.applied/report.normal-value)<1e-8,'slider must update actual profile without stacking')
        assert(panel.SpeedLabel.Text==string.format('Dynamic speed  %.2fx',value),'label must show the selected value')
    end
    for step=0,20 do a:SetSpeedMultiplier(1+step*.05);check(1+step*.05)end
    a:SetSpeedMultiplier(.5);check(1)
    a:SetSpeedMultiplier(4);check(2)
    if setthreadidentity then setthreadidentity(8)end
    local input=cloneref(game:GetService('VirtualInputManager'))
    local function inject(method,...)
        if setthreadidentity then setthreadidentity(8)end
        return input[method](input,...)
    end
    local inset=game:GetService('GuiService'):GetGuiInset()
    local function point(fraction)
        return slider.AbsolutePosition.X+8+(slider.AbsoluteSize.X-16)*fraction+inset.X,
            slider.AbsolutePosition.Y+slider.AbsoluteSize.Y/2+inset.Y
    end
    local x,y=point(0)
    inject('SendMouseMoveEvent',x,y,game)
    inject('SendMouseButtonEvent',x,y,0,true,game,0);task.wait(.1);check(1)
    x,y=point(1)
    inject('SendMouseMoveEvent',x,y,game);task.wait(.1);check(2)
    x,y=point(.5)
    inject('SendMouseMoveEvent',x,y,game);task.wait(.1);check(1.5)
    inject('SendMouseButtonEvent',x,y,0,false,game,0);task.wait(.1)
    x,y=point(.8);inject('SendMouseMoveEvent',x,y,game);task.wait(.1);check(1.5)
    local id=7348321
    local ok,err=pcall(function()
        x,y=point(.4);inject('SendTouchEvent',id,0,x,y);task.wait(.1);check(1.4)
        x,y=point(.45);inject('SendTouchEvent',id,1,x,y);task.wait(.1);check(1.45)
    end)
    inject('SendTouchEvent',id,2,x,y)
    assert(ok,err)
    a:Stop()
    assert(a:SpeedReport().multiplier==1,'Stop must restore native speed')
    a:SetSpeedMultiplier(1.75)
    assert(a:SpeedReport().multiplier==1,'adjusting paused must not enable speed')
    a:Start();check(1.75)
    a:SetSpeedMultiplier(1.05)
    return {steps=21,mouse='passed',touch='passed',speedProfiles='passed',pauseResume='passed'}
end
