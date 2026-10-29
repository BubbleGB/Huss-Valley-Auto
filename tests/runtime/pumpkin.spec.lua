-- Exercise the actual event planner and fast action closure in an isolated local map.
return function(source)
    local first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local probe=[[
local originals={session=session,gameState=gameState,hazards=collectHazards,ability=useAbility,tp=tp.try,boost=boost}
local fixture=Instance.new('Model');fixture.Name='HussPumpkinFixture';fixture.Parent=workspace
local floor=Instance.new('Part');floor.Anchored=true;floor.Size=Vector3.new(160,2,160)
floor.Position=Vector3.new(20000,19996,20000);floor.Parent=fixture
local field=Instance.new('Folder');field.Name='Field';field.Parent=fixture;floor.Parent=field
local character=Instance.new('Model');character.Parent=workspace
local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.new(20000,20000,20000);body.Parent=character
local human=Instance.new('Humanoid');human.Parent=character
local event=Instance.new('Folder');event:SetAttribute('AdminMatchMode','PumpkinHunt')
event:SetAttribute('RunNumber',1);event:SetAttribute('EndsAt',workspace:GetServerTimeNow()+60)
local folder=Instance.new('Folder')
local npc=Instance.new('Folder');npc.Name='Pumpkin1';npc:SetAttribute('P',body.Position+Vector3.new(0,0,15))
npc:SetAttribute('Yaw',0);npc:SetAttribute('State','Chase');npc.Parent=folder
local old=gameState
session=event
gameState=setmetatable({FindFirstChild=function(_,name)
    if name=='ActiveMap'then return {Value=fixture}end
    if name=='PumpkinPeople'then return folder end
    return old:FindFirstChild(name)
end},{__index=function(_,key)return old[key]end})
collectHazards=function()return {},''end
useAbility=function()error('event must not invoke player-combat abilities')end
tp.try=function()error('event must not use the standard TP pursuit policy')end
boost={available=function()return false end}
activeRole='Runner'
local ok,err=pcall(function()
    plan(character,human,body)
    assert(actionContext and actionContext.pumpkin,'event must plan without crossing safezones')
    assert(api.Diagnostics.mode=='PumpkinHunt'and api.Target=='Pumpkin1','event must report the NPC objective')
    assert(direction.Magnitude>.1,'a reachable pumpkin must produce movement')
    npc:SetAttribute('State','Lunge')
    checkActions(character,human,body)
    assert(api.ThreatDiagnostics.chasers==1,'fast loop must refresh replicated pumpkin states')
    assert(api.Actions.Melee==0 and api.Actions.Dive==0 and api.Actions.TPAssist==0,'event must not attack players')
    npc:SetAttribute('State','Chase');npc:SetAttribute('P',body.Position+Vector3.new(0,0,50))
    local wall=Instance.new('Part');wall.Anchored=true;wall.Size=Vector3.new(60,18,2)
    wall.Position=body.Position+Vector3.new(0,0,20);wall.Parent=fixture
    plan(character,human,body)
    assert(actionContext and actionContext.pumpkin,'a pumpkin behind a detour must remain a navigation objective')
    assert(api.Diagnostics.goal.Z>body.Position.Z+25,'blocked direct approaches must choose a destination beyond the wall')
    assert(navigation and navigation.path and #navigation.path>1,'blocked direct approaches must use a real detour route')
    npc:SetAttribute('State','Broken')
    plan(character,human,body)
    assert(not ownedHumanoid and api.Target==nil and direction.Magnitude==0,'all broken pumpkins must release movement')
    assert(next(pumpkin.samples)~=nil,'live records should be observed')
    npc:Destroy();pumpkin.threats()
    assert(next(pumpkin.samples)==nil,'removed records must not retain stale motion')
end)
release();session,gameState=originals.session,originals.gameState
collectHazards,useAbility,tp.try,boost=originals.hazards,originals.ability,originals.tp,originals.boost
fixture:Destroy();character:Destroy();folder:Destroy();event:Destroy()
activeRole=nil;lastMap,lastRun=nil,nil;api.Diagnostics,api.ThreatDiagnostics,api.Target=nil,nil,nil
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    a:Destroy()
    return {eventPlanner='passed',freshLunge='passed',noPlayerCombat='passed',removedNPCs='passed',cleanup='passed'}
end
