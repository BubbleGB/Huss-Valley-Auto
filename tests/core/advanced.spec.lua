return function(Core)
    local n=0
    local function check(ok,message) assert(ok,message);n=n+1 end
    local zero=Vector3.zero
    local visible={id=1,position=Vector3.new(50,0,0)}
    local hidden={id=2,position=Vector3.new(40,0,0),invisible=true}
    check(Core.selectChaseTarget({visible,hidden},1,zero).id==2,'invisible runner must take priority over a visible locked target')
    local rival={id=3,position=Vector3.new(35,0,0),invisible=true}
    check(Core.selectChaseTarget({hidden,rival},2,zero).id==2,'normal target hysteresis must apply among invisible runners')
    rival.position=Vector3.new(15,0,0)
    check(Core.selectChaseTarget({hidden,rival},2,zero).id==3,'much closer invisible runner must replace current invisible target')
    check(Core.selectChaseTarget({visible},2,zero).id==1,'normal targeting must resume after invisibility ends or hidden targets leave')
    local actor=Instance.new('Folder')
    local character=Instance.new('Model')
    local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Transparency=1;root.Parent=character
    local torso=Instance.new('Part');torso.Name='Torso';torso.Parent=character
    local head=Instance.new('Part');head.Name='Head';head.Parent=character
    check(not Core.isInvisible(actor,character,10),'normally transparent root must not mark a player invisible')
    head.Transparency=1
    check(not Core.isInvisible(actor,character,10),'headless avatar must not receive invisibility priority')
    head.Transparency=.8;torso.Transparency=.8
    check(Core.isInvisible(actor,character,10),'faint cloaked body must receive invisibility priority')
    head.Transparency=0;torso.Transparency=0;actor:SetAttribute('CloakUntil',12)
    check(Core.isInvisible(actor,character,10),'active cloak timer must count')
    check(not Core.isInvisible(actor,character,15),'expired cloak timer must not count')
    actor:Destroy();character:Destroy()
    local function intercept(position,velocity)
        return Core.dynamicIntercept(zero,position,velocity,{MaxSpeed=30,Acceleration=1000000,Deceleration=66},zero,
            {MaxSpeed=velocity.Magnitude,Acceleration=1000000,Deceleration=66},zero,3,1.25)
    end
    local point,time=intercept(Vector3.new(20,0,0),Vector3.new(0,0,12))
    check(point.Z>5 and time>0,'chaser must lead across a moving runner instead of running at their current position')
    point,time=intercept(Vector3.new(20,0,0),Vector3.new(80,0,0))
    check(time<=1.25 and point.X<121,'unreachable target must have a bounded prediction')
    point,time=intercept(Vector3.new(2,0,0),Vector3.new(0,0,30))
    check(time==0 and point.X==2,'close-range melee pursuit must not overlead')
    local choice={enabled=true,afk=false,inMatch=true,role='Catcher',phase='SelectHero',id=10,leadId=10,selectedId=0,now=10,endsAt=20}
    local action,value=Core.choiceAction(choice,{{id=21},{id=22}},2)
    check(action=='SelectHero' and value==22,'lead chaser must randomly select from eligible runners')
    choice.role='Runner';choice.phase='HeroChoice';choice.selectedId=10
    action,value=Core.choiceAction(choice,{},1)
    check(action=='HeroChoice' and value=='Chicken','challenged runner must always choose Chicken')
    choice.selectedId=11
    check(Core.choiceAction(choice,{},1)==nil,'must never choose for a different runner')
    choice.selectedId=10;choice.afk=true
    check(Core.choiceAction(choice,{},1)==nil,'AFK must suppress automatic choices')
    choice.afk=false;choice.enabled=false
    check(Core.choiceAction(choice,{},1)==nil,'Stop must suppress automatic choices')
    choice.enabled=true;choice.now=21
    check(Core.choiceAction(choice,{},1)==nil,'expired prompts must not be submitted')
    local vote={phase='Voting',token='round1',endsAt=20,options={{id='Map1'},{id='Map4'}},votes={}}
    check(Core.voteChoice(vote,10,10,2)=='Map4','map vote must choose from the offered maps')
    vote.votes['10']='Map1'
    check(Core.voteChoice(vote,10,10,2)==nil,'automatic vote must respect an existing vote')
    vote.votes={};vote.phase='Closed'
    check(Core.voteChoice(vote,10,10,2)==nil,'closed vote must not receive requests')
    vote.phase='Voting';vote.token=nil
    check(Core.voteChoice(vote,10,10,2)==nil,'malformed vote must not produce a request')
    local history=Core.observeMotion(nil,zero,10,Vector3.new(0,0,20))
    history=Core.observeMotion(history,Vector3.new(0,0,2),10.1,zero)
    check(history.velocity.Z>10,'position samples must recover velocity when replication reports zero')
    history=Core.observeMotion(history,Vector3.new(1000,0,0),10.2,Vector3.new(1000,0,0))
    check(history.velocity.Magnitude==0,'teleports must reset prediction instead of producing huge intercepts')
    local index=0
    for _=1,5 do
        local ready;ready,index=Core.requestDue(10+index,0,index)
        if not ready then break end
    end
    check(index==3,'automatic prompt retry count must be bounded')
    check(not Core.requestDue(10,11,0),'automatic requests must respect retry spacing')
    local start,goal=zero,Vector3.new(24,0,18)
    local function corridor(p)return (math.abs(p.X)<=2 and p.Z>=0 and p.Z<=20)
        or(p.X>=0 and p.X<=26 and p.Z>=16 and p.Z<=20)end
    local function allowed(a,b)
        for i=0,20 do if not corridor(a+(b-a)*(i/20))then return false end end
        return true
    end
    local path,step=Core.planRoute(start,{goal},allowed,function()return 0 end,false)
    check(path and step==6,'failed coarse search must refine to navigate an offset narrow turn')
    check(not Core.directSafe(zero,Vector3.new(240,0,0),function()return true end,
        function(p)return p.X>25 and p.X<35 and 2 or 0 end),'direct route must detect risk between old quarter-point samples')
    return {passed=n}
end
