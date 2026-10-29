-- Exercises the actual fast runner decision closure without sending action remotes.
return function(source)
    local marker='env.HussAutoCross=api'
    local first,last=assert(source:find(marker,1,true))
    local probe=[[
local fixture=Instance.new('Model')
local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Position=Vector3.zero;body.Parent=fixture
local human=Instance.new('Humanoid');human.Parent=fixture
local oldThreats,oldHazards,oldAbility=threats,collectHazards,useAbility
local oldRole=activeRole
local incoming
local rocket={position=Vector3.new(30,0,0),velocity=Vector3.new(-64,0,0),radius=10,catchRadius=8,
    hardRadius=10,activeAbility=true,burstFor=.42,afterVelocity=Vector3.new(-35,0,0)}
threats=function()return {rocket}end
collectHazards=function()return {}end
useAbility=function(_,_,_,_,_,nearby)incoming=nearby;return false end
activeRole='Runner';direction=Vector3.xAxis
actionContext={character=fixture,role='Runner',at=os.clock(),finish=Vector3.new(100,0,0),
    nearby={},hazards={},policy={urgency=1},lookahead=12,
    geometryAllowed=function(_,b)return b.Z>=.2 end}
checkActions(fixture,human,body)
assert(direction.Z>.1,'fast runner checks must evade a newly active rocket using current threat data')
assert(incoming and incoming[1]==rocket,'fresh threats must also reach defensive ability timing')
assert(api.ThreatDiagnostics.chasers==1 and(api.EvasiveAdjustments or 0)>0,'evasion diagnostics must reflect the actual fast decision')
local harmless={position=Vector3.new(60,0,0),velocity=Vector3.new(35,0,0),radius=24.5,catchRadius=8,
    potentialAbility='UnknownGear',potentialVelocity=Vector3.new(64,0,0),potentialFor=.42}
threats=function()return {harmless}end
actionContext.at=os.clock();actionContext.waypoint=Vector3.new(0,0,30)
actionContext.geometryAllowed=function()return true end
direction=Vector3.zAxis
checkActions(fixture,human,body)
assert(direction.Z>.7,'a harmless ready ability must not overwrite the route detour with a direct-to-finish heading')
threats,collectHazards,useAbility=oldThreats,oldHazards,oldAbility
activeRole=oldRole;release();fixture:Destroy()
api.EvasiveAdjustments,api.ThreatDiagnostics,api.ActionChecks,api.MaxActionCheckGapMS=nil,nil,nil,nil
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    assert(not a.Enabled and not a.ThreatDiagnostics,'runtime fixture must leave no fake live telemetry')
    a:Destroy()
    return {freshThreats='passed',perpendicularEscape='passed',obstacles='passed',defensiveTiming='passed',cleanup='passed'}
end
