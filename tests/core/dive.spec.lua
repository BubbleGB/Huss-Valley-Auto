return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local pkg=game.ReplicatedStorage.ChickenOrHero
    local hit=require(pkg.Game.HitReplayMath)
    local motion=require(pkg.Game.TackleMotion)
    local cfg=require(pkg.Game.GameConfig).Tackle
    local p=require(pkg.Game.TackleProfile).select(cfg,35,37)
    local melee=require(pkg.Game.ContactCatchConfig)
    local options={sweep=hit.sweep,diveBox=hit.bounds('Tackle',p),meleeBox=hit.bounds('Melee',melee),
        windup=melee.Windup,active=melee.ActiveDuration,diveTravel=function(t)return motion.distance(p,t)end,
        stableFor=.5,directionStableFor=.5,closeDive=true,farDive=true,acceleration=Vector3.zero,
        diveClear=function()return true end}
    local function attack(relative,target,own,change)
        local opts=table.clone(options)
        for k,v in pairs(change or{})do opts[k]=v end
        return Core.combatAction(relative,target,own,p.Distance,p.Duration,p.Reach,5.25,true,true,true,opts)
    end
    local z=Vector3.zero
    check(attack(Vector3.new(0,0,10),Vector3.new(0,0,20),Vector3.new(0,0,33),{diveLatency=.12})==nil,
        'higher reply latency must account for the full one-way position uncertainty')
    check(attack(Vector3.new(0,0,10),Vector3.new(0,0,20),Vector3.new(0,0,33),{diveLatency=.03})=='Dive',
        'an otherwise robust low-latency catch should remain eligible')
    check(attack(Vector3.new(0,0,12),Vector3.new(0,0,20),Vector3.new(0,0,33))==nil,
        'a nominal contact that misses a modest sideways change must not authorize a dive')
    check(attack(Vector3.new(0,0,9),Vector3.new(0,0,35),Vector3.new(0,0,33))==nil,'late chasing contact without escape margin must wait for a closer approach')
    check(Core.combatAction(Vector3.new(0,0,4.8),Vector3.new(0,0,35),Vector3.new(0,0,33),
        15,.32,5.5,5.25,false,true,true,{closeDive=true,farDive=false})~='Dive',
        'distance and alignment alone must never authorize a dive without native catch prediction')
    local action,aim,style,at=attack(Vector3.new(0,0,9),Vector3.new(0,0,20),Vector3.new(0,0,33))
    check(action=='Dive'and at<=.3,'an early robust contact beyond close range must remain a dive candidate')
    action,aim=attack(Vector3.new(0,0,8),Vector3.new(20,0,20),Vector3.new(0,0,33))
    check(action=='Dive'and aim.X>.1,'dive must lead a consistent lateral trajectory rather than reject all strafing')
    check(attack(Vector3.new(0,0,12),z,Vector3.new(0,0,12))=='Dive','must exploit reachable stationary targets with native long-profile contact')
    check(attack(Vector3.new(0,0,7),Vector3.new(0,0,35),Vector3.new(0,0,33),
        {stableFor=.05,directionStableFor=.16,farDive=false})=='Dive','close consistent direction should qualify without a long speed-stability wait')
    check(attack(Vector3.new(0,0,20),Vector3.new(0,0,70),Vector3.new(0,0,33))==nil,'native reachability must reject targets outrunning the dive')
    check(attack(Vector3.new(0,0,30),z,Vector3.new(0,0,33))==nil,'must reject distant targets outside the finite dive path')
    check(attack(Vector3.new(0,0,10),Vector3.new(20,0,20),Vector3.new(0,0,33),
        {stableFor=.02,directionStableFor=.02})==nil,'new or turning targets must not trigger speculative dives')
    check(attack(Vector3.new(0,0,9),Vector3.new(0,0,35),Vector3.new(0,0,33),
        {stableFor=1,directionStableFor=.02})==nil,'old speed stability must not override a newly reset heading')
    check(attack(Vector3.new(0,0,10),z,Vector3.new(0,0,12),{shielded=true})==nil,'must not dive at a shield')
    check(attack(Vector3.new(0,0,10),z,Vector3.new(0,0,12),{protected=true})==nil,'must not dive at an invulnerable runner')
    check(attack(Vector3.new(0,0,10),z,Vector3.new(0,0,12),{evasive=true})==nil,'native evasive abilities must still suppress dives')
    check(attack(Vector3.new(0,0,10),z,Vector3.new(0,0,12),{diveClear=function()return false end})==nil,'predicted contact must not override blocked full-travel clearance')
    check(attack(Vector3.new(0,0,4),Vector3.new(0,0,34),Vector3.new(0,0,33))=='Melee','a valid immediate melee must still take priority')
    check(Core.diveRetry(p,'close')>=p.Cooldown and Core.diveRetry(p,'close')<2,'close dive spacing must respect native timing without an extra two-second lockout')
    check(Core.diveRetry(p,'predicted')>=p.Cooldown and Core.diveRetry(p,'predicted')<2,'predicted dive spacing must not retain the four-second lockout')
    local history
    for i,speed in ipairs({10,15,20,25,30,34})do history=Core.trackMotion(history,1,Vector3.new(0,0,speed),i*.1)end
    check(history.directionSince<=.11 and history.stableSince>.2,'straight acceleration must retain independent direction consistency')
    history=Core.trackMotion(history,1,Vector3.new(20,0,25),.7)
    check(history.directionSince==.7,'a material heading change must restart direction observation')
    return {passed=n}
end
