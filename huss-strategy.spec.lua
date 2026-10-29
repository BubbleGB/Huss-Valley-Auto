return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    check(Core.travelTime(100,30,60,0)>100/30,'travel estimate must account for acceleration from rest')
    check(Core.travelTime(100,40,100,0)<Core.travelTime(100,30,30,0),'speed and acceleration buffs must reduce travel time')
    check(Core.distanceAt(1,0,40,20)<Core.distanceAt(1,0,40,80),'interception reach must reflect acceleration')
    local safe=Core.runnerPolicy(60,200,36,60,30,2,10,1,0)
    local late=Core.runnerPolicy(5,200,36,60,30,2,10,1,0)
    check(late.urgency>safe.urgency+0.5,'deadline must make runner accept more risk')
    local crowded=Core.runnerPolicy(60,200,36,60,30,8,2,6,0)
    check(crowded.urgency>safe.urgency,'chaser density and ratio must affect strategy before deadline')
    local stuck=Core.runnerPolicy(60,200,36,60,30,2,10,1,6)
    check(stuck.urgency>safe.urgency,'waiting without progress must increase willingness to push')
    local committed=Core.runnerPolicy(7,200,30,60,30,2,10,1,0)
    local shortened=Core.runnerPolicy(6.9,100,30,60,30,2,10,1,0,committed.urgency,0.1)
    check(shortened.urgency>=committed.urgency-0.02,'a shorter risky route must not immediately undo urgency and force a detour again')
    local slowed=Core.runnerPolicy(10,200,18,25,10,2,10,1,0)
    check(slowed.urgency>=late.urgency,'slowed runner must react to deadline sooner')
    local enemy={position=Vector3.new(15,0,30),radius=24.5,catchRadius=8,velocity=Vector3.zero}
    local ordinary=Core.strategyThreat(enemy,0)
    local urgent=Core.strategyThreat(enemy,1)
    check(not Core.clearSegment(Vector3.zero,Vector3.new(0,0,60),{ordinary}),'cautious policy must stay outside dive range')
    check(Core.clearSegment(Vector3.zero,Vector3.new(0,0,60),{urgent}),'emergency policy must allow calculated dive-range exposure')
    check(urgent.radius>=8,'emergency policy must keep immediate catch clearance')
    local actor=Instance.new('Folder')
    local model=Instance.new('Model')
    model:SetAttribute('HitShielded',true)
    check(Core.abilityState(actor,model,10).shielded,'must recognize the real one-hit shield flag')
    model:SetAttribute('HitShielded',nil);model:SetAttribute('Burrowing','tunnel')
    check(Core.abilityState(actor,model,10).protected,'burrowing target must not receive attacks')
    model:SetAttribute('Burrowing',nil);actor:SetAttribute('GhostImmuneUntil',0);model:SetAttribute('GhostImmuneUntil',12)
    check(Core.abilityState(actor,model,10).protected,'character immunity must not be hidden by a zero player timer')
    check(not Core.abilityState(actor,model,15).protected,'expired immunity must not block attacks')
    model:SetAttribute('DashUntil',12)
    check(Core.abilityState(actor,model,10).evasive,'active dash must affect dive decisions')
    actor:Destroy();model:Destroy()
    local profile={MaxSpeed=36,Acceleration=60,Deceleration=66}
    local runner={MaxSpeed=35,Acceleration=80}
    local _,slowTime=Core.dynamicIntercept(Vector3.zero,Vector3.new(20,0,0),Vector3.new(0,0,15),
        profile,Vector3.zero,runner,Vector3.zero,3,1.25)
    local _,fastTime=Core.dynamicIntercept(Vector3.zero,Vector3.new(20,0,0),Vector3.new(0,0,15),
        profile,Vector3.new(30,0,0),runner,Vector3.zero,3,1.25)
    check(slowTime>=fastTime,'stationary chaser must not assume instant full running speed')
    local slowedPoint=Core.dynamicIntercept(Vector3.zero,Vector3.new(50,0,0),Vector3.new(0,0,50),
        profile,Vector3.zero,{MaxSpeed=18,Acceleration=25,Deceleration=66},Vector3.zero,3,1.25)
    local boostedPoint=Core.dynamicIntercept(Vector3.zero,Vector3.new(50,0,0),Vector3.new(0,0,50),
        profile,Vector3.zero,{MaxSpeed=50,Acceleration=80,Deceleration=66},Vector3.zero,3,1.25)
    check(slowedPoint.Z<boostedPoint.Z,'prediction must brake toward the target current slowed profile')
    local burstPoint=Core.dynamicIntercept(Vector3.zero,Vector3.new(50,0,0),Vector3.new(0,0,50),
        profile,Vector3.zero,{MaxSpeed=18,Acceleration=25,Deceleration=66,BurstRemaining=0.3},Vector3.zero,3,1.25)
    check(burstPoint.Z>slowedPoint.Z,'known active burst must persist until its observed end before braking')
    local function attack(options,meleeReady,diveReady)
        return Core.combatAction(Vector3.new(0,0,4.8),Vector3.new(0,0,35),Vector3.new(0,0,33),
            15,.32,5.5,5.25,meleeReady~=false,diveReady~=false,true,options)
    end
    local action,_,style=attack({closeDive=true,farDive=false})
    check(action~='Dive','close pursuit must not authorize a dive without native catch prediction')
    check(attack({closeDive=false,farDive=false})=='Melee','otherwise melee should remain preferred close up')
    check(attack({closeDive=true,shielded=true})==nil,'must not waste a finishing dive on a shield')
    check(attack({closeDive=true,protected=true})==nil,'must not attack an invulnerable target')
    check(attack({closeDive=true,evasive=true})~='Dive','must not commit to a dive against an active evasive motion')
    check(attack({closeDive=true},true,false)=='Melee','finishing dive must still respect native cooldown')
    local actionFar=Core.combatAction(Vector3.new(0,0,14),Vector3.new(0,0,35),Vector3.new(0,0,33),
        15,.32,5.5,5.25,true,true,true,{closeDive=true,farDive=false})
    check(actionFar~='Dive','close-dive policy must not reintroduce long speculative dives')
    return {passed=n}
end
