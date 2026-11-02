local function createLobbyNavigation(services)
    local navigation={};local goal,range,route,index;local version=0;local pending=false
    local nextCompute=0;local failures=0;local progressPosition,progressAt;local blocked=false
    local spawn=services.spawn or task.spawn
    function navigation:Cancel()
        version=version+1;goal=nil;route=nil;index=nil;pending=false;blocked=false
        failures=0;progressPosition=nil;progressAt=nil
    end
    function navigation:SetGoal(position,distance)
        distance=math.max(0,distance or 3)
        if goal and (goal-position).Magnitude<.5 and range==distance then return end
        self:Cancel();goal=position;range=distance
    end
    local function compute(position,now)
        if pending or now<nextCompute or failures>=4 then return end
        pending=true;blocked=false;nextCompute=now+.75
        local ticket=version;local destination=goal
        spawn(function()
            local ok,points=pcall(function()
                local path=services.pathfinding:CreatePath({AgentCanJump=true,WaypointSpacing=4})
                path:ComputeAsync(position,destination)
                if path.Status~=Enum.PathStatus.Success then return nil end
                return path:GetWaypoints()
            end)
            if ticket~=version then return end
            pending=false
            if ok and points and #points>0 then
                route=points;index=1;blocked=false
                progressPosition=position;progressAt=services.clock()
            else
                route=nil;blocked=true;failures=failures+1
                nextCompute=services.clock()+math.min(4,.75*failures)
            end
        end)
    end
    function navigation:Step(character,humanoid,root)
        local zero=Vector3.zero
        if not goal then return zero,false,'idle'end
        if not character or not humanoid or not root or humanoid.Health<=0
            or services.canWalk and not services.canWalk(character,humanoid,root)then return zero,false,'blocked'end
        local now=services.clock();local position=root.Position
        local verticalTolerance=6
        if humanoid.HipHeight and root.Size then
            verticalTolerance=math.max(4,humanoid.HipHeight+root.Size.Y*.5+4)
        end
        local function reached(target,radius)
            local delta=position-target
            return math.abs(delta.Y)<=verticalTolerance and Vector3.new(delta.X,0,delta.Z).Magnitude<=radius
        end
        if reached(goal,range)then
            if pending then version=version+1;pending=false end
            return zero,false,'arrived'
        end
        if route and progressPosition then
            if (position-progressPosition).Magnitude>=1 then
                progressPosition=position;progressAt=now;failures=0
            elseif now-progressAt>=2 then
                route=nil;blocked=true;failures=failures+1
            end
        end
        if not route then
            compute(position,now)
            return zero,false,blocked and 'blocked'or 'planning'
        end
        while index<=#route do
            local radius=index==#route and math.min(2,range)or 2
            local passed=false
            if index>1 and index<#route then
                local segment=route[index].Position-route[index-1].Position
                segment=Vector3.new(segment.X,0,segment.Z)
                passed=math.abs(position.Y-route[index].Position.Y)<=verticalTolerance
                    and segment.Magnitude>.01 and (position-route[index].Position):Dot(segment)>=0
            end
            if not passed and not reached(route[index].Position,radius)then break end
            index=index+1
        end
        if index>#route then route=nil;blocked=true;return zero,false,'blocked'end
        local waypoint=route[index];local delta=waypoint.Position-position
        local flat=Vector3.new(delta.X,0,delta.Z)
        if flat.Magnitude<.01 then return zero,waypoint.Action==Enum.PathWaypointAction.Jump,'walking'end
        return flat.Unit,waypoint.Action==Enum.PathWaypointAction.Jump,'walking'
    end
    return navigation
end
runner.createLobbyNavigation=createLobbyNavigation
