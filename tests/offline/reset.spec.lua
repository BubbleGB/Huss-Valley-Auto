return function(source)
 local a=assert(source:find('local function createPreferences(api,services)',1,true));local b=assert(source:find('runner.preferences=createPreferences',a,true))
 local make=assert(loadstring(source:sub(a,b-1)..'\nreturn createPreferences'))()
 local function fixture()
  local data={};local api={Settings={AutoSave=false,AutoLoad=true,Feature=true},StopEverything=false}
  function api:ExportProfile()return 'original'end
  function api:DefaultProfile()return 'defaults'end
  function api:ApplyProfile()error('failed reset must not apply defaults')end
  local p;local services={userId=1,clock=function()return 0 end,encode=function(v)return v end,
   exists=function(path)return data[path]~=nil end,read=function(path)return data[path]end,
   write=function(path,value)if path==p.optionsPath then error('options write failed')end;data[path]=value end,
   remove=function(path)data[path]=nil end}
  p=make(api,services);p.ready=true;data[p.optionsPath]='existing-autoload-policy'
  return p,api,data,services
 end
 local p,api,data=fixture()
 assert(not p:Reset()and api.Settings.Feature,'failed reset preserves active settings')
 assert(data[p.path]==nil and data[p.optionsPath]=='existing-autoload-policy','failed reset must not leave a new default profile behind an old autoload policy')
 local q,other,files,services=fixture()
 services.write=function(path,value)files[path]=value;if path==q.path then error('partial profile write')end end
 assert(not q:Reset()and other.Settings.Feature,'partial write failure preserves runtime')
 assert(files[q.path]==nil and files[q.optionsPath]=='existing-autoload-policy','rollback deletes newly created profile and restores prior options')
 local broken,live,bytes,storage=fixture();storage.remove=nil
 storage.write=function(path,value)bytes[path]=value;if path==broken.path then error('partial profile write')end end
 assert(not broken:Reset()and broken.corrupt and live.Settings.Feature,'unrecoverable storage rollback blocks automatic overwrites')
 return {passed=5}
end
