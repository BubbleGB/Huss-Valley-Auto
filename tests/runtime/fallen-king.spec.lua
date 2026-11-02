return function(source)
 local a=assert(source:find('local function createFallenKing',1,true),'Fallen King factory missing')
 local b=assert(source:find('runner.createFallenKing=createFallenKing',a,true))
 local marker=assert(source:find('assert(game.PlaceId',1,true))
 local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
 local make=assert(loadstring(source:sub(a,b-1)..'\nreturn createFallenKing'))()
 local world=Instance.new('Folder');local fight=Instance.new('Folder');fight.Name='FallenKingFight';fight.Parent=world
 local king=Instance.new('Model');king.Name='FallenKing';king.Parent=fight
 local kr=Instance.new('Part');kr.Name='HumanoidRootPart';kr.Position=Vector3.new(0,0,-25);kr.Parent=king
 local bomb=Instance.new('Part');bomb.Name='BossBomb';bomb.Anchored=true;bomb.Position=Vector3.new(10,0,0);bomb.Parent=fight
 local character=Instance.new('Model');local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Parent=character
 local humanoid=Instance.new('Humanoid');humanoid.Parent=character
 local attrs={InMatch=true,RunState='Active'};local state={BossActive=true,BossFighting=true};local now=0;local goals={};local ranges={};local stationary=false;local touches=0;local melees=0
 local nav={SetGoal=function(_,p,r)goals[#goals+1]=p;ranges[#ranges+1]=r end,Cancel=function()end,Step=function()return stationary and Vector3.zero or Vector3.xAxis,false end}
 local boss=make({Core=Core,world=world,config={Hearts={Count=3}},clock=function()return now end,
 player={GetAttribute=function(_,k)return attrs[k]end},session={GetAttribute=function(_,k)return state[k]end},
 navigation=nav,enabled=function()return true end,clear=function()return true end,
 melee=function()melees=melees+1;return true end,meleeAimed=function()return true end,meleeReach=7,throw=function()touches=touches+1;return true end,aimed=function()return true end,operation=function()end})
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 local handled,move=boss:Step(character,humanoid,root,.016)
 check(handled and move.Magnitude>0 and goals[#goals]==bomb.Position,'active boss collects native free bomb')
 attrs.BossBomb='one';now=.3;boss:Step(character,humanoid,root,.016)
 check(touches==1 and boss:Facing()~=nil,'held bomb uses native throw control toward boss')
 now=.7;boss:Step(character,humanoid,root,.016);check(touches==1,'same held bomb cannot be blindly thrown twice')
 attrs.BossDownedUntil=20;now=1;handled,move=boss:Step(character,humanoid,root,.016)
 check(handled and move.Magnitude==0 and touches==1,'downed waits without buying paid revival')
 attrs.BossDownedUntil=nil;state.BossFighting=false;handled,move=boss:Step(character,humanoid,root,.016)
 check(handled and move.Magnitude==0,'native intro or outro yields movement')
 state.BossActive=false;check(not boss:Step(character,humanoid,root,.016),'map model alone cannot enable event')
 boss:Receive('Attack',{kind='Ring',position=Vector3.zero,radius=10,seconds=1})
 state.BossActive=true;state.BossFighting=true;attrs.BossBomb=nil;now=1.1
 boss:Receive('Attack',{kind='Ring',position=Vector3.zero,radius=10,seconds=1})
 check(boss:Report().hazards==1,'native telegraph is tracked for evasion')
 stationary=true;now=1.2;handled,move=boss:Step(character,humanoid,root,.016)
 check(move.Magnitude>.1,'stationary boss state still escapes an incoming ring');stationary=false
 now=3;boss:Step(character,humanoid,root,.016);check(boss:Report().hazards==0,'expired telegraph is discarded')
 local shrine=Instance.new('Model');shrine.Name='Shrine';shrine:SetAttribute('Health',100);shrine.Parent=fight
 local pivot=Instance.new('Part');pivot.Name='Pivot';pivot.Position=Vector3.new(5,0,0);pivot.Parent=shrine
 bomb:Destroy();now=4;boss:Step(character,humanoid,root,.016)
 check(melees==1,'safely reachable healing shrine receives native melee')
 check((goals[#goals]-pivot.Position).Magnitude+ranges[#ranges]<=7,'entire shrine arrival region is within melee reach')
 now=4.1;boss:Step(character,humanoid,root,.016);check(melees==1,'melee respects recovery between attempts')
 boss:Reset();world:Destroy();character:Destroy();return{passed=n}
end
