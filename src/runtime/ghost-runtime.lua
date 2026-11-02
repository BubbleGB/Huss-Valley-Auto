-- Native Ghost Trader packets only; never opens the camera-owning trader presentation.
do
    local remote=gameState:FindFirstChild('GhostTraderEvent')
    local configModule=gameState:FindFirstChild('GhostTraderConfig')
    if remote and configModule then
        local config=require(configModule)
        local ghost=runner.createGhostTrader({cards=config.Cards,clock=os.clock,
            serverTime=function()return workspace:GetServerTimeNow()end,
            enabled=function()return api.Enabled and not api.Destroyed and not api.StopEverything and api.Settings.AutoGhostTrader end,
            ready=function()return progression:lobbyReady()end,
            random=function(count)return random:NextInteger(1,count)end,
            send=function(command,slot)
                if not api.Enabled or api.StopEverything or not api.Settings.AutoGhostTrader or not progression:lobbyReady()then return false end
                if command~='State'and command~='Flip'then return false end
                remote:FireServer(command,slot)
                return true
            end,
            operation=function(text,action,target,ttl)runner.operation:Set('progression',text,ttl,action,target,'ghost-trader')end})
        progression.ghost=ghost
        connect(remote.OnClientEvent,function(kind,payload)ghost:Receive(kind,payload)end)
    end
end
function api:GhostTraderReport()
    return progression.ghost and progression.ghost:Report()or{status='Ghost Trader unavailable'}
end
