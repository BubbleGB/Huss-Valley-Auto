return function(source)
 local a=assert(source:find('local function createUIObstructions',1,true),'obstruction factory missing')
 local b=assert(source:find('runner.createUIObstructions=createUIObstructions',a,true))
 local make=assert(loadstring(source:sub(a,b-1)..'\nreturn createUIObstructions'))()
 local core=Instance.new('Folder');local list=Instance.new('ScreenGui');list.Name='PlayerList';list.Parent=core
 local row=Instance.new('TextButton');row.Parent=list
 local other=Instance.new('TextButton');other.Parent=core
 local hits={row};local on=true;local now=0;local writes=0
 local guard=make({clock=function()return now end,coreGui=core,hits=function()return hits end,
  starter={GetCoreGuiEnabled=function()return on end,SetCoreGuiEnabled=function(_,_,value)on=value;writes=writes+1 end}})
 assert(not guard:ClearAt(10,20)and not on,'blocking list closes before touching game controls')
 hits={};assert(guard:ClearAt(10,20),'cleared target is usable')
 now=1;guard:Tick();assert(not on,'short interaction gap keeps list closed')
 now=3;guard:Tick();assert(on and writes==2,'idle restores original list availability')
 hits={other,row};assert(not guard:ClearAt(10,20)and not on,'player list is hidden even when another control is also present');hits={};now=6;guard:Tick();assert(on,'list availability restored after overlapping control')
 hits={other};assert(not guard:ClearAt(10,20)and on and writes==4,'unrelated CoreGui is never hidden')
 on=false;hits={};guard:ClearAt(10,20);guard:Restore();assert(not on,'user-disabled list stays disabled')
 local identity=2;local privileged=true;local secure=make({clock=function()return now end,coreGui=core,hits=function()return{row}end,
  identityGet=function()return identity end,identitySet=function(value)identity=value end,
  starter={GetCoreGuiEnabled=function()assert(identity==8);return privileged end,SetCoreGuiEnabled=function(_,_,value)assert(identity==8);privileged=value end}})
 assert(not secure:ClearAt(0,0)and not privileged and identity==2,'list hides with callback permissions and restores caller identity')
 secure:Restore();assert(privileged and identity==2,'list restores with callback permissions and restores caller identity')
 core:Destroy();return {passed=10}
end
