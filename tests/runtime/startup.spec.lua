-- Initialization must either publish the complete current UI or roll back everything.
return function(source)
    local env=getgenv();local old=env.HussAutoCross;if old then old:Destroy()end
    local player=game.Players.LocalPlayer
    local profiles=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementProfiles)
    local native=profiles.get
    local cache=env.HussWindUICache
    if not cache then local bootstrap=assert(loadstring(source))();cache=env.HussWindUICache;bootstrap:Destroy()end
    local function replace(text,needle,replacement)
        local first,last=text:find(needle,1,true)
        assert(first,'startup fixture anchor missing')
        return text:sub(1,first-1)..replacement..text:sub(last+1)
    end
    local function clean()
        local a=env.HussAutoCross;if a and a.Destroy then pcall(a.Destroy,a)end
        env.HussWindUICache=cache;env.HussStartupOwned=nil
    end
    local function noResidue()
        assert(profiles.get==native,'failed initialization must restore exact native getter')
        assert(not env.HussAutoCross,'failed initialization must not publish partial API')
        assert(not player.PlayerGui:FindFirstChild('HussAutoCrossUI'),'failed initialization must remove overlay ownership root')
        for _,child in ipairs(player.PlayerGui:GetChildren())do
            assert(child.Name:sub(1,#'HussAutoCrossWindUI_')~='HussAutoCrossWindUI_','failed initialization must remove partial library GUI')
        end
    end
    local function fails(text,message)
        local ok,err=pcall(assert(loadstring(text)))
        assert(not ok and tostring(err):find(message,1,true),'fixture must fail at intended resource boundary: '..tostring(err))
        noResidue()
    end
    local ok,err=pcall(function()
        for _,marker in ipairs({"gui.Name='HussAutoCrossUI'",'setProfileGetter(speedProfileGet)'})do
            fails(replace(source,marker,marker.."\nerror('injected initialization failure')"),'injected initialization failure')
        end
        env.HussWindUICache={version='1.6.66',source='error("unavailable library fixture")'}
        fails(source,'UI initialization failed')
        env.HussWindUICache=cache
        local needle="local runnerTab=tab('Runner','footprints')"
        local partial=replace(source,needle,[[
env.HussStartupOwned={guis=table.clone(ui.OwnedGuis),connections=table.clone(ui.Library.Creator.Signals)}
error('partial library initialization fixture')
]])
        fails(partial,'partial library initialization fixture')
        local owned=assert(env.HussStartupOwned)
        assert(#owned.connections>2,'fixture must capture actual initialized library connections')
        for _,connection in ipairs(owned.connections)do assert(not connection.Connected,'failed startup must disconnect actual owned connection')end
        for _,gui in ipairs(owned.guis)do assert(not gui.Parent,'failed startup must destroy actual owned library GUI')end
        env.HussStartupOwned=nil
        local drift,count=cache.source:gsub('e.InputChanged:Connect%(','f.InputChanged:Connect(',1)
        assert(count==1 and #drift==#cache.source,'same-size compatibility drift fixture must be valid')
        env.HussWindUICache={version='1.6.66',source=drift}
        fails(source,'WindUI compatibility anchor mismatch')
        env.HussWindUICache=cache
        local a=assert(loadstring(source))()
        assert(a.UI.Window and not a.Enabled,'normal launch must recover after every failure case')
        a:Destroy();noResidue()
        env.HussAutoCross={Enabled=false}
        local b=assert(loadstring(source))()
        assert(b and b.UI.Window and not b.Enabled,'legacy incomplete API must not prevent recovery')
        b:Destroy();noResidue()
    end)
    clean();assert(ok,err)
    return {failureSites=5,transactional='passed',partialLibraryCleanup='passed',getterRestoration='passed',reload='passed'}
end
