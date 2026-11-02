local function createUIObstructions(services)
    local guard={}
    local owned,lastAt=false,0
    local function call(method,...)
        local previous
        if services.identityGet and services.identitySet then
            local ok,value=pcall(services.identityGet)
            if ok and type(value)=='number'then previous=value;pcall(services.identitySet,8)end
        end
        local result=table.pack(pcall(method,...))
        if previous~=nil then pcall(services.identitySet,previous)end
        return table.unpack(result,1,result.n)
    end
    function guard:ClearAt(x,y)
        local list,other=false,false
        local objects=services.hits and services.hits(x,y)or services.coreGui:GetGuiObjectsAtPosition(x,y)
        for _,object in ipairs(objects)do
            local current=object
            local inList=false
            while current and current~=services.coreGui do
                if current.Name=='PlayerList'and current:IsA('ScreenGui')then inList=true;break end
                current=current.Parent
            end
            if inList then list=true
            elseif object:IsA('GuiButton')or object:IsA('TextBox')or object:IsA('GuiObject')and object.Active then other=true end
        end
        if list then
            local ok,enabled=call(services.starter.GetCoreGuiEnabled,services.starter,Enum.CoreGuiType.PlayerList)
            if not ok or not enabled then return false end
            local hidden=call(services.starter.SetCoreGuiEnabled,services.starter,Enum.CoreGuiType.PlayerList,false)
            if hidden then owned=true;lastAt=services.clock()end
            return false
        end
        if other then return false end
        if owned then lastAt=services.clock()end
        return true
    end
    function guard:Restore()
        if owned then call(services.starter.SetCoreGuiEnabled,services.starter,Enum.CoreGuiType.PlayerList,true)end
        owned=false
    end
    function guard:Tick()
        if owned and services.clock()-lastAt>=1.5 then self:Restore()end
    end
    return guard
end
runner.createUIObstructions=createUIObstructions
