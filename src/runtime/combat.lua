local function faceToward(character, humanoid, root, aim, updateCamera, actionFacing)
    if aim.Magnitude < 0.01 or character:GetAttribute('TackleActive') or character:GetAttribute('GearMotion')
        or root.Anchored or humanoid.Sit or humanoid.PlatformStand then return end
    if actionFacing and facingHumanoid then
        -- Let the native action capture the pre-chase value and own its own lifetime.
        if facingHumanoid.Parent then facingHumanoid.AutoRotate=previousAutoRotate end
        facingHumanoid,previousAutoRotate=nil,nil
    end
    if not actionFacing and api.Settings.AutoFaceTarget and facingHumanoid ~= humanoid then
        facingHumanoid,previousAutoRotate=humanoid,humanoid.AutoRotate
    end
    aim=flat(aim)
    if aim.Magnitude < 0.01 then return end
    aim=aim.Unit
    if not actionFacing and api.Settings.AutoFaceTarget then
        humanoid.AutoRotate=false
        root.CFrame=CFrame.lookAt(root.Position,root.Position+aim)
    end
    if actionFacing then
        -- Native tackle.request reads root facing; this one-shot yaw owns no movement state.
        root.CFrame=CFrame.lookAt(root.Position,root.Position+aim)
    end
    local camera=workspace.CurrentCamera
    if updateCamera and api.Settings.FollowCamera and camera and camera.CameraType ~= Enum.CameraType.Scriptable and camera.CameraSubject == humanoid then
        local pitch=math.clamp(camera.CFrame.LookVector.Y,-0.65,0.35)
        local view=aim*math.sqrt(1-pitch*pitch)+Vector3.new(0,pitch,0)
        local focus=root.Position+Vector3.new(0,1.5,0)
        local zoom=math.clamp((camera.CFrame.Position-camera.Focus.Position).Magnitude,6,18)
        camera.CFrame=CFrame.lookAt(focus-view*zoom,focus)
        camera.Focus=CFrame.new(focus)
    end
end

local function faceTarget(updateCamera)
    if not api.Enabled or activeRole ~= 'Catcher' or not ownedHumanoid or not huntTarget or not activeRunner(huntTarget) then return end
    local c=player.Character
    local h=c and c:FindFirstChildOfClass('Humanoid')
    local root=c and c:FindFirstChild('HumanoidRootPart')
    if not h or not root or c:GetAttribute('MovementLocked') or c:GetAttribute('Ragdolled') then return end
    local targetRoot=huntTarget.Character.HumanoidRootPart
    local aim=combatFacing and combatFacing.character==c and workspace:GetServerTimeNow()<combatFacing.untilAt
        and combatFacing.aim or flat(targetRoot.Position-root.Position)
    faceToward(c,h,root,aim,updateCamera)
end

