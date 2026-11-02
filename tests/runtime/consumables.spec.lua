return function(source)
 local a=assert(source:find('local function useConsumable',1,true))
 local b=assert(source:find('local function collectHazards',a,true))
 local marker=assert(source:find('assert(game.PlaceId',1,true))
 local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
 local prefix=[[
local now=100;local workspace={GetServerTimeNow=function()return now end}
local api={Enabled=true,Settings={UseConsumables=true},Actions={}}
local armory={loaded=true,equippedGear='Adrenaline',gear={Adrenaline=2}}
local character={GetAttribute=function()end}
local humanoid={Health=100,FloorMaterial=Enum.Material.Concrete}
local root={Position=Vector3.zero,AssemblyLinearVelocity=Vector3.zero,CFrame=CFrame.identity}
local attrs={GameRole='Runner',RunState='Active',InMatch=true,GearReadyAt=0}
local player={GetAttribute=function(_,k)return attrs[k]end}
local item={Kind='Item',Burst=5,Cooldown=12}
local gearCatalog={get=function()return item end,equippedForRole=function()return ''end}
local session={GetAttribute=function()return false end}
local abilityRules={blocked=function()return false end};local tackle={isActive=function()return false end}
local controlGate={reason=function()end};local abilityFailures={};local nextAbilityAt=0
local direction=Vector3.xAxis;local pendingAbilities={};local runner={consumableReadyAt={}}
local function flat(v)return v*Vector3.new(1,0,1)end
local requests=0
local gearPrediction={request=function()requests=requests+1;return 'r'..requests end}
local function actionRequest()return{}end
]]
 local test=[[
local context={finish=Vector3.xAxis*40};local enemies={{position=Vector3.xAxis*18,velocity=-Vector3.xAxis*20,catchRadius=8}}
local function use()return useConsumable(character,humanoid,root,context,enemies,{},function()return true end)end
assert(use()and requests==1,'safe approaching threat justifies one native request')
now=102;use();assert(requests==1,'pending consumable request prevents duplicate spending')
pendingAbilities={};runner.consumableReadyAt.Adrenaline=112
use();assert(requests==1,'confirmed native cooldown blocks stale replicated readiness')
now=113;assert(use()and requests==2,'cooldown expiry permits useful next charge')
return {passed=4}
]]
 local make=assert(loadstring('local Core=...\n'..prefix..source:sub(a,b-1)..test))
 return make(Core)
end
