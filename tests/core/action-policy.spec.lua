return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local z=Vector3.zero
    local solo={id=1,position=Vector3.new(20,0,0),velocity=z}
    local group={{id=2,position=Vector3.new(0,0,22),velocity=z},
        {id=3,position=Vector3.new(2,0,23),velocity=z},{id=4,position=Vector3.new(-2,0,23),velocity=z}}
    local candidates={solo,group[1],group[2],group[3]}
    local chosen,cluster=Core.selectChaseTarget(candidates,nil,z)
    check(chosen.id~=1 and cluster.count>=3,'a nearby runner cluster must beat a similarly distant isolated runner')
    check(Core.selectChaseTarget(candidates,1,z).id~=1,'a materially better cluster must justify switching from an isolated pursuit')
    local near={id=5,position=Vector3.new(4,0,0),velocity=z}
    candidates[#candidates+1]=near
    check(Core.selectChaseTarget(candidates,nil,z).id==5,'immediate close catches must outrank distant clusters')
    local hidden={id=6,position=Vector3.new(30,0,0),velocity=z,invisible=true}
    near.position=Vector3.new(11.9,0,0)
    check(Core.selectChaseTarget({near,hidden},5,z).id==5,'close runner must stay selected initially')
    near.position=Vector3.new(12.1,0,0)
    check(Core.selectChaseTarget({near,hidden},5,z).id==5,'close-tier hysteresis must not flicker at12studs')
    near.position=Vector3.new(14.1,0,0)
    check(Core.selectChaseTarget({near,hidden},5,z).id==6,'invisibility priority resumes after leaving the retained close band')
    near.position=Vector3.new(8,0,0);near.closeClear=false
    check(Core.selectChaseTarget({near,hidden},6,z).id==6,'blocked close approaches must not create false catching opportunities')
    local model=require(game.ReplicatedStorage.ChickenOrHero.Movement.MovementModel)
    local pkg=game.ReplicatedStorage.ChickenOrHero
    local profile=require(pkg.Movement.MovementProfiles).get('Runner',game.Players.LocalPlayer)
    local state=model.new()
    for _=1,60 do model.step(state,Vector3.zAxis,30,1/60,profile,true,z,1,false,Vector3.zAxis*30,false)end
    local intent=Vector3.new(1,0,1).Unit
    local aim=Core.dashPreview(intent,{{direction=Vector3.zAxis,at=10}},10.01,profile.Dash)
    model.step(state,intent,30,1/60,profile,true,z,1,true,Vector3.zAxis*30,false)
    check(aim and aim:Dot(state.dashDirection)>.999,'dash preview must match the native redirected movement vector')
    check(aim.X>.99 and math.abs(aim.Z)<.01,'a diagonal intent can produce a lateral dash rather than a diagonal path')
    check(not Core.dashPreview(intent,{{direction=Vector3.zAxis,at=9}},10,profile.Dash),'expired turn history must not request a dash')
    local hit=require(pkg.Game.HitReplayMath)
    local cfg=require(pkg.Game.ContactCatchConfig)
    local box=hit.bounds('Melee',cfg)
    check(not Core.predictContact(Vector3.new(0,0,5),z,z,Vector3.zAxis,box,.12,.18,hit.sweep),
        'nominal commit distance must not substitute for the real melee contact box')
    check(Core.predictContact(Vector3.new(0,0,10),Vector3.new(0,0,-40),z,Vector3.zAxis,box,.12,.18,hit.sweep),
        'melee must anticipate an incoming runner crossing during its active window')
    check(not Core.predictContact(Vector3.new(0,5,3),z,z,Vector3.zAxis,box,.12,.18,hit.sweep),'hit prediction must respect native vertical bounds')
    local options={sweep=hit.sweep,meleeBox=box,windup=.12,active=.18,closeDive=true,farDive=false}
    local action=Core.combatAction(Vector3.new(0,0,4),Vector3.new(0,0,34),Vector3.new(0,0,33),15,.32,5.5,5.25,true,true,false,options)
    check(action=='Melee','a blocked dive must not suppress a native-box-valid melee')
    action=Core.combatAction(Vector3.new(0,0,5),Vector3.new(0,0,35),Vector3.new(0,0,35),15,.32,5.5,5.25,true,false,true,options)
    check(action==nil,'must not swing at a same-speed target outside the actual contact box')
    local big=table.clone(box);big.far=big.far*2;options.meleeBox=big
    check(Core.combatAction(Vector3.new(0,0,7),z,z,15,.32,5.5,10.5,true,false,true,options)=='Melee','Big Dagger must use its actual doubled forward reach')
    options.meleeBox=box;options.shielded=true
    check(Core.combatAction(Vector3.new(0,0,3),z,z,15,.32,5.5,5.25,true,true,true,options)==nil,'native geometry must still respect shields')
    local throwers={{id=1,position=Vector3.new(0,0,45),velocity=Vector3.new(0,0,-35)},
        {id=2,position=Vector3.new(45,0,0),velocity=Vector3.new(-30,0,0)},
        {id=3,position=Vector3.new(45,0,1),velocity=Vector3.new(-30,0,0)},
        {id=4,position=Vector3.new(45,0,-1),velocity=Vector3.new(-30,0,0)}}
    local trap,time,count=Core.clusterTrapAim(throwers,z,10,.9,2,function()return true end)
    check(trap and trap.X>.9 and count>=3,'trap placement must prefer a dense predicted crossing over an earlier isolated crossing')
    trap=Core.clusterTrapAim(throwers,z,10,.9,2,function(aim)return aim.Z>.5 end)
    check(trap and trap.Z>.9,'blocked cluster placement must fall back to another legal crossing')
    local projectile,flight=Core.projectileAim(Vector3.new(20,0,0),Vector3.new(0,0,20),42,84,0)
    check(projectile and projectile.Z>.3 and flight>.47,'projectile aim must solve native travel time rather than fixed lead')
    check(not Core.projectileAim(Vector3.new(20,0,0),Vector3.new(50,0,0),42,84,0),'must not spend a projectile on an unreachable fleeing target')
    check(not Core.projectileAim(Vector3.new(20,0,0),z,65,15,0),'leash prediction must honor its actual15studrange')
    return {passed=n}
end
