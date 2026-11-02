-- Detached native-shaped services. Never sends input to a real client.
return function(source)
 local first=assert(source:find('local function createLobbyInput(',1,true),'lobby input factory missing')
 local last=assert(source:find('runner.createLobbyInput=createLobbyInput',first,true))
 local factory=assert(loadstring('local RaycastParams={new=function()return{}end}\n'..source:sub(first,last-1)..'\nreturn createLobbyInput'))()
 local now=0;local enabled=true;local events={};local focused=nil;local top={};local core={};local inset=Vector2.new(4,50)
 local gui={};local function node(kind,parent)
  return {Parent=parent,Visible=true,Enabled=true,Active=true,Interactable=true,
   AbsolutePosition=Vector2.new(10,20),AbsoluteSize=Vector2.new(40,20),
   IsA=function(_,c)return c==kind or c=='GuiObject' and kind~='ScreenGui' or c=='GuiButton' and kind=='TextButton'end}
 end
 local screen=node('ScreenGui',gui);local button=node('TextButton',screen);local label=node('TextLabel',button)
 local rayHit;local camera={};local view={Name='GhostTraderView',Parent=camera};local card={Name='Card1',Parent=view}
 local hit={Name='Hit',Parent=card,Position=Vector3.new(0,0,5)}
 view.GetChildren=function()return{card}end;card.FindFirstChild=function(_,name)if name=='Hit'then return hit end end
 camera.WorldToScreenPoint=function()return Vector3.new(120,160,5),true end
 camera.ScreenPointToRay=function(_,x,y)assert(x==120 and y==160,'card ray uses raw screen');return{Origin=Vector3.zero,Direction=Vector3.zAxis}end
 local playerGui={GetGuiObjectsAtPosition=function()return top end}
 local externalTouch=Vector2.new(1400,795);local began,ended=0,0
 local presentation=true;camera.FindFirstChild=function(_,name)if presentation and name=='GhostTraderView'then return view end end
 local s=factory({clock=function()return now end,enabled=function()return enabled end,
  playerGui=playerGui,coreGui={GetGuiObjectsAtPosition=function()return core end},
  input=setmetatable({GetFocusedTextBox=function()return focused end},{__index=function(_,key)error('unsupported input member '..key)end}),
  touchesBusy=function(x,y)return not x or(externalTouch-Vector2.new(x,y)).Magnitude<24 end,
  onTouchBegin=function(x,y)began=began+1;return began end,
  onTouchEnd=function(token)assert(token~=nil,'owned touch release keeps its token');ended=ended+1 end,
  guiService={MenuIsOpen=false,GetGuiInset=function()return inset end},camera=function()return camera end,
  workspace={Raycast=function(_,_,_,params)assert(params.FilterDescendantsInstances[1]==hit,'native card ray includes only card Hit parts');return rayHit and{Instance=rayHit}end},
  virtualInput={SendTouchEvent=function(_,id,state,x,y)events[#events+1]={id=id,state=state,x=x,y=y}end}})
 top={label};assert(s:Tap(button),'descendant label permits target touch')
 assert(s:Busy()and #events==1 and events[1].x==34 and events[1].y==80,'logical target plus begin inset')
 assert(not s:Tap(button),'serial owned input');now=.079;s:Tick();assert(#events==1,'minimum hold')
 inset=Vector2.new(10,90);now=.08;s:Tick();assert(#events==2 and events[2].state==2 and events[2].x==34 and events[2].y==80,'paired end freezes begin coordinate')
 assert(began==1 and ended==1,'owned touch lifecycle is released even without a native end callback')
 externalTouch=Vector2.new(30,30);assert(not s:Tap(button),'manual touch on the same target is respected');externalTouch=Vector2.new(1400,795)
 top={node('TextButton',screen),label};assert(not s:Tap(button),'frontmost foreign button blocks')
 top={label};core={node('TextButton',screen)};assert(not s:Tap(button),'CoreGui obstruction blocks');core={}
 screen.Enabled=false;assert(not s:Tap(button),'disabled ancestor blocks');screen.Enabled=true
 focused={};assert(not s:Tap(button),'typing blocks');focused=nil
 enabled=false;assert(not s:Tap(button),'disabled blocks');enabled=true
 top={};rayHit=hit;assert(s:TapCard(hit),'projected native card tap')
 assert(events[3].x==130 and events[3].y==250,'card touch compensates executor inset to deliver projected input position');s:Release()
 assert(events[4].state==2 and not s:Busy(),'release ends active touch')
 rayHit={};assert(not s:TapCard(hit),'wrong ray target rejected');rayHit=hit
 top={label};assert(not s:TapCard(hit),'button ancestor obstructs native card');top={}
 local base={Position=Vector3.new(0,0,0)}
 local prompt={Parent=base,Enabled=true,MaxActivationDistance=5,HoldDuration=.2,ActionText='Spin',
  InputHoldBegin=function()error('must touch visible control')end,InputHoldEnd=function()error('must use paired touch end')end}
 local shown=true;local home={};local billboard=node('BillboardGui',home);billboard.Adornee=base;billboard.AbsoluteSize=Vector2.new(126,72)
 billboard.SizeOffset=Vector2.zero;billboard.StudsOffset=Vector3.zero;billboard.StudsOffsetWorldSpace=Vector3.zero
 local promptButton=node('TextButton',billboard);promptButton.AbsolutePosition=Vector2.zero;promptButton.AbsoluteSize=billboard.AbsoluteSize
 home.GetDescendants=function()return shown and{billboard,promptButton}or{}end
 playerGui.FindFirstChild=function(_,name)return name=='ProximityPrompts'and home or nil end
 billboard.FindFirstChild=function(_,name)return name=='TextButton'and promptButton or name=='ActionText'and{Text='Spin'}or nil end
 assert(not s:Prompt(prompt,{Position=Vector3.new(10,0,0)}),'out of range prompt rejected')
 shown=false;assert(not s:Prompt(prompt,{Position=Vector3.zero}),'unrendered prompt is never activated');shown=true
 local count=#events
 assert(s:Prompt(prompt,{Position=Vector3.new(1,0,0)})and events[#events].x==130 and events[#events].y==250,'visible billboard tap uses projected canvas center plus executor inset')
 now=.4;s:Tick();assert(#events==count+2 and events[#events].state==2 and not s:Busy(),'visible prompt hold ends with matching touch')
 assert(s:Prompt(prompt,{Position=Vector3.zero}));enabled=false;s:Tick();assert(events[#events].state==2,'disable releases prompt touch')
 enabled=true;focused=nil;top={}
 local ghostGui=node('ScreenGui',playerGui);ghostGui.Name='GhostTraderUI'
 local ui=node('Frame',ghostGui);ui.Name='UI'
 local continue=node('TextButton',ui);continue.Name='Continue';continue.Interactable=false
 top={continue};assert(s:TapGhostContinue(continue),'native noninteractable continue allows stationary world touch')
 assert(events[#events].state==0 and events[#events].x==40 and events[#events].y==120,'continue GUI coordinates add begin inset')
 s:Release();assert(events[#events].state==2,'continue touch ends normally')
 presentation=false;assert(not s:TapGhostContinue(continue),'continue requires active native view');presentation=true
 continue.Visible=false;assert(not s:TapGhostContinue(continue),'hidden continue cannot touch world');continue.Visible=true
 continue.Name='Other';assert(not s:TapGhostContinue(continue),'other native targets cannot touch world');continue.Name='Continue'
 top={node('TextButton',screen),continue};assert(not s:TapGhostContinue(continue),'foreign button blocks continue touch')
 top={continue};core={node('TextButton',screen)};assert(not s:TapGhostContinue(continue),'CoreGui blocks continue touch');core={}
 top={};core={};local pumpkinGui=node('ScreenGui',playerGui);pumpkinGui.Name='PumpkinTap'
 local tapLabel=node('TextLabel',pumpkinGui);tapLabel.Name='Tap';tapLabel.Active=false
 assert(s:TapPumpkin(tapLabel),'native pumpkin reveal receives ordinary touch')
 s:Release();tapLabel.Name='Other';assert(not s:TapPumpkin(tapLabel),'arbitrary labels cannot trigger presentation taps')
 local shade=node('Frame',screen);button.Parent=shade;local flash=node('TextLabel',shade);flash.Active=false
 top={flash,label};assert(s:Tap(button),'passive sibling above target does not turn its shared shade into an obstruction');s:Release()
 top={flash,node('TextButton',shade),label};assert(not s:Tap(button),'shared shade cannot conceal an unrelated active button');button.Parent=screen
 local identity=2;local elevatedEvents=0
 top={label}
 local guarded=factory({clock=function()return now end,enabled=function()return true end,
  identityGet=function()return identity end,identitySet=function(value)identity=value end,
  playerGui={GetGuiObjectsAtPosition=function()return{label}end},
  coreGui={GetGuiObjectsAtPosition=function()assert(identity==8,'callback needs native UI permissions');return{}end},
  input={GetFocusedTextBox=function()end},guiService={MenuIsOpen=false,GetGuiInset=function()return Vector2.zero end},
  virtualInput={SendTouchEvent=function()assert(identity==8,'touch send needs native UI permissions');elevatedEvents=elevatedEvents+1 end}})
 assert(guarded:Tap(button)and identity==2,'heartbeat input context is restored after sending native touch')
 guarded:Release();assert(elevatedEvents==2 and identity==2,'paired touch end restores callback context too')
 return {touch='passed',obstructions='passed',cards='passed',prompts='passed'}
end
