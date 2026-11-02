return function(source)
 local a,b=source:find('local function createPreferences(api,services)',1,true)
 assert(a,'preferences factory missing')
 local ending=assert(source:find('runner.preferences=createPreferences',b,true))
 local factory=assert(loadstring(source:sub(a,ending-1)..'\nreturn createPreferences'))()
 local Http=game:GetService('HttpService');local now,writes=0,0;local data={};local starts,stops=0,0
 local api={Enabled=false,StopEverything=false}
 function api:ExportProfile()return {version=1,stopEverything=self.StopEverything,userId=123,settings={HeroThreshold=self.threshold or 5}}end
 function api:ApplyProfile(p)assert(p.version==1 and p.userId==123,'bad profile');self.StopEverything=p.stopEverything;self.threshold=p.settings.HeroThreshold end
 function api:Start()self.Enabled=true;self.StopEverything=false;starts=starts+1 end
 function api:Stop()self.Enabled=false;self.StopEverything=true;stops=stops+1 end
 local services={userId=123,clock=function()return now end,encode=function(v)return Http:JSONEncode(v)end,decode=function(v)return Http:JSONDecode(v)end,
 exists=function(path)return data[path]~=nil end,read=function(path)assert(data[path],'missing');return data[path]end,write=function(path,v)writes=writes+1;data[path]=v end,folder=function()end}
 local p=factory(api,services);p:Boot();assert(api.Enabled and starts==1,'first load starts')
 api.threshold=8;p:Tick();now=1;p:Tick();assert(writes==1,'debounced automatic save')
 api:Stop();p:Save();assert(writes==2,'saved stop')
 local q=factory(api,services);q:Boot();assert(not api.Enabled and api.threshold==8 and stops>=2,'restores stopped state and settings')
 data[q.path]='invalid';api.Enabled=false;local r=factory(api,services);r:Boot();assert(not api.Enabled and api.SettingsError,'corrupt profile fails closed')
 local read=services.read;services.read=function()error('permission denied')end
 api.Enabled=false;local unreadable=factory(api,services);unreadable:Boot();assert(not api.Enabled and unreadable.corrupt,'unreadable existing settings fail closed')
 local unchanged=writes;assert(not unreadable:Save()and writes==unchanged,'unreadable settings preserved')
 services.read=read
 local before=writes;r.suspended=true;api.threshold=9;now=4;r:Tick();assert(writes==before,'test suspension no writes')
 services.write=function()error('disk full')end;local bad=factory(api,services);bad.ready=true;assert(not bad:Save()and api.SettingsError,'write error reported')
 return {autoload='passed',autosave='passed',stopPersistence='passed',corruption='passed',storageFailure='passed'}
end
