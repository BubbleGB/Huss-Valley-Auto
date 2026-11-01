local function finishTouch()
    local touch=anti.touch
    anti.touch=nil
    if touch then pcall(function()VirtualInput:SendTouchEvent(touch.id,2,touch.x,touch.y)end)end
end
local function lockAFKButton(button)
    if not api.Enabled or not api.Settings.AntiAFK or not button:IsA('GuiButton')or(button.Name~='AFKButton'and button.Name~='AFKToggle')or anti.buttons[button]then return end
    local record={interactable=button.Interactable,selectable=button.Selectable,connections={}}
    anti.buttons[button]=record
    local function enforce()
        if api.Enabled and api.Settings.AntiAFK and button.Parent then button.Interactable=false;button.Selectable=false end
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
    return {enabled=self.Enabled and self.Settings.AntiAFK,reportersHeld=held,reporterStatus=self.IdleReporterStatus,
        touchPulses=self.TouchPulses or 0,idleGuardFires=self.IdleGuardFires or 0,
        inputError=self.AntiAFKError,
        nextTouchIn=self.Enabled and self.Settings.AntiAFK and math.max(0,anti.nextTouch-os.clock())or 0}
end
local function antiStop()
    finishTouch()
    if runner.keepAliveSurface then runner.keepAliveSurface.Visible=false end
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
    if not api.Enabled or not api.Settings.AntiAFK then return end
    if runner.keepAliveSurface then runner.keepAliveSurface.Visible=true end
    anti.nextTouch=os.clock()+1
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
    local surface=runner.keepAliveSurface
    if not surface or not surface:IsDescendantOf(gui) or not gui.Enabled
        or not surface.Visible or not surface.Active or not surface.Interactable then return nil end
    local ancestor=surface.Parent
    while ancestor and ancestor~=gui do
        if ancestor:IsA('GuiObject')and not ancestor.Visible then return nil end
        ancestor=ancestor.Parent
    end
    local size=surface.AbsoluteSize
    if size.X<4 or size.Y<4 then return nil end
    local center=surface.AbsolutePosition+size/2
    local x,y=math.floor(center.X),math.floor(center.Y)
    local ok,objects=pcall(player.PlayerGui.GetGuiObjectsAtPosition,player.PlayerGui,x,y)
    -- The dedicated inert button consumes the gesture; never touch world canvas
    -- or whichever active control happens to cover this screen coordinate.
    if not ok or objects[1]~=surface then return nil end
    local inspected,blocked=pcall(function()
        local core=game:GetService('CoreGui')
        for _,object in ipairs(core:GetGuiObjectsAtPosition(x,y))do
            if Core.blocksTouch(object)then return true end
        end
        return false
    end)
    if not inspected then
        api.AntiAFKError='Touch deferred: protected UI inspection unavailable'
        return nil
    end
    api.AntiAFKError=nil
    if blocked then return nil end
    return x,y
end
local function keepAliveTick()
    if not api.Enabled or not api.Settings.AntiAFK then return end
    local now=os.clock()
    if now>=anti.nextScan then anti.scanIdle()end
    local busy=GuiService.MenuIsOpen or Input:GetFocusedTextBox()~=nil or next(anti.touches)~=nil
    if player:GetAttribute('AFK')and not player:GetAttribute('InMatch')and now>=anti.nextAFK then
        anti.nextAFK=now+2
        gameState.PlayerPreferences:FireServer('SetAFK',false)
    end
    if anti.touch then
        local touch=anti.touch
        if now>=touch.ends then
            finishTouch()
            api.TouchPulses=(api.TouchPulses or 0)+1
        end
        return
    end
    if not Core.keepAliveDue(api.Enabled,now,anti.nextTouch,busy)then return end
    local x,y=safeTouchPoint()
    if not x then anti.nextTouch=now+5;return end
    -- Native touch input is inset-relative even when our GUI ignores the inset.
    local inset=GuiService:GetGuiInset()
    x,y=x+inset.X,y+inset.Y
    anti.nextTouch=now+60
    anti.touch={id=random:NextInteger(100000,9999999),x=x,y=y,ends=now+random:NextNumber(.09,.15)}
    VirtualInput:SendTouchEvent(anti.touch.id,0,x,y)
end

