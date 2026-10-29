-- Instrument only math/table primitives in an isolated decision chunk. No live
-- input, remotes or controller initialization are used.
return function(source)
 local marker=assert(source:find('-- Runtime',1,true))
 local bootstrap=[[
local nativeMath,nativeTable=math,table
local counters={trig=0,copies=0}
local math=setmetatable({cos=function(v)counters.trig=counters.trig+1;return nativeMath.cos(v)end,
 sin=function(v)counters.trig=counters.trig+1;return nativeMath.sin(v)end},{__index=nativeMath})
local table=setmetatable({clone=function(v)counters.copies=counters.copies+1;return nativeTable.clone(v)end},{__index=nativeTable})
]]
 local Core,counters=assert(loadstring(bootstrap..source:sub(1,marker-1)..'\nreturn Core,counters'))()
 local z=Vector3.zero
 Core.choose(z,Vector3.new(40,0,0),30,{},function()return true end,z)
 local warmed=counters.trig
 Core.choose(z,Vector3.new(0,0,40),30,{},function()return true end,z)
 assert(counters.trig==warmed,'subsequent steering decisions must reuse fixed directions without trigonometry')
 local threats={}
 for i=1,9 do threats[i]={position=Vector3.new(80,0,i*10),velocity=Vector3.new(-10,0,0),radius=20,catchRadius=6}end
 local before=counters.copies
 assert(Core.runnerEdge(z,Vector3.new(10,0,0),.1,.4,threats),'fixture must have safe swept clearance')
 assert(counters.copies==before,'swept interval checks must not clone every threat snapshot')
 local leaving={position=Vector3.new(8,0,0),velocity=Vector3.xAxis,radius=10,catchRadius=8,expires=.01}
 assert(Core.runnerEdge(z,z,0,.5,{leaving}),'expiry must not shorten the overlap-escape endpoint check')
 local e={position=Vector3.new(10,0,0),velocity=Vector3.new(-10,0,0)}
 local gap,eta=Core.threatApproach(z,z,e,1,2)
 assert(math.abs(gap+2)<.001 and math.abs(eta-.8)<.001,'ordinary swept catch time must remain exact')
 gap,eta=Core.threatApproach(z,z,e,1,2,.3)
 assert(math.abs(gap+2)<.001 and math.abs(eta-.5)<.001,'offset intervals must use the actual future starting position')
 e.velocity=Vector3.new(-20,0,0);e.burstFor=.2;e.afterVelocity=Vector3.new(5,0,0)
 gap,eta=Core.threatApproach(z,z,e,.8,2)
 assert(math.abs(gap-4)<.001 and eta==math.huge,'finite burst followed by retreat must preserve minimum clearance')
 gap=Core.threatApproach(z,z,e,.5,2,.3)
 assert(math.abs(gap-4.5)<.001,'an interval after the burst must use ordinary after-motion')
 -- Frozen previous vector implementation is an independent parity oracle for
 -- the allocation-free scalar sweep, including interval offsets.
 local function flat(v)return Vector3.new(v.X,0,v.Z)end
 local function reference(position,ownVelocity,enemy,horizon,radius)
    if math.abs(enemy.position.Y-position.Y)>12 and not enemy.airborne then return math.huge,math.huge end
    horizon=math.max(0,math.min(horizon,enemy.expires or horizon))
    local burst=math.clamp(enemy.burstFor or horizon,0,horizon)
    local relative=flat(enemy.position-position)
    local best,eta=math.huge,math.huge
    local function segment(start,duration,travel)
        local velocity=flat(travel-ownVelocity)
        local square=velocity:Dot(velocity)
        local at=square>.0001 and math.clamp(-relative:Dot(velocity)/square,0,duration)or 0
        best=math.min(best,(relative+velocity*at).Magnitude-radius)
        local c=relative:Dot(relative)-radius*radius
        if c<=0 then eta=math.min(eta,start)
        elseif square>.0001 then
            local b=2*relative:Dot(velocity)
            local disc=b*b-4*square*c
            if disc>=0 then
                local contact=(-b-math.sqrt(disc))/(2*square)
                if contact>=0 and contact<=duration then eta=math.min(eta,start+contact)end
            end
        end
        relative=relative+velocity*duration
    end
    segment(0,burst,enemy.velocity)
    if burst<horizon then segment(burst,horizon-burst,enemy.afterVelocity or enemy.velocity)end
    return best,eta
end


 local random=Random.new(104729)
 for i=1,300 do
  local base=i%2==0 and 20000 or 0
  local position=Vector3.new(base,0,base)
  local enemy={position=position+Vector3.new(random:NextNumber(-70,70),random:NextNumber(-10,10),random:NextNumber(-70,70)),
   velocity=Vector3.new(random:NextNumber(-70,70),0,random:NextNumber(-70,70))}
  if i%3==0 then enemy.burstFor=random:NextNumber(.05,.5);enemy.afterVelocity=Vector3.new(random:NextNumber(-30,30),0,random:NextNumber(-30,30))end
  if i%4==0 then enemy.expires=random:NextNumber(.1,1.2)end
  local offset=random:NextNumber(0,.7)
  local horizon=random:NextNumber(.05,.8)
  local velocity=Vector3.new(random:NextNumber(-40,40),0,random:NextNumber(-40,40))
  local radius=random:NextNumber(5,10)
  local shifted=table.clone(enemy)
  local burst=enemy.burstFor and math.max(0,enemy.burstFor)or offset
  shifted.position=enemy.position+enemy.velocity*math.min(offset,burst)+(enemy.afterVelocity or enemy.velocity)*math.max(0,offset-burst)
  if enemy.burstFor then shifted.burstFor=math.max(0,enemy.burstFor-offset);if shifted.burstFor==0 then shifted.velocity=enemy.afterVelocity or enemy.velocity end end
  if enemy.expires then shifted.expires=math.max(0,enemy.expires-offset)end
  local oldGap,oldTime=reference(position,velocity,shifted,horizon,radius)
  local gap,time=Core.threatApproach(position,velocity,enemy,horizon,radius,offset)
  assert(math.abs(gap-oldGap)<.01,'optimized sweep must retain prior clearance within sub-stud numeric tolerance')
  assert(oldTime==math.huge and time==math.huge or oldTime~=math.huge and time~=math.huge and math.abs(oldTime-time)<.001,
   'optimized sweep must retain contact/no-contact decisions and timing')
 end
 return {numericReplays=300,fixedDirections='passed',noThreatClones='passed',sweptTimes='passed',finiteMotion='passed'}
end
