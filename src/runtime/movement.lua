local function release(preserveSmart)
    direction = Vector3.zero
    if runner.detours then runner.detours.cancel()end
    if runner.inspection then runner.inspection.hide()end
    if not preserveSmart then
        if smartState then smartState.untilAt=0 end
        api.SmartUntilAt=0
    end
    if ownedHumanoid and ownedHumanoid.Parent then ownedHumanoid:Move(Vector3.zero, false) end
    ownedHumanoid = nil
    actionContext=nil;actionElapsed=0;table.clear(dashHistory)
    lastActionClock=nil
    pendingDash=nil
    if not preserveSmart then combatFacing=nil end
    if boostQueued then boost.clear(); boostQueued=false end
    if facingHumanoid and facingHumanoid.Parent then facingHumanoid.AutoRotate=previousAutoRotate end
    facingHumanoid,previousAutoRotate=nil,nil
    navigation=nil
    runner.replanReason=nil
    api.DashDecision=nil
    runnerProgress=nil
    runnerStrategy=nil
end

