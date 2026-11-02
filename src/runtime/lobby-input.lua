-- Native lobby input owns at most one stationary touch or ordinary prompt hold.
local function createLobbyInput(services)
    local controller={};local active;local touchId=7319
    local function enabled()return services.enabled==nil or services.enabled()end
    local function isA(object,class)return object and object.IsA and object:IsA(class)end
    local function visible(object)
        local current=object
        while current do
            if isA(current,'GuiObject')and not current.Visible then return false end
            if (isA(current,'LayerCollector')or isA(current,'ScreenGui'))and not current.Enabled then return false end
            current=current.Parent
        end
        return true
    end
    local function interactive(object)
        local current=object
        while current do
            if (isA(current,'GuiButton')or isA(current,'TextBox')or isA(current,'GuiObject')and current.Active)and visible(current)then return current end
            current=current.Parent
        end
    end
    local function belongs(object,target)
        while object do if object==target then return true end;object=object.Parent end
        return false
    end
    local function available()
        if active or not enabled()or services.guiService.MenuIsOpen then return false end
        if services.input:GetFocusedTextBox()then return false end
        if services.input.GetTouches and #services.input:GetTouches()>0 then return false end
        return true
    end
    local function clearAt(x,y,target)
        for _,object in ipairs(services.coreGui:GetGuiObjectsAtPosition(x,y))do
            if interactive(object)then return false end
        end
        for _,object in ipairs(services.playerGui:GetGuiObjectsAtPosition(x,y))do
            local control=interactive(object)
            if control then return target~=nil and belongs(object,target)and belongs(control,target)end
        end
        return target==nil
    end
    local function beginTouch(x,y)
        touchId=touchId+1
        active={id=touchId,x=x,y=y,ends=services.clock()+.08}
        local ok=pcall(function()services.virtualInput:SendTouchEvent(active.id,0,x,y)end)
        if not ok then controller:Release()end
        return ok
    end
    function controller:Release()
        local owned=active;active=nil
        if not owned then return end
        pcall(function()
            if owned.prompt then owned.prompt:InputHoldEnd()
            else services.virtualInput:SendTouchEvent(owned.id,2,owned.x,owned.y)end
        end)
    end
    function controller:Busy()return active~=nil end
    local function promptInRange(prompt,root)
        if not prompt or not prompt.Parent or not prompt.Enabled or not root then return false end
        local parent=prompt.Parent;local position
        if isA(parent,'Attachment')then position=parent.WorldPosition
        elseif isA(parent,'Model')then position=parent:GetPivot().Position
        else position=parent.Position end
        return position~=nil and (root.Position-position).Magnitude<=prompt.MaxActivationDistance
    end
    function controller:Tick()
        if not active then return end
        local ok,keep=pcall(function()
            return enabled()and not services.guiService.MenuIsOpen and not services.input:GetFocusedTextBox()
                and(not active.prompt or promptInRange(active.prompt,active.root))
        end)
        if not ok or not keep or services.clock()>=active.ends then self:Release()end
    end
    function controller:Tap(button)
        local ok,result=pcall(function()
            if not available()or not isA(button,'GuiButton')or not button.Parent or not visible(button)
                or not button.Active or button.Interactable==false then return false end
            local size=button.AbsoluteSize;if size.X<=0 or size.Y<=0 then return false end
            local center=button.AbsolutePosition+size*.5
            if not clearAt(center.X,center.Y,button)then return false end
            local inset=services.guiService:GetGuiInset()
            return beginTouch(center.X+inset.X,center.Y+inset.Y)
        end)
        return ok and result==true
    end
    function controller:TapGhostContinue(label)
        local ok,result=pcall(function()
            if not available()or not label or label.Name~='Continue'or not isA(label,'GuiButton')
                or label.Interactable~=false or not visible(label)then return false end
            local ui=label.Parent;local home=ui and ui.Parent
            if not ui or ui.Name~='UI'or not home or home.Name~='GhostTraderUI'
                or home.Parent~=services.playerGui then return false end
            local camera=type(services.camera)=='function'and services.camera()or services.camera
            if not camera or not camera:FindFirstChild('GhostTraderView')then return false end
            local size=label.AbsoluteSize;if size.X<=0 or size.Y<=0 then return false end
            local center=label.AbsolutePosition+size*.5
            for _,object in ipairs(services.coreGui:GetGuiObjectsAtPosition(center.X,center.Y))do
                if interactive(object)then return false end
            end
            for _,object in ipairs(services.playerGui:GetGuiObjectsAtPosition(center.X,center.Y))do
                local current=object
                while current do
                    if not belongs(current,label)and (isA(current,'GuiButton')or isA(current,'TextBox'))
                        and current.Interactable~=false and visible(current)then return false end
                    current=current.Parent
                end
            end
            local inset=services.guiService:GetGuiInset()
            return beginTouch(center.X+inset.X,center.Y+inset.Y)
        end)
        return ok and result==true
    end
    function controller:TapCard(hit)
        local ok,result=pcall(function()
            if not available()or not hit or hit.Name~='Hit'then return false end
            local camera=type(services.camera)=='function'and services.camera()or services.camera
            local card=hit.Parent;local view=card and card.Parent
            if not camera or not view or view.Name~='GhostTraderView'or view.Parent~=camera
                or not card.Name:match('^Card%d+$')then return false end
            local point,onScreen=camera:WorldToScreenPoint(hit.Position)
            if not onScreen or point.Z<=0 or not clearAt(point.X,point.Y,nil)then return false end
            local ray=camera:ScreenPointToRay(point.X,point.Y)
            local hits={}
            for _,candidate in ipairs(view:GetChildren())do
                if candidate.Name:match('^Card%d+$')then
                    local part=candidate:FindFirstChild('Hit');if part then hits[#hits+1]=part end
                end
            end
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances=hits
            local result=services.workspace:Raycast(ray.Origin,ray.Direction*80,params)
            if not result or result.Instance~=hit then return false end
            return beginTouch(point.X,point.Y)
        end)
        return ok and result==true
    end
    function controller:Prompt(prompt,root)
        local ok,result=pcall(function()
            if not available()or not promptInRange(prompt,root)then return false end
            active={prompt=prompt,root=root,ends=services.clock()+math.max(.08,prompt.HoldDuration or 0)}
            prompt:InputHoldBegin()
            return true
        end)
        if not ok then self:Release()end
        return ok and result==true
    end
    return controller
end
runner.createLobbyInput=createLobbyInput
