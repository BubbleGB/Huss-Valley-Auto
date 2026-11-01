-- Evaluate only owned runtime closures; never initialize the controller or fire native remotes.
return function(source)
    local sources=type(source)=='table'and source or {
        settings=assert(source:match('(local settingDefaults.-)function Core.priorityRank'),'settings closure missing'),
        movement=assert(source:match('(local function release.-)function tp.epoch'),'release closure missing'),
        abilities=assert(source:match('(local function useAbility.-)local function collectHazards'),'ability closure missing'),
        combat=assert(source:match('(local function faceToward.-)local function useAbility'),'combat closures missing'),
    }
    local prefix=[[
local workspace=workspace
local activeRunner,controlGate,session,nextCombatAt,nextMelee,nextDive,nextCloseDive,movementProfiles,tackleConfig,tackleProfile,meleeConfig,combat,hitReplay,tackleMotion,tackle,Http,actionRequest,predicted,pursuitHistory,pendingDive,pendingMelee
local player,activeRole,armory,gearCatalog,abilityFailures,abilityRules,nextAbilityAt,ownHistory,gearItems,gearPrediction,pendingAbilities,timingSample,nextCombatAt,gameState
local Core={}; local api={Enabled=true,Actions={Dive=0,Melee=0},Settings={}}
local facingHumanoid,previousAutoRotate,ownedHumanoid,combatFacing
local direction=Vector3.zero;local actionContext,actionElapsed,dashHistory=nil,0,{}
local runner={};local smartState;local lastActionClock,pendingDash,boostQueued,navigation,runnerProgress,runnerStrategy
local function flat(v)return Vector3.new(v.X,0,v.Z)end
]]
    local face=sources.combat:match('(local function faceToward.-)local function faceTarget')
    local combat=sources.combat:match('(local function useCombat.*)')
    local fixture=[[
local model=Instance.new('Model')
local root=Instance.new('Part');root.Anchored=false;root.CFrame=CFrame.new(10000,200,10000);root.Parent=model
local h={AutoRotate=true,Sit=false,PlatformStand=false,FloorMaterial=Enum.Material.Concrete,Parent=model}
local camera=workspace.CurrentCamera;local savedCF,savedFocus=camera.CFrame,camera.Focus
local original=root.CFrame
local function sameCamera()assert(camera.CFrame==savedCF and camera.Focus==savedFocus,'camera ownership leaked')end
local passed=0;local function check(ok,message)assert(ok,message);passed=passed+1 end
local ok,err=pcall(function()
 api.Settings=Core.defaultSettings()
 check(not api.Settings.FollowCamera and not api.Settings.AutoFaceTarget,'camera and body facing must default off')
 faceToward(model,h,root,Vector3.xAxis,true)
 check(root.CFrame==original and h.AutoRotate,'ordinary chase changed body orientation/AutoRotate');sameCamera()
 api.Settings.AutoFaceTarget=true
 faceToward(model,h,root,Vector3.xAxis,false)
 check(root.CFrame.LookVector:Dot(Vector3.xAxis)>.99 and not h.AutoRotate,'explicit body facing must work');sameCamera()
 ownedHumanoid=nil;release()
 check(h.AutoRotate and facingHumanoid==nil,'Stop must restore ownership')
 api.Settings.AutoFaceTarget=false;root.CFrame=original
 -- A fixture camera allows camera opt-in without taking ownership of the live camera.
 local fakeCamera=Instance.new('Camera');fakeCamera.CameraType=Enum.CameraType.Custom;fakeCamera.CFrame=savedCF;fakeCamera.Focus=savedFocus
 local fakeHumanoid=Instance.new('Humanoid');fakeCamera.CameraSubject=fakeHumanoid
 local oldWorkspace=workspace
 workspace={CurrentCamera=fakeCamera}
 api.Settings.FollowCamera=true
 faceToward(model,fakeHumanoid,root,Vector3.xAxis,true)
 check(fakeCamera.CFrame~=savedCF and root.CFrame==original and fakeHumanoid.AutoRotate,'camera opt-in must be independent')
 workspace=oldWorkspace;fakeCamera:Destroy();fakeHumanoid:Destroy();sameCamera()
 api.Settings=Core.defaultSettings()
 player={Character=model,GetAttribute=function()end}
 local runnerPlayer={Character=model}
 activeRunner=function()return true end
 controlGate={reason=function()end};session={GetAttribute=function()end}
 nextCombatAt,nextMelee,nextDive,nextCloseDive=0,0,0,0
 movementProfiles={get=function()return {MaxSpeed=33}end}
 tackleConfig={};tackleProfile={select=function()return {Distance=12,Duration=.3,Reach=4,Recovery=.5}end}
 meleeConfig={Windup=.1,ActiveDuration=.1,Recovery=.1,CommitDistance=7,Enabled=true}
 combat={meleeRemaining=function()return 0 end,meleeBox=function()return {}end}
 hitReplay={bounds=function()return {}end};tackleMotion={distance=function()return 0 end}
 Core.combatReady=function()return true end;Core.abilityState=function()return {}end
 Core.combatAction=function()return 'Dive',Vector3.xAxis,'predicted',.2 end;Core.diveRetry=function()return 1 end
 local requests=0
 tackle={remaining=function()return 0 end,isActive=function()return false end,request=function()
 requests=requests+1;check(root.CFrame.LookVector:Dot(Vector3.xAxis)>.99,'native Dive needs facing before request')
 check(root.Position==original.Position and h.AutoRotate,'Dive must not translate or own AutoRotate');sameCamera();return true end}
 Http={GenerateGUID=function()return 'fixture' end};actionRequest=function()return {}end;predicted=function()end
 api.ActionTiming={};api.Settings.AutoDive=true;api.Settings.AutoMelee=false
 local result=useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},function()return true end)
 check(result and requests==1,'native Dive must dispatch');release()
 check(h.AutoRotate and facingHumanoid==nil,'Dive must not leak ownership')
 api.Settings.AutoFaceTarget=true;faceToward(model,h,root,Vector3.zAxis,false)
 nextDive,nextCloseDive=0,0
 useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},function()return true end)
 check(facingHumanoid==nil and h.AutoRotate,'Dive must hand native AutoRotate its original value even after opt-in chasing')
 api.Settings.AutoFaceTarget=false
 root.CFrame=original;nextDive,nextCloseDive=0,0
 tackle.request=function()
  root.CFrame=root.CFrame+Vector3.new(2,0,0)
  return false
 end
 local rejected=useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},function()return true end)
 check(not rejected and root.CFrame.Rotation==original.Rotation,'rejected Dive must restore prior rotation')
 check(root.Position==original.Position+Vector3.new(2,0,0),'rejected Dive must preserve any native position change')
 check(h.AutoRotate and facingHumanoid==nil,'rejected Dive must not leak AutoRotate ownership');sameCamera()
 root.CFrame=original;nextDive,nextCloseDive=0,0
 tackle.request=function()model:SetAttribute('TackleActive',true);return false end
 useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},function()return true end)
 check(root.CFrame.LookVector:Dot(Vector3.xAxis)>.99,'failed dispatch must not undo a native action that started')
 model:SetAttribute('TackleActive',nil)
 root.CFrame=original;nextDive,nextCloseDive=0,0
 tackle.request=function()player.Character=nil;return false end
 useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},function()return true end)
 check(root.CFrame.LookVector:Dot(Vector3.xAxis)>.99,'failed dispatch must not mutate a replaced character')
 player.Character=model
 root.CFrame=original;nextCombatAt,nextMelee=0,0
 Core.combatAction=function()return 'Melee',Vector3.xAxis,nil,.1 end
 gameState={MeleeEvent={FireServer=function(_,packet)check(packet.direction==Vector3.xAxis,'melee must pass explicit direction')end}}
 combat.begin=function(packet)check(packet.direction==Vector3.xAxis,'prediction must use explicit direction');return true end
 api.Settings.AutoMelee=true
 useCombat(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*5,velocity=Vector3.zero},function()return true end)
 check(root.CFrame==original and h.AutoRotate,'melee must not take body ownership');sameCamera()
 nextMelee,nextAbilityAt=0,0;api.Settings.UseAbilities=true
 player={GetAttribute=function()end};armory={loaded=true,abilities={PocketDoor=true,BowlingBall=true}}
 abilityFailures={};abilityRules={blocked=function()return false end};ownHistory={};pendingAbilities={};timingSample=function()end
 Core.isInvisible=function()return false end;Core.threatApproach=function()return nil,1 end
 Core.abilityUseful=function()return true end
 gearCatalog={equippedForRole=function()return activeRole=='Runner'and'PocketDoor'or'BowlingBall'end,get=function()return {Kind='Ability',ThrowRange=84}end}
 Core.projectileAim=function()return Vector3.xAxis,.2 end
 gearPrediction={request=function(_,aim)
 check(aim.Magnitude>.1,'gear must receive aim data');check(root.CFrame==original and h.AutoRotate,'gear request must not rotate body');sameCamera();return 'gear-fixture' end}
 for _,role in ipairs({'Runner','Catcher'})do
  activeRole=role;nextAbilityAt=0;direction=Vector3.xAxis
  local result=useAbility(model,h,root,{player=runnerPlayer,position=root.Position+Vector3.xAxis*10,velocity=Vector3.zero},{},{},nil,root.Position+Vector3.xAxis*50,function()return true end,{},nil,function()return true end)
  check(result,'ability fixture must dispatch '..role..': '..tostring(api.AbilityError))
 end
end)
model:Destroy();assert(ok,err)
return {passed=passed}
]]
    return assert(loadstring(prefix..sources.settings..'\n'..face..'\n'..sources.movement..'\n'..combat..'\n'..sources.abilities..'\n'..fixture))()
end
