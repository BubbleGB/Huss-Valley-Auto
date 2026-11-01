-- Run actual input closures with recorded virtual input and a detached GUI.
-- No synthetic keyboard, mouse, or touch reaches the client during this test.
return function(source)
    local core=assert(source:match('(local settingDefaults.-)function Core.priorityRank'))
    local antiSource=assert(source:match('(local function finishTouch.-)api.Settings=Core.defaultSettings'))
    local idle=assert(source:match('connect%(player.Idled,function%(%)%s*(.-)%s*end%)%s*connect%(package.Weapons'))
    local fixture=[[
local Core={};local api={Enabled=true}
local anti={buttons={},touches={},idleConnections={},nextScan=math.huge,nextAFK=math.huge,nextTouch=0}
local desktopCalls=0;local events={};local function forbidden()desktopCalls=desktopCalls+1;error('keyboard/mouse input forbidden')end
local VirtualInput={SendKeyEvent=forbidden,SendMouseButtonEvent=forbidden,
 SendTouchEvent=function(_,id,state,x,y)events[#events+1]={id=id,state=state,x=x,y=y}end}
local VirtualUser={CaptureController=forbidden,ClickButton2=forbidden}
local guiInset=Vector2.new(4,58)
local focused;local Input={GetFocusedTextBox=function()return focused end};local GuiService={MenuIsOpen=false,GetGuiInset=function()return guiInset,Vector2.zero end}
local ContextActions={BindActionAtPriority=function()end,UnbindAction=function()end}
local hudNavigation={handlers={}};local binding='Fixture';local random=Random.new(7)
local gui=Instance.new('ScreenGui');gui.Enabled=true
local sink={Active=true,Visible=false,Interactable=true,Parent=gui,AbsolutePosition=Vector2.new(40,40),AbsoluteSize=Vector2.new(16,16),
 IsA=function(_,kind)return kind=='GuiObject'or kind=='GuiButton'end,IsDescendantOf=function(_,owner)return owner==gui end}
local runner={keepAliveSurface=sink}
local top=sink
local player={GetAttribute=function()end,PlayerGui={GetDescendants=function()return {}end,
 GetGuiObjectsAtPosition=function(_,x,y)assert(x==48 and y==48,'hit testing must use logical GUI coordinates');return top and{top}or{}end}}
local workspace={CurrentCamera={ViewportSize=Vector2.new(900,600)}}
local coreObjects={};local coreQueryFails=false
local game={GetService=function()return {GetGuiObjectsAtPosition=function(_,x,y)assert(x==48 and y==48,'CoreGui hit testing must use logical coordinates');if coreQueryFails then error('fixture: CoreGui unavailable')end;return coreObjects end}end}
Core.blocksTouch=function(object)return object.Active end
Core.keepAliveDue=function(enabled,now,due,busy)return enabled and now>=due and not busy end
]]
    local probe=[[
api.Settings=Core.defaultSettings();anti.scanIdle=function()anti.nextScan=math.huge end
local count=0;local function check(ok,msg)assert(ok,msg);count=count+1 end
local ok,err=pcall(function()
antiStart();check(sink.Visible,'Start must show the owned touch sink');anti.nextTouch=0
keepAliveTick()
check(desktopCalls==0,'keepalive must never attempt keyboard or mouse input')
check(#events==1 and events[1].state==0 and events[1].x==52 and events[1].y==106,'touch send coordinates must include current GUI inset for the owned sink')
anti.touch.ends=0;guiInset=Vector2.new(12,90)
keepAliveTick()
check(#events==2 and events[2].state==2,'keepalive must end without a drag/move event')
check(events[1].id==events[2].id and events[1].x==events[2].x and events[1].y==events[2].y,'begin/end must use identical coordinates')
guiInset=Vector2.new(4,58)
check(api.TouchPulses==1,'completed stationary pulse must be counted')
local function blocked(message)
 anti.nextTouch=0;keepAliveTick();check(#events==2,message)
end
runner.keepAliveSurface=nil;blocked('missing sink must not fall back to world canvas');runner.keepAliveSurface=sink
sink.Visible=false;blocked('hidden sink must not receive touch');sink.Visible=true
sink.Active=false;blocked('inactive sink must not receive touch');sink.Active=true
coreObjects={{Active=true}};blocked('CoreGui input blocker must defer touch');coreObjects={}
coreQueryFails=true;blocked('failed CoreGui inspection must defer touch');coreQueryFails=false
check(api:AntiAFKReport().inputError~=nil,'failed protected UI inspection must be reported')
local overlay=Instance.new('TextButton');top=overlay
blocked('topmost foreign active control must block touch');top=nil
blocked('unregistered sink must not receive world touch');top=sink;overlay:Destroy()
GuiService.MenuIsOpen=true;blocked('menu must defer touch');GuiService.MenuIsOpen=false
focused={};blocked('typing must defer touch');focused=nil
anti.touches.real=true;blocked('real touches must defer touch');anti.touches.real=nil
anti.nextTouch=10;fixtureIdle()
check(anti.nextTouch==0 and api.IdleGuardFires==1 and desktopCalls==0,'Idled must schedule touch without desktop input')
keepAliveTick();check(#events==3,'safe sink must resume touch after busy state clears')
antiStop();check(not sink.Visible,'Stop must hide owned sink');check(#events==4 and events[4].state==2 and anti.touch==nil,'Stop must end an owned touch')
api.Settings.AntiAFK=false;antiStart();check(not sink.Visible,'disabled AntiAFK must keep sink hidden');check(not api:AntiAFKReport().enabled,'diagnostics must report effective AntiAFK state')
anti.nextTouch=0;keepAliveTick();check(#events==4,'disabled AntiAFK must inject nothing')
api.Settings.AntiAFK=true;api.Enabled=false;antiStart();check(not sink.Visible,'master off must keep sink hidden');keepAliveTick()
check(#events==4 and not api:AntiAFKReport().enabled,'master off must inject nothing')
end)
antiStop();gui:Destroy();assert(ok,err)
return {passed=count,touchOnly='passed',stationary='passed',ownedSink='passed',busyDeferral='passed'}
]]
    return assert(loadstring(fixture..core..antiSource..'\nlocal function fixtureIdle()\n'..idle..'\nend\n'..probe))()
end
