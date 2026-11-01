-- GENERATED executable: edit src/main.lua and its included source units; run tools/build.py.
-- Huss Valley automatic crossing and chasing. Execute directly; starts paused.
-- getgenv().HussAutoCross:Start(), :Stop(), or :Destroy().
local Core = {}
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- @include core/participants.lua
-- @include core/motion.lua
-- @include core/strategy.lua
-- @include core/speed.lua
-- @include core/threats.lua
-- @include core/tp.lua
-- @include core/abilities.lua
-- @include core/intercept.lua
-- @include core/prompts.lua
-- @include core/combat.lua
-- @include core/hazards.lua
-- @include core/runner.lua
-- @include core/routing.lua
-- @include core/profiles.lua
-- @include core/pumpkin.lua
-- @include core/reactions.lua
-- Runtime
assert(game.PlaceId == 107535308163741, 'This script is for Huss Valley')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Input = game:GetService('UserInputService')
local Http = game:GetService('HttpService')
local Collection = game:GetService('CollectionService')
local ContextActions=game:GetService('ContextActionService')
local GuiService=game:GetService('GuiService')
local VirtualInput=game:GetService('VirtualInputManager')
local VirtualUser=game:GetService('VirtualUser')
local player = Players.LocalPlayer
local package = game:GetService('ReplicatedStorage'):WaitForChild('ChickenOrHero', 10)
assert(package, 'Game is still loading; try again shortly')
local gameState = package:WaitForChild('Game', 10)
assert(gameState, 'Game state unavailable')
local session = gameState:WaitForChild('Session', 10)
assert(session, 'Session unavailable')
local boost = require(package.Movement.BoostInput)
local tackle = require(gameState.TacklePrediction)
local tackleProfile = require(gameState.TackleProfile)
local tackleConfig = require(gameState.GameConfig).Tackle
local hitReplay=require(gameState.HitReplayMath)
local tackleMotion=require(gameState.TackleMotion)
local movementProfiles = require(package.Movement.MovementProfiles)
local gearCatalog=require(package.Gear.GearCatalog)
local gearItems=gearCatalog.Items
local gearPrediction=require(package.Gear.GearPredictionClient)
local abilityRules=require(gameState.AbilityRule)
local hudNavigation=require(package.Presentation.HudNavigation)
local meleeConfig = require(gameState.ContactCatchConfig)
local knifeAbilities=require(package.Weapons.KnifeAbilities)
local combat = require(gameState.CombatPrediction)
local controlGate = require(package.Movement.ControlGate)
local participantDirectory = require(package.Presentation.ParticipantDirectory)
local env = getgenv and getgenv() or _G
if env.HussAutoCross and type(env.HussAutoCross.Destroy)=='function'then env.HussAutoCross:Destroy()end
env.HussAutoCross=nil
local startupCleanup
local function initialize()
local api = {Enabled=false, Destroyed=false, Status='Stopped', Crossings=0, Target=nil,SpeedMultiplier=1.05,SmartSpeedEnabled=true,
    TPDodgeEnabled=false,TPAssistEnabled=false,Actions={Dive=0,Melee=0,Dash=0,TPDodge=0,TPAssist=0},ActionTiming={},ActionTimeline={}}
local runner={stats={started=0,safe=0,caught=0,timeout=0,aborted=0,recent={}}}
local pumpkin={samples={},target=nil,mode=nil}
local tp={nextCheck=0}
tp.state=env.HussTPDodgeState
if type(tp.state)~='table'or tp.state.jobId~=game.JobId or tp.state.policy~=Core.TP_POLICY then
    tp.state={jobId=game.JobId,policy=Core.TP_POLICY,readyAt=0,uses=0}
    env.HussTPDodgeState=tp.state
end
local learned=env.HussSmartSpeedLimit
api.SmartCap=Core.smartLimit(learned,game.JobId)
local smartState,smartContext,smartEpoch=nil,nil,0
local nativeProfileGet=movementProfiles.get
local speedProfiles=setmetatable({},{__mode='k'})
local function speedProfileGet(role,actor)
    local native=nativeProfileGet(role,actor)
    if not api.Enabled or api.Destroyed or actor~=player then return native end
    local multiplier=Core.effectiveSpeed(api.SpeedMultiplier,api.SmartSpeedEnabled,smartState,workspace:GetServerTimeNow(),api.SmartCap)
    local variants=speedProfiles[native]
    if not variants then variants={};speedProfiles[native]=variants end
    local scaled=variants[multiplier]
    if not scaled then scaled=Core.scaleSpeedProfile(native,multiplier,true);variants[multiplier]=scaled end
    return scaled
