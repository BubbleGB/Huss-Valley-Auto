local function createFacingCamera(services)
    local controller={}
    local steeredCharacter
    function controller:Step(character,humanoid,root,aim,dt,pitchAim)
        if not services.allowed()or not aim or humanoid.Health<=0 or humanoid.Sit or humanoid.PlatformStand
            or root.Anchored or character:GetAttribute('MovementLocked')or character:GetAttribute('Ragdolled')
            or character:GetAttribute('TackleActive')or character:GetAttribute('GearMotion')then return false end
        local camera=services.camera()
        if not camera or camera.CameraType~=Enum.CameraType.Custom or camera.CameraSubject~=humanoid then return false end
        local desired=Vector3.new(aim.X,0,aim.Z)
        local look=camera.CFrame.LookVector*Vector3.new(1,0,1)
        if desired.Magnitude<.01 or look.Magnitude<.01 then return false end
        desired=desired.Unit;look=look.Unit
        if desired:Dot(look)>.999999 and not pitchAim then steeredCharacter=character;return true end
        local yaw=math.atan2(-desired.X,-desired.Z)-math.atan2(-look.X,-look.Z)
        local focus=camera.Focus.Position
        dt=math.clamp(tonumber(dt)or 1/60,0,.05)
        yaw=math.atan2(math.sin(yaw),math.cos(yaw))
        yaw=math.clamp(yaw*(1-math.exp(-22*dt)),-math.rad(720)*dt,math.rad(720)*dt)
        steeredCharacter=character
        camera.CFrame=CFrame.new(focus)*CFrame.Angles(0,yaw,0)*CFrame.new(-focus)*camera.CFrame
        if pitchAim and aim.Magnitude>.01 then
            local desiredPitch=math.asin(math.clamp(aim.Unit.Y,-.5,.7))
            local currentPitch=math.asin(math.clamp(camera.CFrame.LookVector.Y,-1,1))
            local delta=math.clamp((desiredPitch-currentPitch)*(1-math.exp(-22*dt)),-math.rad(360)*dt,math.rad(360)*dt)
            local turn=CFrame.fromAxisAngle(camera.CFrame.RightVector,delta)
            camera.CFrame=CFrame.new(focus)*turn*CFrame.new(-focus)*camera.CFrame
        end
        return true
    end
    function controller:Direction(character,humanoid)
        local camera=services.camera()
        if steeredCharacter~=character or not services.allowed()or not camera
            or camera.CameraType~=Enum.CameraType.Custom or camera.CameraSubject~=humanoid then return nil end
        local aim=camera.CFrame.LookVector*Vector3.new(1,0,1)
        return aim.Magnitude>.01 and aim.Unit or nil
    end
    return controller
end
runner.createFacingCamera=createFacingCamera
