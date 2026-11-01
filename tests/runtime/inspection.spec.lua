-- Uses real GUI/projection helpers and cached fixture data; sends no game actions.
return function(source)
    local first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local probe=[[
assert(type(api.SetInspectionEnabled)=='function','inspection toggle is missing')
local savedCamera=workspace.CurrentCamera
local camera=Instance.new('Camera');camera.CFrame=CFrame.lookAt(Vector3.new(20000,20000,20000),Vector3.new(20000,20000,19900))
workspace.CurrentCamera=camera
local origin=camera.CFrame.Position+camera.CFrame.LookVector*50
local character=Instance.new('Model');local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Position=origin;root.Parent=character
local originalPlayer=player
player=setmetatable({Character=character,GetAttribute=function(_,key)return originalPlayer:GetAttribute(key)end},{__index=function(_,key)return originalPlayer[key]end})
local ok,err=pcall(function()
    assert(not api.InspectionEnabled and not inspection.card.Visible,'inspection must default off')
    api:SetInspectionEnabled(true)
    assert(api.InspectionEnabled and inspection.card.Visible,'Info toggle must expose panel')
    api.Enabled=true
    actionContext={at=os.clock(),character=character,role='Runner',waypoint=origin+Vector3.zAxis*10,finish=origin-Vector3.zAxis*25,
        nearby={},hazards={}}
    for i=1,20 do actionContext.nearby[i]={position=origin+Vector3.new(i,0,-5),velocity=Vector3.xAxis*10,radius=8}end
    navigation={index=2,path={origin}}
    for i=2,30 do navigation.path[i]=origin-Vector3.zAxis*i end
    api.Diagnostics={role='Runner',routing='planned',chasers=20,hazards=0,secondsLeft=10}
    inspection.tick(.2)
    assert(inspection.layer.Visible and inspection.goal.Visible,'active cached goal must project to screen')
    assert(#inspection.lines==8 and #inspection.markers==4,'visual object pool must stay bounded')
    local visible=0;for _,v in ipairs(inspection.markers)do if v.Visible then visible=visible+1 end end
    assert(visible==4,'only four nearest cached threats should be drawn')
    assert(inspection.details.Text:find('Runner',1,true)and inspection.details.Text:find('planned',1,true),'panel must describe current role and route')
    local updates=inspection.updates;inspection.tick(.01)
    assert(inspection.updates==updates,'visuals must not redraw every frame')
    actionContext.finish=camera.CFrame.Position-camera.CFrame.LookVector*50
    inspection.tick(.2);assert(not inspection.goal.Visible,'behind-camera goals must not produce misleading markers')
    actionContext.at=os.clock()-1;inspection.tick(.2)
    assert(not inspection.layer.Visible,'stale context must hide world markers')
    actionContext.at=os.clock();inspection.tick(.2)
    api:Stop();assert(not inspection.layer.Visible,'Stop must immediately hide markers')
    api:SetInspectionEnabled(false);assert(not inspection.card.Visible and not inspection.layer.Visible,'toggle off must hide both surfaces')
end)
api.Enabled=false;release();player=originalPlayer;api.Diagnostics=nil
workspace.CurrentCamera=savedCamera;camera:Destroy();character:Destroy()
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    local ui=game.Players.LocalPlayer.PlayerGui:FindFirstChild('HussAutoCrossUI')
    a:Destroy();assert(not ui.Parent,'Destroy must remove diagnostics with the owning GUI')
    return {projection='passed',limits='passed',throttle='passed',stale='passed',lifecycle='passed'}
end
