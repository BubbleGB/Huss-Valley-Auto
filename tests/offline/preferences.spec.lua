return function(source)
 local a=assert(source:find('local function createPreferences(api,services)',1,true))
 local b=assert(source:find('runner.preferences=createPreferences',a,true))
 local factory=assert(loadstring(source:sub(a,b-1)..'\nreturn createPreferences'))()
 local now,encodes,writes=0,0,0
 local api={Settings={AutoSave=true,AutoLoad=false}}
 function api:ExportProfile()return {settings=self.Settings}end
 function api:Start()self.Enabled=true end
 function api:Stop()self.Enabled=false end
 local p=factory(api,{userId=1,clock=function()return now end,exists=function()return false end,
  encode=function()encodes+=1;return api.Settings.Feature and 'changed' or 'same'end,
  write=function()writes+=1 end})
 p:Boot();api.Settings.AutoSave=true
 local initial=encodes
 for i=0,60 do now=i/60;p:Tick()end
 assert(encodes-initial<=6,'unchanged profiles must not serialize every Heartbeat')
 api.Settings.Feature=true
 for i=61,120 do now=i/60;p:Tick()end
 assert(writes==1,'sampled autosave still persists changed settings after its debounce')
 local count=encodes;p.suspended=true
 for i=121,180 do now=i/60;p:Tick()end
 assert(encodes==count,'suspended storage performs no serialization')
 return {passed=3}
end
