local function createFacingCamera(services)
    local controller={}
    function controller:Step(character,humanoid,root,aim)
        if not services.allowed()or not aim or humanoid.Health<=0 or humanoid.Sit or humanoid.PlatformStand
            or root.Anchored or character:GetAttribute('MovementLocked')or character:GetAttribute('Ragdolled')
            or character:GetAttribute('TackleActive')or character:GetAttribute('GearMotion')then return false end
        local camera=services.camera()
        if not camera or camera.CameraType~=Enum.CameraType.Custom or camera.CameraSubject~=humanoid then return false end
        local desired=Vector3.new(aim.X,0,aim.Z)
        local look=camera.CFrame.LookVector*Vector3.new(1,0,1)
        if desired.Magnitude<.01 or look.Magnitude<.01 then return false end
        desired=desired.Unit;look=look.Unit
        if desired:Dot(look)>.999999 then return true end
        local yaw=math.atan2(-desired.X,-desired.Z)-math.atan2(-look.X,-look.Z)
        local focus=camera.Focus.Position
        camera.CFrame=CFrame.new(focus)*CFrame.Angles(0,yaw,0)*CFrame.new(-focus)*camera.CFrame
        return true
    end
    return controller
end
runner.createFacingCamera=createFacingCamera
