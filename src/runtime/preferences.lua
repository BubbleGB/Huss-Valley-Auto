local function createPreferences(api,services)
    local preferences={path='HussValleyAutoUI/settings-'..services.userId..'.json',
        optionsPath='HussValleyAutoUI/options-'..services.userId..'.json',ready=false,
        policy={autoSave=false,autoLoad=false}}
    local function options(autoSave,autoLoad)
        return {version=1,userId=services.userId,autoSave=autoSave==true,autoLoad=autoLoad==true}
    end
    local function read(path)
        if services.exists then
            if not services.exists(path)then return nil end
        elseif not services.read then return nil end
        assert(type(services.read)=='function','Saved settings exist but cannot be read')
        return services.read(path)
    end
    local function write(path,value)
        assert(type(services.write)=='function','Settings storage is unavailable')
        if services.folder then pcall(services.folder,'HussValleyAutoUI')end
        services.write(path,value)
    end
    local function report(ok,err)
        api.SettingsError=not ok and tostring(err)or nil
        return ok
    end
    local function runState()
        if api.StopEverything then api:Stop()else api:Start()end
    end
    local function setPolicy(policy)
        preferences.policy={autoSave=policy.autoSave,autoLoad=policy.autoLoad}
        api.Settings.AutoSave=policy.autoSave;api.Settings.AutoLoad=policy.autoLoad
    end
    function preferences:Save(force)
        if self.suspended or not self.ready or api.Destroyed or
            (not force and (self.corrupt or not api.Settings.AutoSave))then return false end
        local ok,err=pcall(function()
            local encoded=services.encode(api:ExportProfile())
            write(self.path,encoded)
            self.saved=encoded;self.changedAt=nil;self.corrupt=nil
        end)
        return report(ok,err)
    end
    function preferences:Load()
        if self.suspended or not self.ready or api.Destroyed then return false end
        self.loading=true
        local ok,err=pcall(function()
            local raw=assert(read(self.path),'No saved settings')
            api:ApplyProfile(services.decode(raw))
            setPolicy(self.policy)
            runState()
            self.saved=services.encode(api:ExportProfile());self.changedAt=nil;self.corrupt=nil
        end)
        self.loading=false
        return report(ok,err)
    end
    function preferences:Boot()
        if self.suspended or self.ready or api.Destroyed then return false end
        self.loading=true
        local ok,err=pcall(function()
            local raw=read(self.optionsPath)
            if raw then
                local value=services.decode(raw)
                assert(type(value)=='table'and value.version==1 and value.userId==services.userId
                    and type(value.autoSave)=='boolean'and type(value.autoLoad)=='boolean','Invalid settings options')
                setPolicy(value)
            else setPolicy(options(false,false))end
            if self.policy.autoLoad then
                local profile=read(self.path)
                if profile then api:ApplyProfile(services.decode(profile));setPolicy(self.policy)end
            end
            runState()
            self.saved=services.encode(api:ExportProfile())
        end)
        self.loading=false;self.ready=true
        if not ok then self.corrupt=true;api:Stop()end
        return report(ok,not ok and ('Saved settings could not be loaded: '..tostring(err))or nil)
    end
    function preferences:OptionsChanged()
        if self.suspended or self.loading or not self.ready or api.Destroyed then return false end
        local nextPolicy=options(api.Settings.AutoSave,api.Settings.AutoLoad)
        if nextPolicy.autoSave==self.policy.autoSave and nextPolicy.autoLoad==self.policy.autoLoad then return true end
        local ok,err=pcall(function()
            -- A newly enabled AutoLoad must have a current profile to restore.
            if nextPolicy.autoLoad and not self.policy.autoLoad then
                assert(self:Save(true),api.SettingsError or 'Unable to save current settings')
            end
            write(self.optionsPath,services.encode(nextPolicy))
            setPolicy(nextPolicy);self.changedAt=nil
        end)
        if not ok then setPolicy(self.policy)end
        return report(ok,err)
    end
    function preferences:Reset()
        if self.suspended or not self.ready or api.Destroyed then return false end
        self.loading=true
        local ok,err=pcall(function()
            local defaults=api:DefaultProfile()
            local profile=services.encode(defaults)
            local policy=options(false,false)
            local encodedOptions=services.encode(policy)
            -- Read before writing so unreadable existing files remain untouched.
            local priorProfile=read(self.path)
            local priorOptions=read(self.optionsPath)
            local written,writeError=pcall(function()
                write(self.path,profile);write(self.optionsPath,encodedOptions)
            end)
            if not written then
                -- With only read/write injected, restoration is best effort. Existing bytes
                -- are restored; a newly created profile is harmless without AutoLoad policy.
                if priorProfile then pcall(write,self.path,priorProfile)end
                if priorOptions then pcall(write,self.optionsPath,priorOptions)end
                error(writeError)
            end
            api:ApplyProfile(defaults);setPolicy(policy);runState()
            self.saved=profile;self.changedAt=nil;self.corrupt=nil
        end)
        self.loading=false
        return report(ok,err)
    end
    function preferences:Tick()
        if not self.ready or self.suspended or self.loading or self.corrupt or api.Destroyed
            or not api.Settings.AutoSave then return end
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
