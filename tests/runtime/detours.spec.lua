-- Native sequence semantics through actual closures; remote dispatch is replaced in fixture.
return function(source)
    local first,last=assert(source:find('env.HussAutoCross=api',1,true))
    local probe=[[
assert(type(api.SetAutoGemsEnabled)=='function'and type(api.SetAutoReviveEnabled)=='function','gem/revive toggles are missing')
local detours=runner.detours
local original={player=player,session=session,participants=participants}
local fixture=Instance.new('Model');fixture.Parent=workspace
local body=Instance.new('Part');body.Name='HumanoidRootPart';body.Anchored=true;body.Position=Vector3.new(20000,20000,20000);body.Parent=fixture
local downed=Instance.new('Model');downed.Parent=workspace
local targetRoot=Instance.new('Part');targetRoot.Name='HumanoidRootPart';targetRoot.Anchored=true;targetRoot.Position=body.Position+Vector3.xAxis*4;targetRoot.Parent=downed
local actor={UserId=555,Character=downed}
function actor:GetAttribute(key)return key=='GameRole'and'Runner'or key=='InMatch'and true or key=='RunState'and'Caught'end
local event=Instance.new('Folder');event:SetAttribute('Phase','GroupRun');event:SetAttribute('RunNumber',1)
player=setmetatable({Character=fixture,UserId=original.player.UserId,GetAttribute=function(_,k)
    if k=='GameRole'then return 'Runner'elseif k=='RunState'then return 'Active'elseif k=='InMatch'then return true end
    return original.player:GetAttribute(k)end},{__index=function(_,k)return original.player[k]end})
session=event;participants=function()return {actor}end
local requests={}
detours.rescueConfig={Enabled=true,HoldSeconds=.3,Range=7,FinishGrace=1.5}
detours.gemConfig={Enabled=true};detours.remote={FireServer=function(_,kind,id)requests[#requests+1]={kind=kind,id=id}end}
local gemFolder=Instance.new('Folder');local gem=Instance.new('Part');gem.Anchored=true;gem.Name='Gem_1';gem.Position=body.Position+Vector3.xAxis*15;gem.Parent=gemFolder
local board=Instance.new('BillboardGui');board.Enabled=true;board.Parent=gem
local icon=Instance.new('Frame');icon.Name='Gem';icon.Visible=true;icon.Parent=board
local amount=Instance.new('TextLabel');amount.Name='Amount';amount.Text='+3';amount.Parent=board
local ok,err=pcall(function()
    assert(not api.AutoGemsEnabled and not api.AutoReviveEnabled,'detours must default off')
    api:SetAutoGemsEnabled(true);assert(api.AutoGemsEnabled and not api.AutoReviveEnabled,'gem toggle must be independent')
    local list=detours.gems(body.Position,gemFolder);assert(#list==1 and list[1].value==3,'visible native gem must be sensed')
    icon.Visible=false;assert(#detours.gems(body.Position,gemFolder)==0,'collected gem animation must not be targeted');icon.Visible=true
    local candyFolder=Instance.new('Folder');local candy=gem:Clone();candy.Name='Candy_1';candy.Parent=candyFolder
    local candyBoard=candy:FindFirstChildWhichIsA('BillboardGui');candyBoard.Name='CandyCorn'
    candyBoard.Gem.Name='Candy'
    local candies=detours.candy(body.Position,candyFolder)
    assert(#candies==1 and candies[1].kind=='candy'and candies[1].value==3,'visible candy sensed separately from gems')
    candyBoard.Candy.Visible=false
    assert(#detours.candy(body.Position,candyFolder)==0,'collected candy animation ignored')
    candyBoard.Candy.Visible=true;candyBoard.Enabled=false
    assert(#detours.candy(body.Position,candyFolder)==0,'hidden candy ignored')
    candyFolder:Destroy()
    api:SetAutoReviveEnabled(true)
    downed:SetAttribute('RescueAvailable',true);downed:SetAttribute('Ragdolled',true)
    local selected=detours.select(body,body.Position+Vector3.xAxis*100,{}, {urgency=0},function()return true end,20)
    assert(selected and selected.kind=='revive','actual planner selection must find an eligible revive')
    activeRole='Runner';api.Enabled=true
    local context={character=fixture,role='Runner',nearby={},geometryAllowed=function()return true end,
        policy={urgency=0},secondsLeft=20}
    direction=Vector3.xAxis
    assert(detours.act(fixture,body,context,{}, {},100),'eligible revive must hold movement')
    assert(#requests==1 and requests[1].kind=='Begin'and direction==Vector3.zero,'revive must begin once and stop movement')
    detours.select(body,body.Position+Vector3.xAxis*100,{}, {urgency=0},function()return true end,20)
    assert(detours.hold and detours.hold.started==100,'replanning must retain native hold progress')
    detours.act(fixture,body,context,{}, {},100.15);assert(#requests==1,'Finish must not be sent before native hold duration')
    detours.act(fixture,body,context,{}, {},100.31);assert(#requests==2 and requests[2].kind=='Finish','Finish must follow actual hold duration')
    detours.act(fixture,body,context,{}, {},100.5);assert(#requests==2,'completed hold must not spam Finish')
    detours.cancel();detours.retry={};detours.used=0
    detours.target={kind='revive',id=actor.UserId,actor=actor,character=downed,position=targetRoot.Position}
    detours.act(fixture,body,context,{}, {},103)
    local enemy={position=body.Position+Vector3.xAxis*10,velocity=-Vector3.xAxis*40,radius=8,catchRadius=6}
    assert(not detours.act(fixture,body,context,{enemy},{},103.1),'incoming attack must abandon revive')
    assert(requests[#requests].kind=='Cancel'and not detours.hold,'danger must cancel pending hold')
    detours.retry={};detours.target={kind='revive',id=actor.UserId,actor=actor,character=downed,position=targetRoot.Position}
    detours.act(fixture,body,context,{}, {},106)
    api:Stop();assert(not detours.hold and requests[#requests].kind=='Cancel','Stop must cancel pending native hold')
    detours.retry={};detours.used=0
    detours.target={kind='revive',id=actor.UserId,actor=actor,character=downed,position=targetRoot.Position}
    api.Enabled=true;detours.act(fixture,body,context,{}, {},109)
    assert(type(detours.reply)=='function','native rescue cancellation reply handling is missing')
    local count=#requests;detours.reply('Cancelled',actor.UserId)
    assert(not detours.hold and #requests==count,'server cancellation must clear hold without sending another Cancel')
    api:SetAutoGemsEnabled(false);api:SetAutoReviveEnabled(false)
    assert(not api.AutoGemsEnabled and not api.AutoReviveEnabled,'toggles must disable independently')
end)
api.Enabled=false;release();player,session,participants=original.player,original.session,original.participants
fixture:Destroy();downed:Destroy();event:Destroy();gemFolder:Destroy()
assert(ok,err)
env.HussAutoCross=api
]]
    local a=assert(loadstring(source:sub(1,first-1)..probe..source:sub(last+1)))()
    a:Destroy()
    return {toggles='passed',gems='passed',nativeHold='passed',dangerCancellation='passed',stop='passed'}
end
