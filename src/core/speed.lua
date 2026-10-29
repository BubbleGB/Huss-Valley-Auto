Core.SMART_POLICY='short-110-040-12-v1'
Core.SMART_PEAK=1.10

function Core.smartLimit(learned,jobId)
    if type(learned)=='table'and learned.jobId==jobId and learned.policy==Core.SMART_POLICY
        and type(learned.cap)=='number'and learned.cap==learned.cap then
        return math.clamp(learned.cap,1,Core.SMART_PEAK)
    end
    return Core.SMART_PEAK
end

function Core.smartSpeedStep(previous,now,enabled,eligible,nearest,epoch,corrected)
    local state=previous and previous.epoch==epoch and table.clone(previous)
        or{epoch=epoch,untilAt=0,readyAt=previous and previous.readyAt or 0,armed=true,watchUntil=0}
    if now>=state.untilAt then state.untilAt=0 end
    if nearest>=20 then state.armed=true end
    if corrected then
        state.untilAt=0;state.watchUntil=0;state.readyAt=math.max(state.readyAt,now+15);state.armed=false
        return state
    end
    if not enabled or not eligible then state.untilAt=0;return state end
    if state.untilAt==0 and state.armed and nearest<=12 and now>=state.readyAt then
        state.untilAt=now+.4;state.readyAt=now+12;state.watchUntil=now+4.4;state.armed=false
    end
    return state
end

function Core.effectiveSpeed(manual,enabled,state,now,limit)
    return enabled and state and state.untilAt>now and math.max(manual,math.clamp(limit or Core.SMART_PEAK,1,Core.SMART_PEAK))or manual
end

