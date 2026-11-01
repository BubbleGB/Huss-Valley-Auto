return function(Core)
    assert(type(Core.detourGoal)=='function','optional detour policy is missing')
    local n=0;local function check(ok,message)assert(ok,message);n=n+1 end
    local c={position=Vector3.zero,finish=Vector3.xAxis*100,speed=30,secondsLeft=20,urgency=0,
        gems=true,revives=true,enemies={},geometry=function()return true end,holdSeconds=.3}
    local gem={kind='gem',id='g',position=Vector3.new(15,0,3),value=3}
    local revive={kind='revive',id=1,position=Vector3.new(20,0,3)}
    local choice=Core.detourGoal(c,{gem,revive});check(choice==revive,'safe revive must take priority over gem')
    c.revives=false;check(Core.detourGoal(c,{gem,revive})==gem,'gem toggle must work independently')
    c.gems=false;check(not Core.detourGoal(c,{gem,revive}),'both off must retain crossing route')
    c.gems=true;c.urgency=.7;check(not Core.detourGoal(c,{gem}),'urgent crossing must not detour')
    c.urgency=0;c.secondsLeft=2;check(not Core.detourGoal(c,{gem}),'insufficient timer must veto detour')
    c.secondsLeft=20;c.geometry=function()return false end;check(not Core.detourGoal(c,{gem}),'obstructed detours must be rejected')
    c.geometry=function()return true end
    check(not Core.detourGoal(c,{{kind='gem',position=Vector3.new(10,0,30)}}),'large sideways detours must be rejected')
    check(not Core.detourGoal(c,{{kind='gem',position=Vector3.xAxis*40}}),'far away gems must not increase sensing/route scope')
    c.enemies={{position=gem.position,velocity=Vector3.zero,radius=8,catchRadius=6}}
    check(not Core.detourGoal(c,{gem}),'gem inside catch space must be rejected')
    c.enemies={};c.finish=Vector3.xAxis*5;check(not Core.detourGoal(c,{gem}),'near finish must prioritize crossing')
    c.finish=Vector3.xAxis*100;c.revives=true
    c.enemies={{position=Vector3.new(35,0,3),velocity=-Vector3.xAxis*30,radius=8,catchRadius=6}}
    check(not Core.detourGoal(c,{revive}),'incoming chaser must veto a stationary revive hold')
    check(Core.detourHoldSafe(Vector3.zero,.4,{},function()return true end),'clear ground must allow a real hold')
    check(not Core.detourHoldSafe(Vector3.zero,.4,{{position=Vector3.xAxis*12,velocity=-Vector3.xAxis*30,radius=8,catchRadius=6}},function()return true end),'hold must reject approaching catch space')
    return {passed=n}
end
