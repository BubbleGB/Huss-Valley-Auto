-- Exercise actual fast checks and lifecycle closures without sending native actions.
return function(source)
    local first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local probe=[[
assert(type(runner.capture)=='function','crossing evidence capture is missing')
local original={player=player,session=session,gameState=gameState,threats=threats,hazards=collectHazards,
    ability=useAbility,tp=tp.try,boost=boost}
local fixture=Instance.new('Model');fixture.Name='HussReactionFixture';fixture.Parent=workspace
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Anchored=true;root.Position=Vector3.new(20000,20000,20000);root.Parent=fixture
local human=Instance.new('Humanoid');human.Parent=fixture
local event=Instance.new('Folder');event:SetAttribute('RunNumber',1);event:SetAttribute('EndsAt',workspace:GetServerTimeNow()+30)
local attrs={InMatch=true,GameRole='Runner',RunState='Active'}
player=setmetatable({Character=fixture,UserId=original.player.UserId,GetAttribute=function(_,key)return attrs[key]end},
    {__index=function(_,key)return original.player[key]end})
session=event
local state=original.gameState
gameState=setmetatable({FindFirstChild=function(_,name)if name=='ActiveMap'then return {Value=fixture}end return state:FindFirstChild(name)end},
    {__index=function(_,key)return state[key]end})
activeRole='Runner';api.Enabled=true
local actor={UserId=123}
local quiet={actor=actor,position=root.Position+Vector3.xAxis*30,velocity=Vector3.zero,radius=8,catchRadius=5}
local attack=table.clone(quiet);attack.kind='Dive';attack.activeAbility=true;attack.velocity=-Vector3.xAxis*40
local nearby={attack};local hazards={}
threats=function()return nearby end;collectHazards=function()return hazards,''end
useAbility=function()return false end;tp.try=function()return false end;boost={available=function()return false end,clear=function()end}
local ok,err=pcall(function()
    runner.observe(fixture,human,root)
    actionContext={character=fixture,role='Runner',at=os.clock(),nearby={quiet},hazards={},finish=root.Position+Vector3.zAxis*100,
        waypoint=root.Position+Vector3.zAxis*100,policy={urgency=0},lookahead=12,geometryAllowed=function()return true end}
    direction=Vector3.zAxis
    root.Parent:SetAttribute('DashReady',true);root.Parent:SetAttribute('DashCooldownUntil',0)
    api.DashDecision='previous crossing'
    checkActions(fixture,human,root)
    assert(runner.stats.attempt.history[1].dashReady==false,'recorded dash readiness must include native availability')
    assert(runner.stats.attempt.history[1].dashDecision~='previous crossing','new checks must not record a stale dash decision')
    assert(runner.replanReason=='ability','fresh nearby attack must queue full route refresh')
    assert(Core.planDue(.034,runner.replanReason),'queued attack must refresh before 100 ms')
    runner.replanReason=nil;actionContext.nearby=nearby;actionContext.at=os.clock()
    checkActions(fixture,human,root)
    assert(not runner.replanReason,'unchanged attack must not repeatedly refresh')
    hazards={{source=fixture,kind='BearTrap',position=root.Position+Vector3.xAxis*12,radius=4}}
    actionContext.at=os.clock();checkActions(fixture,human,root)
    assert(runner.replanReason=='hazard','new nearby trap must queue full route refresh')
    runner.replanReason=nil;actionContext.hazards=hazards;actionContext.at=os.clock()
    actionContext.geometryAllowed=function()return false end;direction=Vector3.zAxis
    checkActions(fixture,human,root)
    assert(runner.replanReason=='blocked','blocked current heading must queue a new route')
    local attempt=runner.stats.attempt
    attempt.history={};attempt.lastSampleAt=nil
    local base=os.clock()-3
    for i=1,30 do runner.capture(fixture,root,nearby,hazards,base+i*.101)end
    assert(#attempt.history==20,'history must stay bounded to 20 observations')
    local count=#attempt.history;runner.capture(fixture,root,nearby,hazards,base+30*.101+.01)
    assert(#attempt.history==count,'history must sample at most ten times per second')
    attrs.RunState='Caught';runner.observe(fixture,human,root)
    local report=api:CrossingReport();local record=report.recent[#report.recent]
    assert(report.caught==1 and #record.evidence.history==20,'catch must retain recent observations')
    assert(record.evidence.history[20].nearby[1].kind=='Dive','catch evidence must retain the observed ability')
    assert(record.evidence.fresh and record.evidence.history[20].dashReady==false,'catch evidence must include fresh dash readiness')
    record.evidence.history[20].nearby[1].kind='mutated'
    assert(api:CrossingReport().recent[1].evidence.history[20].nearby[1].kind=='Dive','report callers must not mutate nested evidence')
    attrs.RunState='Active';runner.observe(fixture,human,root)
    assert(not runner.stats.attempt.history or #runner.stats.attempt.history==0,'new crossing must not inherit earlier observations')
    runner.capture(fixture,root,nearby,hazards,os.clock()-2)
    attrs.RunState='Caught';runner.observe(fixture,human,root)
    assert(not api:CrossingReport().recent[2].evidence.fresh,'old observations must be marked stale')
    api:Stop();assert(not runner.replanReason,'stopping must clear queued replans')
end)
api.Enabled=false;release()
player,session,gameState=original.player,original.session,original.gameState
threats,collectHazards,useAbility,tp.try,boost=original.threats,original.hazards,original.ability,original.tp,original.boost
fixture:Destroy();event:Destroy()
runner.stats={started=0,safe=0,caught=0,timeout=0,aborted=0,recent={}}
api.Crossings=0;activeRole=nil;api.Diagnostics=nil;api.ThreatDiagnostics=nil
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    a:Destroy()
    return {reactiveRefresh='passed',boundedEvidence='passed',reportIsolation='passed',staleEvidence='passed',cleanup='passed'}
end
