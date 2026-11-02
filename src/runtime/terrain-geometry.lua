local function createTerrainGeometry(services)
    local geometry={}
    local heights={}
    local function ground(point,reference)
        local key=string.format('%.2f:%.2f',point.X,point.Z)
        if heights[key]~=nil then return heights[key]or nil end
        local origin=Vector3.new(point.X,math.min(services.ceiling,(reference or point.Y)+2),point.Z)
        local hit=services.world:Raycast(origin,Vector3.new(0,services.bottom-origin.Y,0),services.groundParams)
        if not hit or hit.Normal.Y<.55 then heights[key]=false;return nil end
        heights[key]=hit.Position
        return hit.Position
    end
    function geometry:Clear(a,b)
        local delta=(b-a)*Vector3.new(1,0,1)
        local count=math.max(1,math.ceil(delta.Magnitude/4))
        local previous=ground(a)
        if not previous then return false end
        local slope=math.tan(math.rad(math.clamp(services.maxSlope or 50,10,50)))
        local offset=Vector3.new(0,(services.clearance or 3)+.5,0)
        for i=1,count do
            local at=ground(a+delta*(i/count),previous.Y+(services.clearance or 3))
            if not at then return false end
            local step=at-previous
            local horizontal=(step*Vector3.new(1,0,1)).Magnitude
            if math.abs(step.Y)>math.max(1.5,horizontal*slope)then return false end
            if step.Magnitude>.01 and services.world:Blockcast(CFrame.new(previous+offset),Vector3.new(3,3,3),step,services.collisionParams)then return false end
            previous=at
        end
        return true
    end
    return geometry
end
runner.createTerrainGeometry=createTerrainGeometry
