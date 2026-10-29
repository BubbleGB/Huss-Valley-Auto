return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local zero=Vector3.zero
    local rocket={position=Vector3.new(30,0,0),velocity=Vector3.new(-64,0,0),radius=9,catchRadius=9,
        burstFor=.42,afterVelocity=Vector3.new(-35,0,0),activeAbility=true,hardRadius=9}
    local clear,eta=Core.threatApproach(zero,zero,rocket,.8,9)
    check(clear<0 and eta>.3 and eta<.4,'fast rocket contact must be anticipated before ordinary melee range')
    local miss=Core.threatApproach(zero,Vector3.new(0,0,35),rocket,.8,9)
    check(miss>0,'perpendicular escape must clear a committed rocket lane')
    local past={position=Vector3.new(-20,0,0),velocity=Vector3.new(-64,0,0),radius=6,
        burstFor=.1,afterVelocity=zero,activeAbility=true}
    check(Core.threatApproach(zero,zero,past,.8,6)>0,'a burst already moving away must not cause a false collision')
    local finite={position=Vector3.new(40,0,0),velocity=Vector3.new(-64,0,0),radius=4,
        burstFor=.1,afterVelocity=zero,expires=.1,activeAbility=true}
    local _,finiteETA=Core.threatApproach(zero,zero,finite,1,4)
    check(finiteETA==math.huge,'expired projectile must not threaten its infinite extrapolated path')
    local above=table.clone(rocket);above.position=Vector3.new(30,30,0)
    check(Core.threatApproach(zero,zero,above,.8,9)>0,'different floors must not appear as immediate horizontal catches')
    local adjusted=Core.strategyThreat(rocket,1)
    check(adjusted.radius>=rocket.hardRadius,'deadline pressure must retain an active attack safety floor')
    local direction=Core.choose(zero,Vector3.new(100,0,0),35,{rocket},function()return true end,zero,1)
    check(math.abs(direction.Z)>.2 or direction.X<0,'runner must evade a rocket rather than run into it even under deadline pressure')
    local constrained=Core.choose(zero,Vector3.new(100,0,0),35,{rocket},function(d)return d.Z>=.2 end,zero,1)
    check(constrained.Z>=.2,'evasion must respect blocked directions')
    local actor=Instance.new('Folder');local character=Instance.new('Model');local root=Instance.new('Part')
    root.Name='HumanoidRootPart';root.CFrame=CFrame.lookAt(Vector3.new(30,0,0),zero);root.Parent=character
    local cfg={radius=24.5,catchRadius=8,maxSpeed=35,cannon={Distance=15,Flight=.7,MaxMomentum=32,CarrySeconds=.5},
        stepOver={BigDistance=12,BigTime=.36,FakeTime=.42,CarrySeconds=.6},ready=true}
    character:SetAttribute('RocketUntil',100.42)
    local t=Core.abilityThreat(actor,character,root,zero,100,cfg)
    check(t.activeAbility and t.velocity.Magnitude>=64 and t.burstFor>0,'replicated rocket start must override lagged velocity')
    character:SetAttribute('RocketUntil',nil);actor:SetAttribute('EquippedKnife','AlbiesCutlass')
    actor:SetAttribute('CannonReadyAt',1000)
    local ordinary=Core.abilityThreat(actor,character,root,zero,100,cfg)
    check(not ordinary.potentialAbility,'a known cannon on cooldown must not create a ready-cannon lane')
    actor:SetAttribute('CannonReadyAt',0)
    local ready=Core.abilityThreat(actor,character,root,Vector3.new(-30,0,0),100,cfg)
    check(ready.potentialAbility and ready.potentialVelocity.Magnitude>40,'ready cannon risk must include native momentum')
    actor:SetAttribute('CannonUntil',100.6)
    local cannon=Core.abilityThreat(actor,character,root,zero,100,cfg)
    check(cannon.activeAbility and cannon.burstFor>=.5,'cannon activation must be anticipated despite lagged velocity')
    actor:SetAttribute('CannonUntil',nil);actor:SetAttribute('EquippedKnife','Futbol');actor:SetAttribute('StepOverUntil',100.7)
    local step=Core.abilityThreat(actor,character,root,Vector3.new(-30,0,0),100,cfg)
    check(step.activeAbility and step.lateralRadius>=12,'step-over fake must reserve its upcoming lateral juke')
    actor:SetAttribute('StepOverUntil',nil);actor:SetAttribute('EquippedKnife','BaseDagger')
    actor:SetAttribute('AbilityReadyAt',1000)
    check(not Core.abilityThreat(actor,character,root,zero,100,cfg).potentialAbility,'cooldown must suppress unknown ready-gear uncertainty')
    actor:SetAttribute('AbilityReadyAt',0)
    local unknown=Core.abilityThreat(actor,character,root,zero,100,cfg)
    check(unknown.potentialAbility and not unknown.activeAbility,'unreplicated ready gear must be soft uncertainty, not an asserted active attack')
    local p=Instance.new('Part');p.Name='BowlingBall';p:SetAttribute('GearVisualKind','BowlingBall')
    p:SetAttribute('GearDirection',Vector3.new(-1,0,0));p:SetAttribute('GearSpawnedAt',99.5);p:SetAttribute('GearDuration',2)
    local h=Core.hazardSnapshot(p,'Runner',{},100)
    check(h.velocity.Magnitude==42 and h.remaining<=1.5,'projectiles must use native fallback speed and remaining lifetime')
    p:Destroy();actor:Destroy();character:Destroy()
    return {passed=n}
end
