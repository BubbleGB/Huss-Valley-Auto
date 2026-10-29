function Core.hazardSnapshot(instance,role,items,now,kind)
    kind=kind or instance:GetAttribute('GearVisualKind') or instance.Name
    if kind:find('BearTrap',1,true)then kind='BearTrap' end
    if kind:find('BananaPeel',1,true)then kind='BananaPeel' end
    if kind:find('SpringBox',1,true)then kind='SpringBox' end
    local config=items[kind] or {}
    local runnerOnly=kind=='BearTrap' or kind=='SpringBox' or kind=='GraveRise'or kind=='BowlingBall'or kind=='RufusLeash'
    if runnerOnly and role~='Runner' then return nil end
    if kind=='FartCloud'and role~='Catcher'then return nil end
    if not runnerOnly and kind~='BananaPeel'and kind~='FartCloud'and not(config.TriggerRadius or config.BurstRadius)then return nil end
    local spawned,duration=instance:GetAttribute('GearSpawnedAt'),instance:GetAttribute('GearDuration')
    local expires=type(spawned)=='number'and type(duration)=='number'and spawned+duration or nil
    if kind=='SpringBox' then expires=instance:GetAttribute('PopAt')or expires end
    if kind=='GraveRise' then
        local sink=instance:GetAttribute('SinkAt')
        if type(sink)=='number'then expires=sink+(instance:GetAttribute('Sink')or 0.45)end
    end
    if expires and now>expires+0.25 then return nil end
    local position=instance:GetAttribute('GearLanding')or instance:GetAttribute('Landing')
    if typeof(position)=='CFrame'then position=position.Position end
    if typeof(position)~='Vector3'then
        if instance:IsA('Model')or instance:IsA('BasePart')then position=instance:GetPivot().Position else return nil end
    end
    local radius=(config.TriggerRadius or config.BurstRadius or 2.5)+3.5
    if kind=='FartCloud'then radius=(instance:IsA('BasePart')and instance.Size.X/1.6 or config.Radius or 9)+3.5 end
    if kind=='BowlingBall'then radius=6 end
    if kind=='RufusLeash'then radius=6 end
    if kind=='GraveRise'then
        local size=instance:IsA('BasePart')and instance.Size or Vector3.new(5,8,5)
        if instance:IsA('Model')then local _,bounds=instance:GetBoundingBox();size=bounds end
        radius=Vector2.new(size.X,size.Z).Magnitude/2+2.5
    end
    local direction,speed=instance:GetAttribute('GearDirection'),instance:GetAttribute('GearSpeed')
    if kind=='BowlingBall'or kind=='RufusLeash'then speed=type(speed)=='number'and speed or(kind=='BowlingBall'and 42 or 65)end
    local velocity=typeof(direction)=='Vector3'and type(speed)=='number'and flat(direction)*math.clamp(speed,0,100)or Vector3.zero
    return {position=position,radius=radius,kind=kind,source=instance,velocity=velocity,
        remaining=expires and math.max(0,expires-now)or nil}
end

