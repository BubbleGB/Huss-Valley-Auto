gui = Instance.new('ScreenGui')
gui.Name = 'HussAutoCrossUI'
gui:SetAttribute('LightsOutKeep',true)
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild('PlayerGui')
local panel = Instance.new('Frame')
panel.Name = 'Panel'
panel.Size = UDim2.fromOffset(294, 286)
panel.Position = UDim2.new(0, 24, 0.35, 0)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
panel.Active = true
panel.Parent = gui
local corner = Instance.new('UICorner', panel)
corner.CornerRadius = UDim.new(0, 10)
local function label(name, text, position, size)
    local v = Instance.new('TextLabel')
    v.Name, v.Text = name, text
    v.Position, v.Size = position, size
    v.BackgroundTransparency = 1
    v.TextColor3 = Color3.fromRGB(230, 235, 245)
    v.Font = Enum.Font.Gotham
    v.TextSize = 13
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.Parent = panel
    return v
end
local title = label('DragHandle', 'HUSS  /  AUTO PLAY', UDim2.fromOffset(14, 0), UDim2.new(1,-60,0,40))
title.Active = true
title.Font = Enum.Font.GothamBold
local status = label('Status', 'Stopped', UDim2.fromOffset(14,44), UDim2.new(1,-28,0,38))
status.TextWrapped = true
local function button(name, text, position, size, color)
    local b = Instance.new('TextButton')
    b.Name, b.Text = name, text
    b.Position, b.Size = position, size
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1,1,1)
    b.Font, b.TextSize = Enum.Font.GothamBold, 14
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new('UICorner', b).CornerRadius = UDim.new(0,6)
    return b
end
local speedLabel=label('SpeedLabel','Dynamic speed  1.05x',UDim2.fromOffset(14,88),UDim2.new(1,-28,0,24))
local speedSlider=button('SpeedSlider','',UDim2.fromOffset(14,116),UDim2.fromOffset(266,28),Color3.fromRGB(37,42,53))
speedSlider.AutoButtonColor=false
local speedFill=Instance.new('Frame')
speedFill.Name='Fill';speedFill.BorderSizePixel=0;speedFill.BackgroundColor3=Color3.fromRGB(30,145,103)
speedFill.Position=UDim2.fromOffset(8,11);speedFill.Size=UDim2.new(.25,-4,0,6);speedFill.Parent=speedSlider
Instance.new('UICorner',speedFill).CornerRadius=UDim.new(1,0)
local speedKnob=Instance.new('Frame')
speedKnob.Name='Knob';speedKnob.AnchorPoint=Vector2.new(.5,.5)
speedKnob.Size=UDim2.fromOffset(16,16);speedKnob.BackgroundColor3=Color3.fromRGB(230,235,245)
speedKnob.BorderSizePixel=0;speedKnob.Parent=speedSlider
Instance.new('UICorner',speedKnob).CornerRadius=UDim.new(1,0)
function api:SetSpeedMultiplier(value)
    if self.Destroyed then return end
    assert(type(value)=='number'and value==value,'Speed multiplier must be a number')
    local multiplier=Core.speedMultiplier(value)
    if multiplier~=self.SpeedMultiplier then
        self.SpeedMultiplier=multiplier
        table.clear(speedProfiles)
        navigation=nil
        elapsed=1
    end
    local fraction=multiplier-1
    speedLabel.Text=string.format('Dynamic speed  %.2fx',multiplier)
    speedKnob.Position=UDim2.new(fraction,8-16*fraction,.5,0)
    speedFill.Size=UDim2.new(fraction,-16*fraction,0,6)
    return multiplier
end
api:SetSpeedMultiplier(api.SpeedMultiplier)
local sliderInput
local function slide(input)
    local inset=GuiService:GetGuiInset()
    local fraction=(input.Position.X-inset.X-speedSlider.AbsolutePosition.X-8)/math.max(1,speedSlider.AbsoluteSize.X-16)
    api:SetSpeedMultiplier(1+fraction)
