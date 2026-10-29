local function finishTouch()
    local touch=anti.touch
    anti.touch=nil
    if touch then pcall(function()VirtualInput:SendTouchEvent(touch.id,2,touch.x,touch.y)end)end
end
local function lockAFKButton(button)
    if not api.Enabled or not button:IsA('GuiButton')or(button.Name~='AFKButton'and button.Name~='AFKToggle')or anti.buttons[button]then return end
    local record={interactable=button.Interactable,selectable=button.Selectable,connections={}}
    anti.buttons[button]=record
    local function enforce()
        if api.Enabled and button.Parent then button.Interactable=false;button.Selectable=false end
    end
    record.connections={button:GetPropertyChangedSignal('Interactable'):Connect(enforce),button:GetPropertyChangedSignal('Selectable'):Connect(enforce)}
    enforce()
end
local function restoreAFKButtons()
    for button,record in pairs(anti.buttons)do
        for _,connection in ipairs(record.connections)do connection:Disconnect()end
        if button.Parent then button.Interactable=record.interactable;button.Selectable=record.selectable end
    end
    anti.buttons={}
end
function anti.scanIdle()
    anti.nextScan=os.clock()+5
    if type(getconnections)~='function'then
        api.IdleReporterStatus='Connection inspection unavailable'
        return
    end
    local scripts=player:FindFirstChild('PlayerScripts')
    local reporter=scripts and scripts:FindFirstChild('IdleReportClient')
    if not reporter then api.IdleReporterStatus='Reporter not loaded';return end
    local ok,list=pcall(getconnections,player.Idled)
    if not ok then api.IdleReporterStatus='Connection inspection failed';return end
    for _,connection in ipairs(list)do
        if connection.Enabled==true and type(connection.Function)=='function'then
            local readable,owner=pcall(function()return getfenv(connection.Function).script end)
            if readable and owner==reporter then
                local disabled=pcall(connection.Disable,connection)
                if disabled and connection.Enabled==false then anti.idleConnections[connection]=true end
            end
        end
    end
    local held=0
    for connection in pairs(anti.idleConnections)do
        if connection.Connected==false then anti.idleConnections[connection]=nil
        else held=held+1 end
    end
    api.IdleReporterStatus=held>0 and'Blocked while running'or'No matching reporter connection'
end
function api:AntiAFKReport()
    local held=0
    for _ in pairs(anti.idleConnections)do held=held+1 end
    return {enabled=self.Enabled,reportersHeld=held,reporterStatus=self.IdleReporterStatus,
        touchPulses=self.TouchPulses or 0,keyPulses=self.KeyPulses or 0,idleGuardFires=self.IdleGuardFires or 0,
        inputError=self.AntiAFKError,keyError=self.KeyKeepAliveError,keyHeld=anti.keyHeld==true,
        nextKeyIn=self.Enabled and math.max(0,anti.nextKey-os.clock())or 0}
end
function anti.finishKey()
    if not anti.keyHeld then return true end
    local ok,err=pcall(VirtualInput.SendKeyEvent,VirtualInput,false,Enum.KeyCode.F15,false,game)
    if ok then anti.keyHeld=false else api.KeyKeepAliveError=tostring(err)end
    return ok
end
local function antiStop()
    finishTouch()
    anti.finishKey()
    for connection in pairs(anti.idleConnections)do pcall(connection.Enable,connection)end
    table.clear(anti.idleConnections)
    api.IdleReporterStatus='Stopped'
    ContextActions:UnbindAction(binding..'_AFK')
    if anti.guard and hudNavigation.handlers.AFK==anti.guard then hudNavigation.handlers.AFK=anti.original end
    anti.guard,anti.original=nil,nil
    restoreAFKButtons()
end
local function antiStart()
    antiStop()
    anti.nextTouch=os.clock()+1
    anti.nextKey=os.clock()+1
    anti.nextAFK=0
    anti.scanIdle()
    anti.original=hudNavigation.handlers.AFK
    anti.guard=function()end
    hudNavigation.handlers.AFK=anti.guard
    ContextActions:BindActionAtPriority(binding..'_AFK',function()
        return Input:GetFocusedTextBox()and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
    end,false,Enum.ContextActionPriority.High.Value+100,Enum.KeyCode.K)
    for _,v in ipairs(player.PlayerGui:GetDescendants())do lockAFKButton(v)end
end
local function safeTouchPoint()
    local camera=workspace.CurrentCamera
    if not camera then return nil end
    local viewport=camera.ViewportSize
    if viewport.X<80 or viewport.Y<80 then return nil end
    local points={{.55,.88},{.65,.30},{.80,.42},{.48,.68},{.72,.58}}
    local offset=random:NextInteger(0,#points-1)
    for i=1,#points do
        local point=points[(i+offset-1)%#points+1]
        local x=math.clamp(math.floor(viewport.X*point[1])+random:NextInteger(-3,3),32,viewport.X-32)
        local y=math.clamp(math.floor(viewport.Y*point[2])+random:NextInteger(-3,3),32,viewport.Y-32)
        local blocked=false
        for _,root in ipairs({player.PlayerGui,game:GetService('CoreGui')})do
            local ok,objects=pcall(root.GetGuiObjectsAtPosition,root,x,y)
            if ok then for _,object in ipairs(objects)do
                if Core.blocksTouch(object)then blocked=true;break end
            end end
        end
        if not blocked then return x,y end
    end
end
local function keepAliveTick()
    if not api.Enabled then return end
    local now=os.clock()
    if now>=anti.nextScan then anti.scanIdle()end
    local busy=GuiService.MenuIsOpen or Input:GetFocusedTextBox()~=nil or next(anti.touches)~=nil
    -- This pulse is independent of screen hit testing and touch availability.
    if anti.keyHeld and not anti.finishKey()then anti.nextKey=now+1 end
    if now>=anti.nextKey and not busy and not anti.keyHeld then
        anti.nextKey=now+45
        local down,err=pcall(VirtualInput.SendKeyEvent,VirtualInput,true,Enum.KeyCode.F15,false,game)
        anti.keyHeld=down
        local up,upError=pcall(VirtualInput.SendKeyEvent,VirtualInput,false,Enum.KeyCode.F15,false,game)
        if up then anti.keyHeld=false end
        if down and up then
            api.KeyPulses=(api.KeyPulses or 0)+1;api.KeyKeepAliveError=nil
        else
            api.KeyKeepAliveError=tostring(err or upError);anti.nextKey=now+5
        end
    end
    if player:GetAttribute('AFK')and not player:GetAttribute('InMatch')and now>=anti.nextAFK then
        anti.nextAFK=now+2
        gameState.PlayerPreferences:FireServer('SetAFK',false)
    end
    if anti.touch then
        local touch=anti.touch
        if now>=touch.ends then
            finishTouch()
            api.TouchPulses=(api.TouchPulses or 0)+1
        elseif not touch.moved and now>=touch.moves then
            touch.moved=true
            touch.x,touch.y=touch.x+random:NextInteger(1,2),touch.y+random:NextInteger(0,1)
            VirtualInput:SendTouchEvent(touch.id,1,touch.x,touch.y)
        end
        return
    end
    if not Core.keepAliveDue(api.Enabled,now,anti.nextTouch,busy)then return end
    local x,y=safeTouchPoint()
    if not x then anti.nextTouch=now+5;return end
    anti.nextTouch=now+60
    anti.touch={id=random:NextInteger(100000,9999999),x=x,y=y,moves=now+.04,ends=now+random:NextNumber(.09,.15)}
    VirtualInput:SendTouchEvent(anti.touch.id,0,x,y)
end

