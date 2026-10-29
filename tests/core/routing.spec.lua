return function(Core)
    local count=0
    local function check(ok,message) assert(ok,message);count=count+1 end
    local start,goal=Vector3.zero,Vector3.new(48,0,0)
    local trap={position=Vector3.new(24,0,0),radius=6}
    check(not Core.clearSegment(start,goal,{trap}), 'must reject a segment crossing a noncolliding trap')
    check(Core.clearSegment(start,Vector3.new(48,0,20),{trap}), 'must allow a detour clear of a trap')
    check(Core.clearSegment(Vector3.new(24,0,0),Vector3.new(24,0,10),{trap}), 'must allow escaping a newly placed trap')
    check(not Core.clearSegment(Vector3.new(28,0,0),Vector3.new(24,0,0),{trap}), 'must not run deeper into a hazard')
    check(Core.chaserRadius(15,6.5,0,false)>24, 'ready chaser clearance must include dive travel and catch reach')
    check(Core.chaserRadius(15,6.5,2,false)<Core.chaserRadius(15,6.5,0,false), 'cooling chaser should not impose a ready dive buffer')
    check(Core.chaserRadius(15,6.5,2,true)>24, 'active dive must keep full danger clearance')
    local function allowed(a,b)
        return math.abs(b.X)<80 and math.abs(b.Z)<40 and Core.clearSegment(a,b,{trap})
    end
    local path=Core.route(start,{goal},8,allowed,function()return 0 end,400)
    check(path and #path>=3, 'route must detour around the trap')
    for i=2,#path do check(allowed(path[i-1],path[i]), 'every route edge must stay outside trap range') end
    check((path[#path]-goal).Magnitude<0.1, 'route must reach its finish')
    local wall={position=Vector3.new(24,0,0),radius=12}
    path=Core.route(start,{goal},8,function(a,b)
        return math.abs(b.X)<80 and math.abs(b.Z)<40 and Core.clearSegment(a,b,{wall})
    end,function()return 0 end,400)
    check(path and #path>=3, 'must plan around a physical obstacle instead of steering into a dead end')
    path=Core.route(start,{goal},8,function()return false end,function()return 0 end,20)
    check(path==nil, 'must report no route when movement is blocked')
    local alternate=Vector3.new(48,0,24)
    path=Core.route(start,{goal,alternate},8,function(a,b)
        return math.abs(b.X)<80 and math.abs(b.Z)<40 and (b-goal).Magnitude>12
    end,function()return 0 end,400)
    check(path and (path[#path]-alternate).Magnitude<0.1, 'must use another finish point when nearest finish is unsafe')
    path=Core.route(start,{goal},8,function(a,b)return math.abs(b.X)<80 and math.abs(b.Z)<40 end,
        function(p)return math.abs(p.Z)<7 and p.X>8 and p.X<40 and 50 or 0 end,400)
    local detoured=false
    if path then for _,p in ipairs(path)do if math.abs(p.Z)>=7 then detoured=true end end end
    check(detoured, 'must prefer a short safer route over a dangerous direct route')
    local safePath={start,Vector3.new(8,0,16),Vector3.new(40,0,16),goal}
    local function crossingRisk(p)return p.X>8 and p.X<40 and math.abs(p.Z)<7 and 50 or 0 end
    local index=Core.smoothWaypoint(start,safePath,2,function()return true end,crossingRisk)
    check(index<4, 'smoothing must not erase a safer detour by cutting through high-risk ground')
    local part=Instance.new('Part')
    part.Name='BearTrapArmed'
    part.CanCollide=false
    part.CFrame=CFrame.new(24,0,0)
    part:SetAttribute('GearVisualKind','BearTrap')
    part:SetAttribute('GearSpawnedAt',10)
    part:SetAttribute('GearDuration',12.9)
    local items={BearTrap={TriggerRadius=2},SpringBox={BurstRadius=12}}
    local snapshot=Core.hazardSnapshot(part,'Runner',items,15)
    check(snapshot and snapshot.radius>=5.5, 'noncolliding bear trap must include body and safety clearance')
    check(not Core.clearSegment(start,goal,{snapshot}), 'recognized bear trap must block crossing through its trigger')
    check(Core.hazardSnapshot(part,'Catcher',items,15)==nil, 'runner-only traps must not block chasers')
    check(Core.hazardSnapshot(part,'Runner',items,30)==nil, 'expired trap must not leave a phantom obstacle')
    part:SetAttribute('GearVisualKind','SpringBox')
    snapshot=Core.hazardSnapshot(part,'Runner',items,15)
    check(snapshot and snapshot.radius>=15, 'spring box must use blast radius rather than visual size')
    part:Destroy()
    local grave=Instance.new('Model')
    part=Instance.new('Part')
    part.Size=Vector3.new(18,8,18)
    part.Parent=grave
    snapshot=Core.hazardSnapshot(grave,'Runner',items,15,'GraveRise')
    check(snapshot and snapshot.radius>14, 'model graves must use actual bounds instead of a small fixed footprint')
    grave:Destroy()
    return {passed=count}
end
