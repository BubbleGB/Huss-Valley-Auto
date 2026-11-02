-- Isolated native-shaped snapshots and fake send only; no live remote or menu access.
return function(source)
 local first=assert(source:find('local function createGhostTrader(',1,true))
 local last=assert(source:find('runner.createGhostTrader=createGhostTrader',first,true))
 local create=assert(loadstring(source:sub(first,last-1)..'\nreturn createGhostTrader'))()
 local passed=0
 local function check(value,message)assert(value,message);passed=passed+1 end
 local function fixture()
  local f={now=0,epoch=1000,on=false,ready=true,requests={},operations={}}
  f.trader=create({enabled=function()return f.on end,ready=function()return f.ready end,
   clock=function()return f.now end,serverTime=function()return f.epoch end,cards=6,
   random=function(count)return count end,
   send=function(command,slot)f.requests[#f.requests+1]={command,slot};return f.accept~=false end,
   operation=function(text,action,target,ttl)f.operations[#f.operations+1]={text,action,target,ttl}end})
  function f:state(changes)
   local s={live=true,restricted=false,keys=16,nextAt=1000,deal=1,opened={false,false,true,false,false,false},won={},cursed=0}
   for k,v in pairs(changes or{})do s[k]=v end
   self.trader:Receive('State',s);return s
  end
  function f:start()self.on=true;check(self.trader:Tick(),'enabled requests State');check(self.requests[1][1]=='State','first dispatch is State')end
  return f
 end
 local f=fixture();f:state();check(not f.trader:Tick()and #f.requests==0,'default off never sends')
 f:start();check(not f.trader:Tick()and #f.requests==1,'await State before spending')
 f:state();f.now=2;check(f.trader:Tick(),'fresh eligible snapshot flips')
 check(f.requests[2][1]=='Flip'and f.requests[2][2]==6,'Flip selects unopened integer slot')
 f.now=4;f:state();check(not f.trader:Tick()and #f.requests==2,'unchanged unsolicited State cannot confirm pending Flip')
 f.now=10;check(f.trader:Tick()and f.requests[3][1]=='State','timeout refreshes State instead of retrying Flip')
 check(not f.trader:Tick(),'wait for refresh reply')
 f:state({keys=15,opened={false,false,true,false,false,true}});f.now=12
 check(f.trader:Tick()and f.requests[4][2]==5,'confirmed opened slot excluded on next Flip')
 f.trader:Receive('Result',{reward={id='fixture'},state={live=true,restricted=false,keys=0,nextAt=1000,deal=1,opened={false,false,true,false,true,true},won={},cursed=0}})
 f.now=14;check(not f.trader:Tick(),'key depletion stops spending')
 local report=f.trader:Report();check(type(report)=='table'and type(report.status)=='string','report explains current state')
 for _,change in ipairs({{live=false},{restricted=true},{keys=0},{keys=-1},{keys=0/0},{nextAt=1005},{opened={true,true,true,true,true,true}},{opened={}},{deal=false}})do
  local g=fixture();g:start();g:state(change);g.now=2
  check(not g.trader:Tick()and #g.requests==1,'ineligible native state blocks Flip')
 end
 local g=fixture();g:start();g:state({nextAt=1005});g.now=6;g.epoch=1006
 check(g.trader:Tick()and g.requests[2][1]=='State','cooldown expiry refreshes authoritative state')
 g=fixture();g:start();g:state();g.now=31
 check(g.trader:Tick()and g.requests[2][1]=='State','stale snapshots require refresh')
 for _,field in ipairs({'on','ready'})do
  g=fixture();g:start();g:state();g[field]=false;g.now=2
  check(not g.trader:Tick()and #g.requests==1,'stop or lobby guard blocks sends')
  g:state();g[field]=true;g.now=4
  check(g.trader:Tick()and g.requests[2][1]=='State','resume requires fresh snapshot')
 end
 g=fixture();g:start();g:state();g.now=2;g.trader:Tick()
 g.trader:Receive('Result',{reward={id='fixture'}});g.now=4
 check(not g.trader:Tick()and #g.requests==2,'malformed Result does not unlock spending')
 g.trader:Receive('Notice','Too far away');g.now=5
 check(not g.trader:Tick(),'native Notice backs off')
 check(g.trader:Report().status:find('Too far away',1,true),'native rejection remains truthful')
 g.now=25;check(g.trader:Tick()and g.requests[#g.requests][1]=='State','Notice recovers with State refresh')
 -- A delayed Result for card 6 must not confirm a newer Flip of card 5.
 g=fixture();g:start();g:state();g.now=2;g.trader:Tick()
 local result={reward={id='fixture'},state={live=true,restricted=false,keys=15,nextAt=1000,deal=1,opened={false,false,true,false,false,true},won={},cursed=0}}
 g.trader:Receive('Result',result);g.now=4
 check(g.trader:Tick()and g.requests[3][2]==5,'native Result confirms the requested card')
 g.trader:Receive('Result',result);g.now=6
 check(not g.trader:Tick()and #g.requests==3,'delayed duplicate Result cannot confirm another card')
 g=fixture();g.accept=false;g.on=true
 check(not g.trader:Tick(),'rejected send is not reported dispatched')
 check(not g.trader:Tick()and #g.requests==1,'failed send backs off')
 for _,h in ipairs({f,g})do for _,request in ipairs(h.requests)do
  check(request[1]=='State'or request[1]=='Flip','never sends paid, Enter, or Skip commands')
 end end
 return {passed=passed}
end
