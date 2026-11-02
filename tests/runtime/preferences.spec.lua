return function(source)
 local a,b=source:find('local function createPreferences(api,services)',1,true)
 assert(a,'preferences factory missing')
 local ending=assert(source:find('runner.preferences=createPreferences',b,true))
 local factory=assert(loadstring(source:sub(a,ending-1)..'\nreturn createPreferences'))()
 local Http=game:GetService('HttpService')
 local function fixture()
  local f={now=0,writes=0,reads=0,data={},starts=0,stops=0,applies=0}
  local api={Settings={AutoSave=false,AutoLoad=false},StopEverything=false}
  function api:DefaultProfile()return {version=2,userId=123,stopEverything=false,settings={AutoSave=false,AutoLoad=false,Feature=false}}end
  function api:ExportProfile()return {version=2,userId=123,stopEverything=self.StopEverything,settings={AutoSave=self.Settings.AutoSave,AutoLoad=self.Settings.AutoLoad,Feature=self.Settings.Feature==true}}end
  function api:ApplyProfile(p)
   assert(p.version==2 and p.userId==123 and type(p.settings)=='table','bad profile')
   self.StopEverything=p.stopEverything;self.Settings=p.settings;f.applies=f.applies+1
   if f.p then f.p:OptionsChanged()end
  end
  function api:Start()self.Enabled=true;self.StopEverything=false;f.starts=f.starts+1 end
  function api:Stop()self.Enabled=false;self.StopEverything=true;f.stops=f.stops+1 end
  local services={userId=123,clock=function()return f.now end,encode=function(v)return Http:JSONEncode(v)end,decode=function(v)return Http:JSONDecode(v)end,
   exists=function(path)return f.data[path]~=nil end,read=function(path)f.reads=f.reads+1;assert(f.data[path],'missing');return f.data[path]end,
   write=function(path,v)if f.failPath==path then error('disk full')end;f.writes=f.writes+1;f.data[path]=v end,folder=function()end}
  f.api=api;f.services=services;f.p=factory(api,services)
  function f:put(path,value)self.data[path]=Http:JSONEncode(value)end
  function f:tick()self.p:Tick();self.now=self.now+1;self.p:Tick()end
  return f
 end
 local f=fixture();f.p:Boot();assert(f.api.Enabled and f.starts==1,'fresh defaults start core play')
 f.api.Settings.Feature=true;f:tick();assert(f.writes==0,'autosave defaults off')
 assert(not f.p:Save() and f.writes==0,'unload save obeys autosave off')
 assert(f.p:Save(true) and f.writes==1,'manual save writes with autosave off')
 local skip=fixture();skip.data[skip.p.path]='invalid';skip.p:Boot();assert(skip.api.Enabled and skip.reads==0,'autoload off ignores corrupt unused profile')
 local on=fixture();on.p:Boot();on.api.Settings.Feature=true;on.api.Settings.AutoLoad=true
 assert(on.p:OptionsChanged(),'enable autoload');assert(on.data[on.p.path] and on.data[on.p.optionsPath],'enable autoload saves profile and policy')
 local restart=factory(on.api,on.services);on.p=restart;on.api.Settings.Feature=false;restart:Boot();assert(on.api.Settings.Feature and on.applies==1,'explicit autoload restores profile')
 on.api.Settings.AutoSave=true;assert(restart:OptionsChanged());local before=on.writes;on.api.Settings.Feature=false;on:tick();assert(on.writes==before+1,'autosave debounces profile change')
 local manual=fixture();manual.p:Boot();manual:put(manual.p.path,{version=2,userId=123,stopEverything=true,settings={AutoSave=false,AutoLoad=true,Feature=true}})
 assert(manual.p:Load() and manual.api.Settings.Feature and not manual.api.Enabled,'manual load works with autoload off and restores stop')
 local bad=fixture();bad:put(bad.p.optionsPath,{version=1,userId=123,autoSave=false,autoLoad=true});bad.data[bad.p.path]='invalid';bad.p:Boot()
 assert(bad.p.corrupt and not bad.api.Enabled and bad.api.SettingsError,'requested corrupt autoload fails closed')
 local writes=bad.writes;assert(not bad.p:Save() and bad.writes==writes,'autosave preserves corrupt bytes');assert(bad.p:Save(true),'explicit save can replace corrupt profile')
 local opts=fixture();opts.data[opts.p.optionsPath]='invalid';opts.p:Boot();assert(opts.p.corrupt and not opts.api.Enabled,'corrupt policy fails closed')
 local unreadable=fixture();unreadable:put(unreadable.p.optionsPath,{version=1,userId=123,autoSave=false,autoLoad=true});unreadable.data[unreadable.p.path]='unreadable'
 local originalRead=unreadable.services.read;unreadable.services.read=function(path)if path==unreadable.p.path then error('permission denied')end;return originalRead(path)end
 unreadable.p:Boot();assert(unreadable.p.corrupt and not unreadable.api.Enabled and unreadable.writes==0,'unreadable requested profile fails closed without overwrite')
 local account=fixture();account:put(account.p.optionsPath,{version=1,userId=999,autoSave=true,autoLoad=true});account.p:Boot();assert(account.p.corrupt and not account.api.Enabled,'another account policy rejected')
 local invalid=fixture();invalid.p:Boot();invalid.api.Settings.Feature=true;invalid:put(invalid.p.path,{version=2,userId=999,settings={Feature=false}})
 assert(not invalid.p:Load() and invalid.api.Settings.Feature and invalid.api.Enabled,'invalid manual load preserves runtime')
 local errors=fixture();errors.p:Boot();errors.api.Settings.AutoSave=true;assert(errors.p:OptionsChanged());errors.api.Settings.Feature=true;errors.failPath=errors.p.path;errors:tick()
 assert(errors.api.SettingsError and errors.data[errors.p.path]==nil,'autosave reports storage failure');errors.failPath=nil;errors.now=12;errors.p:Tick();assert(errors.data[errors.p.path],'autosave retries after backoff')
 local reset=fixture();reset.p:Boot();reset.api.Settings.Feature=true;assert(reset.p:Save(true));local old=reset.data[reset.p.path]
 reset.failPath=reset.p.optionsPath;assert(not reset.p:Reset() and reset.api.Settings.Feature and reset.data[reset.p.path]==old,'failed reset preserves runtime and previous profile')
 reset.failPath=nil;assert(reset.p:Reset() and not reset.api.Settings.Feature and reset.api.Enabled,'reset persists then restores default running state')
 assert(Http:JSONDecode(reset.data[reset.p.path]).settings.Feature==false and Http:JSONDecode(reset.data[reset.p.optionsPath]).autoLoad==false,'reset replaces both files even autosave off')
 local suspended=fixture();suspended.p.suspended=true;suspended.p:Boot();assert(not suspended.p:Save(true) and not suspended.p:Load() and not suspended.p:Reset(),'suspension blocks manual actions');suspended.api.Settings.AutoLoad=true;suspended.p:OptionsChanged();suspended:tick();assert(suspended.writes==0 and suspended.reads==0 and suspended.applies==0,'suspended tests never touch storage/runtime')
 return {defaults='passed',policy='passed',autosave='passed',autoload='passed',manual='passed',reset='passed',corruption='passed',suspension='passed'}
end
