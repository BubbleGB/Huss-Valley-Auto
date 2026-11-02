return function(Core)
    local n=0;local function check(ok,message)assert(ok,message);n=n+1 end
    check(type(Core.defaultSettings)=='function','settings defaults missing')
    local s=Core.defaultSettings()
    local off=true;for _,value in pairs(s)do if type(value)=='boolean'and value then off=false end end
    check(off and s.HeroThreshold==5,'every visible setting toggle defaults off')
    check(s.AutoRun==nil and s.AutoChase==nil and s.AutoMelee==nil and s.FollowCamera==nil,'retired settings removed')
    check(not s.AutoFaceTarget,'body facing defaults off')
    check(Core.settingValue('MapPreference','Map7')=='Map7','native arbitrary Map IDs')
    check(not pcall(Core.settingValue,'MapPreference','Unavailable'),'invalid map rejected')
    check(not pcall(Core.settingValue,'HeroThreshold',5.5),'fractional threshold rejected')
    check(not pcall(Core.settingValue,'AutoDash',1),'nonboolean toggle rejected')
    check(not pcall(Core.priorityOrder,{'Escape','Escape','Gems & Currency','Catches'}),'duplicates rejected')
    local p={'Gems & Currency','Revives','Escape','Catches'};local copy=Core.priorityOrder(p);p[1]='bad'
    check(copy[1]=='Gems & Currency','priority setter copies')
    local vote={phase='Voting',token='v',endsAt=10,options={{id='Map7'},{id='Map2'}}}
    check(Core.voteChoice(vote,1,0,2,'Map7')=='Map7','preferred available map chosen')
    check(Core.voteChoice(vote,1,0,2,'Map5')=='Map2','unavailable map falls back to random index')
    local state={enabled=true,inMatch=true,now=0,endsAt=10,phase='HeroChoice',role='Runner',selectedId=1,id=1,chasers=9,heroMode='Hero'}
    local _,value=Core.choiceAction(state,{},1);check(value=='Hero','forced Hero')
    state.heroMode='Auto';state.heroThreshold=10;_,value=Core.choiceAction(state,{},1);check(value=='Hero','configured threshold')
    state.heroMode='Chicken';_,value=Core.choiceAction(state,{},1);check(value=='Chicken','forced Chicken')
    local c={position=Vector3.zero,finish=Vector3.xAxis*100,speed=30,secondsLeft=20,urgency=0,gems=true,revives=true,enemies={},geometry=function()return true end,holdSeconds=.3,priorities={'Gems & Currency','Revives','Escape','Catches'}}
    local gem={kind='gem',position=Vector3.new(15,0,3)};local revive={kind='revive',position=Vector3.new(20,0,3)}
    check(Core.detourGoal(c,{revive,gem})==gem,'configured gem priority')
    c.priorities={'Escape','Revives','Gems & Currency','Catches'};c.urgency=.4
    check(not Core.detourGoal(c,{gem}),'escape wins under moderate pressure')
    c.priorities={'Gems & Currency','Revives','Escape','Catches'}
    check(Core.detourGoal(c,{gem})==gem,'optional goal can outrank escape under moderate pressure')
    c.urgency=.7;check(not Core.detourGoal(c,{gem}),'immediate danger always vetoes')
    local migrated=Core.profileSettings({FollowCamera=true,AutoRun=false,AutoMelee=false,Priorities={'Escape','Revives','Gems','Catches'}},true)
    check(migrated.FollowCamera==nil and migrated.AutoRun==nil and migrated.Priorities[3]=='Gems & Currency','legacy profiles migrate without restoring retired features')
    return {passed=n}
end
