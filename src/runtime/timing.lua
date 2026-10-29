local function timingSample(kind,name,value)
    local stats=api.ActionTiming[kind]or{requests=0,accepted=0,rejected=0}
    api.ActionTiming[kind]=stats
    local sample=stats[name]or{count=0,min=value,max=value,mean=0}
    sample.count=sample.count+1;sample.min=math.min(sample.min,value);sample.max=math.max(sample.max,value)
    sample.mean=sample.mean+(value-sample.mean)/sample.count;sample.last=value
    stats[name]=sample
end
local function actionRequest(kind,id,clock,serverAt)
    local stats=api.ActionTiming[kind]or{requests=0,accepted=0,rejected=0}
    api.ActionTiming[kind]=stats;stats.requests=stats.requests+1
    local record={kind=kind,id=id,requestedClock=clock,requestedAt=serverAt,source='script'}
    pendingActions[id]=record
    api.ActionTimeline[#api.ActionTimeline+1]=record
    if #api.ActionTimeline>32 then table.remove(api.ActionTimeline,1)end
    return record
end
local function predicted(record)
    record.predictionMS=(os.clock()-record.requestedClock)*1000
    timingSample(record.kind,'predictionMS',record.predictionMS)
end
local function activated(record)
    if not record or record.activationMS then return end
    record.activationMS=(os.clock()-record.requestedClock)*1000
    timingSample(record.kind,'activationMS',record.activationMS)
end
local function actionReply(id,accepted,data)
    local record=pendingActions[id]
    if not record or record.replyMS then return end
    record.replyMS=(os.clock()-record.requestedClock)*1000;record.accepted=accepted==true
    timingSample(record.kind,'replyMS',record.replyMS)
    local stats=api.ActionTiming[record.kind]
    local field=record.accepted and'accepted'or'rejected';stats[field]=stats[field]+1
    if type(data)=='table'then
        record.reason=type(data.reason)=='string'and data.reason or nil
        if type(data.startedAt)=='number'then
            record.serverStartMS=(data.startedAt-record.requestedAt)*1000
            timingSample(record.kind,'serverStartMS',record.serverStartMS)
        end
    end
    if record.kind=='Melee'and not accepted then
        nextMelee=math.min(nextMelee,workspace:GetServerTimeNow()+.2)
        combatFacing=nil
    end
    if not accepted and pendingDive==record then pendingDive=nil end
end
