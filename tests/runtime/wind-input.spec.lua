-- Actual visible pinned WindUI touch routing and release; automation remains paused.
return function(source)
    local a=assert(loadstring(source))()
    local input=cloneref(game:GetService('VirtualInputManager'))
    local run=game:GetService('RunService')
    local p=game.Players.LocalPlayer
    local touchId=7348321
    local touchDown=false
    local x,y=0,0
    local touchInset
    local gestureSnapshot
    local function sameFrame(before,after)
        local relative=before:ToObjectSpace(after)
        local _,angle=relative:ToAxisAngle()
        -- Permit sub-pixel/native resting physics noise, never a visible pan or step.
        return relative.Position.Magnitude<=.005 and math.abs(angle)<=.001
    end
    local function unchanged()
        if not gestureSnapshot then return end
        local before=gestureSnapshot
        assert(workspace.CurrentCamera==before.camera,'touch gesture must not replace the camera')
        assert(sameFrame(before.cframe,before.camera.CFrame) and sameFrame(before.focus,before.camera.Focus),
            'camera changed during touch gesture; aborting further input')
        assert(p.Character==before.character and before.root.Parent==before.character
            and sameFrame(before.body,before.root.CFrame),'player body changed during touch gesture; aborting further input')
    end
    local function inject(state,px,py)
        if state~=2 then unchanged()end
        x,y=px,py
        -- Mark ownership before dispatch so even an injection error releases this ID.
        if state==0 then
            touchInset=game:GetService('GuiService'):GetGuiInset()
            touchDown=true
        end
        assert(touchInset,'touch conversion requires the begin-time inset')
        -- GUI hit testing uses logical coordinates; VIM touch takes inset-offset coordinates.
        local result=input:SendTouchEvent(touchId,state,px+touchInset.X,py+touchInset.Y)
        if state==2 then touchDown=false end
        return result
    end
    local function waitFor(predicate,message)
        local deadline=os.clock()+4
        repeat
            unchanged()
            if predicate()then return end
            run.RenderStepped:Wait()
        until os.clock()>deadline
        error(message)
    end
    local function point(object,fraction)
        -- AbsolutePosition and GetGuiObjectsAtPosition share logical GUI coordinates.
        return object.AbsolutePosition.X+object.AbsoluteSize.X*fraction,
            object.AbsolutePosition.Y+object.AbsoluteSize.Y/2
    end
    local function hit(object)
        local px,py=point(object,.5)
        for _,candidate in ipairs(p.PlayerGui:GetGuiObjectsAtPosition(px,py))do
            if candidate==object or candidate:IsDescendantOf(object)then return true end
        end
        return false
    end
    local function inputConsumer(candidate)
        if candidate:IsA('GuiButton')then return candidate.Interactable end
        if candidate:IsA('TextBox')then return candidate.TextEditable or candidate.Active end
        if candidate:IsA('ScrollingFrame')then return candidate.ScrollingEnabled or candidate.Active end
        return candidate.Active
    end
    local function visibleConsumer(candidate)
        local ancestor=candidate
        while ancestor do
            if ancestor:IsA('GuiObject')and not ancestor.Visible then return false end
            if ancestor:IsA('ScreenGui')and not ancestor.Enabled then return false end
            ancestor=ancestor.Parent
        end
        return inputConsumer(candidate)
    end
    local function beginGesture(target,px,py)
        assert(not game:GetService('GuiService').MenuIsOpen,'Roblox menu is open; abort before touch')
        -- CoreGui overlays render above PlayerGui; uncertainty must abort before input.
        local queried,coreHits=pcall(function()
            return game:GetService('CoreGui'):GetGuiObjectsAtPosition(px,py)
        end)
        assert(queried and type(coreHits)=='table','cannot verify CoreGui obstruction; abort before touch')
        for _,candidate in ipairs(coreHits)do
            assert(not visibleConsumer(candidate),
                'CoreGui consumes touch start; abort before touch: '..candidate:GetFullName())
        end
        local first
        for _,candidate in ipairs(p.PlayerGui:GetGuiObjectsAtPosition(px,py))do
            if visibleConsumer(candidate)then first=candidate;break end
        end
        local main=a.UI.Window.UIElements.Main
        assert(first and (first==target or first:IsDescendantOf(target))
            and (first==main or first:IsDescendantOf(main)),
            'touch start is blocked by another input consumer: '..(first and first:GetFullName()or 'none'))
        local camera=assert(workspace.CurrentCamera,'camera required for touch safety snapshot')
        local character=assert(p.Character,'character required for touch safety snapshot')
        local root=assert(character:FindFirstChild('HumanoidRootPart'),'root required for touch safety snapshot')
        gestureSnapshot={camera=camera,cframe=camera.CFrame,focus=camera.Focus,
            character=character,root=root,body=root.CFrame}
        inject(0,px,py)
    end
    local function finishGesture()
        unchanged()
        gestureSnapshot=nil
    end
    local function stableVisible(object)
        local previous,stable
        waitFor(function()
            local position,size=object.AbsolutePosition,object.AbsoluteSize
            local current=tostring(position)..tostring(size)
            stable=current==previous and (stable or 0)+1 or 0;previous=current
            return size.X>20 and size.Y>2 and stable>=3 and hit(object)
        end,'visible widget bounds/hit registration did not settle: '..object.Name)
    end
    local function check(value)
        waitFor(function()return math.abs(a.SpeedMultiplier-value)<.001 end,'touch did not select '..value..' (actual '..a.SpeedMultiplier..')')
        assert(not a.Enabled,'input must leave automation paused')
    end
    local function released(value)
        for _=1,5 do
            run.RenderStepped:Wait()
            unchanged()
            assert(math.abs(a.SpeedMultiplier-value)<.001,'released slider must ignore further touch movement')
        end
    end
    local ok,err=pcall(function()
        a:SetSetting('AutoRun',false);a:SetSetting('AutoChase',false);a:SetSetting('AntiAFK',false)
        assert(not a.Enabled,'input fixture must load paused')
        local window=a.UI.Window
        local main=window.UIElements.Main
        local title=main.Main.Topbar
        waitFor(function()return main.AbsoluteSize.Y>300 end,'window opening layout must finish')
        local viewport=main:FindFirstAncestorOfClass('ScreenGui').AbsoluteSize
        local fit=math.min(1,(viewport.X-40)/main.AbsoluteSize.X,(viewport.Y-60)/main.AbsoluteSize.Y)
        if fit<1 then window:SetUIScale(window:GetUIScale()*fit);window:SetToTheCenter()end
        stableVisible(title)
        local before=main.AbsolutePosition
        x,y=point(title,.4)
        beginGesture(title,x,y)
        waitFor(function()return window.Dragging end,'visible title did not receive touch begin')
        local dragX,dragY=x+40,y+25
        inject(1,dragX,dragY)
        waitFor(function()return (main.AbsolutePosition-before).Magnitude>15 end,'touch title drag must move actual WindUI window')
        inject(2,dragX,dragY)
        waitFor(function()return not window.Dragging end,'title touch release must finish dragging')
        finishGesture()
        window:SelectTab(6)
        waitFor(function()return window.TabModule.SelectedTab==6 end,'Move tab must be selected')
        local slider=a.UI.Controls.SpeedMultiplier
        local track=slider.UIElements.SliderIcon
        stableVisible(slider.UIElements.SliderContainer);stableVisible(track)
        x,y=point(track,.4);beginGesture(slider.UIElements.SliderContainer,x,y);check(1.4)
        x,y=point(track,.55);inject(1,x,y);check(1.55)
        inject(2,x,y)
        waitFor(function()return a.UI.Library.CurrentInput==nil end,'touch release must relinquish slider input')
        released(1.55)
        finishGesture()
    end)
    if touchDown then pcall(inject,2,x,y)end
    a:Destroy()
    assert(ok,err)
    return {titleTouchDrag='passed',titleTouchRelease='passed',touchSteps='passed',touchRelease='passed',cameraBodyUnchanged='passed'}
end
