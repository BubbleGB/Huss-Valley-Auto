return function(Core)
 local n=0
 local function check(ok,msg)assert(ok,msg);n=n+1 end
 local z=Vector3.zero
 local enemy={position=Vector3.new(18,0,20),velocity=Vector3.new(0,0,-40),radius=25,catchRadius=5,
  forward=Vector3.new(-1,0,0),diveReadyIn=2,diveDistance=15,diveHalfWidth=4}
 check(type(Core.runnerEdge)=='function','runner routing must evaluate collision at arrival time')
 check(not Core.runnerEdge(z,Vector3.new(36,0,0),0,1,{enemy}),'must reject a chaser arriving at the same crossing point')
 local leaving=table.clone(enemy);leaving.velocity=Vector3.new(0,0,40)
 check(Core.runnerEdge(z,Vector3.new(36,0,0),0,1,{leaving}),'a departing chaser must not leave a static blocked lane')
 local burst=table.clone(enemy);burst.position=Vector3.new(40,0,0);burst.velocity=Vector3.new(-80,0,0)
 burst.burstFor=.2;burst.afterVelocity=z;burst.activeAbility=true;burst.hardRadius=6
 check((Core.runnerPosition(burst,1)-Vector3.new(24,0,0)).Magnitude<.01,'finite attacks must stop at their actual motion horizon')
 local expired={position=Vector3.new(20,0,0),velocity=z,radius=8,catchRadius=5,expires=.1}
 check(Core.runnerEdge(Vector3.new(19,0,0),Vector3.new(21,0,0),.3,.4,{expired}),
  'an expired projectile must not block an otherwise safe recovery interval')
 check(Core.runnerRisk(Vector3.new(20,0,0),.3,{expired},0)==0,'expired attacks must not create phantom risk')
 local inside=table.clone(enemy);inside.position=Vector3.new(2,0,0);inside.velocity=z
 check(Core.runnerEdge(z,Vector3.new(-15,0,0),0,.4,{inside}),'must allow moving out of existing catch space')
 check(not Core.runnerEdge(z,Vector3.new(15,0,0),0,.4,{inside}),'must not escape through the chaser body')
 local ready={position=z,velocity=z,radius=25,catchRadius=5,forward=Vector3.xAxis,diveReadyIn=0,diveDistance=15,diveHalfWidth=4}
 local front=Core.runnerRisk(Vector3.new(17,0,0),.3,{ready},0)
 local rear=Core.runnerRisk(Vector3.new(-17,0,0),.3,{ready},0)
 check(front>rear+2,'ready dive risk must account for facing instead of a full circular exclusion')
 local cooling=table.clone(ready);cooling.diveReadyIn=2
 check(Core.runnerRisk(Vector3.new(17,0,0),.3,{cooling},0)<front,'observed dive cooldown must open a crossing window')
 check(Core.runnerRisk(Vector3.new(3,0,0),.2,{ready},1)>20,'ranking urgency must retain immediate catch penalties')
 local path=Core.route(z,{Vector3.new(36,0,0)},6,function(a,b,t0,t1)
  assert(type(t0)=='number'and t1>=t0,'timed route edges must carry physical elapsed time')
  return math.abs(b.Z)<=24 and b.X>=0 and b.X<=42 and Core.runnerEdge(a,b,t0,t1,{enemy})
 end,function(p,t)return Core.runnerRisk(p,t,{enemy},.5)end,600,{speed=36})
 check(path~=nil,'timed A* must find an available detour')
 local walked=0
 for i=2,#path do local d=(path[i]-path[i-1]).Magnitude;check(Core.runnerEdge(path[i-1],path[i],walked/36,(walked+d)/36,{enemy}),'every returned edge must retain its arrival-time clearance');walked=walked+d end
 local route={z,Vector3.new(0,0,16),Vector3.new(36,0,16),Vector3.new(36,0,0)}
 local index=Core.smoothWaypoint(z,route,2,function(a,b,t0,t1)return Core.runnerEdge(a,b,t0,t1,{enemy})end,
  function()return 0 end,{speed=36})
 check(index<4,'smoothing must not shortcut through a chaser arriving at the same time')
 check(Core.keepRunnerLane(100,94),'a small cost change must not cause lane oscillation')
 check(not Core.keepRunnerLane(100,60),'a material improvement must permit a lane change')
 local urgent=Core.runnerPolicy(1,100,36,100,36,5,2,4,0)
 check(urgent.riskWeight>=.3,'late-round pressure must retain a risk floor')
 check(type(Core.dashTravel)=='function','dash timing must follow native eased displacement')
 local pkg=game.ReplicatedStorage.ChickenOrHero
 local model=require(pkg.Movement.MovementModel)
 local profile=require(pkg.Movement.MovementProfiles).get('Runner',game.Players.LocalPlayer)
 local state=model.new()
 for _=1,60 do model.step(state,Vector3.zAxis,30,1/60,profile,true,z,1,false,Vector3.zAxis*30,false)end
 local elapsed,traveled=0,0
 while elapsed<profile.Dash.Duration-1e-6 do
  local dt=math.min(1/60,profile.Dash.Duration-elapsed)
  model.step(state,Vector3.xAxis,30,dt,profile,true,z,1,elapsed==0,Vector3.zAxis*30,false)
  elapsed=elapsed+dt;traveled=traveled+state.outputSpeed*dt
  assert(math.abs(Core.dashTravel(profile.Dash,profile.MaxSpeed,30,elapsed)-traveled)<.002,
   'predicted dash displacement must match actual native model at every sampled time')
 end
 check(traveled<profile.Dash.Distance,'a slower entry must reduce actual native dash distance')
 local dash={position=z,walk=Vector3.xAxis,aim=Vector3.xAxis,goal=Vector3.new(100,0,0),speed=30,
  config={Distance=10,Duration=.28,RecoveryDuration=.2,RecoverySpeedRatio=.8,Cooldown=1.1},enemies={}}
 check(type(Core.runnerDash)=='function','runner dash must evaluate tactical benefit')
 check(not Core.runnerDash(dash),'clear ground with negligible net gain must conserve dash')
 dash.config.Distance=20
 check(Core.runnerDash(dash),'a useful early dash with no approaching threats should remain available')
 dash.enemies={{position=Vector3.new(42,0,42),velocity=Vector3.new(0,0,-30),radius=9,catchRadius=5}}
 check(Core.runnerDash(dash),'early progress is useful when native cooldown ends before the approaching threat')
 dash.enemies={{position=Vector3.new(30,0,30),velocity=Vector3.new(0,0,-30),radius=9,catchRadius=5}}
 check(not Core.runnerDash(dash),'dash must be reserved when it will still be cooling at the next threat')
 local incoming={position=Vector3.new(15,0,15),velocity=Vector3.new(0,0,-30),radius=9,catchRadius=5,activeAbility=true,hardRadius=6}
 dash.enemies={incoming};dash.aim=Vector3.zAxis;dash.config.Distance=12
 check(Core.runnerDash(dash),'a safe lateral dash must beat walking into an incoming attack')
 dash.enemies={{position=Vector3.new(0,0,12),velocity=z,radius=9,catchRadius=5}}
 check(not Core.runnerDash(dash),'a dash into a chaser must be rejected even when walking is threatened')
 dash.enemies={{position=Vector3.new(9,0,12),velocity=z,radius=9,catchRadius=5}}
 check(not Core.runnerDash(dash),'dash recovery must be checked rather than just its endpoint')
 check(type(Core.crossingStep)=='function','crossing outcomes need observable state tracking')
 local c={enabled=true,inMatch=true,role='Runner',state='Active',health=100,character='a',map='Map',run=1,now=10,endsAt=20,dashes=0}
 local attempt,event=Core.crossingStep(nil,c)
 check(attempt and not event,'active runner must start one attempt')
 check(Core.crossingStep(attempt,c)==attempt,'repeated active frames must retain the same attempt')
 c.state='Safe';c.now=15;c.dashes=1
 local nextAttempt,outcome=Core.crossingStep(attempt,c)
 check(not nextAttempt and outcome.outcome=='safe'and outcome.dashes==1,'Safe must record one success with its dash count')
 local _,duplicate=Core.crossingStep(nextAttempt,c);check(not duplicate,'Safe must not be counted repeatedly')
 c.state='Active';c.now=16;c.endsAt=30;attempt=Core.crossingStep(nil,c)
 c.role='Catcher';c.now=17
 _,outcome=Core.crossingStep(attempt,c);check(outcome.outcome=='caught','runner-to-chaser conversion before deadline must count as a catch')
 c.role='Runner';c.state='Active';c.now=16;attempt=Core.crossingStep(nil,c)
 c.state='Lobby';c.inMatch=false;c.now=31
 _,outcome=Core.crossingStep(attempt,c);check(outcome.outcome=='timeout','an ended crossing after its deadline must count as timeout')
 c.state='Active';c.inMatch=true;c.now=16;attempt=Core.crossingStep(nil,c)
 c.enabled=false
 _,outcome=Core.crossingStep(attempt,c);check(outcome.outcome=='aborted','manual Stop must not be counted as a loss')
 c.enabled=true;c.state='Active';c.inMatch=true;c.role='Runner';c.now=16;c.endsAt=30
 attempt=Core.crossingStep(nil,c)
 c.endsAt=40;c.now=25;attempt=Core.crossingStep(attempt,c)
 c.state='Lobby';c.inMatch=false;c.now=31
 _,outcome=Core.crossingStep(attempt,c)
 check(outcome.outcome=='aborted','a server-extended deadline must not turn an ambiguous exit into a timeout')
 c.state='Active';c.inMatch=true;c.now=16;c.endsAt=30
 attempt=Core.crossingStep(nil,c)
 c.character='new';c.health=0
 _,outcome=Core.crossingStep(attempt,c)
 check(outcome.outcome=='aborted','a different character must not attribute its death to the previous attempt')
 c.health=100;c.enabled=true;c.special=true
 check(Core.crossingStep(nil,c)==nil,'special events must not contaminate crossing statistics')
 return {passed=n}
end
