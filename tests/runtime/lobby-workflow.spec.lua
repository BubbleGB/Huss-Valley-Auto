-- Pure factory extraction; fake services never access native input, menus, or controllers.
return function(source)
 local first=assert(source:find('local function createLobbyWorkflow(',1,true),'workflow factory missing')
 local last=assert(source:find('runner.createLobbyWorkflow=createLobbyWorkflow',first,true))
 local create=assert(loadstring(source:sub(first,last-1)..'\nreturn createLobbyWorkflow'))()
 local passed=0
 local function check(value,message)assert(value,message);passed=passed+1 end
 local function fixture()
  local f={now=0,on=true,ready=true,allowed=true,reached=false,view={visible=false},events={},operations={},changes={},halts=0}
  f.jobs={{key='spin',kind='spins',name='Spins',cooldown=10},{key='journey',kind='journey',name='Journey',cooldown=10}}
  local function event(kind,job,token)f.events[#f.events+1]={kind=kind,key=job.key,token=token};return f.sent~=false end
  f.workflow=create({clock=function()return f.now end,enabled=function()return f.on end,
   ready=function(job)return f.ready end,allowed=function(job)return f.allowed and job.blocked~=true end,
   jobs=function()return f.jobs end,reach=function(job)event('reach',job);return f.reached,f.reason end,
   open=function(job)return event('open',job)end,inspect=function(job)return f.view end,
   act=function(job,token)return event('act',job,token)end,close=function(job)return event('close',job)end,
   halt=function()f.halts=f.halts+1 end,operation=function(text,action,target)f.operations[#f.operations+1]={text,action,target}end,
   changed=function(job,active)f.changes[#f.changes+1]={job.key,active}end})
  function f:tick(at)self.now=at;return self.workflow:Tick()end
  function f:count(kind)local n=0;for _,e in ipairs(self.events)do if e.kind==kind then n=n+1 end end;return n end
  function f:start()self.reached=true;self:tick(0);self:tick(.21);self.view={visible=true};self:tick(.42)end
  return f
 end
 -- Removing the reach gate would emit opening input while walking.
 local f=fixture();f:tick(0)
 check(f:count('reach')==1,'first tick starts walking to an eligible station')
 check(f:count('open')==0 and f:count('act')==0,'no input before reaching station')
 check(f.workflow:Report().active==true,'report exposes active navigation')
 check(f.operations[#f.operations][2]=='walking','navigation operation uses walk label')
 f:tick(.1);check(f:count('reach')==1,'scheduler throttles sub-.2s ticks')
 f.reached=true;f:tick(.21);check(f:count('open')==1,'reached station receives native open')
 f:tick(.42);check(f:count('open')==1,'open input waits .6s between attempts')
 f:tick(.83);check(f:count('open')==2,'invisible menu retries bounded open')
 f.view={visible=true,action='spin10',description='Spin 10'};f:tick(1.44)
 check(f:count('act')==1 and f.events[#f.events].token=='spin10','visible action token forwarded exactly')
 f.view={visible=true,waiting=true,action='spin10'};f:tick(2.1);f:tick(4)
 check(f:count('act')==1,'waiting snapshot forbids blind duplicate input')
 f.view={visible=true,done=true};f:tick(4.3)
 check(f:count('close')==1,'done menu receives native close')
 check(f.workflow:Report().active,'closing remains serial until menu disappears')
 f:tick(5);check(f.workflow:Report().key=='spin','visible menu retains job ownership')
 f.view={visible=false};f:tick(5.3)
 check(not f.workflow:Report().active and f.changes[#f.changes][2]==false,'observed close releases job')
 f:tick(5.6);check(f.workflow:Report().key=='journey','next eligible job receives fair turn')
 -- Removing immediate guards would leak close/action input after Stop, lobby exit or feature disable.
 for _,guard in ipairs({'on','ready','allowed'})do
  local g=fixture();g:start();g.view={visible=true,done=true};g[guard]=false;g:tick(.43)
  check(g:count('close')==0 and g:count('act')==0,'guard cancels even before next scheduled tick: '..guard)
  check(g.halts>0 and not g.workflow:Report().active,'guard releases input/navigation: '..guard)
 end
 local g=fixture();g:start();g.workflow:Cancel('Stopped');g.view={visible=true,done=true}
 check(g:count('close')==0 and not g.workflow:Report().active and g.halts>0,'Cancel releases without new close input')
 g=fixture();g.reached=true;g:tick(0);g:tick(8.1)
 check(not g.workflow:Report().active and g.halts>0,'opening has bounded eight-second deadline')
 g:tick(8.4);check(g.workflow:Report().key=='journey','timed-out job backs off without starving next job')
 g=fixture();g:tick(0);g:tick(60.1)
 check(not g.workflow:Report().active and g.halts>0,'walking cannot own workflow beyond sixty seconds')
 g=fixture();g:start();g.view={visible=true,done=true};g:tick(1);g:tick(9.1)
 check(not g.workflow:Report().active and g.halts>0,'closing has bounded eight-second deadline')
 g=fixture();g.jobs[1].blocked=true;g:tick(0)
 check(g.workflow:Report().key=='journey','disabled feature skipped during selection')
 g=fixture();g.jobs={g.jobs[1]};g:start();g.view={visible=true,done=true};g:tick(1);g.view={visible=false};g:tick(1.3);g:tick(2)
 check(not g.workflow:Report().active,'completed job observes configured cooldown')
 g:tick(11.5);check(g.workflow:Report().key=='spin','job becomes eligible after cooldown')
 g=fixture();g.sent=false;g.reached=true
 check(not g:tick(0),'rejected native input never reports sent')
 g:tick(.21);check(g:count('open')==1,'rejected open also observes input interval')
 g=fixture();g:start();g.view={visible=false,action='unsafe'};g:tick(1)
 check(g:count('act')==0,'hidden menu action never runs')
 g=fixture();g:start();g.view={visible=true,waiting=true,done=true};g:tick(1)
 check(g:count('act')==0 and g:count('close')==0,'waiting wins over stale done/action flags')
 -- Unexpected menu disappearance must respect a user's close instead of reopening.
 g=fixture();g.jobs={g.jobs[1]};g:start();g.view={visible=false,action='spin10'};g:tick(1)
 check(not g.workflow:Report().active and g.halts>0,'unexpected hidden menu ends the active job')
 g:tick(1.3);check(g:count('open')==1 and g:count('act')==0,'user-close receives backoff instead of reopening')
 -- Overall expiry owns cleanup while the native menu is visible, with its own bound.
 g=fixture();g:start();g.view={visible=true,action='spin10'};g:tick(60.1)
 check(g.workflow:Report().phase=='closing' and g.workflow:Report().active,'overall deadline transitions a visible menu to closing')
 check(g:count('close')==1 and g:count('act')==0,'expiry closes visible menu without another action')
 g:tick(61);check(g.workflow:Report().active and g:count('close')==2,'sixty-second deadline does not cancel cleanup')
 g.view={visible=false};g:tick(61.3)
 check(not g.workflow:Report().active,'expiry cleanup completes after observed menu close')
 g=fixture();g:start();g.view={visible=true,waiting=true,action='spin10'};g:tick(60.1);g:tick(64)
 check(g.workflow:Report().phase=='closing' and g:count('close')==0,'expiry cleanup waits for native presentation')
 g.view.waiting=false;g:tick(65)
 check(g:count('close')==1,'expiry cleanup closes once native presentation is ready')
 g:tick(68.2)
 check(not g.workflow:Report().active,'expiry cleanup has a separate eight-second bound')
 for _,guard in ipairs({'on','ready','allowed'})do
  g=fixture();g:start();g.view={visible=true,waiting=true};g:tick(60.1);g[guard]=false;g:tick(60.11)
  check(not g.workflow:Report().active and g:count('close')==0,'cleanup still cancels immediately on guard: '..guard)
 end
 return {passed=passed}
end
