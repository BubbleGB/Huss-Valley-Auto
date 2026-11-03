local function vectorType(dim)
 local methods={};local mt={__type='Vector'..dim}
 local function new(...)
  local a={...};local v={X=a[1]or 0,Y=a[2]or 0};if dim==3 then v.Z=a[3]or 0 end
  return setmetatable(v,mt)
 end
 mt.__index=function(v,k)
  if k=='Magnitude'then return math.sqrt(v:Dot(v))end
  if k=='Unit'then return v/v.Magnitude end
  return methods[k]
 end
 mt.__add=function(a,b)return new(a.X+b.X,a.Y+b.Y,dim==3 and a.Z+b.Z or nil)end
 mt.__sub=function(a,b)return new(a.X-b.X,a.Y-b.Y,dim==3 and a.Z-b.Z or nil)end
 mt.__unm=function(a)return a*-1 end
 mt.__mul=function(a,b)
  if type(a)=='number'then a,b=b,a end
  if type(b)=='number'then return new(a.X*b,a.Y*b,dim==3 and a.Z*b or nil)end
  return new(a.X*b.X,a.Y*b.Y,dim==3 and a.Z*b.Z or nil)
 end
 mt.__div=function(a,b)return a*(1/b)end
 mt.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
 function methods:Dot(b)return self.X*b.X+self.Y*b.Y+(dim==3 and self.Z*b.Z or 0)end
 function methods:Cross(b)return new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
 function methods:Lerp(b,t)return self+(b-self)*t end
 return {new=new,zero=new(),one=new(1,1,1),xAxis=new(1,0,0),yAxis=new(0,1,0),zAxis=new(0,0,1)}
end
local V3,V2=vectorType(3),vectorType(2)
local C={};local cm={__type='CFrame'};local methods={}
local function frame(p,r,u,b)return setmetatable({Position=p,RightVector=r,UpVector=u,LookVector=-b},cm)end
function C.new(x,y,z)
 return frame(type(x)=='table'and x or V3.new(x,y,z),V3.xAxis,V3.yAxis,V3.zAxis)
end
function methods:VectorToWorldSpace(v)return self.RightVector*v.X+self.UpVector*v.Y-self.LookVector*v.Z end
function methods:VectorToObjectSpace(v)return V3.new(v:Dot(self.RightVector),v:Dot(self.UpVector),-v:Dot(self.LookVector))end
function methods:PointToWorldSpace(v)return self.Position+self:VectorToWorldSpace(v)end
function methods:PointToObjectSpace(v)return self:VectorToObjectSpace(v-self.Position)end
cm.__index=methods
cm.__mul=function(a,b)
 if getmetatable(b).__type=='Vector3'then return a:PointToWorldSpace(b)end
 return frame(a:PointToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),a:VectorToWorldSpace(b.UpVector),-a:VectorToWorldSpace(b.LookVector))
end
function C.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 return frame(V3.zero,V3.new(cy*cz,cx*sz+sx*sy*cz,sx*sz-cx*sy*cz),V3.new(-cy*sz,cx*cz-sx*sy*sz,sx*cz+cx*sy*sz),V3.new(sy,-sx*cy,cx*cy))
end
function C.lookAt(p,t,up)
 local back=(p-t).Unit;local right=(up or V3.yAxis):Cross(back).Unit
 return frame(p,right,back:Cross(right),back)
end
C.identity=C.new()
return {Vector3=V3,Vector2=V2,CFrame=C,Enum=setmetatable({},{__index=function(t,k)local e=setmetatable({},{__index=function(s,n)rawset(s,n,k..'.'..n);return s[n]end});rawset(t,k,e);return e end})}
