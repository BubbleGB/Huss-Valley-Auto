-- Native lobby integration with fake menus/navigation; never touches the live controller.
return function(source)
 local first=assert(source:find('local function createNativeProgression(services)',1,true),'native progression factory missing')
 local last=assert(source:find('runner.createNativeProgression=createNativeProgression',first,true))
 local create=assert(loadstring(source:sub(first,last-1)..'\nreturn createNativeProgression'))()
 local marker=assert(source:find('assert(game.PlaceId',1,true))
 local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
 local ownedBuilds=0;local buildOwned=Core.ownedEquipment
 Core.ownedEquipment=function(...)ownedBuilds=ownedBuilds+1;return buildOwned(...)end
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 local now=0;local attrs={ClientReady=true,InMatch=false};local api={Enabled=true,Settings=Core.defaultSettings()}
 function api:SetSetting(k,v)self.Settings[k]=v end
 local root={Position=Vector3.zero};local humanoid={Health=100}
 local player={Character={FindFirstChild=function(_,name)return name=='HumanoidRootPart'and root or humanoid end},GetAttribute=function(_,k)return attrs[k]end}
 local session={GetAttribute=function()return false end}
 local calls={};local prompt={Enabled=true,MaxActivationDistance=10,position=Vector3.new(30,0,0)}
 local ui={Prompt=function(_,job)return(job.kind=='crate'or job.kind=='spin'or job.kind=='ghost')and prompt or nil end}
 for _,name in ipairs({'Open','Inspect','Act','Close'})do ui[name]=function()error('integration must route effects through workflow services')end end
 local input={Tick=function()calls.tick=true end,Release=function()calls.released=true end}
 local nav={SetGoal=function(_,p,r)calls.goal=p end,Cancel=function()calls.cancelled=true end,Step=function()return Vector3.xAxis,false,'walking'end}
 local armory={loaded=true,abilities={Shield=true},gear={Juice=2},equippedAbilities={}}
 local items={Shield={Kind='Ability',Name='Shield',UseRole='Runner'},Juice={Kind='Item',Name='Juice'}}
 local services={api=api,Core=Core,player=player,session=session,clock=function()return now end,serverTime=function()return now end,
  inputService={GetFocusedTextBox=function()return nil end},guiService={MenuIsOpen=false},input=input,navigation=nav,
  armory=function()return armory end,gearItems=items,gearCatalog={get=function(id)return items[id]end,equippedForRole=function(a,r)return(a.equippedAbilities or{})[r]or''end},
  crateCatalog={Crates={Basic={Name='Basic'}}},journeyConfig={SeasonId='s',TrackId='t',Rewards={}},
  makeUI=function()return ui end,makeWorkflow=function(s)calls.services=s;return {Tick=function()calls.workflowTick=true end,Cancel=function()s.halt()end,Report=function()return calls.report or{active=false}end}end,
  promptPosition=function(p)return p.position end}
 local p=create(services);local s=calls.services
 check(#s.jobs()==0,'default-off settings produce no reward jobs')
 for _,k in ipairs({'AutoJourney','AutoSpins','AutoCrates','AutoGhostTrader'})do api.Settings[k]=true end
 check(#s.jobs()==4,'enabled native tasks are available without custom state requests')
 p:receive('ghost','State',{keys=10,live=true,restricted=false,nextAt=now+60});check(#s.jobs()==3,'cooldown skips unnecessary trader visits')
 now=now+60;check(#s.jobs()==4,'trader returns when native cooldown expires')
 prompt.Enabled=false;check(#s.jobs()==1,'disabled world prompts are not bypassed')
 prompt.Enabled=true;local job={key='spin',kind='spin',name='Wheel Spin'}
 prompt.position=Vector3.new(30,-318,0);check(#s.jobs()==1,'hidden below-map station prompts are excluded');prompt.position=Vector3.new(30,0,0)
 check(s.reach(job)==false and calls.goal and(calls.goal-prompt.position).Magnitude<=8,'station tasks route to reachable space outside the prop')
 root.Position=Vector3.new(25,0,0);check(s.reach(job)==true and calls.cancelled,'in-range station stops navigation before opening')
 check(s.reach({kind='journey'})==true,'HUD Journey entry requires no invented station')
 root.Position=Vector3.zero;services.stationApproach=function()return Vector3.new(25,0,0)end
 local ghostJob={kind='ghost',key='ghost-stand'};check(not s.reach(ghostJob)and calls.goal==Vector3.new(25,0,0),'native trader standing spot avoids routing into its model')
 services.stationApproach=nil;root.Position=Vector3.new(25,0,0)
 attrs.InMatch=true;check(not s.ready(nil),'match blocks lobby collection')
 attrs.InMatch=false;attrs.AFK=true;check(s.ready(nil),'native lobby menus remain usable while AFK');attrs.AFK=nil
 attrs.SpinWheelOpen=true;check(not s.ready(nil)and s.ready(job),'only owned wheel flow can continue through its open panel')
 attrs.ArmoryOpen=true;check(not s.ready(job),'another native panel interrupts current work');attrs.ArmoryOpen=nil;attrs.SpinWheelOpen=nil
 api.Settings.AutoSpins=false;check(not s.allowed(job),'disabled feature cancels its selected job');api.Settings.AutoSpins=true
 api.Settings.RunnerEquipment='Shield';local options=api:EquipmentOptions('Runner');check(#options==1 and options[1].id=='Shield','owned role equipment preserved')
 options[1].name='Changed';local again=api:EquipmentOptions('Runner')
 check(again[1].name=='Shield'and ownedBuilds==1,'inventory snapshot caches sorting while returning independent option values')
 api:SelectEquipment('Consumable','Juice');check(api.Settings.ConsumableEquipment=='Juice','owned choice queues native menu selection')
 check(not pcall(api.SelectEquipment,api,'Runner','Missing'),'unowned equipment rejected without purchase')
 p:receive('spin','State',{credits=10});check(p.spin.value.credits==10 and p.spin.revision==1,'passive snapshots update state')
 p:receive('spin','State',{credits=0,results={{id='x'}}});check(p.spin.resultRevision==1,'native result marks confirmation separately')
 p:receive('crate','Result',{crate='Basic',id='x'});check(p.states.Basic.resultRevision==1,'crate confirmation retained without replaying a token')
 p:receive('ghost','Result',{state={keys=1,live=true}});check(p.ghost.value.keys==1 and p.ghost.resultRevision==1,'ghost native result state retained')
 p:Tick();check(calls.tick and calls.workflowTick,'heartbeat advances input release and serial workflow')
 calls.report={active=true,phase='walking',job=job};local d,j=p:Step(player.Character,humanoid,root);check(d==Vector3.xAxis and j==false,'only walking phase contributes lobby movement')
 calls.report.phase='acting';d=p:Step(player.Character,humanoid,root);check(d==Vector3.zero,'open menu never keeps walking')
 p:Cancel();check(calls.released and calls.cancelled,'stop releases input/navigation')
 armory=table.clone(armory);armory.abilities={};check(#api:EquipmentOptions('Runner')==0,'fresh native inventory invalidates ownership cache')
 p:AvoidStation(prompt);check(p:IsStationBlocked(prompt),'unreachable prompt is remembered')
 local oldPromptPosition=prompt.position;prompt.position=oldPromptPosition+Vector3.new(5,0,0)
 check(not p:IsStationBlocked(prompt),'relocated station invalidates its old failed route')
 p:AvoidStation(prompt);now=now+121;check(not p:IsStationBlocked(prompt),'station backoff expires for a fresh attempt')
 return {passed=n}
end
