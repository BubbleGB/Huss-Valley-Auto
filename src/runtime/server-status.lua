-- Read-only dashboard snapshot; no action/remotes and no dependence on automation state.
local function createServerStatus(services)
    local status={loadedAt=services.clock(),nextAt=0}
    function status:Duration(seconds)
        seconds=math.max(0,math.floor(seconds or 0))
        return string.format('%02d:%02d:%02d',math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
    end
    function status:Read()
        local now=services.clock()
        if not self.snapshot or now>=self.nextAt then
            local result={players=#services.players(),bots=0,chasers=0,runners=0,
                scriptRuntime=math.max(0,now-self.loadedAt),serverUptime=math.max(0,services.connectedTime()),
                serverUptimeIsLowerBound=true}
            local seen={}
            for _,actor in ipairs(services.participants())do
                local id=actor.UserId
                local bot=type(actor)=='table'and actor.IsBot==true
                if id and not seen[id]and(not bot or not(actor:GetAttribute('Hidden')or actor:GetAttribute('FadeOutAt')))then
                    seen[id]=true
                    if bot then result.bots=result.bots+1 end
                    if actor:GetAttribute('InMatch')==true then
                        local role=actor:GetAttribute('GameRole')
                        if role=='Catcher'then result.chasers=result.chasers+1
                        elseif role=='Runner'then result.runners=result.runners+1 end
                    end
                end
            end
            self.snapshot=result;self.nextAt=now+1
        end
        return table.clone(self.snapshot)
    end
    function status:Text()
        local r=self:Read()
        return string.format('Script runtime: %s\nServer uptime: at least %s (since you joined)\nPlayers: %d humans + %d bots\nChasers: %d\nRunners: %d',
            self:Duration(r.scriptRuntime),self:Duration(r.serverUptime),r.players,r.bots,r.chasers,r.runners)
    end
    return status
end
runner.serverStatus=createServerStatus({clock=os.clock,connectedTime=function()return workspace.DistributedGameTime end,
    players=function()return Players:GetPlayers()end,participants=participants})
function api:ServerReport()return runner.serverStatus:Read()end
