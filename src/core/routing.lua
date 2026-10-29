function Core.segmentRisk(a,b,cost,t0,t1)
    local risk=0
    local count=math.max(1,math.ceil(flat(b-a).Magnitude/6))
    for i=0,count do risk=math.max(risk,cost(a+(b-a)*(i/count),t0 and t0+((t1 or t0)-t0)*(i/count)or nil))end
    return risk
end

function Core.directSafe(position,goal,allowed,cost,timing)
    local at=timing and flat(goal-position).Magnitude/timing.speed
    return Core.segmentRisk(position,goal,cost,at and 0,at)<=0.6 and allowed(position,goal,at and 0,at)
end

function Core.smoothWaypoint(position,path,index,allowed,cost,timing)
    local chosen,prefixRisk=index,0
    local previous=position
    local elapsed=0
    for i=index,math.min(#path,index+5)do
        local nextAt=timing and elapsed+flat(path[i]-previous).Magnitude/timing.speed
        local directAt=timing and flat(path[i]-position).Magnitude/timing.speed
        prefixRisk=math.max(prefixRisk,Core.segmentRisk(previous,path[i],cost,nextAt and elapsed,nextAt))
        if Core.segmentRisk(position,path[i],cost,directAt and 0,directAt)<=prefixRisk+0.05
            and allowed(position,path[i],directAt and 0,directAt)then chosen=i end
        previous=path[i];elapsed=nextAt or 0
    end
    return chosen
end

-- Static hazard circles also cover noncolliding trigger areas.
function Core.clearSegment(a,b,zones)
    local span=flat(b-a)
    local length2=span:Dot(span)
    for _,zone in ipairs(zones) do
        if math.abs(a.Y-zone.position.Y)<10 or math.abs(b.Y-zone.position.Y)<10 then
            local relative=flat(a-zone.position)
            local t=length2>0.001 and math.clamp(-relative:Dot(span)/length2,0,1) or 0
            local closest=(relative+span*t).Magnitude
            if relative.Magnitude < zone.radius then
                if closest < relative.Magnitude-0.01 or flat(b-zone.position).Magnitude <= relative.Magnitude+0.01 then return false end
            elseif closest < zone.radius then return false end
        end
    end
    return true
end

-- Bounded A* with lazy collision probes; distance plus risk chooses short safe detours.
function Core.route(start,goals,step,allowed,cost,maxNodes,timing)
    if #goals==0 then return nil end
    local riskSamples={}
    local function sampledCost(position,at)
        if timing then
            local times=riskSamples[position]
            if not times then times={};riskSamples[position]=times end
            local risk=times[at]
            if risk==nil then risk=cost(position,at);times[at]=risk end
            return risk
        end
        local risk=riskSamples[position]
        if risk==nil then risk=cost(position);riskSamples[position]=risk end
        return risk
    end
    local function heuristic(p)
        local best=math.huge
        for _,g in ipairs(goals)do best=math.min(best,flat(g-p).Magnitude/step)end
        return best
    end
    local heap={}
    local function push(node)
        local i=#heap+1
        while i>1 do
            local parent=math.floor(i/2)
            if heap[parent].f<=node.f then break end
            heap[i]=heap[parent];i=parent
        end
        heap[i]=node
    end
    local function pop()
        local root=heap[1]
        local last=table.remove(heap)
        if #heap>0 then
            local i=1
            while i*2<=#heap do
                local child=i*2
                if child<#heap and heap[child+1].f<heap[child].f then child=child+1 end
                if last.f<=heap[child].f then break end
                heap[i]=heap[child];i=child
            end
            heap[i]=last
        end
        return root
    end
    local first={x=0,z=0,position=start,g=0,time=0,f=heuristic(start),key='0:0'}
    local best={['0:0']=0}
    local closed={}
    push(first)
    local expanded=0
    while #heap>0 and expanded<(maxNodes or 450)do
        local node=pop()
        if not closed[node.key] and node.g==best[node.key] then
            if node.goal then
                local path={}
                local cursor=node
                while cursor do table.insert(path,1,cursor.position);cursor=cursor.parent end
                return path
            end
            closed[node.key]=true
            expanded=expanded+1
            for index,goal in ipairs(goals)do
                local length=flat(goal-node.position).Magnitude
                local at=timing and node.time+length/timing.speed
                if length<=step*1.5 and allowed(node.position,goal,at and node.time,at)then
                    local g=node.g+length/step*(1+math.max(0,Core.segmentRisk(node.position,goal,sampledCost,at and node.time,at)))
                    local key='goal:'..index
                    if not best[key]or g<best[key]then
                        best[key]=g
                        push({position=goal,g=g,f=g,key=key,parent=node,goal=true,time=at or 0})
                    end
                end
            end
            for dx=-1,1 do for dz=-1,1 do if dx~=0 or dz~=0 then
                local x,z=node.x+dx,node.z+dz
                local length=math.sqrt(dx*dx+dz*dz)
                local at=timing and node.time+length*step/timing.speed
                local key=x..':'..z..(at and(':'..math.min(5,math.floor(at/.25)))or'')
                if not closed[key]then
                    local position=start+Vector3.new(x*step,0,z*step)
                    local g=node.g+length*(1+math.max(0,Core.segmentRisk(node.position,position,sampledCost,at and node.time,at)))
                    if (not best[key]or g<best[key])and allowed(node.position,position,at and node.time,at)then
                        best[key]=g
                        push({x=x,z=z,key=key,position=position,g=g,f=g+heuristic(position),parent=node,time=at or 0})
                    end
                end
            end end end
        end
    end
    return nil
end

function Core.planRoute(start,goals,allowed,cost,fine,timing)
    local path
    if not fine then path=Core.route(start,goals,12,allowed,cost,450,timing)end
    if path then return path,12 end
    return Core.route(start,goals,6,allowed,cost,600,timing),6
end

-- Relative motion predicts closest approach, including enemies crossing our path.
function Core.choose(position, goal, speed, threats, allowed, previous,urgency,options)
    urgency=math.clamp(urgency or 0,0,1)
    local delta = flat(goal - position)
    if delta.Magnitude < 1 then return Vector3.zero end
    local forward = delta.Unit
    local candidates = {forward, Vector3.zero}
    for i=0,23 do
        local a = i * math.pi / 12
        candidates[#candidates+1] = Vector3.new(math.cos(a), 0, math.sin(a))
    end
    local best, bestScore = Vector3.zero, -math.huge
    for _,direction in ipairs(candidates) do
        if direction.Magnitude == 0 or allowed(direction) then
            local score = direction:Dot(forward)*(5+5*urgency) + direction:Dot(previous)*0.4
            if direction.Magnitude == 0 then score = -6-6*urgency end
            for _,enemy in ipairs(threats) do
                local radius = options and options.runner and not enemy.activeAbility and((enemy.catchRadius or 8)+1)or enemy.radius or 10
                local clearance,eta=Core.threatApproach(position,direction*speed,enemy,.9,radius)
                if clearance<0 then
                    local weight=(enemy.activeAbility or options and options.runner)and 1 or(1-0.65*urgency)
                    score=score-(150-clearance*20)*weight
                    if enemy.activeAbility then score=score-600-math.max(0,.9-eta)*250 end
                elseif clearance<18 then
                    score=score-28*((18-clearance)/18)^2*(1-0.8*urgency)
                end
                if enemy.potentialAbility then
                    local potential={position=enemy.position,velocity=enemy.potentialVelocity,burstFor=enemy.potentialFor,
                        afterVelocity=enemy.velocity,expires=enemy.potentialFor}
                    local gap=Core.threatApproach(position,direction*speed,potential,.8,enemy.potentialRadius or enemy.catchRadius+3)
                    if gap<8 then score=score-20*math.clamp((8-gap)/16,0,2)*(1-.6*urgency)end
                end
            end
            if options and options.risk then score=score-options.risk(position+direction*speed*.4,.4)*1.5 end
            if score > bestScore then best, bestScore = direction, score end
        end
    end
    return best
end

