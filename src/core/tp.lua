Core.TP_POLICY='short-234-12-2-v1'
function Core.tpChoice(context,candidates)
    if not context.enabled or not context.running or not context.eligible or context.blocked
        or context.now<(context.readyAt or 0)or(context.uses or 0)>=2 then return nil end
    local best,score
    for _,candidate in ipairs(candidates)do
        local attack=(context.attackETA or math.huge)<=.25 and not context.walkSafe and(candidate.attackETA or 0)>=.4
        local bypass=(context.stuck or 0)>=1.1 and(candidate.gain or 0)>=1
            and(candidate.hazardBlocked or candidate.pathBlocked and candidate.thinObstacle)
        local chase=context.role=='Catcher'and context.chaseReady and not context.currentCatch
            and candidate.catchOpportunity and(candidate.chaseGain or 0)>=1.5
        if candidate.distance>=1.9 and candidate.distance<=4 and candidate.landingSafe and candidate.exitSafe
            and(candidate.clearance or -math.huge)>=1.5 and(candidate.attackETA or 0)>=.4
            and(not candidate.pathBlocked or candidate.thinObstacle)and(attack or bypass or chase)then
            local value=-candidate.distance*10+math.min(3,candidate.clearance)*.2+math.min(3,candidate.gain or 0)*.1
            if not score or value>score then best,score=candidate,value end
        end
    end
    return best
end

function Core.tpObservation(watch,now,observed)
    if not watch then return 'idle'end
    if not observed.valid or observed.epoch~=watch.epoch or observed.phase~=watch.phase then return 'interrupted'end
    if observed.reset~=watch.reset then return 'corrected'end
    local dt=now-watch.at
    if dt>.15 then return 'uncertain'end
    if now>watch.untilAt then return 'complete'end
    if dt>0 and dt<=.15 then
        local expected=(flat(watch.velocity)+flat(observed.velocity))*(dt*.5)
        local residual=flat(observed.position-watch.position)-expected
        if residual.Magnitude>math.max(1.25,watch.distance*.55)then return 'corrected'end
    end
    return 'watching'
end

