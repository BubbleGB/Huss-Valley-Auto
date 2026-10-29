local function collectHazards(position,role)
    local result,seen,signature={},{},{}
    local now=workspace:GetServerTimeNow()
    local function add(instance,kind)
        if seen[instance]or not instance:IsDescendantOf(workspace)then return end
        if kind=='GraveRise'and type(instance:GetAttribute('RiseAt'))~='number'then return end
        local hazard=Core.hazardSnapshot(instance,role,gearItems,now,kind)
        if hazard and flat(hazard.position-position).Magnitude<450 then
            seen[instance]=true
            local update=projectilePositions[instance:GetAttribute('GearRequestId')]
            if update and os.clock()-update.time<0.5 then hazard.position=update.position end
            result[#result+1]=hazard
            signature[#signature+1]=hazard.kind..':'..math.floor(hazard.position.X*2)..':'..math.floor(hazard.position.Z*2)..':'..hazard.radius
            if hazard.velocity and hazard.velocity.Magnitude>1 and(hazard.kind=='BowlingBall'or hazard.kind=='RufusLeash')then
                local horizon=math.min(.8,hazard.remaining or .8)
                local count=math.clamp(math.ceil(hazard.velocity.Magnitude*horizon/math.max(4,hazard.radius)),1,12)
                for i=1,count do
                    local point=hazard.position+hazard.velocity*(horizon*i/count)
                    result[#result+1]={position=point,radius=hazard.radius,kind=hazard.kind}
                    signature[#signature+1]=hazard.kind..':'..math.floor(point.X*2)..':'..math.floor(point.Z*2)
                end
            end
        end
    end
    local folder=workspace:FindFirstChild('ValleyGearTraps')
    if folder then for _,v in ipairs(folder:GetChildren())do add(v)end end
    local effects=workspace:FindFirstChild('LocalGearEffects')
    if effects then for _,v in ipairs(effects:GetChildren())do if v.Name=='FartCloud'then add(v,'FartCloud')end end end
    for _,tag in ipairs({'PredictedGearVisual','SpringBoxShake','GraveRise'})do
        for _,v in ipairs(Collection:GetTagged(tag))do add(v,tag~='PredictedGearVisual'and(tag=='SpringBoxShake'and'SpringBox'or tag)or nil)end
    end
    table.sort(signature)
    return result,table.concat(signature,';')
end

local function threats(now)
    local result = {}
    local serverNow=workspace:GetServerTimeNow()
    local function add(model,actor)
        local root = model and model:FindFirstChild('HumanoidRootPart')
        local humanoid=model and model:FindFirstChildOfClass('Humanoid')
        if not root or (humanoid and humanoid.Health<=0)then return end
        local sample=motion(actor,now)
        local velocity=sample and sample.velocity or Vector3.zero
        local reach=math.max(meleeConfig.CommitDistance,tackleConfig.HumanBox and tackleConfig.HumanBox.Reach['Long Dive']or tackleConfig.Reach)
        if model:GetAttribute('BigDaggerActive')then reach=math.max(reach,meleeConfig.CommitDistance*2)end
        local cooldown=math.max(0,((actor or model):GetAttribute('TackleReadyAt')or 0)-serverNow)
        local radius=Core.chaserRadius(tackleConfig.MaxDistance or 15,reach,cooldown,model:GetAttribute('TackleActive'))
        if velocity.Magnitude>50 then radius=math.max(radius,velocity.Magnitude*0.42+reach+3)end
        result[#result+1]=Core.abilityThreat(actor,model,root,velocity,serverNow,
            {radius=radius,catchRadius=reach+1.5,maxSpeed=movementProfiles.get('Catcher',actor).MaxSpeed,
                cannon=knifeAbilities.Cannon,stepOver=knifeAbilities.StepOver,
                ready=not abilityRules.blocked(actor),knifeBlocked=abilityRules.knifeBlocked(actor)})
    end
    for _,p in ipairs(participants()) do
        if p ~= player and p:GetAttribute('InMatch') == true and p:GetAttribute('GameRole') == 'Catcher'
            and p:GetAttribute('RunState')=='Active' then
            add(p.Character,p)
        end
    end
    return result
end

