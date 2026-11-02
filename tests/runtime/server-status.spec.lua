return function(source)
    local first=assert(source:find('local function createServerStatus(',1,true),'server status factory missing')
    local last=assert(source:find('runner.serverStatus=createServerStatus',first,true))
    local factory=assert(loadstring(source:sub(first,last-1)..'\nreturn createServerStatus'))()
    local now,connected=100,3600
    local function actor(id,role,inMatch,bot,hidden)
        return {UserId=id,IsBot=bot,GetAttribute=function(_,key)
            if key=='GameRole'then return role elseif key=='InMatch'then return inMatch elseif key=='Hidden'then return hidden end
        end}
    end
    local human=actor(1,'Runner',true)
    local list={human,actor(2,'Catcher',true),actor(3,'Runner',false),actor(-1,'Runner',true,true),actor(-2,'Catcher',true,true,true)}
    local humans={human,list[2],list[3]}
    local scans=0
    local s=factory({clock=function()return now end,connectedTime=function()return connected end,
        players=function()return humans end,participants=function()scans=scans+1;return list end})
    local r=s:Read()
    assert(r.players==3 and r.bots==1 and r.chasers==1 and r.runners==2,'live participants include visible bots, exclude lobby/hidden')
    assert(r.scriptRuntime==0 and r.serverUptime==3600 and r.serverUptimeIsLowerBound,'uptime must identify connection lower bound')
    r.runners=99;assert(s:Read().runners==2 and scans==1,'returned report isolated and cached')
    now=101.2;connected=3601.2;humans={human};list={human,human}
    r=s:Read();assert(r.players==1 and r.runners==1 and r.chasers==0 and scans==2,'joins/leaves/role changes refresh and deduplicate')
    assert(math.abs(r.scriptRuntime-1.2)<.001,'runtime continues independently of automation')
    assert(s:Duration(90061)=='25:01:01'and s:Duration(-1)=='00:00:00','duration supports long servers and clamps negative')
    assert(s:Text():find('Server uptime: at least 01:00:01',1,true),'clear lower bound label')
    return {counts='passed',uptime='passed',runtime='passed',cache='passed',format='passed'}
end