end
local function setProfileGetter(getter)
    local readonly=isreadonly(movementProfiles)
    setreadonly(movementProfiles,false)
    movementProfiles.get=getter
    setreadonly(movementProfiles,readonly)
end
function api:SpeedReport()
    local role=player:GetAttribute('GameRole')
    local native=nativeProfileGet(role,player)
    local applied=movementProfiles.get(role,player)
    local now=workspace:GetServerTimeNow()
    local active=self.Enabled and self.SmartSpeedEnabled and smartState and smartState.untilAt>now or false
    return {role=role,normal=native.MaxSpeed,applied=applied.MaxSpeed,
        multiplier=applied.MaxSpeed/math.max(.001,native.MaxSpeed),baseMultiplier=self.SpeedMultiplier,
        smartEnabled=self.SmartSpeedEnabled,smartActive=active,smartLimit=self.SmartCap,smartSecondsLeft=active and smartState.untilAt-now or 0,
        smartDuration=.4,smartCooldown=12,
        instantAcceleration=self.Enabled and not self.Destroyed,
        acceleration=applied.Acceleration,deceleration=applied.Deceleration}
end
local connections, samples = {}, setmetatable({}, {__mode='k'})
local characterTimingConnections={}
local binding = 'HussAutoCross_'..Http:GenerateGUID(false)
local gui
startupCleanup=function()
    if type(api.Stop)=='function'then pcall(api.Stop,api)end
    api.Enabled=false;api.Destroyed=true
    if movementProfiles.get==speedProfileGet then setProfileGetter(nativeProfileGet)end
    RunService:UnbindFromRenderStep(binding)
    RunService:UnbindFromRenderStep(binding..'_Facing')
    for _,connection in ipairs(connections)do connection:Disconnect()end
    for _,connection in ipairs(characterTimingConnections)do connection:Disconnect()end
    table.clear(connections)
    if gui then gui:Destroy()end
    if env.HussAutoCross==api then env.HussAutoCross=nil end
end
local direction, ownedHumanoid = Vector3.zero, nil
local elapsed, wasActive, lastMap, target, lastRun = 1, false, nil, nil, nil
local huntTarget, activeRole
local facingHumanoid, previousAutoRotate, boostQueued
local nextMelee, nextDashRequest = 0, 0
local nextDive, pursuitHistory = 0, nil
local nextCloseDive,runnerProgress,runnerStrategy=0,nil,nil
local navigation
local actionContext,actionElapsed,combatFacing,lastActionClock=nil,0,nil,nil
local dashHistory={}
local pendingActions={}
local pendingDash,pendingDive,pendingMelee
local actorCache={}
local random=Random.new()
local choiceRequest,voteRequest={},{}
local promptElapsed=1
local armory={abilities={},loaded=false}
local nextAbilityAt,nextCombatAt=0,0
local pendingAbilities,abilityFailures,projectilePositions={},{},{}
local ownHistory={}
local anti={nextTouch=math.huge,nextKey=math.huge,nextAFK=0,nextScan=0,buttons={},touches={},idleConnections={}}
-- @include runtime/actors.lua
-- @include runtime/timing.lua
-- @include runtime/movement.lua
-- @include runtime/tp-geometry.lua
-- @include runtime/anti-afk.lua
-- @include runtime/ui.lua
-- @include runtime/lifecycle.lua
-- @include runtime/events.lua
-- @include runtime/participant-state.lua
-- @include runtime/prompts.lua
-- @include runtime/combat.lua
-- @include runtime/abilities.lua
-- @include runtime/sensing.lua
-- @include runtime/pumpkin.lua
-- @include runtime/routing.lua
-- @include runtime/planner.lua
-- @include runtime/tp-assist.lua
-- @include runtime/actions.lua
-- @include runtime/loop.lua
setProfileGetter(speedProfileGet)
env.HussAutoCross=api
return api
end
local ready,result=xpcall(initialize,function(err)return debug.traceback(tostring(err),2)end)
if not ready then
    if startupCleanup then pcall(startupCleanup)end
    error(result,0)
end
return result
