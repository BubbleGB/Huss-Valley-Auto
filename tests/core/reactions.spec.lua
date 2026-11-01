-- Changes to danger gating or evidence copying must fail these behavioral cases.
return function(Core)
    assert(type(Core.dangerChange)=='function','danger change detection is missing')
    local passed=0
    local function check(ok,message)assert(ok,message);passed=passed+1 end
    local actors={}
    local function enemy(id,x,kind)actors[id]=actors[id]or{UserId=id};return {actor=actors[id],position=Vector3.new(x,0,0),velocity=Vector3.zero,kind=kind,activeAbility=kind~=nil}end
    local origin=Vector3.zero
    local old={enemy(1,30)}
    check(Core.dangerChange(origin,old,{enemy(1,30,'Dive')},{},{},.04)=='ability','nearby dive must trigger route refresh')
    check(not Core.dangerChange(origin,old,{enemy(1,30)},{},{},.04),'unchanged threats must retain normal cadence')
    check(not Core.dangerChange(origin,{enemy(1,150)},{enemy(1,150,'Rocket')},{},{},.04),'distant attacks must not flood planning')
    check(Core.dangerChange(origin,old,{enemy(1,39)},{},{},.04)=='motion','unexpected nearby displacement must refresh')
    local moving=enemy(1,30);moving.velocity=Vector3.xAxis*40
    check(not Core.dangerChange(origin,{moving},{enemy(1,34)},{},{},.1),'predicted travel alone must not refresh')
    local reach=enemy(1,30);reach.reaching=true
    check(Core.dangerChange(origin,old,{reach},{},{},.04)=='ability','melee windup must refresh')
    check(Core.dangerChange(origin,{},old,{},{},.04)=='arrival','new nearby opponents must refresh')
    local trap={source='trap1',position=Vector3.new(12,0,0),radius=4,kind='BearTrap'}
    check(Core.dangerChange(origin,old,old,{}, {trap},.04)=='hazard','new nearby traps must refresh')
    check(not Core.dangerChange(origin,old,old,{trap},{trap},.04),'existing traps must not cause repeated refreshes')
    local projection={projectionOf='ball',kind='BowlingBall',position=Vector3.new(14,0,0),radius=6}
    check(not Core.dangerChange(origin,old,old,{}, {projection},.04),'projected trail points must not masquerade as new hazards')
    local far={source='far',position=Vector3.new(150,0,0),radius=4,kind='BearTrap'}
    check(not Core.dangerChange(origin,old,old,{}, {far},.04),'faraway hazards must not refresh')
    check(not Core.planDue(.02,'ability'),'reactive plans must honor 30 Hz floor')
    check(Core.planDue(.034,'ability'),'reactive plans must run before ordinary 100 ms interval')
    check(not Core.planDue(.034,nil),'ordinary planning must not accelerate')
    check(Core.planDue(.1,nil),'ordinary cadence must remain 100 ms')
    local evidence=Core.crossingSnapshot({now=1,position=origin,velocity=Vector3.zero,direction=Vector3.xAxis,
        nearby={enemy(1,30,'Dive')},hazards={trap},dashReady=false,routing='blocked',waypoint=Vector3.xAxis*40})
    check(evidence.nearby[1].kind=='Dive'and evidence.nearby[1].distance==30,'snapshot must preserve observed attack and distance')
    check(evidence.hazards[1].kind=='BearTrap'and evidence.dashReady==false,'snapshot must preserve hazard and dash evidence')
    check(evidence.nearby[1].actor==nil and evidence.hazards[1].source==nil,'evidence must not retain actors or instances')
    local copied=Core.copyEvidence({history={evidence}});copied.history[1].nearby[1].kind='changed'
    check(evidence.nearby[1].kind=='Dive','returned nested reports must not mutate internal evidence')
    local many={};for i=1,12 do many[i]=enemy(i,13-i)end
    evidence=Core.crossingSnapshot({now=1,position=origin,velocity=Vector3.zero,direction=Vector3.xAxis,nearby=many,hazards={}})
    check(#evidence.nearby==4 and evidence.nearby[1].distance==1 and evidence.nearby[4].distance==4,'snapshot must retain only four nearest opponents')
    return {passed=passed}
end
