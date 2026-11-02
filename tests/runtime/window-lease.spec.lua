return function(source)
 local first=assert(source:find('local function createWindowLease',1,true),'window lease factory missing')
 local last=assert(source:find('runner.createWindowLease=createWindowLease',first,true))
 local make=assert(loadstring(source:sub(first,last-1)..'\nreturn createWindowLease'))()
 local restores,minimizes=0,0
 local ui={Minimized=false,Minimize=function(self)self.Minimized=true;minimizes=minimizes+1 end,Restore=function(self)self.Minimized=false;restores=restores+1 end}
 local lease=make(function()return ui end)
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 check(not lease:Acquire('prompt')and ui.Minimized,'first input waits for window to minimize')
 check(lease:Acquire('progression'),'progression shares already clear window')
 lease:Release('prompt');check(ui.Minimized and restores==0,'prompt completion cannot expose window over active progression')
 lease:Release('progression');check(not ui.Minimized and restores==1,'last owner restores original open state')
 lease:Acquire('progression');lease:Acquire('prompt');lease:Release('progression')
 check(ui.Minimized,'progression completion cannot expose window over active prompt')
 lease:Release('prompt');check(restores==2,'reverse completion restores exactly once')
 ui.Minimized=true;lease:Acquire('prompt');lease:Release('prompt');check(ui.Minimized and restores==2,'user minimized state stays minimized')
 ui.Minimized=false;lease:Acquire('prompt');ui.Cleaned=true;lease:Release('prompt');check(restores==2,'dead windows cannot be restored')
 return {passed=n}
end
