return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local context={enabled=true,running=true,eligible=true,now=100,readyAt=0,uses=0,attackETA=.1,walkSafe=false,stuck=2}
    local good={point=Vector3.new(0,0,2),distance=2,landingSafe=true,exitSafe=true,
        clearance=2,attackETA=.6,gain=0,pathBlocked=false}
    check(Core.tpChoice(context,{good})==good,'must select a short useful escape from an imminent attack')
    context.enabled=false;check(not Core.tpChoice(context,{good}),'toggle OFF must prohibit teleportation')
    context.enabled=true;context.running=false;check(not Core.tpChoice(context,{good}),'Stop must prohibit teleportation')
    context.running=true;context.eligible=false;check(not Core.tpChoice(context,{good}),'airborne or forced movement must prohibit teleportation')
    context.eligible=true;context.readyAt=101;check(not Core.tpChoice(context,{good}),'must respect persistent cooldown')
    context.readyAt=0;context.blocked=true;check(not Core.tpChoice(context,{good}),'correction block must prohibit further attempts')
    context.blocked=false;context.uses=2;check(not Core.tpChoice(context,{good}),'round budget must prevent repeated jumps')
    context.uses=0;context.walkSafe=true;check(not Core.tpChoice(context,{good}),'must conserve teleport when walking can safely avoid the attack')
    context.walkSafe=false
    local far=table.clone(good);far.distance=4.1;check(not Core.tpChoice(context,{far}),'must never exceed four studs')
    local solid=table.clone(good);solid.landingSafe=false;check(not Core.tpChoice(context,{solid}),'must refuse occupied landing points')
    local trap=table.clone(good);trap.exitSafe=false;check(not Core.tpChoice(context,{trap}),'must refuse a trapped exit')
    local stillHit=table.clone(good);stillHit.attackETA=.2;check(not Core.tpChoice(context,{stillHit}),'a teleport must not merely postpone the same imminent catch')
    local long=table.clone(good);long.distance=4;long.point=Vector3.new(0,0,4)
    check(Core.tpChoice(context,{long,good})==good,'prefer the shortest useful displacement')
    context.attackETA=math.huge
    local obstacle=table.clone(good);obstacle.pathBlocked=true;obstacle.thinObstacle=true;obstacle.gain=2
    check(Core.tpChoice(context,{obstacle})==obstacle,'verified thin obstacle bypass should be possible after being stuck')
    obstacle.thinObstacle=false;check(not Core.tpChoice(context,{obstacle}),'must refuse thick or unverified obstacle bypasses')
    obstacle.thinObstacle=true;context.stuck=.2;check(not Core.tpChoice(context,{obstacle}),'must not teleport through obstacles during ordinary progress')
    context.stuck=2
    local bypass=table.clone(good);bypass.hazardBlocked=true;bypass.gain=2
    check(Core.tpChoice(context,{bypass})==bypass,'must permit a safe short bypass of a blocked trap route')
    bypass.clearance=-1;check(not Core.tpChoice(context,{bypass}),'hazard bypass must not land in a different attack')
    context.role='Catcher';context.chaseReady=true;context.stuck=0
    local catch=table.clone(good);catch.catchOpportunity=true;catch.chaseGain=2
    check(Core.tpChoice(context,{catch})==catch,'chaser must use a short TP that creates a predicted melee opportunity')
    context.currentCatch=true;check(not Core.tpChoice(context,{catch}),'must not teleport when melee already reaches')
    context.currentCatch=false;context.chaseReady=false
    check(not Core.tpChoice(context,{catch}),'must not teleport toward a target while melee is unavailable or target is protected')
    context.chaseReady=true;catch.catchOpportunity=false
    check(not Core.tpChoice(context,{catch}),'closing distance without a predicted catch is insufficient')
    catch.catchOpportunity=true;catch.chaseGain=.5
    check(not Core.tpChoice(context,{catch}),'chaser TP must create a meaningful interception gain')
    catch.chaseGain=2;context.role='Runner'
    check(not Core.tpChoice(context,{catch}),'runner must not inherit offensive teleport behavior')
    local watch={at=100,untilAt=101.5,epoch='a',phase='Run',reset=1,position=Vector3.zero,velocity=Vector3.zero,distance=2}
    local observed={epoch='a',phase='Run',reset=1,position=Vector3.zero,velocity=Vector3.zero,valid=true}
    check(Core.tpObservation(watch,100.1,observed)=='watching','normal motion must not falsely disable TP dodge')
    observed.reset=2;check(Core.tpObservation(watch,100.1,observed)=='corrected','same-context movement resets must disable further use')
    observed.reset=1;observed.position=Vector3.new(-2,0,0)
    check(Core.tpObservation(watch,100.1,observed)=='corrected','snapbacks without a reset attribute must also be detected')
    observed.epoch='b';check(Core.tpObservation(watch,100.1,observed)=='interrupted','round/role/map changes must not be mislabelled as corrections')
    observed.epoch='a';observed.valid=false;check(Core.tpObservation(watch,100.1,observed)=='interrupted','forced ability motion must interrupt correction inference')
    observed.valid=true;observed.position=Vector3.zero
    check(Core.tpObservation(watch,100.16,observed)=='uncertain','a long observation gap must not erase a possible unobserved correction')
    watch.at=101.5
    check(Core.tpObservation(watch,101.6,observed)=='complete','watch must expire without inventing server acceptance')
    return {passed=n}
end
