-- Exercise actual native reporter/AFK controls through isolated closures.
-- The controller never starts; no movement planning or input reaches the game.
return function(source)
    local core=assert(source:match('(local settingDefaults.-)function Core.priorityRank'))
    local antiSource=assert(source:match('(local function finishTouch.-)api.Settings=Core.defaultSettings'))
    local fixture=[[
local Core={};local api={Enabled=true}
local runner={keepAliveSurface={Visible=false}}
local anti={buttons={},touches={},idleConnections={},nextTouch=math.huge,nextScan=math.huge}
local player=game.Players.LocalPlayer
local Input=game:GetService('UserInputService');local ContextActions=game:GetService('ContextActionService')
local hudNavigation=require(game.ReplicatedStorage.ChickenOrHero.Presentation.HudNavigation)
local binding='HussIsolatedAFKAudit'
local virtualEnds=0
local VirtualInput={SendTouchEvent=function(_,_,state)assert(state==2);virtualEnds=virtualEnds+1 end,
 SendKeyEvent=function()error('keyboard input forbidden')end}
]]
    local probe=[[
api.Settings=Core.defaultSettings()
local original=hudNavigation.handlers.AFK
local buttons={}
for _,button in ipairs(player.PlayerGui:GetDescendants())do
 if button:IsA('GuiButton')and(button.Name=='AFKButton'or button.Name=='AFKToggle')then
  buttons[button]={interactable=button.Interactable,selectable=button.Selectable}
 end
end
local reporters={}
if getconnections then
 for _,connection in ipairs(getconnections(player.Idled))do
  local ok,owner=pcall(function()return type(connection.Function)=='function'and getfenv(connection.Function).script end)
  if ok and owner==player.PlayerScripts:FindFirstChild('IdleReportClient')then reporters[connection]=connection.Enabled end
 end
end
local ok,err=pcall(function()
 antiStart();assert(runner.keepAliveSurface.Visible,'Start must show owned touch sink')
 for connection,enabled in pairs(reporters)do if enabled then assert(not connection.Enabled,'Start must block real native idle reporter')end end
 assert(hudNavigation.handlers.AFK~=original,'Start must own AFK navigation handler')
 for button in pairs(buttons)do
  assert(not button.Interactable and not button.Selectable,'Start must lock actual AFK controls')
  button.Interactable=true;task.wait()
  assert(not button.Interactable,'lock must survive native UI refresh')
 end
 anti.touch={id=123,x=10,y=10};antiStop();assert(not runner.keepAliveSurface.Visible,'Stop must hide owned sink')
 assert(anti.touch==nil and virtualEnds==1,'Stop must release pending touch through stub only')
 for connection,enabled in pairs(reporters)do assert(connection.Enabled==enabled,'Stop must restore real reporter ownership')end
 assert(hudNavigation.handlers.AFK==original,'Stop must restore exact native handler')
 for button,record in pairs(buttons)do
  if button.Parent then assert(button.Interactable==record.interactable and button.Selectable==record.selectable,'Stop must restore exact control properties')end
 end
end)
antiStop();api.Enabled=false;assert(ok,err)
return {controls='passed',restoration='passed',touchCleanup='passed',isolated='passed'}
]]
    return assert(loadstring(fixture..core..antiSource..probe))()
end
