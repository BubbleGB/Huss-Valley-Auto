local function participants()
    local result,current={},{}
    for _,source in ipairs(participantDirectory.list())do
        if type(source)=='table'and type(source.UserId)=='number'then
            local actor=actorCache[source.UserId]
            if not actor then
                actor={UserId=source.UserId,IsBot=true}
                function actor:GetAttribute(name)return self.source:GetAttribute(name)end
                setmetatable(actor,{__index=function(t,k)return t.source[k]end})
            end
            actor.source=source
            current[source.UserId]=actor
            result[#result+1]=actor
        elseif typeof(source)=='Instance'and source:IsA('Player')then result[#result+1]=source end
    end
    actorCache=current
    return result
end
local function motion(actor,now)
    local model=actor.Character
    local root=model and model:FindFirstChild('HumanoidRootPart')
    if not root then return nil end
    local reported=root.AssemblyLinearVelocity
    if type(actor)=='table'and type(actor.source.pose)=='function'then
        local _,_,velocity=actor.source:pose()
        if typeof(velocity)=='Vector3' then reported=velocity end
    end
    local sample=Core.observeMotion(samples[model],root.Position,now,reported)
    samples[model]=sample
    return sample
end
local function connect(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections+1] = c
    return c
end
