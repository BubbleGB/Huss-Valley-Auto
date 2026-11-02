local function createLobbyInput(services)
    local controller={};local active;local touchId=7319
    local function inputCall(callback)
        local previous
        if services.identityGet and services.identitySet then
            local ok,value=pcall(services.identityGet)
            if ok and type(value)=='number'then previous=value;pcall(services.identitySet,8)end
        end
        local result=table.pack(pcall(callback))
        if previous~=nil then pcall(services.identitySet,previous)end
        return table.unpack(result,1,result.n)
    end
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
        return true
    end
    local function clearAt(x,y,target,allowEmpty)
        if services.touchesBusy and services.touchesBusy(x,y)then controller.LastBlockedReason='manual touch';return false end
        if services.obstructions and not services.obstructions:ClearAt(x,y)then controller.LastBlockedReason='CoreGui obstruction or player list closing';return false end
        for _,object in ipairs(services.coreGui:GetGuiObjectsAtPosition(x,y))do
            if interactive(object)then controller.LastBlockedReason='CoreGui obstruction: '..object.Name;return false end
        end
        for _,object in ipairs(services.playerGui:GetGuiObjectsAtPosition(x,y))do
            local control=interactive(object)
            if control then
                if target and belongs(object,target)and belongs(control,target)then return true end
                if not(target and belongs(target,control))then
                    controller.LastBlockedReason='GUI obstruction: '..control.Name;return false
                end
            end
        end
        local clear=target==nil or allowEmpty==true
        if not clear then controller.LastBlockedReason='target absent from hit test' end
        return clear
    end
    local function beginTouch(x,y)
        local inset=services.guiService:GetGuiInset()
        x,y=x+inset.X,y+inset.Y
        touchId=touchId+1
        active={id=touchId,x=x,y=y,ends=services.clock()+.08}
        if services.onTouchBegin then active.token=services.onTouchBegin(x,y)end
        local ok=pcall(function()services.virtualInput:SendTouchEvent(active.id,0,x,y)end)
        if not ok then controller:Release()end
        return ok
    end
    function controller:Release()
        local owned=active;active=nil
        if not owned then return end
        inputCall(function()
            services.virtualInput:SendTouchEvent(owned.id,2,owned.x,owned.y)
        end)
        if services.onTouchEnd then pcall(services.onTouchEnd,owned.token)end
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
        if services.obstructions then services.obstructions:Tick()end
        if not active then return end
        local ok,keep=pcall(function()
            return enabled()and not services.guiService.MenuIsOpen and not services.input:GetFocusedTextBox()
                and(not active.prompt or promptInRange(active.prompt,active.root))
        end)
        if not ok or not keep or services.clock()>=active.ends then self:Release()end
    end
    function controller:Tap(button)
        self.LastBlockedReason=nil
        local ok,result=inputCall(function()
            if not available()then self.LastBlockedReason='input busy, typing or menu';return false end
            if not isA(button,'GuiButton')or not button.Parent or not visible(button)
                or not button.Active or button.Interactable==false then return false end
            local size=button.AbsoluteSize;if size.X<=0 or size.Y<=0 then return false end
            local center=button.AbsolutePosition+size*.5
            if not clearAt(center.X,center.Y,button)then return false end
            return beginTouch(center.X,center.Y)
        end)
        if not ok then self.LastBlockedReason=tostring(result)end
        return ok and result==true
    end
    function controller:TapGhostContinue(label)
        local ok,result=inputCall(function()
            if not available()or not label or label.Name~='Continue'or not(isA(label,'TextLabel')or isA(label,'GuiButton'))
                or isA(label,'GuiButton')and label.Interactable~=false or not visible(label)then return false end
            local parent=label.Parent
            local home=parent and(parent.Name=='GhostTraderUI'and parent or parent.Name=='UI'and parent.Parent)
            if not home or home.Name~='GhostTraderUI'or home.Parent~=services.playerGui then return false end
            local camera=type(services.camera)=='function'and services.camera()or services.camera
            if not camera or not camera:FindFirstChild('GhostTraderView')then return false end
            local size=label.AbsoluteSize;if size.X<=0 or size.Y<=0 then return false end
            local center=label.AbsolutePosition+size*.5
            if services.touchesBusy and services.touchesBusy(center.X,center.Y)then return false end
            if services.obstructions and not services.obstructions:ClearAt(center.X,center.Y)then return false end
            for _,object in ipairs(services.coreGui:GetGuiObjectsAtPosition(center.X,center.Y))do
                if interactive(object)then return false end
            end
            for _,object in ipairs(services.playerGui:GetGuiObjectsAtPosition(center.X,center.Y))do
                local current=object
                while current do
                    if not belongs(current,label)and (isA(current,'GuiButton')or isA(current,'TextBox'))
                        and visible(current)then return false end
                    current=current.Parent
                end
            end
            return beginTouch(center.X,center.Y)
        end)
        return ok and result==true
    end
    function controller:TapPumpkin(label)
        local ok,result=inputCall(function()
        if not available()or not label or label.Name~='Tap'or not isA(label,'TextLabel')or not visible(label)then return false end
        local screen=label.Parent
        if not screen or screen.Name~='PumpkinTap'or screen.Parent~=services.playerGui then return false end
        local size=label.AbsoluteSize;if size.X<=0 or size.Y<=0 then return false end
        local point=label.AbsolutePosition+size*.5
        if not clearAt(point.X,point.Y,nil,true)then return false end
        return beginTouch(point.X,point.Y)
        end)
        return ok and result==true
    end
    function controller:TapCard(hit)
        local ok,result=inputCall(function()
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
        local ok,result=inputCall(function()
            if not available()or not promptInRange(prompt,root)then return false end
            local home=services.playerGui:FindFirstChild('ProximityPrompts')
            if not home then return false end
            local shown
            for _,candidate in ipairs(home:GetDescendants())do
                if isA(candidate,'BillboardGui')and candidate.Adornee==prompt.Parent and candidate.Enabled and candidate.Active then shown=candidate;break end
            end
            if not shown then return false end
            local button=shown:FindFirstChild('TextButton')
            if not isA(button,'GuiButton')or not visible(button)or button.Interactable==false then return false end
            local action=shown:FindFirstChild('ActionText',true)
            if action and action.Text~=prompt.ActionText then return false end
            local camera=type(services.camera)=='function'and services.camera()or services.camera
            if not camera then return false end
            local parent=prompt.Parent
            local position=isA(parent,'Attachment')and parent.WorldPosition or parent.Position
            position=position+(shown.StudsOffsetWorldSpace or Vector3.zero)
            local offset=shown.StudsOffset or Vector3.zero
            if offset.Magnitude>0 then position=position+camera.CFrame:VectorToWorldSpace(offset)end
            local point,onScreen=camera:WorldToScreenPoint(position)
            if not onScreen or point.Z<=0 then return false end
            local center=button.AbsolutePosition+button.AbsoluteSize*.5-shown.AbsoluteSize*.5
            local sizeOffset=shown.SizeOffset or Vector2.zero
            local x,y=point.X+center.X+sizeOffset.X*shown.AbsoluteSize.X,point.Y+center.Y+sizeOffset.Y*shown.AbsoluteSize.Y
            if not clearAt(x,y,button,true)then return false end
            if not beginTouch(x,y)then return false end
            active.prompt,active.root=prompt,root
            active.ends=services.clock()+math.max(.12,(prompt.HoldDuration or 0)+.08)
            return true
        end)
        if not ok then self:Release()end
        return ok and result==true
    end
    return controller
end
runner.createLobbyInput=createLobbyInput
