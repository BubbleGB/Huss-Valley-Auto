return function(source)
 local a=assert(source:find('local function createTerrainGeometry',1,true),'terrain geometry factory missing')
 local b=assert(source:find('runner.createTerrainGeometry=createTerrainGeometry',a,true))
 local make=assert(loadstring(source:sub(a,b-1)..'\nreturn createTerrainGeometry'))()
 local hole=false;local wall=false;local rises=0
 local world={Raycast=function(_,origin)
  if hole and origin.X>8 then return nil end
  return {Position=Vector3.new(origin.X,origin.X*.2,origin.Z),Normal=Vector3.yAxis}
 end,Blockcast=function(_,_,_,delta)if math.abs(delta.Y)>.01 then rises=rises+1 end;return wall and{}or nil end}
 local g=make({world=world,ceiling=100,bottom=-100,clearance=3,maxSlope=50})
 assert(g:Clear(Vector3.new(0,3,0),Vector3.new(60,3,0))and rises>0,'long gradual slope follows sampled ground rather than fixed root height')
 wall=true;assert(not g:Clear(Vector3.new(0,3,0),Vector3.new(4,3,0)),'actual obstacle still blocks')
 wall=false;hole=true;local h=make({world=world,ceiling=100,bottom=-100,clearance=3,maxSlope=50})
 assert(not h:Clear(Vector3.new(0,3,0),Vector3.new(20,3,0)),'missing ground remains unsafe')
 local lowerWorld={Raycast=function(_,origin)return{Position=Vector3.new(origin.X,origin.Y>20 and 20 or 0,origin.Z),Normal=Vector3.yAxis}end,
 Blockcast=function(_,cf)assert(cf.Position.Y<10,'under-bridge route must test player floor, not deck above');return nil end}
 local lower=make({world=lowerWorld,ceiling=100,bottom=-100,clearance=3,maxSlope=50})
 assert(lower:Clear(Vector3.new(0,3,0),Vector3.new(10,3,0)),'overlapping platform keeps starting elevation')
 local stackedWorld={Raycast=function(_,origin)return{Position=Vector3.new(origin.X,origin.Y>=10 and 10 or 0,origin.Z),Normal=Vector3.yAxis}end,
 Blockcast=function(_,cf)return cf.Position.Y>10 and {}or nil end}
 local stacked=make({world=stackedWorld,ceiling=30,bottom=-20,clearance=3,maxSlope=45})
 assert(stacked:Clear(Vector3.new(0,3,0),Vector3.new(4,3,0)),'lower floor is clear')
 assert(not stacked:Clear(Vector3.new(0,13,0),Vector3.new(4,13,0)),'lower-floor cached heights must not hide an upper-floor obstruction')
 return{passed=6}
end
