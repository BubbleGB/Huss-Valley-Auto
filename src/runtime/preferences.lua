local function createPreferences(api,services)
    local preferences={path='HussValleyAutoUI/settings-'..services.userId..'.json',ready=false}
    function preferences:Save()
        if self.suspended or self.corrupt or not self.ready or api.Destroyed then return false end
        local ok,err=pcall(function()
            assert(type(services.write)=='function','Settings storage is unavailable')
            if services.folder then pcall(services.folder,'HussValleyAutoUI')end
            local encoded=services.encode(api:ExportProfile())
            services.write(self.path,encoded)
            self.saved=encoded;self.changedAt=nil
        end)
        api.SettingsError=not ok and tostring(err)or nil
        return ok
    end
    function preferences:Boot()
        if self.suspended then return end
        local valid,err,present=true,nil,true
        if services.exists then
            local ok,value=pcall(services.exists,self.path)
            if ok then present=value==true else valid,err=false,value end
        end
        if valid and present and services.read then
            local loaded,raw=pcall(services.read,self.path)
            if loaded then valid,err=pcall(function()api:ApplyProfile(services.decode(raw))end)
            else valid,err=false,raw end
        elseif valid and present and services.exists then
            valid,err=false,'Saved settings exist but cannot be read'
        end
        self.ready=true
        if not valid then
            api:Stop();api.SettingsError='Saved settings could not be loaded: '..tostring(err)
            self.corrupt=true -- preserve the original file until an explicit reset/save
        elseif api.StopEverything then api:Stop()else api:Start()end
        self.saved=services.encode(api:ExportProfile())
    end
    function preferences:Tick()
        if not self.ready or self.suspended or self.corrupt or api.Destroyed then return end
        local encoded=services.encode(api:ExportProfile())
        if encoded==self.saved then self.changedAt=nil;return end
        local now=services.clock()
        self.changedAt=self.changedAt or now
        if now-self.changedAt>=.5 and now>=(self.retryAt or 0)then
            if not self:Save()then self.retryAt=now+10 end
        end
    end
    return preferences
end
runner.preferences=createPreferences(api,{userId=player.UserId,clock=os.clock,
    encode=function(value)return Http:JSONEncode(value)end,decode=function(value)return Http:JSONDecode(value)end,
    exists=type(isfile)=='function'and isfile or nil,
    read=type(readfile)=='function'and readfile or nil,write=type(writefile)=='function'and writefile or nil,
    folder=type(makefolder)=='function'and makefolder or nil})
api.Preferences=runner.preferences
connect(RunService.Heartbeat,function()
    if not api.Destroyed then
        local ok,err=pcall(runner.preferences.Tick,runner.preferences)
        if not ok then api.SettingsError=tostring(err)end
    end
end)
