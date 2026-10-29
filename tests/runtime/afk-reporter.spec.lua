-- No native callbacks are fired: exercise ownership, recovery, and input fallback
-- in the real closures, with only external connection/input effects replaced.
return function(source)
    local first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local setup=[[
local afkFixture={calls=0,keys=0,failTouch=false}
local idleScript=assert(player.PlayerScripts:FindFirstChild('IdleReportClient'))
local function ownedCallback()end
setfenv(ownedCallback,setmetatable({script=idleScript},{__index=getfenv()}))
local function foreignCallback()end
local function fake(fn,enabled)
    return {Function=fn,Enabled=enabled,Disable=function(self)self.Enabled=false end,
        Enable=function(self)self.Enabled=true end}
end
afkFixture.owned=fake(ownedCallback,true)
afkFixture.foreign=fake(foreignCallback,true)
afkFixture.disabled=fake(ownedCallback,false)
local getconnections=function()return {afkFixture.owned,afkFixture.foreign,afkFixture.disabled}end
local originalInput=VirtualInput
local VirtualInput=setmetatable({SendTouchEvent=function()
    if afkFixture.failTouch then error('fixture: touch unavailable')end
end,SendKeyEvent=function(_,down,key)
    assert(key==Enum.KeyCode.F15,'keepalive must not press a gameplay key')
    if not down and afkFixture.failKeyUp then error('fixture: key-up unavailable')end
    afkFixture.keys=afkFixture.keys+(down and 1 or -1);afkFixture.calls=afkFixture.calls+1
end},{__index=function(_,name)return originalInput[name]end})
]]
    -- Lexical substitutes only inside this controller instance.
    local at=assert(source:find('local function initialize()',1,true))
    local lineEnd=assert(source:find('\n',at,true))
    source=source:sub(1,lineEnd)..setup..source:sub(lineEnd+1)
    first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local probe=[[
local ok,err=pcall(function()
    api.Enabled=true;antiStart()
    assert(not afkFixture.owned.Enabled,'Start must suppress the native idle reporter before its first idle event')
    assert(afkFixture.foreign.Enabled,'unrelated Idled handlers must remain enabled')
    assert(not afkFixture.disabled.Enabled,'pre-disabled reporter must remain disabled')
    anti.nextKey=0;anti.nextTouch=math.huge
    keepAliveTick()
    assert(afkFixture.calls==2 and afkFixture.keys==0,'a blocked touch schedule must still emit and release neutral input')
    assert(api:AntiAFKReport().reportersHeld==1,'diagnostics must report the actual held connection')
    afkFixture.owned.Enabled=true
    anti.scanIdle()
    assert(not afkFixture.owned.Enabled,'periodic scans must reapply protection if the reporter is re-enabled')
    anti.nextKey=0;afkFixture.failKeyUp=true
    keepAliveTick()
    assert(afkFixture.keys==1,'fixture must reproduce a partial key pulse')
    afkFixture.failKeyUp=false
    antiStop()
    assert(afkFixture.keys==0,'Stop must release a key whose first key-up failed')
    assert(afkFixture.owned.Enabled and afkFixture.foreign.Enabled and not afkFixture.disabled.Enabled,
        'Stop must restore only connections this controller disabled')
    antiStart()
    assert(not afkFixture.owned.Enabled,'restart must protect the reporter again')
    antiStop();api.Enabled=false
end)
antiStop();api.Enabled=false
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    a:Destroy()
    return {nativeReporter='passed',foreignHandlers='passed',neutralInput='passed',restoration='passed'}
end
