return function(source)
 local first=assert(source:find('local function createClientMetrics(services)',1,true),'client metrics factory missing')
 local last=assert(source:find('runner.createClientMetrics=createClientMetrics',first,true))
 local make=assert(loadstring(source:sub(first,last-1)..'\nreturn createClientMetrics'))()
 local now,calls=0,0;local stats={FrameTime=.02,RenderCPUFrameTime=.005,RenderGPUFrameTime=.008,DataSendKbps=3,DataReceiveKbps=7,InstanceCount=500,SceneDrawcallCount=80}
 function stats:GetTotalMemoryUsageMb()calls=calls+1;return 1234 end
 local player={GetNetworkPing=function()return .09 end}
 local m=make({clock=function()return now end,stats=stats,player=player})
 local n=0;local function check(v,msg)assert(v,msg);n=n+1 end
 local r=m:Read();check(r.pingMS==90 and r.frameMS==20,'ping and frame seconds convert once')
 check(r.cpuMS==5 and r.gpuMS==8 and r.memoryMB==1234,'render timing and Roblox memory have accurate units')
 check(r.sendKBps==3 and r.receiveKBps==7 and r.instances==500 and r.drawCalls==80,'traffic and scene counters')
 r.memoryMB=0;check(m:Read().memoryMB==1234 and calls==1,'cached snapshot is isolated')
 now=1;stats.RenderGPUFrameTime=0/0;stats.FrameTime=math.huge;player.GetNetworkPing=function()error('unavailable')end
 r=m:Read();check(r.gpuMS==nil and r.frameMS==nil and r.pingMS==nil,'invalid or unavailable samples stay unknown')
 check(calls==2 and r.cpuPercent==nil and r.gpuPercent==nil and r.temperature==nil,'no fabricated hardware readings')
 local text=m:Text();check(text:find('unavailable',1,true)and text:find('Roblox memory',1,true),'display labels unknown readings and memory scope')
 return {passed=n}
end
