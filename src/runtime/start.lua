setProfileGetter(speedProfileGet)
env.HussAutoCross=api
runner.preferences:Boot()
return api
end
local ready,result=xpcall(initialize,function(err)return debug.traceback(tostring(err),2)end)
if not ready then
    if startupCleanup then pcall(startupCleanup)end
    error(result,0)
end
return result
