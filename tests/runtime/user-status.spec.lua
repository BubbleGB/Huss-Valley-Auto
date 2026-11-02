return function(source)
    local first=assert(source:find('local function createUserStatus(',1,true),'user status factory missing')
    local last=assert(source:find('runner.userStatus=createUserStatus',first,true))
    local factory=assert(loadstring(source:sub(first,last-1)..'\nreturn createUserStatus'))()
    local now=0;local attrs={GameRole='Catcher',Level=12}
    local stats={Level={Value=13},Wins={Value=48},Catches={Value=110},LMS={Value=8}}
    for _,v in pairs(stats)do function v:IsA(class)return class=='ValueBase'end end
    local folder={FindFirstChild=function(_,name)return stats[name]end}
    local p={Name='ExampleUser',UserId=123,FindFirstChild=function()return folder end,GetAttribute=function(_,name)return attrs[name]end}
    local s=factory(p,function()return now end)
    local r=s:Read()
    assert(r.username=='ExampleUser'and r.role=='Chaser'and r.level==13 and r.wins==48 and r.catches==110 and r.lms==8,'native user stats and role mapping')
    r.wins=999;assert(s:Read().wins==48,'report isolation')
    stats.Wins.Value=49;attrs.GameRole='Runner';now=1.1;r=s:Read()
    assert(r.wins==49 and r.role=='Runner','live stat and role updates')
    stats.Level=nil;stats.LMS=nil;now=2.2;r=s:Read()
    assert(r.level==12 and r.lms==nil,'level attribute fallback and unloaded LMS stays unknown')
    assert(s:Text():find('LMS (Last Man Standing):',1,true),'LMS expanded')
    p.FindFirstChild=function()return nil end;attrs.GameRole=nil;attrs.Level=nil;now=3.3
    r=s:Read();assert(r.wins==nil and r.role=='Unknown','late-loading stats tolerated')
    assert(s:Thumbnail()=='rbxthumb://type=AvatarHeadShot&id=123&w=150&h=150','headshot belongs to current user')
    return {stats='passed',liveUpdates='passed',missingValues='passed',role='passed',identity='passed'}
end
