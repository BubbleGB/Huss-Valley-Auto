return function(source)
 local first=assert(source:find('local function createFacingCamera(services)',1,true),'camera facing factory missing')
 local last=assert(source:find('runner.createFacingCamera=createFacingCamera',first,true))
 local make=assert(loadstring(source:sub(first,last-1)..'\nreturn createFacingCamera'))()
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 local model=Instance.new('Model');local root=Instance.new('Part');root.Parent=model
 local h=Instance.new('Humanoid');h.Parent=model
 local focus=Vector3.new(0,3,0);local camera={CameraType=Enum.CameraType.Custom,CameraSubject=h,Focus=CFrame.new(focus),FieldOfView=70,CFrame=CFrame.lookAt(Vector3.new(0,7,12),focus)}
 local allowed=true;local align=make({camera=function()return camera end,allowed=function()return allowed end})
 local distance=(camera.CFrame.Position-focus).Magnitude;local pitch=camera.CFrame.LookVector.Y;local pos=root.Position
 check(align:Step(model,h,root,Vector3.xAxis),'camera yaw aligned')
 local flat=camera.CFrame.LookVector*Vector3.new(1,0,1)
 check(flat.Unit:Dot(Vector3.xAxis)>.999,'native cached camera yaw agrees with requested facing')
 check(math.abs((camera.CFrame.Position-focus).Magnitude-distance)<.001 and math.abs(camera.CFrame.LookVector.Y-pitch)<.001,'preserve zoom and pitch')
 check(camera.Focus==CFrame.new(focus)and camera.CameraType==Enum.CameraType.Custom and camera.CameraSubject==h and camera.FieldOfView==70,'normal camera ownership and focus remain')
 check(root.Position==pos,'camera alignment cannot translate player')
 local saved=camera.CFrame;allowed=false;check(not align:Step(model,h,root,-Vector3.xAxis)and camera.CFrame==saved,'menu/stop guard');allowed=true
 camera.CameraType=Enum.CameraType.Scriptable;check(not align:Step(model,h,root,-Vector3.xAxis),'native cinematic guard');camera.CameraType=Enum.CameraType.Custom
 camera.CameraSubject=root;check(not align:Step(model,h,root,-Vector3.xAxis),'spectating or another subject yields');camera.CameraSubject=h
 model:SetAttribute('GearMotion',true);check(not align:Step(model,h,root,-Vector3.xAxis),'native motion yields');model:SetAttribute('GearMotion',nil)
 check(not align:Step(model,h,root,Vector3.zero),'zero aim cannot move camera')
 model:Destroy();return {passed=n}
end
