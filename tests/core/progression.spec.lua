return function(Core)
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 local items={Shield={Name='Shield',Kind='Ability',UseRole='Runner'},Trap={Name='Trap',Kind='Ability',UseRole='Catcher'},Juice={Name='Juice',Kind='Item'},Missing={Kind='Ability',UseRole='Runner'}}
 local state={loaded=true,abilities={Shield=true,Trap=true},gear={Juice=2}}
 check(#Core.ownedEquipment(state,items,'Runner')==1,'runner owned only')
 check(Core.ownedEquipment(state,items,'Catcher')[1].id=='Trap','chaser role filtering')
 check(Core.ownedEquipment(state,items,'Consumable')[1].id=='Juice','consumable owned counts')
 state.gear.Juice=0;check(#Core.ownedEquipment(state,items,'Consumable')==0,'depleted item disappears')
 state.loaded=false;check(#Core.ownedEquipment(state,items,'Runner')==0,'unloaded inventory empty')
 local cfg={SeasonId='s',TrackId='t',Rewards={{Free={Key='a'},Premium={Key='b'}}}}
 local s={loaded=true,seasonId='s',tier=1,claims={['t:a']=true}}
 check(not Core.journeyClaimable(s,cfg),'locked premium excluded')
 s.premium=true;check(Core.journeyClaimable(s,cfg),'owned premium reward eligible')
 s.claims['t:b']=true;check(not Core.journeyClaimable(s,cfg),'already claimed excluded')
 s.seasonId='old';s.claims={};check(not Core.journeyClaimable(s,cfg),'wrong season excluded')
 check(Core.freeCrateReady({loaded=true,allowed=true,free=1,token='abc'},10,12),'fresh free crate')
 check(not Core.freeCrateReady({loaded=true,allowed=true,free=1,token='abc'},10,50),'stale crate excluded')
 check(not Core.freeCrateReady({loaded=true,allowed=true,free=0,token='abc'},10,12),'no currency fallback')
 check(not Core.freeCrateReady({loaded=true,allowed=true,free=1},10,12),'token required')
 check(Core.consumableUseful('Adrenaline','Runner',{active=true,pressured=true,safeForward=true,goalDistance=30}),'use boost under safe pressure')
 check(not Core.consumableUseful('Adrenaline','Runner',{active=true,pressured=true,safeForward=true,boosted=true,goalDistance=30}),'avoid stacking boosts')
 check(Core.consumableUseful('RescueKit','Runner',{caught=true,rescue=true}),'caught self revive')
 check(not Core.consumableUseful('RescueKit','Runner',{caught=true,rescue=true,soulReap=true}),'Soul Reap excludes self revive')
 check(not Core.consumableUseful('Unknown','Runner',{active=true,pressured=true}),'unknown no blind usage')
 return {passed=n}
end
