-- Real planner and final movement guard on detached geometry; no live player moves.
return function(source)
 local first,last=assert(source:find('env.HussAutoCross=api',1,true))
 local probe=[[
assert(type(detours.guardCollection)=='function','final collection movement guard missing')
local original={player=player,session=session,state=gameState,participants=participants,threats=threats,
    hazards=collectHazards,gems=detours.gems,candy=detours.candyActive}
local fixture=Instance.new('Model');fixture.Name='HussCollectionFixture';fixture.Parent=workspace
local origin=Vector3.new(20000,20000,20000)
local field=Instance.new('Folder');field.Name='Field';field.Parent=fixture
local floor=Instance.new('Part');floor.Anchored=true;floor.Size=Vector3.new(180,2,180);floor.Position=origin-Vector3.new(0,4,0);floor.Parent=field
for _,side in ipairs({'A','B'})do
    local zone=Instance.new('Part');zone.Anchored=true;zone.CanCollide=false;zone.Name='Safezone'..side..'Side'
    zone.Size=Vector3.new(12,2,120);zone.Position=origin+Vector3.new(side=='A'and-72 or 72,-3,0);zone.Parent=field
end
local character=Instance.new('Model');character.Parent=workspace
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Anchored=true;root.Position=origin;root.Parent=character
local human=Instance.new('Humanoid');human.Parent=character
local event=Instance.new('Folder');event:SetAttribute('Phase','GroupRun');event:SetAttribute('RunNumber',1)
event:SetAttribute('StartSide','A');event:SetAttribute('EndsAt',workspace:GetServerTimeNow()+30)
local attrs={InMatch=true,GameRole='Runner',RunState='Active'}
player=setmetatable({Character=character,UserId=original.player.UserId,GetAttribute=function(_,k)return attrs[k]end},
    {__index=function(_,k)return original.player[k]end})
session=event
local state=original.state
gameState=setmetatable({FindFirstChild=function(_,n)if n=='ActiveMap'then return{Value=fixture}end return state:FindFirstChild(n)end},
    {__index=function(_,k)return state[k]end})
participants=function()return {}end;threats=function()return {}end;collectHazards=function()return {},''end
detours.candyActive=function()return false end
local gem=Instance.new('Part');gem.Anchored=true;gem.CanCollide=false;gem.Position=origin+Vector3.new(15,0,3);gem.Parent=fixture
local board=Instance.new('BillboardGui');board.Enabled=true;board.Parent=gem
local icon=Instance.new('Frame');icon.Name='Gem';icon.Visible=true;icon.Parent=board
local item={kind='gem',id='forward',source=gem,position=gem.Position,value=3}
detours.gems=function()return{table.clone(item)}end
local ok,err=pcall(function()
    api.Enabled=true;api.AutoGemsEnabled=true;activeRole='Runner'
    plan(character,human,root)
    assert(actionContext and actionContext.collection,'forward pickup integrated into planner')
    assert(direction:Dot(Vector3.xAxis)>=0,'pickup steering never reverses crossing axis')
    assert(not actionContext.geometryAllowed(origin,origin-Vector3.xAxis),'collection geometry rejects backward walk/dash')
    assert(not actionContext.allowed(-Vector3.xAxis,3),'fast action previews reject reverse collection travel')
    assert(not detours.guardCollection(root),'visible forward pickup remains valid')
    direction=-Vector3.xAxis
    assert(detours.guardCollection(root)and direction==Vector3.zero and not actionContext and not navigation,
        'reverse command cancels pickup and stale route before movement')
    plan(character,human,root);assert(not actionContext.collection,'abandoned blocked pickup is not immediately selected again')
    detours.retry={};plan(character,human,root);root.Position=origin+Vector3.xAxis*16
    assert(detours.guardCollection(root)and direction==Vector3.zero,'passed pickup abandoned immediately')
    plan(character,human,root);assert(not actionContext.collection,'passed pickup not selected again')
    root.Position=origin;navigation=nil;detours.retry={};plan(character,human,root);icon.Visible=false
    assert(detours.guardCollection(root),'collected icon is abandoned without circling back')
    icon.Visible=true;detours.retry={};plan(character,human,root);api.AutoGemsEnabled=false
    assert(detours.guardCollection(root),'collection toggle off cancels current pickup')
    api.AutoGemsEnabled=true;detours.retry={};plan(character,human,root);direction=Vector3.zero
    assert(detours.guardCollection(root),'blocked pickup cannot stall crossing')
    api:SetSetting('AutoSeasonalCurrency',false)
    assert(not api.Settings.AutoSeasonalCurrency,'seasonal toggle independently disabled')
    detours.retry={};event:SetAttribute('RunNumber',2);event:SetAttribute('StartSide','B');root.Position=origin
    plan(character,human,root);assert(not actionContext.collection,'opposite crossing cannot return for a pickup behind')
    item.position=origin-Vector3.xAxis*15;gem.Position=item.position
    plan(character,human,root);assert(actionContext.collection and actionContext.collection.forward.X<0,'opposite crossing axis follows safe zones')
    assert(not actionContext.geometryAllowed(origin,origin+Vector3.xAxis),'opposite direction geometry remains forward-only')
end)
api.Enabled=false;release();api.AutoGemsEnabled=false
player,session,gameState,participants,threats,collectHazards=original.player,original.session,original.state,original.participants,original.threats,original.hazards
detours.gems,detours.candyActive=original.gems,original.candy
fixture:Destroy();character:Destroy();event:Destroy()
assert(ok,err)
env.HussAutoCross=api
]]
 local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
 a:Destroy()
 return {planner='passed',forwardEdges='passed',passedPickup='passed',collected='passed',disabled='passed',blocked='passed'}
end
