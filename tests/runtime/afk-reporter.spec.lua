-- No native callbacks are fired: exercise reporter and stationary touch ownership
-- in the real closures, with only external connection/input effects replaced.
return function(source)
    local core=assert(source:match('(local settingDefaults.-)function Core.priorityRank'))
    local antiSource=assert(source:match('(local function finishTouch.-)api.Settings=Core.defaultSettings'))
    local setup=[[
local Core={};local api={Enabled=false}
local runner={keepAliveSurface={Visible=false}}
local anti={buttons={},touches={},idleConnections={},nextTouch=math.huge,nextScan=math.huge}
local nativePlayer=game.Players.LocalPlayer
local player={PlayerScripts=nativePlayer.PlayerScripts,Idled=nativePlayer.Idled,
 PlayerGui={GetDescendants=function()return {}end},FindFirstChild=function(_,name)return nativePlayer:FindFirstChild(name)end}
local ContextActions={UnbindAction=function()end,BindActionAtPriority=function()end}
local hudNavigation={handlers={}};local binding='HussFixture'
local afkFixture={touches=0,ends=0}
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
local VirtualInput={SendTouchEvent=function(_,id,state)
    assert(state==0 or state==2,'keepalive must never drag')
    afkFixture.touches=afkFixture.touches+1
    if state==2 then afkFixture.ends=afkFixture.ends+1 end
end,SendKeyEvent=function()error('keyboard input forbidden')end}
]]
    local probe=[[
api.Settings=Core.defaultSettings()
local ok,err=pcall(function()
    api.Enabled=true;antiStart()
    assert(not afkFixture.owned.Enabled,'Start must suppress the native idle reporter before its first idle event')
    assert(afkFixture.foreign.Enabled,'unrelated Idled handlers must remain enabled')
    assert(not afkFixture.disabled.Enabled,'pre-disabled reporter must remain disabled')
    assert(api:AntiAFKReport().reportersHeld==1,'diagnostics must report the actual held connection')
    afkFixture.owned.Enabled=true
    anti.scanIdle()
    assert(not afkFixture.owned.Enabled,'periodic scans must reapply protection if the reporter is re-enabled')
    anti.touch={id=123,x=5,y=6,ends=math.huge}
    antiStop()
    assert(anti.touch==nil and afkFixture.ends==1,'Stop must release a pending stationary touch')
    assert(afkFixture.owned.Enabled and afkFixture.foreign.Enabled and not afkFixture.disabled.Enabled,
        'Stop must restore only connections this controller disabled')
    antiStart()
    assert(not afkFixture.owned.Enabled,'restart must protect the reporter again')
    antiStop();api.Enabled=false
end)
antiStop();api.Enabled=false
assert(ok,err)
]]
    assert(loadstring(setup..core..antiSource..probe))()
    return {nativeReporter='passed',foreignHandlers='passed',touchCleanup='passed',restoration='passed'}
end
