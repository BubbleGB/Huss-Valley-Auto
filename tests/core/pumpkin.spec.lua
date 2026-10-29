return function(Core)
 local n=0
 local function check(ok,msg)assert(ok,msg);n=n+1 end
 local z=Vector3.zero
 local cfg=require(game.ReplicatedStorage.ChickenOrHero.Game.PumpkinHuntConfig).People
 check(type(Core.pumpkinActive)=='function','Pumpkin Hunt must have its own activity gate')
 check(Core.pumpkinActive('PumpkinHunt',true,false,'Active'),'active event participant must run')
 check(not Core.pumpkinActive(nil,true,false,'Active'),'normal rounds must not enter hunt')
 check(not Core.pumpkinActive('PumpkinHunt',false,false,'Active'),'spectators must not enter hunt')
 check(not Core.pumpkinActive('PumpkinHunt',true,true,'Active'),'eliminated hunter must stop')
 check(not Core.pumpkinActive('PumpkinHunt',true,false,'Waiting'),'event countdown must not move')
 local function npc(state,p,yaw,v)
  return Core.pumpkinThreat({id='one',state=state,position=p or Vector3.new(0,0,15),yaw=yaw or 0,velocity=v or z},cfg)
 end
 check(npc('Broken')==nil,'broken pumpkins must be ignored')
 check(npc('Rise')==nil,'rising pumpkins must not be farm targets')
 local tell=npc('Tell')
 check(tell.activeAbility and tell.potentialAbility,'tell must reserve the impending lunge corridor')
 local lunge=npc('Lunge')
 check(lunge.velocity.Z< -40 and lunge.burstFor==cfg.LungeSeconds,'lunge must use replicated heading and native speed')
 check(lunge.afterVelocity.Magnitude==0,'lunge projection must stop after finite attack duration')
 local enemies={npc('Chase')}
 local goal,id=Core.pumpkinGoal(z,enemies,nil,0,60,function()return true end,function()return 0 end)
 check(goal and id=='one','hunt must seek a reachable pumpkin instead of a safezone')
 check((goal-enemies[1].position).Magnitude<=cfg.BreakRange,'bait must stay within native break range')
 local low=Core.pumpkinGoal(z,enemies,nil,3,60,function()return true end,function()return 0 end)
 check((low-enemies[1].position).Magnitude>(goal-enemies[1].position).Magnitude,'last life must keep more spacing')
 check(Core.pumpkinGoal(z,enemies,nil,0,60,function()return false end,function()return 0 end)==nil,'blocked candidates must not become movement goals')
 check(Core.pumpkinGoal(z,{},nil,0,60,function()return true end,function()return 0 end)==nil,'no NPC means wait')
 local dodge=Core.pumpkinGoal(z,{lunge},nil,0,60,function()return true end,function()return 0 end)
 check(dodge and math.abs(dodge.X)>5,'incoming lunge must favor a lateral dodge')
 local steer=Core.choose(z,Vector3.new(18,0,0),30,{lunge},function()return true end,z,0)
 check(math.abs(steer.X)>.5,'native swept lunge must influence real steering')
 local approaching=npc('Chase',Vector3.new(0,0,20),0,Vector3.new(0,0,-20))
 check(Core.threatApproach(z,z,approaching,.8,approaching.radius)<0,'chasing pumpkins must retain observed movement in collision prediction')
 local far=npc('Chase',Vector3.new(0,0,150))
 check(Core.pumpkinGoal(z,{far},nil,0,60,function()return true end,function()return 0 end)~=nil,'distant pumpkins must remain valid navigation objectives')
 return {passed=n}
end