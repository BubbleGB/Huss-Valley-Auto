-- Exercises the actual action closure with an isolated body and a stubbed native
-- request: no player movement, attack remotes or fake live telemetry survives.
return function(source)
    local marker='env.HussAutoCross=api'
    local first,last=assert(source:find(marker,1,true))
    local probe=[[
local fixture=Instance.new('Model');fixture.Name='HussDiveFixture';fixture.Parent=workspace
local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.new(20000,100,20000)
body.CFrame=CFrame.lookAt(body.Position,body.Position+Vector3.zAxis);body.Parent=fixture
body.AssemblyLinearVelocity=Vector3.new(0,0,33)
local victim=Instance.new('Model');victim.Name='DiveRunner';victim.Parent=fixture
local runner={Name='DiveRunner',UserId=-999,Character=victim,GetAttribute=function()return nil end}
local pursuit={id=-999,player=runner,position=body.Position+Vector3.new(0,0,9),
    velocity=Vector3.new(0,0,35),acceleration=Vector3.zero}
local oldTackle,oldCombat,oldGate,oldSession,oldRunner=tackle,combat,controlGate,session,activeRunner
local oldHistory,oldDive,oldClose,oldMelee=pursuitHistory,nextDive,nextCloseDive,nextMelee
local requests=0
tackle=table.clone(tackle);tackle.remaining=function()return 0 end;tackle.isActive=function()return false end
tackle.request=function()requests=requests+1;fixture:SetAttribute('TacklePredictionId','fixture-dive');return true end
combat=table.clone(combat);combat.meleeRemaining=function()return 0 end
controlGate=table.clone(controlGate);controlGate.reason=function()return nil end
session={GetAttribute=function()return nil end}
activeRunner=function(actor)return actor==runner end
pursuitHistory={id=-999,stableSince=os.clock()-.5,directionSince=os.clock()-.5}
local h={FloorMaterial=Enum.Material.Concrete,AutoRotate=true}
local ok,err=pcall(function()
    nextDive,nextCloseDive,nextMelee=0,0,0
    assert(useCombat(fixture,h,body,pursuit,function()return true end)and requests==1,
        'runtime must dispatch a reachable predicted dive beyond the old cap')
    assert(api.LastDiveStyle=='predicted'and pendingDive.predictedContact<=.3,'runtime must record the native predicted contact')
    local now=workspace:GetServerTimeNow()
    assert(nextDive>now and nextDive<now+2 and nextCloseDive==nextDive,'runtime must use native-based repeat spacing')
    useCombat(fixture,h,body,pursuit,function()return true end)
    assert(requests==1,'added repeat spacing must still prevent an immediate second request')
    nextDive,nextCloseDive=0,0
    useCombat(fixture,h,body,pursuit,function()return false end)
    assert(requests==1,'blocked full-travel path must suppress the request')
    local originalAction=Core.combatAction
    Core.combatAction=function()return 'Dive',Vector3.zAxis,'close',nil end
    useCombat(fixture,h,body,pursuit,function()return true end)
    Core.combatAction=originalAction
    assert(requests==1,'dispatch must fail closed if a dive decision has no predicted catch time')
    victim:SetAttribute('HitShielded',true)
    useCombat(fixture,h,body,pursuit,function()return true end)
    assert(requests==1,'shield must suppress the request in the actual runtime closure')
end)
tackle,combat,controlGate,session,activeRunner=oldTackle,oldCombat,oldGate,oldSession,oldRunner
pursuitHistory,nextDive,nextCloseDive,nextMelee=oldHistory,oldDive,oldClose,oldMelee
pendingDive=nil;table.clear(pendingActions);table.clear(api.ActionTiming);table.clear(api.ActionTimeline)
api.Actions.Dive=0;api.LastAction=nil;api.LastDiveStyle=nil
release();fixture:Destroy()
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    assert(not a.Enabled and next(a.ActionTiming)==nil,'isolated dive tests must leave no fake observations')
    a:Destroy()
    return {dispatch='passed',spacing='passed',obstacles='passed',shields='passed',cleanup='passed'}
end
