function tp.epoch(character)
    local active=gameState:FindFirstChild('ActiveMap')
    return table.concat({tostring(active and active.Value),tostring(session:GetAttribute('RunNumber')),
        tostring(player:GetAttribute('GameRole')),tostring(character and character:GetAttribute('CombatLife'))},':')
end
function tp.eligible(character,humanoid,root,observing)
    local now=workspace:GetServerTimeNow()
    for _,name in ipairs({'CannonUntil','StepOverUntil','TruckUntil'})do
        if math.max(tonumber(player:GetAttribute(name))or 0,tonumber(character:GetAttribute(name))or 0)>now then return false end
    end
    return character==player.Character and humanoid.Health>0 and not root.Anchored and not humanoid.Sit
        and not humanoid.PlatformStand and humanoid.FloorMaterial~=Enum.Material.Air
        and player:GetAttribute('InMatch')==true and player:GetAttribute('RunState')=='Active'
        and not player:GetAttribute('AFK')and not session:GetAttribute('MapChanging')and not session:GetAttribute('GlobalPaused')
        and session:GetAttribute('AdminMatchMode')==nil and not controlGate.reason(player)
        and not character:GetAttribute('TackleActive')and not character:GetAttribute('GearMotion')
        and not character:GetAttribute('Burrowing')and not character:GetAttribute('Ragdolled')and not character:GetAttribute('MovementLocked')
        and not Core.abilityState(player,character,now).evasive and(observing or combat.meleeRemaining()<=0)
end
function tp.observe()
    local watch=tp.state.watch
    if not watch then return end
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local humanoid=character and character:FindFirstChildOfClass('Humanoid')
    local now=os.clock()
    local observed={position=root and root.Position or Vector3.zero,velocity=root and root.AssemblyLinearVelocity or Vector3.zero,
        epoch=tp.epoch(character),phase=session:GetAttribute('Phase'),reset=character and character:GetAttribute('MovementReset'),
        valid=character==watch.character and root~=nil and humanoid~=nil and tp.eligible(character,humanoid,root,true)}
    local outcome=Core.tpObservation(watch,now,observed)
    api.TPLastObservation=outcome
    if outcome=='watching'then
        watch.position,watch.velocity,watch.at=observed.position,observed.velocity,now
    else
        tp.state.watch=nil
        if outcome=='corrected'or outcome=='uncertain'then
            tp.state.blocked=true;api.TPDodgeEnabled=false;api.TPAssistEnabled=false
            tp.state.reason=outcome=='corrected'and'correction'or'observation gap'
            if outcome=='corrected'then api.TPCorrections=(api.TPCorrections or 0)+1
            else api.TPObservationGaps=(api.TPObservationGaps or 0)+1 end
        elseif outcome=='complete'then api.TPCleanWatches=(api.TPCleanWatches or 0)+1 end
    end
end
function tp.probe(character,root,field,point,params,groundParams)
    local delta=flat(point-root.Position)
    if delta.Magnitude<1.9 or delta.Magnitude>4.001 or math.abs(point.Y-root.Position.Y)>.1 then return nil end
    local body=Vector3.new(math.max(3.2,root.Size.X+1),math.max(4.5,root.Size.Y+2),math.max(3.2,root.Size.Z+1))
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances={character}
    overlap.RespectCanCollide=true;overlap.CollisionGroup=root.CollisionGroup
    local function free(p)
        return #workspace:GetPartBoundsInBox(CFrame.new(p+Vector3.new(0,.25,0)),body,overlap)==0
    end
    local ground=workspace:Raycast(root.Position+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
    if not ground then return nil end
    local function supported(p)
        local hit=workspace:Raycast(p+Vector3.new(0,2,0),Vector3.new(0,-10,0),groundParams)
        return hit and hit.Normal.Y>.7 and math.abs(hit.Position.Y-ground.Position.Y)<=.75
            and p.Y-hit.Position.Y>=1.5 and p.Y-hit.Position.Y<=5.5
    end
    local exit=point+delta.Unit*2
    if not free(point)or not supported(point)or not free(exit)or not supported(exit)then return nil end
    local blocked=workspace:Blockcast(CFrame.new(root.Position+Vector3.new(0,.25,0)),body,delta,params)
    local thin=false
    if blocked then
        local part=blocked.Instance
        local name=(part.Name..' '..part.Parent.Name):lower()
        if name:find('safe',1,true)or name:find('zone',1,true)or name:find('barrier',1,true)
            or name:find('boundary',1,true)or name:find('spawn',1,true)or name:find('finish',1,true)
            or not part:IsA('BasePart')or not part.Anchored then return nil end
        local front=workspace:Raycast(root.Position,delta,params)
        local back=workspace:Raycast(point,-delta,params)
        thin=front and back and front.Instance==part and back.Instance==part
            and(front.Position-back.Position).Magnitude<=1.25
        if not thin then return nil end
        local remaining=RaycastParams.new()
        remaining.FilterType=Enum.RaycastFilterType.Exclude
        local excluded=table.clone(params.FilterDescendantsInstances);excluded[#excluded+1]=part
        remaining.FilterDescendantsInstances=excluded;remaining.RespectCanCollide=true
        remaining.CollisionGroup=root.CollisionGroup
        if workspace:Blockcast(CFrame.new(root.Position+Vector3.new(0,.25,0)),body,delta,remaining)then return nil end
    elseif not supported(root.Position+delta*.5)then return nil end
    return {point=point,distance=delta.Magnitude,landingSafe=true,exitSafe=true,pathBlocked=blocked~=nil,
        thinObstacle=thin,exitPoint=exit}
end
function tp.commit(character,root,candidate,epoch)
    local now=os.clock()
    local humanoid=character:FindFirstChildOfClass('Humanoid')
    if not api.Enabled or not api.TPDodgeEnabled or not humanoid or not tp.eligible(character,humanoid,root)
        or tp.state.blocked or tp.state.watch or now<tp.state.readyAt then return false end
    if tp.state.epoch~=epoch then tp.state.epoch=epoch;tp.state.uses=0 end
    if tp.state.uses>=2 then return false end
    local from,velocity=root.Position,root.AssemblyLinearVelocity
    local delta=candidate.point-from
    if delta.Magnitude>4.001 then return false end
    tp.state.readyAt=now+12;tp.state.uses=tp.state.uses+1
    tp.state.watch={character=character,epoch=epoch,phase=session:GetAttribute('Phase'),reset=character:GetAttribute('MovementReset'),
        position=candidate.point,velocity=velocity,at=now,untilAt=now+1.5,distance=delta.Magnitude}
    character:PivotTo(character:GetPivot()+delta)
    root.AssemblyLinearVelocity=velocity
    direction=flat(delta).Unit
    api.Actions.TPDodge=api.Actions.TPDodge+1;api.Actions.TPAssist=api.Actions.TPAssist+1;api.LastAction='TP Assist'
    api.TPLast={from=from,to=candidate.point,distance=delta.Magnitude,at=now,kind=candidate.kind}
    table.clear(dashHistory);table.clear(ownHistory);samples[character]=nil
    navigation=nil;runnerProgress=nil;actionContext=nil;elapsed=1
    if boostQueued then boost.clear();boostQueued=false end
    pendingDash=nil
    return true
end

