return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local configs={OneHitShield={Kind='Ability',UseRole='Runner'},BearTrap={Kind='Ability',UseRole='Catcher'},
        RocketShoes={Kind='Ability',UseRole='Catcher'},Cloak={Kind='Ability',UseRole='Runner'}}
    local context={ready=true,owned=true,active=true,imminent=true,goalDistance=100,nearest=8,pressured=true,safeForward=true}
    check(Core.abilityUseful('OneHitShield','Runner',context,configs),'shield should protect against an imminent hit')
    context.imminent=false
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'shield must not be wasted on general distant pressure')
    context.imminent=true;context.ownShielded=true
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'must not stack an active shield')
    context.ownShielded=false;context.ready=false
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'must honor ability cooldown')
    context.ready=true;context.owned=false
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'must not request unowned abilities')
    context.owned=true;context.blocked=true
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'must honor no-abilities match rules')
    context.blocked=false;context.charges=0
    check(not Core.abilityUseful('OneHitShield','Runner',context,configs),'must honor empty charges')
    context.charges=nil
    check(not Core.abilityUseful('OneHitShield','Catcher',context,configs),'must use only abilities for the current role')
    check(Core.abilityUseful('Cloak','Runner',context,configs),'cloak should be used when pressured during a crossing')
    context.goalDistance=2
    check(not Core.abilityUseful('Cloak','Runner',context,configs),'must conserve long defensive cooldowns when already finishing')
    local aim,time=Core.trapAim(Vector3.new(0,0,45),Vector3.new(0,0,-35),10,0.9,2)
    check(aim and time>=0.9 and time<1.3,'trap must lead an incoming runner to an armed crossing point')
    check(Core.trapAim(Vector3.new(0,0,5),Vector3.new(0,0,35),10,0.9,2)==nil,'must not throw a trap behind a fleeing runner who passes before it arms')
    check(Core.trapAim(Vector3.new(30,0,0),Vector3.new(0,0,30),10,0.9,2)==nil,'must not place a trap off the runner trajectory')
    context={ready=true,owned=true,active=true,trapOpportunity=true,castClear=true,targetProtected=false,targetShielded=false}
    check(Core.abilityUseful('BearTrap','Catcher',context,configs),'chaser should exploit a predicted trap crossing')
    context.castClear=false
    check(not Core.abilityUseful('BearTrap','Catcher',context,configs),'must not throw traps into a blocked landing')
    context.castClear=true;context.targetProtected=true
    check(not Core.abilityUseful('BearTrap','Catcher',context,configs),'must not spend offense on protected targets')
    check(not Core.keepAliveDue(false,100,0,false),'Stop must suppress periodic touches')
    check(not Core.keepAliveDue(true,59,60,false),'touch must wait for its next minute')
    check(Core.keepAliveDue(true,60,60,false),'touch should become due once per minute')
    check(not Core.keepAliveDue(true,61,60,true),'must not inject touches over menus or existing user touches')
    local part=Instance.new('Part');part.Name='FartCloud';part.Size=Vector3.new(24,3,24)
    local cloud=Core.hazardSnapshot(part,'Catcher',{},10)
    check(cloud and cloud.radius>=15,'chasers must avoid the actual slowing cloud footprint')
    check(Core.hazardSnapshot(part,'Runner',{},10)==nil,'runner-friendly slowing clouds must not obstruct runners')
    part.Name='BowlingBall';part:SetAttribute('GearVisualKind','BowlingBall')
    check(Core.hazardSnapshot(part,'Runner',{},10)~=nil,'runners must recognize noncolliding bowling projectiles')
    part:Destroy()
    return {passed=n}
end
