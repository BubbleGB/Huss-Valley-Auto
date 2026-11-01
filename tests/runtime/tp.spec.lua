-- Real client collision probes; no actual player teleportation or combat remotes.
return function(source)
    local env=getgenv()
    local saved=env.HussTPDodgeState
    env.HussTPDodgeState=nil
    local marker='env.HussAutoCross=api'
    local first,last=assert(source:find(marker,1,true))
    local probe=[[
local world=Instance.new('Model');world.Name='HussTPGeometryFixture';world.Parent=workspace
local body=Instance.new('Model');body.Name='TPProbeBody';body.Parent=workspace
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Size=Vector3.new(2,2,1)
root.Anchored=true;root.Position=Vector3.new(20000,20,20000);root.Parent=body
local floor=Instance.new('Part');floor.Size=Vector3.new(40,1,40);floor.Anchored=true
floor.Position=root.Position-Vector3.new(0,3.5,0);floor.Parent=world
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={body};params.RespectCanCollide=true
local ground=RaycastParams.new();ground.FilterType=Enum.RaycastFilterType.Include
ground.FilterDescendantsInstances={world};ground.RespectCanCollide=true
local ok,err=pcall(function()
    local point=root.Position+Vector3.new(4,0,0)
    assert(tp.probe(body,root,world,point,params,ground),'clear supported landing must pass actual geometry checks')
    local wall=Instance.new('Part');wall.Name='ThinObstacle';wall.Anchored=true
    wall.Size=Vector3.new(.3,8,10);wall.Position=root.Position+Vector3.new(2,0,0);wall.Parent=world
    local thin=tp.probe(body,root,world,point,params,ground)
    assert(thin and thin.pathBlocked and thin.thinObstacle,'verified thin obstacle must be crossable with a clear landing and exit')
    local side=Instance.new('Part');side.Name='SafeZoneBoundary';side.Anchored=true
    side.Size=Vector3.new(.2,8,.2);side.Position=root.Position+Vector3.new(2.2,0,1.5);side.Parent=world
    assert(not tp.probe(body,root,world,point,params,ground),'a second off-centre boundary in the body sweep must reject the bypass')
    side:Destroy()
    wall.Name='SafeZoneBoundary'
    assert(not tp.probe(body,root,world,point,params,ground),'safe-zone barriers must never be bypassed')
    wall.Name='ThickObstacle';wall.Size=Vector3.new(3,8,10)
    assert(not tp.probe(body,root,world,point,params,ground),'occupied landing and thick walls must fail')
    wall.Size=Vector3.new(.3,8,10);wall.Name='ThinObstacle'
    local human=Instance.new('Humanoid');human.Parent=body
    local oldEligible,oldCommit,oldParticipants=tp.eligible,tp.commit,participants
    local oldRole,oldDirection,oldProgress=activeRole,direction,runnerProgress
    local chosen
    tp.eligible=function()return true end
    tp.commit=function(_,_,candidate)chosen=candidate;return true end
    participants=function()return {}end
    api.Enabled=true;api.TPDodgeEnabled=true;activeRole='Runner';direction=Vector3.zero
    runnerProgress={at=os.clock()-2};tp.nextCheck=0
    local worked=tp.try(body,human,root,{waypoint=root.Position+Vector3.new(100,0,0),
        finish=root.Position+Vector3.new(100,0,0),field=world,collisionParams=params,groundParams=ground},
        {},{},function()return false end)
    tp.eligible,tp.commit,participants=oldEligible,oldCommit,oldParticipants
    activeRole,direction,runnerProgress=oldRole,oldDirection,oldProgress
    api.Enabled=false;api.TPDodgeEnabled=false
    assert(worked and chosen and chosen.thinObstacle,'complete TP decision must select the verified short obstacle bypass')
    tp.eligible=function()return true end
    api.Enabled=true;api.TPDodgeEnabled=true;tp.state.readyAt=0;tp.state.watch=nil;tp.state.uses=0
    direction=Vector3.xAxis
    local landing=root.Position+Vector3.new(0,0,2)
    assert(tp.commit(body,root,{point=landing,kind='fixture'},'fixture-commit'),'isolated body commit must translate to its selected landing')
    assert((root.Position-landing).Magnitude<.01 and direction.Z>.9,'post-TP movement must follow the checked exit direction')
    tp.eligible=oldEligible;api.Enabled=false;api.TPDodgeEnabled=false
    tp.state.watch=nil;tp.state.readyAt=0;tp.state.uses=0;tp.state.epoch=nil
    direction=oldDirection;api.Actions.TPDodge=0;api.TPLast=nil
    root.Position=Vector3.new(20000,20,20000)
    wall:Destroy()
    local target=Instance.new('Model');target.Name='FixtureRunner';target.Parent=world
    local targetRoot=Instance.new('Part');targetRoot.Name='HumanoidRootPart';targetRoot.Anchored=true;targetRoot.CanCollide=false
    targetRoot.Position=root.Position+Vector3.new(6,0,0);targetRoot.Parent=target
    local runner={UserId=-99,Name='FixtureRunner',Character=target,GetAttribute=function()return nil end}
    local pursuit={id=-99,player=runner,position=targetRoot.Position,velocity=Vector3.zero}
    local savedCombat,savedActive,savedHistory=combat,activeRunner,pursuitHistory
    local savedNextMelee=nextMelee
    combat=table.clone(combat);combat.meleeRemaining=function()return 0 end
    activeRunner=function(actor)return actor==runner end
    pursuitHistory={id=-99,stableSince=os.clock()-.5}
    tp.eligible=function()return true end
    tp.commit=function(_,_,candidate)chosen=candidate;api.TPLast={};return true end
    participants=function()return {runner}end
    api.Enabled=true;api.TPDodgeEnabled=true;activeRole='Catcher';direction=Vector3.xAxis;runnerProgress=nil
    params.FilterDescendantsInstances={body,target}
    local chaseContext={waypoint=root.Position+Vector3.new(100,0,0),finish=root.Position+Vector3.new(100,0,0),
        field=world,collisionParams=params,groundParams=ground}
    local function chase()
        chosen=nil;tp.nextCheck=0
        return tp.try(body,human,root,chaseContext,{}, {},function()return true end,pursuit)
    end
    assert(chase()and chosen.kind=='chase'and chosen.catchOpportunity,'chaser TP must create a real native-box melee opportunity')
    assert(chosen.distance<=4 and chosen.chaseGain>=1.5,'chaser TP must retain distance cap and interception improvement')
    target:SetAttribute('HitShielded',true)
    assert(not chase(),'shielded runner must not trigger offensive TP')
    target:SetAttribute('HitShielded',nil);target:SetAttribute('GearMotion',true)
    assert(not chase(),'evasive runner must not trigger offensive TP')
    target:SetAttribute('GearMotion',nil);pursuitHistory.stableSince=os.clock()
    assert(not chase(),'unstable runner motion must not trigger offensive TP')
    pursuitHistory.stableSince=os.clock()-.5;nextMelee=workspace:GetServerTimeNow()+2
    assert(not chase(),'melee cooldown must prevent offensive TP')
    nextMelee=0;targetRoot.Position=root.Position+Vector3.new(4,0,0);pursuit.position=targetRoot.Position
    assert(not chase(),'existing native melee reach must conserve TP')
    target:Destroy()
    combat,activeRunner,pursuitHistory=savedCombat,savedActive,savedHistory;nextMelee=savedNextMelee
    tp.eligible,tp.commit,participants=oldEligible,oldCommit,oldParticipants
    activeRole,direction,runnerProgress=oldRole,oldDirection,oldProgress
    api.Enabled=false;api.TPDodgeEnabled=false;api.TPLast=nil
    tp.state.watch=nil;tp.state.readyAt=0;tp.state.uses=0;tp.state.epoch=nil
    params.FilterDescendantsInstances={body};floor.Size=Vector3.new(40,1,2)
    assert(not tp.probe(body,root,world,root.Position+Vector3.new(0,0,4),params,ground),'unsupported landing must fail')
    local before=root.Position
    assert(not tp.commit(body,root,{point=point},'fixture')and root.Position==before,'paused controller must not teleport even through its commit closure')
    tp.state.blocked=true
    assert(not api:SetTPDodgeEnabled(true)and not api.TPDodgeEnabled,'correction block must prevent manual rearming')
    tp.state.blocked=nil;api:SetTPDodgeEnabled(false)
end)
world:Destroy();body:Destroy()
assert(ok,err)
env.HussAutoCross=api
]]
    local a
    local ok,result=pcall(function()
        a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
        assert(not a.TPAssistEnabled and not a.TPDodgeEnabled,'TP assist must default OFF')
        a:SetTPAssistEnabled(true)
        assert(a.TPAssistEnabled and a.TPDodgeEnabled and not a.Enabled,'alias must preserve paused behavior and legacy API')
        a:SetTPDodgeEnabled(false)
        assert(not a.TPAssistEnabled and not a.TPDodgeEnabled,'legacy setter must disable both aliases')
        a:Destroy()
        return {geometry='passed',thinObstacles='passed',barriers='passed',void='passed',paused='passed',correctionBlock='passed',toggle='passed'}
    end)
    if a and not a.Destroyed then a:Destroy()end
    env.HussTPDodgeState=saved
    assert(ok,result)
    return result
end
