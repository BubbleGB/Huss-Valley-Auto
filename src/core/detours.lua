function Core.detourHoldSafe(position,duration,enemies,geometry)
    if not geometry(position,position)then return false end
    for _,enemy in ipairs(enemies)do
        local radius=math.max(enemy.hardRadius or 0,(enemy.catchRadius or 8)+3)
        if Core.threatApproach(position,Vector3.zero,enemy,duration+.2,radius)<0 then return false end
        if enemy.potentialAbility then
            local possible={position=enemy.position,velocity=enemy.potentialVelocity,expires=enemy.potentialFor}
            if Core.threatApproach(position,Vector3.zero,possible,duration+.2,enemy.potentialRadius or radius)<3 then return false end
        end
    end
    return true
end

function Core.detourGoal(context,candidates)
    local direct=flat(context.finish-context.position).Magnitude
    if direct<8 or(context.urgency or 0)>=.65 or not(context.gems or context.revives)then return nil end
    local speed=math.max(1,context.speed)
    local best,bestCost,bestRank
    local pressure=(context.urgency or 0)>=.35 or Core.runnerRisk(context.position,0,context.enemies,context.urgency or 0)>6
    for _,candidate in ipairs(candidates)do
        local revive=candidate.kind=='revive'
        local rank=Core.priorityRank(context.priorities,revive and'Revives'or'Gems')
        if pressure and Core.priorityRank(context.priorities,'Escape')<rank then continue end
        if revive and not context.revives or not revive and not context.gems then continue end
        local distance=flat(candidate.position-context.position).Magnitude
        local onward=flat(context.finish-candidate.position).Magnitude
        local extra=distance+onward-direct
        local hold=revive and context.holdSeconds or 0
        if distance>(revive and 48 or 36)or extra>(revive and 20 or 12)
            or math.abs(candidate.position.Y-context.position.Y)>5
            or type(context.secondsLeft)~='number'or(distance+onward)/speed+hold+1.5>=context.secondsLeft then continue end
        local goal=Vector3.new(candidate.position.X,context.position.Y,candidate.position.Z)
        local arrival=distance/speed
        if not context.geometry(context.position,goal)or not context.geometry(goal,context.finish)
            or not Core.runnerEdge(context.position,goal,0,arrival,context.enemies)
            or Core.runnerRisk(goal,arrival,context.enemies,0)>6 then continue end
        if revive then
            local shifted={}
            for _,enemy in ipairs(context.enemies)do
                local future=table.clone(enemy);future.position=Core.runnerPosition(enemy,arrival)
                future.burstFor=enemy.burstFor and math.max(0,enemy.burstFor-arrival)or nil
                if enemy.burstFor and arrival>=enemy.burstFor then future.velocity=enemy.afterVelocity or enemy.velocity end
                future.expires=enemy.expires and math.max(0,enemy.expires-arrival)or nil
                shifted[#shifted+1]=future
            end
            if not Core.detourHoldSafe(goal,hold,shifted,context.geometry)then continue end
        end
        local cost=extra+distance*.2-(not revive and math.min(6,candidate.value or 1)or 0)
        if not bestRank or rank<bestRank or rank==bestRank and cost<bestCost then best,bestCost,bestRank=candidate,cost,rank end
    end
    return best
end
