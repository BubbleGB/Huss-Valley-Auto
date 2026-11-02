local function createVisualPerformance(services)
    local performance={}
    local settings={HideParticles=false,HideOtherPlayers=false,HideGemsCurrency=false}
    local records,queued,queue,characters={},{},{},{}
    local observers={}
    local first,last,nextCharacters=1,0,0
    local worldConnections={}
    local destroyed=false
    local hiddenCount=0
    local stats={scans=0,processed=0,writes=0,lastMS=0}
    local protectedRoots={ValleyGearTraps=true,LocalGearEffects=true,PredictedGearPresentation=true,
        LocalShieldBubbles=true,TimeWarpFX=true,HauntRigs=true,Lifelines=true,SoulReapLocal=true,
        FallenKingLocal=true,FallenKingBombFX=true,PumpkinBombLocal=true,PiratesCall=true,
        PumpkinPeopleRigs=true,AbilityClones=true}
    local pickupRoots={LocalRunnerGems=true,LocalRunnerCandyCorn=true,LocalRunnerCoins=true}
    local function active()return settings.HideParticles or settings.HideOtherPlayers or settings.HideGemsCurrency end
    local function enqueue(object)
        if destroyed or not active()or queued[object]then return end
        if not(object:IsA('BasePart')or object:IsA('Humanoid')or object:IsA('BillboardGui')or object:IsA('SurfaceGui')
            or object:IsA('ParticleEmitter')or object:IsA('Trail')or object:IsA('Beam'))then return end
        if not records[object]then
            local effect=object:IsA('ParticleEmitter')or object:IsA('Trail')or object:IsA('Beam')
            if effect and not(settings.HideParticles or settings.HideGemsCurrency)then return end
            if not effect and not(settings.HideOtherPlayers or settings.HideGemsCurrency)then return end
        end
        last=last+1;queue[last]=object;queued[object]=true
    end
    local function descendants(object)
        if not object then return end
        stats.scans=stats.scans+1;enqueue(object)
        for _,child in ipairs(object:GetDescendants())do enqueue(child)end
    end
    local function releaseProperty(object,name,entry)
        if entry.connection then entry.connection:Disconnect()end
        pcall(function()object[name]=entry.original end)
    end
    local function release(object)
        if observers[object]then observers[object]:Disconnect();observers[object]=nil end
        local record=records[object]
        if not record then return end
        records[object]=nil
        hiddenCount=hiddenCount-1
        if record.ancestry then record.ancestry:Disconnect()end
        for name,entry in pairs(record.properties)do releaseProperty(object,name,entry)end
    end
    local function claim(object,name,value)
        local record=records[object]
        if not record then
            if observers[object]then observers[object]:Disconnect();observers[object]=nil end
            record={properties={}};records[object]=record;hiddenCount=hiddenCount+1
            record.ancestry=object.AncestryChanged:Connect(function()enqueue(object)end)
        end
        local entry=record.properties[name]
        if not entry then
            entry={original=object[name],desired=value};record.properties[name]=entry
            entry.connection=object:GetPropertyChangedSignal(name):Connect(function()
                if records[object]~=record or entry.writing then return end
                local native=object[name]
                if native~=entry.desired then
                    entry.original=native;entry.writing=true
                    object[name]=entry.desired;entry.writing=false;stats.writes=stats.writes+1
                end
            end)
        end
        entry.desired=value
        if object[name]~=value then entry.writing=true;object[name]=value;entry.writing=false;stats.writes=stats.writes+1 end
    end
    local function classify(object)
        local other,pickup,protected,gameplay=false,false,false,false
        local localCharacter=services.localCharacter and services.localCharacter()
        local parent=object
        while parent and parent~=services.world do
            if parent==localCharacter then protected=true;other=false;break end
            if characters[parent]then other=true;protected=true end
            if pickupRoots[parent.Name]then pickup=true end
            if protectedRoots[parent.Name]or parent:GetAttribute('TackleActive')or parent:GetAttribute('GearMotion')then protected=true;gameplay=true end
            if parent:IsA('Model')and parent:FindFirstChildOfClass('Humanoid')then protected=true end
            if not gameplay and services.protected and services.protected(parent)then protected=true;gameplay=true end
            parent=parent.Parent
        end
        return other,pickup,protected,gameplay
    end
    local function apply(object)
        if not object:IsDescendantOf(services.world)then release(object);return end
        local other,pickup,protected,gameplay=classify(object)
        local hidden=(settings.HideOtherPlayers and other or settings.HideGemsCurrency and pickup)and not gameplay
        local desired={}
        if hidden then
            if object:IsA('BasePart')then desired.LocalTransparencyModifier=1
            elseif object:IsA('BillboardGui')or object:IsA('SurfaceGui')then desired.Enabled=false
            elseif object:IsA('Humanoid')then desired.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
        end
        if object:IsA('ParticleEmitter')or object:IsA('Trail')or object:IsA('Beam')then
            if not gameplay and((settings.HideParticles and not protected)or(settings.HideGemsCurrency and pickup))then desired.Enabled=false end
        end
        local record=records[object]
        if record then
            for name,entry in pairs(record.properties)do
                if desired[name]==nil then record.properties[name]=nil;releaseProperty(object,name,entry)end
            end
            if next(record.properties)==nil then release(object)end
        end
        for name,value in pairs(desired)do claim(object,name,value)end
        if not records[object]and not observers[object]and(settings.HideParticles or settings.HideGemsCurrency)
            and(object:IsA('ParticleEmitter')or object:IsA('Trail')or object:IsA('Beam'))then
            observers[object]=object.AncestryChanged:Connect(function()enqueue(object)end)
        end
    end
    local function syncCharacters()
        local current={}
        local localCharacter=services.localCharacter and services.localCharacter()
        for _,character in ipairs(services.otherCharacters()or{})do
            if character~=localCharacter and character:IsDescendantOf(services.world)then current[character]=true end
        end
        for character in pairs(characters)do if not current[character]then descendants(character)end end
        for character in pairs(current)do if not characters[character]then descendants(character)end end
        characters=current;nextCharacters=services.clock()+1
    end
    local function releaseAll()
        local objects={};for object in pairs(records)do objects[#objects+1]=object end
        for _,object in ipairs(objects)do release(object)end
        for object,connection in pairs(observers)do connection:Disconnect();observers[object]=nil end
    end
    function performance:Configure(value)
        if destroyed then return end
        local particles=settings.HideParticles~= (value.HideParticles==true)
        local players=settings.HideOtherPlayers~= (value.HideOtherPlayers==true)
        local pickups=settings.HideGemsCurrency~= (value.HideGemsCurrency==true)
        settings={HideParticles=value.HideParticles==true,HideOtherPlayers=value.HideOtherPlayers==true,HideGemsCurrency=value.HideGemsCurrency==true}
        if not active()then
            for _,connection in ipairs(worldConnections)do connection:Disconnect()end;worldConnections={}
            releaseAll();queued,queue,characters={},{},{};first,last=1,0
            return
        end
        if #worldConnections==0 then
            worldConnections={services.world.DescendantAdded:Connect(enqueue),services.world.DescendantRemoving:Connect(release)}
            if services.protectedSignals then
                for _,signal in ipairs(services.protectedSignals())do
                    worldConnections[#worldConnections+1]=signal:Connect(descendants)
                end
            end
        end
        syncCharacters()
        if not(settings.HideParticles or settings.HideGemsCurrency)then
            for object,connection in pairs(observers)do connection:Disconnect();observers[object]=nil end
        end
        for object in pairs(records)do enqueue(object)end
        if particles and settings.HideParticles then descendants(services.world)end
        if players then for character in pairs(characters)do descendants(character)end end
        if pickups then for name in pairs(pickupRoots)do descendants(services.world:FindFirstChild(name))end end
    end
    function performance:Tick()
        if destroyed or not active()then return end
        if services.clock()>=nextCharacters then syncCharacters()end
        local started=services.clock()
        for _=1,120 do
            if first>last then break end
            local object=queue[first];queue[first]=nil;first=first+1;queued[object]=nil
            local ok=pcall(apply,object)
            if not ok then release(object)end
            stats.processed=stats.processed+1
            if services.clock()-started>=.0015 then break end
        end
        if first>last then queue={};first,last=1,0 end
        stats.lastMS=math.max(0,(services.clock()-started)*1000)
    end
    function performance:Report()
        return {hidden=hiddenCount,pending=math.max(0,last-first+1),scans=stats.scans,processed=stats.processed,writes=stats.writes,lastMS=stats.lastMS}
    end
    function performance:Destroy()
        if destroyed then return end
        self:Configure({});destroyed=true
    end
    return performance
end
runner.createVisualPerformance=createVisualPerformance
