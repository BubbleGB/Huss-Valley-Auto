runner.visualPerformance=runner.createVisualPerformance({world=workspace,clock=os.clock,
    localCharacter=function()return player.Character end,
    otherCharacters=function()
        local result={}
        for _,actor in ipairs(participants())do
            if actor.UserId~=player.UserId and actor.Character then result[#result+1]=actor.Character end
        end
        return result
    end,
    protected=function(object)
        return Collection:HasTag(object,'PredictedGearVisual')or Collection:HasTag(object,'GraveRise')
            or Collection:HasTag(object,'SpringBoxShake')
    end,
    protectedSignals=function()
        local signals={}
        for _,tag in ipairs({'PredictedGearVisual','GraveRise','SpringBoxShake'})do
            signals[#signals+1]=Collection:GetInstanceAddedSignal(tag)
            signals[#signals+1]=Collection:GetInstanceRemovedSignal(tag)
        end
        return signals
    end})
runner.clientMetrics=runner.createClientMetrics({clock=os.clock,stats=game:GetService('Stats'),player=player})
local performanceFrames,performanceTime=0,0
function runner.configurePerformance()
    runner.visualPerformance:Configure(api.Enabled and not api.StopEverything and api.Settings or{})
end
function api:PerformanceReport()
    local result=runner.visualPerformance:Report()
    for name,value in pairs(runner.clientMetrics:Read())do result[name]=value end
    result.fps=runner.frameRate
    result.plannerLastMS=self.LastPlanMS or 0
    result.plannerMeanMS=(self.Plans or 0)>0 and(self.TotalPlanMS or 0)/self.Plans or 0
    result.active=self.Enabled and not self.StopEverything
    return result
end
connect(RunService.Heartbeat,function(dt)
    if api.Destroyed then return end
    performanceFrames=performanceFrames+1;performanceTime=performanceTime+dt
    if performanceTime>=1 then runner.frameRate=performanceFrames/performanceTime;performanceFrames,performanceTime=0,0 end
    runner.visualPerformance:Tick()
end)
