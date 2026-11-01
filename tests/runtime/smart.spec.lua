return function(source)
    local marker='env.HussAutoCross=api'
    local first,last=assert(source:find(marker,1,true))
    local probe=[[
local now=workspace:GetServerTimeNow()
local savedCap=api.SmartCap
api.SmartCap=1.10
smartState=Core.smartSpeedStep(nil,now,true,true,5,smartEpoch)
release(true)
assert(smartState.untilAt>now,'changing targets must not prematurely cancel an active burst')
api.Enabled=true
local normal=nativeProfileGet('Runner',player).MaxSpeed
assert(math.abs(movementProfiles.get('Runner',player).MaxSpeed/normal-1.10)<1e-8,'runtime getter must apply the active short-burst cap')
api.SmartCap=1.05
assert(math.abs(movementProfiles.get('Runner',player).MaxSpeed/normal-math.max(api.SpeedMultiplier,1.05))<1e-8,'learned limit must select the matching cached runtime profile')
smartState.untilAt=now-.1
assert(math.abs(movementProfiles.get('Runner',player).MaxSpeed/normal-api.SpeedMultiplier)<1e-8,'expired bursts must not leave a stale cached speed')
smartState=Core.smartSpeedStep(nil,now,true,true,5,smartEpoch)
api:SetSmartSpeedEnabled(false)
assert(smartState.untilAt==0,'toggle off must clear runtime burst state')
api:SetSmartSpeedEnabled(true)
smartState=Core.smartSpeedStep(nil,now,true,true,5,smartEpoch)
release()
assert(smartState.untilAt==0,'own movement suspension must cancel a burst')
local originalGate,originalRole=controlGate,activeRole
local originalLearned,originalCorrections=env.HussSmartSpeedLimit,api.SmartCorrections
local fixture=Instance.new('Model')
local detected,problem=pcall(function()
    controlGate={reason=function()return nil end};activeRole='Runner'
    fixture:SetAttribute('MovementReset',2)
    smartContext={character=fixture,round=session:GetAttribute('RunNumber'),role=activeRole,
        phase=session:GetAttribute('Phase'),reset=1}
    smartState=Core.smartSpeedStep(nil,now-1,true,true,5,smartEpoch)
    api.SmartCap=1.10
    updateSmartSpeed(fixture,{FloorMaterial=Enum.Material.Air},
        {Position=Vector3.new(100000,0,100000),CollisionGroup='Default'})
    assert(api.SmartCap==1.05 and smartState.readyAt>=now+15,
        'a delayed reset while airborne must still trigger fallback and backoff')
    assert(env.HussSmartSpeedLimit.policy==Core.SMART_POLICY,'fallback must be saved under the short-burst policy')
end)
controlGate=originalGate;activeRole=originalRole
env.HussSmartSpeedLimit=originalLearned;api.SmartCorrections=originalCorrections
fixture:Destroy()
assert(detected,problem)
api.Enabled=false;smartState=nil;smartContext=nil;api.SmartCap=savedCap
api.SmartUntilAt=0;api.SmartReadyAt=0;api.SmartWatchUntil=0
env.HussAutoCross=api
]]
    local instrumented=source:sub(1,first-1)..probe..source:sub(last+1)
    local a=assert(loadstring(instrumented))()
    local p=game.Players.LocalPlayer
    assert(a.SmartSpeedEnabled,'smart speed must default ON')
    a:SetSmartSpeedEnabled(false)
    assert(not a.SmartSpeedEnabled,'API toggle must disable smart speed')
    a:SetSetting('AutoRun',false);a:SetSetting('AutoChase',false)
    a:Start()
    local profiles=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles)
    local model=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementModel)
    local checks=0
    for _,role in ipairs({'Runner','Catcher'})do
        local profile=profiles.get(role,p)
        local state=model.new()
        model.step(state,Vector3.zAxis,0,1/60,profile,true,Vector3.zero,1,false,Vector3.zero,false)
        assert(math.abs(state.outputSpeed-profile.MaxSpeed)<.001,'native '..role..' model must reach its cap on the first movement frame')
        model.step(state,Vector3.xAxis,profile.MaxSpeed,1/60,profile,true,Vector3.zero,1,false,Vector3.zAxis*profile.MaxSpeed,false)
        assert(math.abs(state.outputSpeed-profile.MaxSpeed)<.001,'turning must not reintroduce a speed ramp')
        checks=checks+2
    end
    assert(a:SpeedReport().instantAcceleration and not a:SpeedReport().smartActive,'disabled smart mode must leave instant ordinary movement available')
    a:Stop()
    a:SetSmartSpeedEnabled(true)
    assert(a.SmartSpeedEnabled,'API toggle must turn smart mode back on')
    a:Stop()
    local report=a:SpeedReport()
    assert(report.multiplier==1 and not report.instantAcceleration and not report.smartActive,'Stop must restore native movement and cancel smart bursts')
    a:SetSmartSpeedEnabled(false)
    assert(not a.SmartSpeedEnabled and not a.Enabled,'changing smart mode while paused must not start movement')
    a:SetSmartSpeedEnabled(true)
    return {toggle='passed',nativeFirstFrameChecks=checks,turnSpeed='passed',stopRestoration='passed',
        runtimeBurstCache='passed',retargetRetention='passed',delayedAirborneReset='passed'}
end