end
connect(speedSlider.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        sliderInput=input;slide(input)
    end
end)
connect(Input.InputChanged,function(input)
    if sliderInput and(input==sliderInput or(sliderInput.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement))then slide(input)end
end)
connect(Input.InputEnded,function(input)if input==sliderInput then sliderInput=nil end end)
connect(Input.WindowFocusReleased,function()sliderInput=nil end)
local smartButton=button('SmartSpeed','Smart speed: ON',UDim2.fromOffset(14,154),UDim2.fromOffset(266,30),Color3.fromRGB(35,104,118))
local function refreshSmartButton()
    local now=workspace:GetServerTimeNow()
    local active=api.Enabled and api.SmartSpeedEnabled and smartState and smartState.untilAt>now
    smartButton.Text=not api.SmartSpeedEnabled and'Smart speed: OFF'or active
        and string.format('Smart speed: ON  /  %.1fs',smartState.untilAt-now)
        or api.SmartCap<Core.SMART_PEAK and string.format('Smart speed: ON  /  limit %.2fx',api.SmartCap)or'Smart speed: ON'
    smartButton.BackgroundColor3=api.SmartSpeedEnabled and Color3.fromRGB(35,104,118)or Color3.fromRGB(65,70,83)
end
function api:SetSmartSpeedEnabled(enabled)
    if self.Destroyed then return end
    assert(type(enabled)=='boolean','Smart speed requires true or false')
    self.SmartSpeedEnabled=enabled
    if not enabled and smartState then smartState.untilAt=0;self.SmartUntilAt=0 end
    navigation=nil;elapsed=1
    refreshSmartButton()
end
connect(smartButton.Activated,function()api:SetSmartSpeedEnabled(not api.SmartSpeedEnabled)end)
local tpButton=button('TPAssist','TP Assist: OFF',UDim2.fromOffset(14,194),UDim2.fromOffset(266,30),Color3.fromRGB(65,70,83))
function tp.refresh()
    local seconds=math.max(0,tp.state.readyAt-os.clock())
    tpButton.Text=tp.state.blocked and('TP Assist: BLOCKED / '..(tp.state.reason or'correction'))or not api.TPDodgeEnabled and'TP Assist: OFF'
        or tp.state.watch and'TP Assist: ON / observing'or seconds>0 and string.format('TP Assist: ON / %.0fs',seconds)or'TP Assist: ON'
    tpButton.BackgroundColor3=api.TPDodgeEnabled and Color3.fromRGB(83,75,140)or Color3.fromRGB(65,70,83)
end
function api:SetTPAssistEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','TP Assist requires true or false')
    self.TPDodgeEnabled=enabled and not tp.state.blocked
    self.TPAssistEnabled=self.TPDodgeEnabled
    tp.refresh()
    return self.TPDodgeEnabled
end
function api:SetTPDodgeEnabled(enabled)return self:SetTPAssistEnabled(enabled)end
function api:TPReport()
    return {enabled=self.TPDodgeEnabled,blocked=tp.state.blocked==true,blockReason=tp.state.reason,cooldown=math.max(0,tp.state.readyAt-os.clock()),
        usesThisRound=tp.state.uses,maxDistance=4,cooldownSeconds=12,maxUsesPerRound=2,
        watching=tp.state.watch~=nil,last=self.TPLast,observation=self.TPLastObservation,corrections=self.TPCorrections or 0}
end
connect(tpButton.Activated,function()api:SetTPAssistEnabled(not api.TPAssistEnabled)end)
tp.refresh()
local start = button('Start','Start',UDim2.fromOffset(14,236),UDim2.fromOffset(128,36),Color3.fromRGB(30,145,103))
local stop = button('Stop','Stop',UDim2.fromOffset(152,236),UDim2.fromOffset(128,36),Color3.fromRGB(155,65,75))
local close = button('Close','X',UDim2.new(1,-38,0,7),UDim2.fromOffset(30,28),Color3.fromRGB(65,70,83))
local function report(message)
    api.Status = message
    status.Text = message
end
