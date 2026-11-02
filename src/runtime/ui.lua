-- Overlay ownership and feature state; visible controls live only in WindUI.
gui=Instance.new('ScreenGui')
gui.Name='HussAutoCrossUI'
gui:SetAttribute('LightsOutKeep',true)
gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild('PlayerGui')
local function button(name,text,position,size,color)
    local control=Instance.new('TextButton')
    control.Name,control.Text=name,text;control.Position,control.Size=position,size
    control.BackgroundColor3=color;control.TextColor3=Color3.new(1,1,1)
    control.Font,control.TextSize=Enum.Font.GothamBold,14
    control.AutoButtonColor=true;control.Parent=gui
    Instance.new('UICorner',control).CornerRadius=UDim.new(0,6)
    return control
end
local function report(message,action,target)
    api.Status=message
    runner.operation:Base(message,action,target)
end
function api:SetSpeedMultiplier(value)
    if self.Destroyed then return end
    assert(type(value)=='number'and value==value,'Speed multiplier must be a number')
    local multiplier=Core.speedMultiplier(value)
    if multiplier~=self.SpeedMultiplier then
        self.SpeedMultiplier=multiplier;table.clear(speedProfiles);navigation=nil;elapsed=1
    end
    return multiplier
end
function api:SetSmartSpeedEnabled(enabled)
    if self.Destroyed then return end
    assert(type(enabled)=='boolean','Smart speed requires true or false')
    self.SmartSpeedEnabled=enabled
    if not enabled and smartState then smartState.untilAt=0;self.SmartUntilAt=0 end
    navigation=nil;elapsed=1
end
function api:SetTPAssistEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','TP Assist requires true or false')
    self.TPDodgeEnabled=enabled and not tp.state.blocked
    self.TPAssistEnabled=self.TPDodgeEnabled
    return self.TPDodgeEnabled
end
function api:SetTPDodgeEnabled(enabled)return self:SetTPAssistEnabled(enabled)end
function api:TPReport()
    return {enabled=self.TPDodgeEnabled,blocked=tp.state.blocked==true,blockReason=tp.state.reason,
        cooldown=math.max(0,tp.state.readyAt-os.clock()),usesThisRound=tp.state.uses,maxDistance=4,
        cooldownSeconds=12,maxUsesPerRound=2,watching=tp.state.watch~=nil,last=self.TPLast,
        observation=self.TPLastObservation,corrections=self.TPCorrections or 0}
end
-- An inert, input-consuming surface keeps idle touches away from gameplay/camera.
runner.keepAliveSurface=button('IdleGuardSurface','IDLE',UDim2.fromOffset(8,72),UDim2.fromOffset(40,18),Color3.fromRGB(25,55,55))
runner.keepAliveSurface.TextSize=9;runner.keepAliveSurface.AutoButtonColor=false
runner.keepAliveSurface.Active=true;runner.keepAliveSurface.Selectable=false;runner.keepAliveSurface.Visible=false
