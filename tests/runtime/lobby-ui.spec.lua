-- Pure detached table hierarchy. No live UI, input, movement, camera or remotes.
return function(source)
 local first=assert(source:find('local function createLobbyUI(services)',1,true),'lobby UI factory missing')
 local last=assert(source:find('runner.createLobbyUI=createLobbyUI',first,true))
 local create=assert(loadstring(source:sub(first,last-1)..'\nreturn createLobbyUI'))()
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 local function node(name,class,parent,props)
  local v=props or{};v.Name=name;v.ClassName=class or'Frame';v.Parent=parent;v.children={}
  if parent then parent.children[#parent.children+1]=v end
  function v:IsA(c)return c==self.ClassName or c=='GuiObject'and(self.ClassName=='Frame'or self.ClassName=='TextButton')or c=='GuiButton'and self.ClassName=='TextButton'end
  function v:FindFirstChild(k,deep)for _,c in ipairs(self.children)do if c.Name==k then return c end end;if deep then for _,c in ipairs(self.children)do local x=c:FindFirstChild(k,true);if x then return x end end end end
  function v:GetDescendants()local out={};for _,c in ipairs(self.children)do out[#out+1]=c;for _,d in ipairs(c:GetDescendants())do out[#out+1]=d end end;return out end
  function v:GetAttribute(k)return(self.attrs or{})[k]end
  if v:IsA('GuiObject')then if v.Visible==nil then v.Visible=true end end
  return v
 end
 local gui=node('PlayerGui','PlayerGui');local world=node('Workspace','Workspace')
 local wheel=node('SpinWheel','ScreenGui',gui,{Enabled=true});local main=node('Main','Frame',wheel)
 local one=node('Spin','TextButton',main,{Active=true,AutoButtonColor=true})
 local five=node('Spin5','TextButton',main,{Active=true,AutoButtonColor=true})
 local ten=node('Spin10','TextButton',main,{Active=true,AutoButtonColor=true})
 local locked=node('Locked','Frame',ten)
 local now=10;local tapped={};local randomPick=1;local randomCalls=0;local states={spin={value={credits=10},at=10,revision=1,resultRevision=0}}
 local input={Tap=function(_,v)tapped[#tapped+1]=v;return true end,TapCard=function(_,v)tapped[#tapped+1]=v;return true end,Prompt=function()return true end,TapGhostContinue=function(_,v)tapped[#tapped+1]=v;return true end}
 local arm={loaded=true,abilities={Shield=true},equippedAbilities={Runner=''},gear={}}
 local ui=create({random=function(count)randomCalls=randomCalls+1;return math.min(randomPick,count)end,playerGui=gui,workspace=world,input=input,clock=function()return now end,serverTime=function()return now end,states=function()return states end,armory=function()return arm end,gearCatalog={get=function()return{Kind='Ability',UseRole='Runner'}end,equippedForRole=function(s,r)return s.equippedAbilities[r]end}})
 local job={key='spin',kind='spin'}
 check(ui:Inspect(job).action~=nil,'spin selector available');check(ui:Inspect(job).action.count==5,'spin token carries native count')
 check(ui:Act(job,ui:Inspect(job).action)and tapped[1]==five,'largest unlocked native spin')
 check(ui:Inspect(job).waiting and not ui:Act(job,ui:Inspect(job).action),'pending prevents duplicate spin');check(ui:Inspect(job).description:find('Spinning x5',1,true),'pending status names dispatched native spin count')
 states.spin.revision=2;check(ui:Inspect(job).waiting,'plain state cannot confirm spin')
 states.spin.resultRevision=1;states.spin.value.credits=0;check(ui:Inspect(job).waiting,'server reply alone does not finish native spin animation')
 now=11;check(ui:Inspect(job).done,'native batch settles before closing')
 ui:Close(job);locked.Visible=false;states.spin.value.credits=10
 check(ui:Act(job,ui:Inspect(job).action)and tapped[#tapped]==ten,'hidden lock allows x10')
 now=30;check(ui:Inspect(job).action==nil,'timeout cannot blindly retry primary');check(ui:Inspect(job).done,'confirmation timeout finishes job for bounded closure')
 local crates=node('Crates','ScreenGui',gui,{Enabled=true});local collectionShade=node('CollectionShade','Frame',crates);local collection=node('Collection','Frame',collectionShade)
 local paid=node('Gems','TextButton',collection,{Active=true});local free=node('Free','TextButton',collection,{Active=false});local continue=node('Continue','TextButton',collection,{Active=true,Visible=false})
 local crate={kind='crate',key='crate:Basic',id='Basic'};states.states={Basic={value={loaded=true,allowed=true,free=0},at=now,revision=1,resultRevision=0}}
 check(ui:Inspect(crate).action==nil,'paid offers never substitute for free')
 local armory=node('ValleyArmory','ScreenGui',gui,{Enabled=true});local overlay=node('Overlay','Frame',armory);local canvas=node('Canvas','Frame',overlay);local shop=node('GearShop','Frame',canvas);local card=node('Shield','Frame',shop);local equip=node('Equip','TextButton',card,{Active=true,Text='EQUIP ABILITY'})
 local eq={key='equip:Runner',kind='equip',slot='Runner',id='Shield'}
 check(ui:Act(eq,ui:Inspect(eq).action)and tapped[#tapped]==equip,'owned native equip only')
 arm.equippedAbilities.Runner='Shield';equip.Text='ABILITY EQUIPPED  ✓';check(ui:Inspect(eq).done,'native equipped label confirms with cache')
 ui:Close(eq);check(ui:Inspect(eq).done and ui:Inspect(eq).action==nil,'already equipped never toggles off')
 arm.equippedAbilities.Runner='';arm.abilities.Shield=false;equip.Text='EQUIP ABILITY';check(ui:Inspect(eq).action==nil,'unowned equipment rejected despite label')
 now=40
 local journey=node('ValleyJourney','ScreenGui',gui,{Enabled=true});local shade=node('Shade','Frame',journey);local journal=node('Journal','Frame',shade);local claim=node('ClaimAll','TextButton',journal,{Active=true})
 states.journey={value={loaded=true,claims={}},at=now,revision=1};local jj={key='journey',kind='journey'}
 check(ui:Act(jj,ui:Inspect(jj).action)and tapped[#tapped]==claim,'native claim all target')
 states.journey.revision=2;check(ui:Inspect(jj).waiting,'journey state alone cannot confirm active claim')
 claim.Active=false;check(ui:Inspect(jj).done,'updated claims and inactive claim confirms journey')
 free.Active=true;states.states.Basic.value.free=1;states.states.Basic.at=now
 check(ui:Act(crate,ui:Inspect(crate).action)and tapped[#tapped]==free,'only native free crate action')
 states.states.Basic.resultRevision=1;continue.Visible=false
 local nativeReveal=node('Reveal','Frame',collection,{Visible=true})
 check(ui:Inspect(crate).waiting and not ui:Inspect(crate).done,'crate result waits during native reveal before Continue appears')
 continue.Visible=true
 local reveal=ui:Inspect(crate);check(not reveal.done and reveal.action~=nil,'confirmed crate reveal requires continue')
 check(ui:Act(crate,reveal.action)and tapped[#tapped]==continue and ui:Inspect(crate).done,'continue completes native reveal')
 local ghost=node('GhostTraderUI','ScreenGui',gui,{Enabled=true});local ghostUI=node('UI','Frame',ghost);local ghostContinue=node('Continue','TextButton',ghostUI,{Visible=false,Interactable=false,Active=false});local ghostLeave=node('PanelLeave','TextButton',ghostUI,{Visible=true,Active=true})
 local cam=node('Camera','Camera',world);world.CurrentCamera=cam;local view=node('GhostTraderView','Model',cam);local gc=node('Card1','Model',view);local hit=node('Hit','Part',gc)
 states.ghost={at=now,revision=1,resultRevision=0,value={live=true,restricted=false,keys=1,nextAt=0,deal=1,opened={false,false,false,false,false,false}}}
 local gj={key='ghost',kind='ghost'}
 check(ui:Act(gj,ui:Inspect(gj).action)and tapped[#tapped]==hit,'ghost selects native projected card hit')
 check(not ui:Inspect(gj).waiting,'first tap selects without claiming a flip')
 check(ui:Act(gj,ui:Inspect(gj).action)and ui:Inspect(gj).waiting,'second native card tap awaits confirmation')
 states.ghost.revision=2;check(ui:Inspect(gj).waiting,'unchanged ghost state cannot confirm flip')
 states.ghost.value.opened[1]=true;ghostLeave.Visible=false
 check(ui:Inspect(gj).waiting and not ui:Inspect(gj).done,'ghost native result waits for hidden native reveal controls')
 ghostContinue.Visible=true;local ghostReveal=ui:Inspect(gj)
 check(ghostReveal.action and ghostReveal.action.kind=='ghostContinue','noninteractable native ghost Continue becomes specialized touch action')
 check(ui:Act(gj,ghostReveal.action)and tapped[#tapped]==ghostContinue,'ghost Continue sends specialized ordinary touch')
 check(ui:Inspect(gj).waiting and ui:Inspect(gj).action==nil,'ghost Continue tap waits without repeating until native presentation dismissal')
 ghostContinue.Visible=false;ghostLeave.Visible=true
 check(ui:Inspect(gj).done,'ghost closes only after Continue hides and Leave becomes visible')
 ui:Close(gj);states.ghost.value.keys=0;check(ui:Inspect(gj).action==nil,'ghost never buys missing keys')
 ui:Close(job);states.spin.at=now;local stale=ui:Inspect(job).action;check(stale~=nil,'stale token fixture is actionable');one.Active=false;five.Active=false;ten.Active=false
 check(not ui:Act(job,stale),'stale action rechecks native availability')
 wheel.Enabled=false;check(not ui:Inspect(job).visible,'disabled screen is not visible')
 ui:Close(job);wheel.Enabled=true;states.spin.value.credits=0;states.spin.at=now
 check(ui:Inspect(job).done,'fresh empty spin balance closes promptly')
 ui:Close(crate);continue.Visible=false;states.states.Basic.value.free=0
 check(ui:Inspect(crate).done,'fresh empty free crate balance closes promptly')
 ui:Close(jj);check(ui:Inspect(jj).done,'fresh inactive journey claim closes promptly')
 ui:Close(gj);check(ui:Inspect(gj).done,'fresh missing ghost keys closes promptly')
 ui:Close(eq);check(ui:Inspect(eq).done,'unowned equipment closes rather than buying')
 states.ghost.value.keys=1;states.ghost.value.restricted=true
 check(ui:Inspect(gj).done,'restricted ghost presentation closes promptly')
 states.ghost.value.restricted=false;states.ghost.value.opened[1]=false
 local gc2=node('Card2','Model',view);local hit2=node('Hit','Part',gc2);randomPick=2
 ui:Close(gj);local beforeRandom=randomCalls;local randomToken=ui:Inspect(gj).action
 check(randomToken and randomToken.hit==hit2,'random chooses among unopened native cards')
 randomPick=1;check(ui:Act(gj,randomToken)and tapped[#tapped]==hit2,'random card remains stable through input recheck')
 check(ui:Act(gj,ui:Inspect(gj).action)and tapped[#tapped]==hit2 and randomCalls==beforeRandom+1,'selected random card retained for both taps')
 local lobby=node('Lobby','Model',world);local interactables=node('Interactables','Folder',lobby);local station=node('SpinTheWheel','Model',interactables);local pad=node('PromptPad','Part',station);local prompt=node('ProximityPrompt','ProximityPrompt',pad,{Enabled=true})
 local scans=0;local scan=interactables.GetDescendants;function interactables:GetDescendants()scans=scans+1;return scan(self)end
 local worldScans=0;local worldScan=world.GetDescendants;function world:GetDescendants()worldScans=worldScans+1;return worldScan(self)end
 check(ui:Prompt(job)==prompt and ui:Prompt(job)==prompt and scans==1 and worldScans==0,'prompt scans cached and confined to native interactables')
 prompt.Enabled=false;check(ui:Prompt(job)==nil,'cached disabled prompt refused immediately')
 prompt.Enabled=true;prompt.Parent=nil;check(ui:Prompt(job)==nil,'cached removed prompt refused immediately')
 prompt.Parent=pad;now=now+2.1;check(ui:Prompt(job)==prompt and scans==2,'prompt cache refreshes after two seconds')
 local hud=node('ValleyHUD','ScreenGui',gui,{Enabled=true});local drawer=node('DrawerClip','Frame',hud);local panel=node('Panel','Frame',drawer);local navigation=node('Navigation','Frame',panel);local hudAbilities=node('Abilities','TextButton',navigation,{Active=true});local menuToggle=node('MenuToggle','TextButton',hud,{Active=true})
 armory.Enabled=false
 local itemJob={key='equip:Consumable',kind='equip',slot='Consumable',id='Adrenaline'}
 check(ui:Open(itemJob)and tapped[#tapped]==hudAbilities,'consumable opens actual HUD Abilities entry when Items entry absent')
 armory.Enabled=true;shop.Visible=false;local tabs=node('Tabs','Frame',canvas);local itemsTab=node('Items','TextButton',tabs,{Active=true})
 arm.gear.Adrenaline=1
 local itemUI=create({playerGui=gui,workspace=world,input=input,clock=function()return now end,states=function()return states end,armory=function()return arm end,gearCatalog={get=function()return{Kind='Item'}end}})
 check(itemUI:Act(itemJob,itemUI:Inspect(itemJob).action)and tapped[#tapped]==itemsTab,'consumable switches native Items tab after HUD fallback')
 claim.Active=true;states.journey.at=now;states.journey.revision=3
 local claimable=true
 local journeyUI=create({playerGui=gui,workspace=world,input=input,clock=function()return now end,states=function()return states end,armory=function()return arm end,journeyClaimable=function()return claimable end})
 check(journeyUI:Act(jj,journeyUI:Inspect(jj).action),'journey confirmation guard fixture dispatched')
 claim.Active=false;states.journey.revision=4
 check(journeyUI:Inspect(jj).waiting,'XP state during saving cannot confirm claimable Journey rewards')
 claimable=false;check(journeyUI:Inspect(jj).done,'no claimable native rewards confirms completed Journey')
 continue.Visible=false;states.states.Basic.at=now;states.states.Basic.value.free=1
 local boundedUI=create({playerGui=gui,workspace=world,input=input,clock=function()return now end,states=function()return states end,armory=function()return arm end})
 check(boundedUI:Act(crate,boundedUI:Inspect(crate).action),'bounded crate reveal fixture dispatched')
 states.states.Basic.resultRevision=states.states.Basic.resultRevision+1
 check(boundedUI:Inspect(crate).waiting,'bounded crate reveal starts waiting')
 now=now+26;check(boundedUI:Inspect(crate).done,'stuck native reveal eventually closes safely')
 local function ghostFixture()
  states.ghost.at=now;states.ghost.value.opened[1]=true;states.ghost.value.opened[2]=false;ghostContinue.Visible=false
  local fixture=create({random=function()return 1 end,playerGui=gui,workspace=world,input=input,clock=function()return now end,serverTime=function()return now end,states=function()return states end})
  check(fixture:Act(gj,fixture:Inspect(gj).action)and fixture:Act(gj,fixture:Inspect(gj).action),'ghost reveal timing fixture dispatches native two taps')
  states.ghost.value.opened[2]=true
  return fixture
 end
 ghostLeave.Visible=true;local autoGhost=ghostFixture()
 check(autoGhost:Inspect(gj).waiting,'early Leave visibility cannot close before Ghost reveal starts')
 now=now+4.1;check(autoGhost:Inspect(gj).done,'native auto-dismissal with visible Leave completes after initial delay')
 ghostLeave.Visible=false;local stuckGhost=ghostFixture()
 check(stuckGhost:Inspect(gj).waiting,'hidden native Ghost controls keep reveal pending')
 now=now+26;check(stuckGhost:Inspect(gj).done,'Ghost native presentation waiting is bounded')
 local hud=gui:FindFirstChild('ValleyHUD')or node('ValleyHUD','ScreenGui',gui,{Enabled=true})
 local drawer=hud:FindFirstChild('DrawerClip')or node('DrawerClip','Frame',hud)
 local panel=drawer:FindFirstChild('Panel')or node('Panel','Frame',drawer)
 local navigation=panel:FindFirstChild('Navigation')or node('Navigation','Frame',panel)
 local journeyEntry=navigation:FindFirstChild('Journey')or node('Journey','TextButton',navigation,{Active=true})
 local menu=hud:FindFirstChild('MenuToggle')or node('MenuToggle','TextButton',hud,{Active=true})
 journeyEntry.AbsolutePosition=Vector2.new(-255,100);journeyEntry.AbsoluteSize=Vector2.new(115,60)
 shade.Visible=false
 check(ui:Open({kind='journey',key='drawer-closed'})and tapped[#tapped]==menu,'offscreen visible HUD entry opens drawer first')
 journeyEntry.AbsolutePosition=Vector2.new(100,100)
 check(ui:Open({kind='journey',key='drawer-open'})and tapped[#tapped]==journeyEntry,'onscreen Journey entry uses native HUD button')
 wheel.Enabled=true;one.Active=true;one.AutoButtonColor=true;five.Active=true;five.AutoButtonColor=true;five.Visible=true;ten.Active=true;ten.AutoButtonColor=true;ten.Visible=true;locked.Visible=false
 local wheelFrame=main:FindFirstChild('Wheel')or node('Wheel','Frame',main)
 local spinner=wheelFrame:FindFirstChild('Spinner')or node('Spinner','Frame',wheelFrame,{Rotation=0})
 local skip=main:FindFirstChild('Skip')or node('Skip','TextButton',main,{Visible=false,Active=true})
 now=100;states.spin={value={credits=1},at=now,revision=1,resultRevision=0}
 local single={kind='spin',key='single-animation'};local token=ui:Inspect(single).action
 check(token and token.count==1 and token.button==one,'single native button selected below five credits')
 check(ui:Act(single,token),'single native button receives touch')
 states.spin.value.credits=0;states.spin.resultRevision=1;now=100.2
 check(ui:Inspect(single).waiting,'single server result does not close during animation')
 now=105.3;spinner.Rotation=320;check(ui:Inspect(single).waiting,'moving spinner delays closure even after configured windup')
 now=106;check(ui:Inspect(single).done,'single spin closes only after animation settles')
 now=110;states.spin={value={credits=10},at=now,revision=1,resultRevision=0}
 local batch={kind='spin',key='batch-animation'};token=ui:Inspect(batch).action
 check(token and token.count==10 and token.button==ten and ui:Act(batch,token),'native x10 selected and touched when unlocked')
 states.spin.value.credits=0;states.spin.resultRevision=1;five.Visible=false;skip.Visible=true;now=112
 check(ui:Inspect(batch).waiting,'native multi-stage controls keep batch open until finished')
 five.Visible=true;skip.Visible=false;now=113;ui:Inspect(batch);now=113.5
 check(ui:Inspect(batch).done,'finished batch closes once native controls and spinner settle')
 for _,credits in ipairs({1.5,math.huge,0/0})do
  now=120;states.spin={value={credits=credits},at=now,revision=1,resultRevision=0}
  local invalid=ui:Inspect({kind='spin',key='invalid:'..tostring(credits)})
  check(invalid.done and not invalid.action,'invalid native balances never authorize a spin')
 end
 local quests=node('ValleyQuests','ScreenGui',gui,{Enabled=true});local qs=node('QuestPanelShade','Frame',quests);local qp=node('QuestPanel','Frame',qs)
 local list=node('QuestList','Frame',qp);local qc=node('spin_running','Frame',list)
 local earned=node('Claim','TextButton',qc,{Active=true,Text='CLAIM'});local paidSkip=node('AutoComplete','TextButton',list,{Active=true})
 local qj={kind='quest',key='quest'};states.quest={at=now,revision=1,value={loaded=true}}
 check(ui:Inspect(qj).action and ui:Inspect(qj).action.button==earned,'quests select native earned claim only')
 check(ui:Act(qj,ui:Inspect(qj).action)and tapped[#tapped]==earned,'quest claims use touch adapter')
 check(ui:Inspect(qj).waiting,'quest claim awaits refreshed native state')
 earned.Active=false;earned.Text='CLAIMED';states.quest.revision=2
 check(ui:Inspect(qj).done,'claimed state finishes without paid rerolls or auto complete')
 ui:Close(qj);earned.Active=true;earned.Text='CLAIM KNIFE'
 check(ui:Inspect(qj).action and ui:Act(qj,ui:Inspect(qj).action),'earned event knife uses native quest Claim')
 earned.Active=false;earned.Text='OWNED';states.quest.revision=3
 check(ui:Inspect(qj).done,'owned event reward confirms quest claim')
 ui:Close(qj);earned.Active=true;earned.Text='CLAIMING...'
 check(not ui:Inspect(qj).action,'pending quest button cannot duplicate claim')
 earned.Active=false
 local nextCard=node('KnifeB','TextButton',list,{Active=true})
 local thirdCard=node('KnifeC','TextButton',list,{Active=true})
 states.quest.value={loaded=true,mode='Event',event={claimsEnabled=true,weapons={{id='KnifeB',claimable=true,claimed=false},{id='KnifeC',claimable=true,claimed=false}}}}
 local select=ui:Inspect(qj).action
 check(select and select.kind=='questTab'and select.button==nextCard,'select another earned event weapon through native card')
 check(ui:Act(qj,select)and tapped[#tapped]==nextCard,'event selection uses touch adapter')
 earned.Active=true;earned.Text='CLAIM KNIFE'
 check(ui:Act(qj,ui:Inspect(qj).action)and tapped[#tapped]==earned,'selected event reward can be claimed')
 states.quest.revision=4;states.quest.value.event.weapons[1].claimed=true;earned.Active=false;earned.Text='OWNED'
 local nextReward=ui:Inspect(qj).action
 check(nextReward and nextReward.kind=='questTab'and nextReward.button==thirdCard,'confirmed reward continues to next earned event card')
 check(ui:Act(qj,nextReward),'next earned card selection succeeds')
 earned.Active=true;earned.Text='CLAIM KNIFE';check(ui:Act(qj,ui:Inspect(qj).action),'second earned event claim succeeds')
 states.quest.revision=5;states.quest.value.event.weapons[2].claimed=true;earned.Active=false;earned.Text='OWNED'
 check(ui:Inspect(qj).done,'all earned event claims complete without purchase controls')
 now=200;states.spin={value={credits=4},at=now,revision=1,resultRevision=0}
 one.Active=true;one.AutoButtonColor=true
 local drain={kind='spin',key='drain-four'}
 for remaining=4,1,-1 do
  local token=ui:Inspect(drain).action
  check(token and token.count==1,'remaining sub-five credits continue with single spins: '..remaining)
  check(ui:Act(drain,token),'next single spin dispatched only after settlement')
  states.spin.value.credits=remaining-1;states.spin.resultRevision=states.spin.resultRevision+1;states.spin.revision=states.spin.revision+1
  now=now+5.3;states.spin.at=now;ui:Inspect(drain);now=now+.5
 end
 check(ui:Inspect(drain).done,'wheel closes after all four credits are consumed')
 return {passed=n}
end
