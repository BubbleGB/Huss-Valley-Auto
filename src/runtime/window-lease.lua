local function createWindowLease(getUI)
    local lease={}
    local owners,restore,ownedUI={},false,nil
    function lease:Acquire(owner)
        local view=getUI()
        if not view or view.Cleaned then return true end
        if next(owners)==nil then restore=not view.Minimized;ownedUI=view end
        owners[owner]=true
        if not view.Minimized then view:Minimize();return false end
        return true
    end
    function lease:Release(owner)
        owners[owner]=nil
        if next(owners)~=nil then return end
        if restore and ownedUI and not ownedUI.Cleaned and ownedUI.Minimized then ownedUI:Restore()end
        restore,ownedUI=false,nil
    end
    return lease
end
runner.createWindowLease=createWindowLease
