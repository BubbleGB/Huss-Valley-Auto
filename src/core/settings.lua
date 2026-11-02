local settingDefaults={AutoRun=true,AutoChase=true,AutoDash=true,AutoDive=true,AutoMelee=true,
    UseAbilities=true,AntiAFK=true,AutoVote=true,AutoSelectRunner=true,FollowCamera=false,AutoFaceTarget=false,
    AutoJourney=false,AutoSpins=false,AutoCrates=false,
    RunnerEquipment='',ChaserEquipment='',ConsumableEquipment='',UseConsumables=true,
    MapPreference='Random',HeroMode='Auto',HeroThreshold=5}
function Core.priorityOrder(value)
    assert(type(value)=='table','Priorities requires a permutation')
    local known={Escape=true,Revives=true,Gems=true,Catches=true}
    local result={}
    for key,item in pairs(value)do
        assert(type(key)=='number'and key%1==0 and key>=1 and key<=4 and known[item],'Invalid priority permutation')
        known[item]=nil;result[key]=item
    end
    assert(#result==4 and next(known)==nil,'Priorities requires all four tasks')
    return result
end
function Core.defaultSettings()
    local result=table.clone(settingDefaults)
    result.Priorities={'Escape','Revives','Gems','Catches'}
    return result
end
function Core.settingValue(name,value)
    local default=settingDefaults[name]
    assert(default~=nil,'Unknown setting: '..tostring(name))
    if type(default)=='boolean'then assert(type(value)=='boolean',name..' requires true or false')
    elseif name=='HeroThreshold'then
        assert(type(value)=='number'and value>=0 and value<=50 and value%1==0,'HeroThreshold requires an integer from 0 to 50')
    elseif name:match('Equipment$')then assert(type(value)=='string'and #value<=80 and(value==''or value:match('^[%w_]+$')),'Invalid equipment ID')
    elseif name=='HeroMode'then assert(value=='Auto'or value=='Hero'or value=='Chicken','Invalid HeroMode')
    else assert(type(value)=='string'and(value=='Random'or value:match('^Map%d+$')),'Invalid MapPreference')end
    return value
end
function Core.copySettings(settings)
    local result=table.clone(settings)
    result.Priorities=table.clone(settings.Priorities)
    return result
end
function Core.priorityRank(priorities,name)
    for rank,item in ipairs(priorities or{'Escape','Revives','Gems','Catches'})do if item==name then return rank end end
    return 5
end
