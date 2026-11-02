return function(source)
 local first=assert(source:find('local function faceToward',1,true))
 local last=assert(source:find('local function useCombat',first,true))
 local prefix=[[
local api={Enabled=true,Settings={AutoFaceTarget=true}}
local runner={};local pumpkin={};local ownedHumanoid,activeRole,huntTarget,combatFacing,facingHumanoid,previousAutoRotate
local direction=Vector3.zero
local function flat(v)return Vector3.new(v.X,0,v.Z)end
local function activeRunner(p)return p.active end
local model=Instance.new('Model');local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Parent=model
local h=Instance.new('Humanoid');h.Parent=model
local player={Character=model}
]]
 local fixture=[[
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local position=root.Position
ownedHumanoid=h;activeRole='Runner';direction=Vector3.xAxis;faceTarget()
check(root.CFrame.LookVector:Dot(Vector3.xAxis)>.99,'runner faces current route direction')
check(root.Position==position and not h.AutoRotate,'facing changes yaw without moving position')
pumpkin.mode='PumpkinHunt';pumpkin.facing=position+Vector3.zAxis*15;faceTarget()
check(root.CFrame.LookVector:Dot(Vector3.zAxis)>.99,'event faces pumpkin while traveling sideways')
pumpkin.mode=nil;pumpkin.facing=nil
direction=Vector3.zero;faceTarget();check(h.AutoRotate,'idle returns native rotation ownership')
local targetModel=Instance.new('Model');local targetRoot=Instance.new('Part');targetRoot.Name='HumanoidRootPart';targetRoot.Position=root.Position+Vector3.zAxis*10;targetRoot.Parent=targetModel
activeRole='Catcher';huntTarget={active=true,Character=targetModel};faceTarget()
check(root.CFrame.LookVector:Dot(Vector3.zAxis)>.99,'chaser faces runner rather than movement')
combatFacing={character=model,untilAt=workspace:GetServerTimeNow()+1,aim=-Vector3.xAxis};faceTarget()
check(root.CFrame.LookVector:Dot(-Vector3.xAxis)>.99,'active attack aim takes precedence')
local saved=root.CFrame;model:SetAttribute('GearMotion',true);combatFacing.aim=Vector3.xAxis;faceTarget()
check(root.CFrame==saved,'native ability motion retains facing ownership');model:SetAttribute('GearMotion',nil)
api.Settings.AutoFaceTarget=false;faceTarget();check(root.CFrame==saved,'disabled facing cannot turn character')
runner.fallenKing={NeedsAim=function()return true end,Facing=function()return root.Position+Vector3.zAxis*10 end}
faceTarget();check(root.CFrame.LookVector:Dot(Vector3.zAxis)>.99 and not h.AutoRotate,'native boss attack takes body aim ownership with optional facing off')
runner.fallenKing=nil;faceTarget();check(h.AutoRotate,'boss aim completion restores rotation ownership')
root.CFrame=saved
api.Settings.AutoFaceTarget=true;model:SetAttribute('MovementLocked',true);faceTarget();check(root.CFrame==saved,'locked character cannot turn')
model:SetAttribute('MovementLocked',nil);api.Enabled=false;faceTarget();check(root.CFrame==saved,'stopped controller cannot turn')
model:Destroy();targetModel:Destroy();return {passed=n}
]]
 return assert(loadstring(prefix..source:sub(first,last-1)..fixture))()
end