local function useCombat(character,humanoid,root,pursuit,allowed)
    if not pursuit or not activeRunner(pursuit.player) or character:GetAttribute('TackleActive')
        or character:GetAttribute('GearMotion') or humanoid.FloorMaterial == Enum.Material.Air
        or controlGate.reason(player) or session:GetAttribute('GlobalPaused')
        or session:GetAttribute('AdminMatchMode') == 'BladeBall'
        or (character:GetAttribute('DaggerEquipped') and character:GetAttribute('DaggerState') ~= 'Held') then return end
    local now=workspace:GetServerTimeNow()
    if now<nextCombatAt then return end
    local velocity=flat(root.AssemblyLinearVelocity)
    local profile=tackleProfile.select(tackleConfig,velocity.Magnitude,movementProfiles.get('Catcher',player).MaxSpeed)
    local total=meleeConfig.Windup+meleeConfig.ActiveDuration+meleeConfig.Recovery
    local started=character:GetAttribute('ReachStartedAt') or 0
    local attackReady=Core.combatReady(now,nextMelee,started,total,combat.meleeRemaining())
    local meleeReady=api.Settings.AutoMelee and meleeConfig.Enabled and attackReady
    local stableFor=pursuitHistory and os.clock()-pursuitHistory.stableSince or 0
    local directionStableFor=pursuitHistory and os.clock()-(pursuitHistory.directionSince or pursuitHistory.stableSince)or 0
    local nativeReady=api.Settings.AutoDive and attackReady and tackle.remaining() <= 0.02 and not tackle.isActive(character)
    local normalDive=nativeReady and now>=nextDive and directionStableFor>=.25
    local closeDive=nativeReady and now>=nextCloseDive and directionStableFor>=.14
    local abilities=Core.abilityState(pursuit.player,pursuit.player.Character,now)
    local meleeRange=meleeConfig.CommitDistance*(character:GetAttribute('BigDaggerActive')and 2 or 1)
    local relative=pursuit.position-root.Position
    local measured=api.ActionTiming.Melee and api.ActionTiming.Melee.serverStartMS
    local delay=measured and math.clamp(measured.mean/1000,0,.06)or 0
    local action,aim,style,contactAt=Core.combatAction(relative,pursuit.velocity,velocity,profile.Distance,
        profile.Duration,profile.Reach,meleeRange,meleeReady,normalDive or closeDive,true,
        {closeDive=closeDive,farDive=normalDive,shielded=abilities.shielded,protected=abilities.protected,evasive=abilities.evasive,
            stableFor=stableFor,directionStableFor=directionStableFor,acceleration=pursuit.acceleration,
            diveLatency=math.clamp((api.ActionTiming.Dive and api.ActionTiming.Dive.replyMS
                and api.ActionTiming.Dive.replyMS.mean or 100)/2000,.03,.12),
            diveClear=function(d,distance)return allowed(d,math.max(.1,distance))end,
            sweep=hitReplay.sweep,meleeBox=combat.meleeBox(character),diveBox=hitReplay.bounds('Tackle',profile),
            windup=meleeConfig.Windup,active=meleeConfig.ActiveDuration,delay=delay,
            diveTravel=function(at)return tackleMotion.distance(profile,at)end})
    if not action then return end
    local distance=action == 'Dive' and profile.Distance or flat(relative).Magnitude
    if not allowed(aim,math.max(0.1,distance)) then return end
    local clock=os.clock()
    if action == 'Dive' then
        if type(contactAt)~='number'or contactAt~=contactAt or contactAt<0 or contactAt>profile.Duration then return end
        local previousRotation=root.CFrame.Rotation
        faceToward(character,humanoid,root,aim,false,true)
        if tackle.request() then
            local id=character:GetAttribute('TacklePredictionId')or Http:GenerateGUID(false)
            pendingDive=actionRequest('Dive',id,clock,now)
            pendingDive.activeDuration=profile.Duration;pendingDive.recovery=profile.Recovery
            pendingDive.predictedContact=contactAt;predicted(pendingDive)
            nextDive=now+Core.diveRetry(profile,style)
            nextCloseDive=nextDive
            direction=Vector3.zero
            api.Actions.Dive=api.Actions.Dive+1
            api.LastAction='Dive'
            api.LastDiveStyle=style
            return true
        end
        if player.Character==character and root.Parent==character
            and not character:GetAttribute('TackleActive')and not character:GetAttribute('GearMotion')
            and not tackle.isActive(character)then
            root.CFrame=CFrame.new(root.Position)*previousRotation
        end
        nextDive=now+.25;nextCloseDive=nextDive
    else
        local id=Http:GenerateGUID(false)
        nextMelee=now+total
        pendingMelee=actionRequest('Melee',id,clock,now)
        pendingMelee.windup=meleeConfig.Windup;pendingMelee.activeDuration=meleeConfig.ActiveDuration
        pendingMelee.predictedContact=contactAt
        combatFacing={character=character,aim=aim,untilAt=now+meleeConfig.Windup+meleeConfig.ActiveDuration}
        gameState.MeleeEvent:FireServer({id=id,at=now,direction=aim,position=root.Position})
        local prediction=combat.begin({id=id,kind='Melee',character=character,predicted=true,startedAt=now,
            starts=now+meleeConfig.Windup,ends=now+meleeConfig.Windup+meleeConfig.ActiveDuration,
            direction=aim,box=combat.meleeBox(character)})
        if prediction then predicted(pendingMelee)end
        api.Actions.Melee=api.Actions.Melee+1
        api.LastAction='Melee'
        return true
    end
end

