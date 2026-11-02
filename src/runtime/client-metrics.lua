local function createClientMetrics(services)
    local metrics={}
    local nextAt,snapshot=0,{}
    local function number(read,scale,positive)
        local ok,value=pcall(read)
        if not ok or type(value)~='number'or value~=value or math.abs(value)==math.huge or value<0 or positive and value==0 then return nil end
        return value*(scale or 1)
    end
    function metrics:Read()
        local now=services.clock()
        if now>=nextAt then
            nextAt=now+1
            local stats=services.stats
            snapshot={frameMS=number(function()return stats.FrameTime end,1000,true),
                cpuMS=number(function()return stats.RenderCPUFrameTime end,1000,true),
                gpuMS=number(function()return stats.RenderGPUFrameTime end,1000,true),
                memoryMB=number(function()return stats:GetTotalMemoryUsageMb()end,1,true),
                pingMS=number(function()return services.player:GetNetworkPing()end,1000),
                sendKBps=number(function()return stats.DataSendKbps end),receiveKBps=number(function()return stats.DataReceiveKbps end),
                instances=number(function()return stats.InstanceCount end),drawCalls=number(function()return stats.SceneDrawcallCount end)}
        end
        return table.clone(snapshot)
    end
    function metrics:Text()
        local value=self:Read()
        local function format(number,unit,decimals)
            return number and string.format('%.'..(decimals or 0)..'f%s',number,unit or'')or'unavailable'
        end
        return 'FPS: '..format(value.frameMS and 1000/value.frameMS)..' | Frame: '..format(value.frameMS,' ms',1)
            ..'\nPing: '..format(value.pingMS,' ms')..' | Down / Up: '..format(value.receiveKBps,' KB/s',1)..' / '..format(value.sendKBps,' KB/s',1)
            ..'\nCPU render: '..format(value.cpuMS,' ms',2)..' | GPU render: '..format(value.gpuMS,' ms',2)
            ..'\nRoblox memory: '..format(value.memoryMB,' MB')..' | Instances: '..format(value.instances)..' | Draw calls: '..format(value.drawCalls)
    end
    return metrics
end
runner.createClientMetrics=createClientMetrics
