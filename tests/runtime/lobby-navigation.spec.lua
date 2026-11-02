-- Async fake path service; the helper never applies movement itself.
return function(source)
 local first=assert(source:find('local function createLobbyNavigation(',1,true),'lobby navigation factory missing')
 local last=assert(source:find('runner.createLobbyNavigation=createLobbyNavigation',first,true))
 local factory=assert(loadstring(source:sub(first,last-1)..'\nreturn createLobbyNavigation'))()
 local now=0;local pending={};local computes=0;local canWalk=true;local pathFails=false
 local waypoints={{Position=Vector3.zero},{Position=Vector3.new(5,0,0),Action=Enum.PathWaypointAction.Jump},{Position=Vector3.new(10,0,0)}}
 local nav=factory({clock=function()return now end,canWalk=function()return canWalk end,
 spawn=function(fn)pending[#pending+1]=fn end,pathfinding={CreatePath=function()
  return{Status=Enum.PathStatus.Success,ComputeAsync=function()computes=computes+1;if pathFails then error('blocked')end end,GetWaypoints=function()return waypoints end}
 end}})
 local root={Position=Vector3.zero};local human={Health=100};local char={}
 nav:SetGoal(Vector3.new(10,0,0),1)
 local dir,jump,status=nav:Step(char,human,root);assert(dir==Vector3.zero and status=='planning' and #pending==1,'planning yields zero and computes asynchronously')
 nav:Step(char,human,root);assert(#pending==1,'one outstanding compute')
 table.remove(pending,1)();dir,jump=nav:Step(char,human,root)
 assert(dir.X>.99 and jump,'waypoint direction and jump returned')
 root.Position=Vector3.new(8.5,0,0);dir,jump,status=nav:Step(char,human,root);assert(dir.X>.99 and status=='walking','final waypoint respects goal range rather than intermediate radius')
 root.Position=Vector3.new(9.5,0,0);dir,jump,status=nav:Step(char,human,root);assert(dir==Vector3.zero and not jump and status=='arrived','goal range stops')
 nav:SetGoal(Vector3.new(20,0,0),1);now=1;root.Position=Vector3.zero;nav:Step(char,human,root)
 nav:Cancel();table.remove(pending,1)();dir,jump,status=nav:Step(char,human,root);assert(dir==Vector3.zero and status=='idle','cancel invalidates stale async path')
 nav:SetGoal(Vector3.new(10,0,0),1);now=2;nav:Step(char,human,root);table.remove(pending,1)()
 canWalk=false;dir,jump,status=nav:Step(char,human,root);assert(dir==Vector3.zero and status=='blocked','walk guard stops stale direction');canWalk=true
 now=5;nav:Step(char,human,root);assert(#pending==1,'stuck route schedules recovery')
 table.remove(pending,1)();now=5.1;nav:Step(char,human,root);assert(#pending==0,'recovery rate limited')
 nav:Cancel();nav:SetGoal(Vector3.new(10,0,0),1);pathFails=true;now=6
 nav:Step(char,human,root);table.remove(pending,1)();dir,jump,status=nav:Step(char,human,root)
 assert(dir==Vector3.zero and status=='blocked','failed path never falls back to blind movement')
 nav:Cancel();pathFails=false;now=7;root.Position=Vector3.new(0,3,0);root.Size=Vector3.new(2,2,1);human.HipHeight=2
 nav:SetGoal(Vector3.new(10,3,0),1);nav:Step(char,human,root);table.remove(pending,1)()
 dir,jump,status=nav:Step(char,human,root);assert(dir.X>.99 and jump,'root above ground waypoint advances and walks')
 root.Position=Vector3.new(9.5,3,0);dir,jump,status=nav:Step(char,human,root);assert(status=='arrived' and dir==Vector3.zero,'ground path final waypoint reaches root-height goal')
 nav:Cancel();now=8;root.Position=Vector3.new(0,20,0);nav:SetGoal(Vector3.new(10,0,0),1)
 nav:Step(char,human,root);table.remove(pending,1)();dir,jump,status=nav:Step(char,human,root)
 assert(dir==Vector3.zero and not jump and status~='arrived','far vertical waypoint is not advanced under a bridge')
 nav:Cancel();nav:SetGoal(Vector3.zero,1);dir,jump,status=nav:Step(char,human,root);assert(status~='arrived','far vertical goal never counts as arrived')
 nav:Cancel();now=9;root.Position=Vector3.new(9.5,3,0);nav:SetGoal(Vector3.new(10,0,0),1)
 dir,jump,status=nav:Step(char,human,root);assert(status=='arrived' and dir==Vector3.zero,'ground-height goal accepts standing root height')
 return {async='passed',waypoints='passed',range='passed',cancellation='passed',recovery='passed'}
end
