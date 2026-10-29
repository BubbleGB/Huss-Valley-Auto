return function(source)
    local old=getgenv().HussAutoCross;if old then old:Destroy()end
    local p=game.Players.LocalPlayer
    local profiles=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles)
    local native=profiles.get
    local function replace(text,needle,replacement)
        local first,last=assert(text:find(needle,1,true))
        return text:sub(1,first-1)..replacement..text:sub(last+1)
    end
    for _,marker in ipairs({"gui.Name = 'HussAutoCrossUI'",'setProfileGetter(speedProfileGet)'})do
        local broken=replace(source,marker,marker.."\nerror('injected initialization failure')")
        local ok,err=pcall(assert(loadstring(broken)))
        assert(not ok and tostring(err):find('injected initialization failure',1,true),'fault injection must reach the intended point')
        assert(profiles.get==native,'failed startup must restore the shared native profile getter')
        assert(not getgenv().HussAutoCross,'failed startup must not publish a partial controller')
        assert(not p.PlayerGui:FindFirstChild('HussAutoCrossUI'),'failed startup must remove any partial UI')
        local a=assert(loadstring(source))()
        assert(a and not a.Enabled and type(a.Destroy)=='function','normal execution must recover after startup failure')
        a:Destroy()
    end
    getgenv().HussAutoCross={Enabled=false}
    local ok,a=pcall(assert(loadstring(source)))
    assert(ok and a and type(a.Destroy)=='function','legacy incomplete globals must not prevent reexecution')
    a:Destroy()
    return {failureSites=2,getterRestoration='passed',partialGuiCleanup='passed',reload='passed',legacyPartial='passed'}
end
