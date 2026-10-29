local function activeRunner(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass('Humanoid')
    local r = c and c:FindFirstChild('HumanoidRootPart')
    local present=type(p)=='table'and actorCache[p.UserId]==p or typeof(p)=='Instance'and p.Parent==Players
    if not present or p.UserId==player.UserId or not c or not c:IsDescendantOf(workspace)or not r then return false end
    if type(p)=='table'and(p:GetAttribute('Hidden')or p:GetAttribute('FadeOutAt'))then return false end
    if Core.abilityState(p,c,workspace:GetServerTimeNow()).protected then return false end
    return Core.isRunner(p:GetAttribute('InMatch'),p:GetAttribute('GameRole'),p:GetAttribute('RunState'),
        h and h.Health or c:GetAttribute('Health')or 100,c:GetAttribute('MovementLocked'),type(p)=='table',r.Anchored)
end

local function updateSmartSpeed(character,humanoid,root)
    local now=workspace:GetServerTimeNow()
    local round,phase=session:GetAttribute('RunNumber'),session:GetAttribute('Phase')
    local reset=character:GetAttribute('MovementReset')
    local same=smartContext and smartContext.character==character and smartContext.round==round and smartContext.role==activeRole
    if not same then smartEpoch=smartEpoch+1 end
    local eligible=not character:GetAttribute('TackleActive')and not character:GetAttribute('GearMotion')
        and not character:GetAttribute('Burrowing')and not controlGate.reason(player)
        and humanoid.FloorMaterial~=Enum.Material.Air
    local corrected=same and smartContext.phase==phase and smartContext.reset~=reset
        and smartState and (smartState.watchUntil or 0)>now and api.SmartCap>api.SpeedMultiplier
    local nearest,visible=math.huge,math.huge
    if api.SmartSpeedEnabled and eligible then
        for _,actor in ipairs(participants())do
            local opposite=activeRole=='Runner'and'Catcher'or'Runner'
            if actor.UserId~=player.UserId and actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')==opposite
                and actor:GetAttribute('RunState')=='Active'and(activeRole=='Runner'or activeRunner(actor))then
                local c=actor.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
                local h=c and c:FindFirstChildOfClass('Humanoid')
                if r and not r.Anchored and(not h or h.Health>0)then
                    local offset=r.Position-root.Position
                    nearest=math.min(nearest,offset.Magnitude)
                    if offset.Magnitude<=12 then
                        local params=RaycastParams.new()
                        params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={character,c}
                        params.RespectCanCollide=true;params.CollisionGroup=root.CollisionGroup
                        if not workspace:Raycast(root.Position,offset,params)then visible=math.min(visible,offset.Magnitude)end
                    end
                end
            end
        end
    end
    local distance=19
    if api.SmartSpeedEnabled and eligible then distance=visible<=12 and visible or nearest>=20 and nearest or 19 end
    smartState=Core.smartSpeedStep(smartState,now,api.SmartSpeedEnabled,eligible,distance,smartEpoch,corrected)
    smartContext={character=character,round=round,role=activeRole,phase=phase,reset=reset}
    api.SmartNearest=nearest;api.SmartUntilAt=smartState.untilAt;api.SmartReadyAt=smartState.readyAt
    api.SmartWatchUntil=smartState.watchUntil
    if corrected then
        api.SmartCorrections=(api.SmartCorrections or 0)+1
        api.SmartCap=math.min(api.SmartCap,1.05)
        env.HussSmartSpeedLimit={jobId=game.JobId,cap=api.SmartCap,policy=Core.SMART_POLICY}
    end
end

