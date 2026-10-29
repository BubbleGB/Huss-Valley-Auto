-- Exercises actual controller closures without sending combat remotes.
return function(source)
    local marker='env.HussAutoCross=api'
    local first,last=assert(source:find(marker,1,true))
    local probe=[[
actionContext={fixture=true};dashHistory[#dashHistory+1]={direction=Vector3.zAxis,at=os.clock()}
release()
assert(actionContext==nil and #dashHistory==0,'release must discard cached action decisions and dash history')
local now=workspace:GetServerTimeNow()
local record=actionRequest('Melee','fixture-melee',os.clock(),now)
predicted(record);activated(record);actionReply('fixture-melee',true,{startedAt=now+.02})
assert(api.ActionTiming.Melee.requests==1 and api.ActionTiming.Melee.accepted==1,'timing must distinguish requests and server acceptance')
assert(api.ActionTiming.Melee.predictionMS.count==1 and api.ActionTiming.Melee.activationMS.count==1,'prediction and activation timings must be separate')
assert(math.abs(api.ActionTiming.Melee.serverStartMS.last-20)<.01,'server start offsets must use matching action timestamps')
actionReply('fixture-melee',true,{startedAt=now+.02})
assert(api.ActionTiming.Melee.accepted==1,'duplicate replies must not double-count acceptance')
pendingDive=actionRequest('Dive','fixture-rejected-dive',os.clock(),now)
actionReply('fixture-rejected-dive',false,{reason='fixture'})
assert(pendingDive==nil,'a rejected dive must not inherit activation from a later manual dive')
for i=1,40 do actionRequest('Dash','fixture-dash-'..i,os.clock(),now)end
assert(#api.ActionTimeline==32,'detailed timing history must remain bounded')
table.clear(api.ActionTiming);table.clear(api.ActionTimeline);table.clear(pendingActions)
pendingDash,pendingMelee,pendingDive=nil,nil,nil
env.HussAutoCross=api
]]
    local instrumented=source:sub(1,first-1)..probe..source:sub(last+1)
    local a=assert(loadstring(instrumented))()
    assert(not a.Enabled and next(a.ActionTiming)==nil and #a.ActionTimeline==0,'fixtures must leave no fake live timing samples')
    a:Destroy()
    return {cacheCleanup='passed',timingStages='passed',matchingReplies='passed',boundedHistory='passed',noFakeSamples='passed'}
end
