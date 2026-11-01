api.Settings=Core.defaultSettings()
function api:GetSettings()
    return Core.copySettings(self.Settings)
end
function api:SetSetting(name,value)
    if self.Destroyed then return false end
    value=Core.settingValue(name,value)
    local updated=Core.copySettings(self.Settings)
    updated[name]=value
    self.Settings=updated
    if name=='AntiAFK'then
        if value and self.Enabled then antiStart()else antiStop()end
    elseif name=='AutoRun'or name=='AutoChase'then
        if not value and activeRole==(name=='AutoRun'and'Runner'or'Catcher')then release()end
    elseif name=='AutoFaceTarget'and not value and facingHumanoid then
        facingHumanoid.AutoRotate=previousAutoRotate
        facingHumanoid,previousAutoRotate=nil,nil
    end
    choiceRequest,voteRequest={},{}
    elapsed=1;navigation=nil
    return value
end
function api:SetPriorities(value)
    if self.Destroyed then return false end
    local priorities=Core.priorityOrder(value)
    local updated=Core.copySettings(self.Settings)
    updated.Priorities=priorities
    self.Settings=updated
    elapsed=1;navigation=nil
    return table.clone(priorities)
end
