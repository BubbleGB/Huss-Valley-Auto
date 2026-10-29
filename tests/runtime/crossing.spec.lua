-- Real planner/action/statistics closures; local geometry and native dash preview,
-- with external combat/dash dispatch replaced to avoid affecting live opponents.
return function(source)
 local first,last=assert(source:find('env.HussAutoCross=api',1,true))
 local probe=[[
local original={player=player,session=session,state=gameState,threats=threats,hazards=collectHazards,
    participants=participants,ability=useAbility,tp=tp.try,boost=boost,choose=Core.choose}
local fixture=Instance.new('Model');fixture.Name='HussCrossingFixture';fixture.Parent=workspace
local field=Instance.new('Folder');field.Name='Field';field.Parent=fixture
local origin=Vector3.new(20000,20000,20000)
local floor=Instance.new('Part');floor.Anchored=true;floor.Size=Vector3.new(180,2,180);floor.Position=origin-Vector3.new(0,4,0);floor.Parent=field
for _,side in ipairs({'A','B'})do
    local part=Instance.new('Part');part.Name='Safezone'..side..'Side';part.Anchored=true;part.CanCollide=false
    part.Size=Vector3.new(12,2,120);part.Position=origin+Vector3.new(side=='A'and -72 or 72,-3,0);part.Parent=field
end
local character=Instance.new('Model');character.Parent=workspace
local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=origin;body.Parent=character
local human=Instance.new('Humanoid');human.Parent=character
local event=Instance.new('Folder');event:SetAttribute('RunNumber',1);event:SetAttribute('StartSide','A')
event:SetAttribute('EndsAt',workspace:GetServerTimeNow()+30)
local attrs={InMatch=true,GameRole='Runner',RunState='Active'}
player=setmetatable({Character=character,UserId=original.player.UserId,GetAttribute=function(_,key)return attrs[key]end},
    {__index=function(_,key)return original.player[key]end})
session=event
local old=gameState
gameState=setmetatable({FindFirstChild=function(_,name)if name=='ActiveMap'then return {Value=fixture}end return old:FindFirstChild(name)end},
    {__index=function(_,key)return old[key]end})
local enemies={{position=origin+Vector3.new(18,0,20),velocity=Vector3.new(0,0,-40),radius=25,catchRadius=5,
    forward=-Vector3.xAxis,diveReadyIn=2,diveDistance=15,diveHalfWidth=4}}
threats=function()return enemies end;collectHazards=function()return {},''end;participants=function()return {}end
useAbility=function()return false end;tp.try=function()return false end
local requests=0;boost={available=function()return true end,request=function()requests=requests+1 end,clear=function()end}
activeRole='Runner'
local ok,err=pcall(function()
    plan(character,human,body)
    assert(actionContext and actionContext.timedRunner and api.Diagnostics.arrivalRouting,'ordinary runner must use arrival-time routing')
    assert(navigation.path,'runner must find a path in a supported field')
    local previous,elapsed=origin,0
    for i=2,#navigation.path do
        local nextAt=elapsed+(navigation.path[i]-previous).Magnitude/api.Diagnostics.maxSpeed
        assert(Core.runnerEdge(previous,navigation.path[i],elapsed,nextAt,enemies),'runtime planned edges must retain predicted clearance')
        previous,elapsed=navigation.path[i],nextAt
    end
    local oldPath={origin,origin+Vector3.new(20,0,5),origin+Vector3.new(40,0,0)}
    navigation={map=fixture,key='lane',signature='old',path=oldPath,index=2,requested=oldPath[3],nextAt=0,status='planned'}
    routeWaypoint(origin,{oldPath[3]},function()return true end,function()return 0 end,fixture,'lane','new',false,{speed=36})
    assert(navigation.retained and navigation.path==oldPath,'minor route changes must retain a viable lane')
    navigation.nextAt=0;navigation.index=2
    routeWaypoint(origin,{oldPath[3]},function(_,b)return b.Z<=origin.Z+1 end,function()return 0 end,fixture,'lane','blocked',false,{speed=36})
    assert(not navigation.retained and navigation.path~=oldPath,'unsafe old lanes must be abandoned immediately')
    enemies={};navigation=nil;plan(character,human,body)
    body.AssemblyLinearVelocity=Vector3.xAxis*30
    character:SetAttribute('DashReady',true);character:SetAttribute('DashCooldownUntil',0)
    direction=Vector3.xAxis;dashHistory={{direction=Vector3.zAxis,at=os.clock()-.01}}
    checkActions(character,human,body)
    assert(requests==0 and api.DashDecision=='save dash','runtime must not waste dash on clear low-benefit ground')
    enemies={{position=origin+Vector3.new(15,0,15),velocity=Vector3.new(0,0,-30),radius=9,catchRadius=5,hardRadius=6,activeAbility=true}}
    direction=Vector3.new(1,0,1).Unit;dashHistory={{direction=Vector3.xAxis,at=os.clock()-.01}}
    actionContext.at=os.clock();actionContext.waypoint=origin+direction*60
    Core.choose=function()return Vector3.new(1,0,1).Unit end
    checkActions(character,human,body)
    assert(requests==1 and api.DashDecision=='escape','runtime must dispatch a native-preview dash that improves an incoming attack escape')
    Core.choose=original.choose
    api.Enabled=true;runner.observe(character,human,body);runner.observe(character,human,body)
    assert(api:CrossingReport().started==1,'active frames must start exactly one tracked crossing')
    attrs.RunState='Safe';runner.observe(character,human,body);runner.observe(character,human,body)
    assert(api:CrossingReport().safe==1 and api.Crossings==1,'Safe must be counted once in both public counters')
    attrs.RunState='Active';runner.observe(character,human,body)
    api.Enabled=false;runner.observe(character,human,body)
    local report=api:CrossingReport()
    assert(report.interrupted==1 and report.resolved==1 and report.successRate==1,'manual stop must not lower the measured success rate')
end)
api.Enabled=false;release()
player,session,gameState=original.player,original.session,original.state
threats,collectHazards,participants,useAbility,tp.try,boost,Core.choose=original.threats,original.hazards,original.participants,original.ability,original.tp,original.boost,original.choose
fixture:Destroy();character:Destroy();event:Destroy()
runner.stats={started=0,safe=0,caught=0,timeout=0,aborted=0,recent={}}
api.Crossings=0;api.Actions.Dash=0;table.clear(pendingActions);table.clear(api.ActionTimeline);table.clear(api.ActionTiming)
api.Diagnostics,api.ThreatDiagnostics,api.DashDecision=nil,nil,nil;activeRole=nil;lastMap,lastRun=nil,nil
assert(ok,err)
env.HussAutoCross=api
]]
 local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
 assert(a:CrossingReport().started==0,'fixture must not leave fake crossing records')
 a:Destroy()
 return {arrivalRouting='passed',laneRetention='passed',dashReserve='passed',dashEscape='passed',outcomes='passed',cleanup='passed'}
end
