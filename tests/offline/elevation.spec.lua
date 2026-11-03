return function(source)
 local a=assert(source:find('local edgeCache={}',1,true))
 local b=assert(source:find('local function edgeAllowed',a,true))
 local make=assert(loadstring('return function(Core,terrain) local hazards={};local root={};local goal;local runner={}\n'..source:sub(a,b-1)..'\nreturn geometryAllowed end'))()
 local calls=0
 local clear=make({clearSegment=function()return true end},{Clear=function(_,a,b)calls+=1;return a.Y<10 end})
 assert(clear(Vector3.new(0,3,0),Vector3.new(4,3,0)),'lower edge clear')
 assert(not clear(Vector3.new(0,13,0),Vector3.new(4,13,0))and calls==2,'planner edge cache must distinguish endpoint elevations')
 return {passed=2}
end
