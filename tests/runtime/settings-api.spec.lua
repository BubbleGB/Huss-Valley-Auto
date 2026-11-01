-- Isolated fixture: no controller startup, input hooks, or live remotes.
return function(controller)
    local marker=assert(controller:find('-- Runtime',1,true))
    local Core=assert(loadstring(controller:sub(1,marker-1)..'\nreturn Core'))()
    local source=assert(controller:match('(api%.Settings=Core%.defaultSettings%(%)%s.-return table%.clone%(priorities%)%s+end)'))
    local fixture=[[
return function(Core)
local api={Enabled=true,Destroyed=false}
local starts,stops,releases=0,0,0
local function antiStart()starts=starts+1 end
local function antiStop()stops=stops+1 end
local function release()releases=releases+1 end
local activeRole='Runner'
local facingHumanoid={AutoRotate=false}
local previousAutoRotate=true
local choiceRequest,voteRequest={},{}
local elapsed,navigation=0,{}
]]..source..'\n'..[[
return api,function()return starts,stops,releases end,function()return facingHumanoid end
end
]]
    local api,counts,facing=assert(loadstring(fixture))()(Core)
    local n=0;local function check(ok,message)assert(ok,message);n=n+1 end
    local settings=api:GetSettings();settings.AutoRun=false;settings.Priorities[1]='Gems'
    check(api.Settings.AutoRun and api.Settings.Priorities[1]=='Escape','GetSettings returns independent copies')
    local before=api.Settings
    check(not pcall(api.SetSetting,api,'HeroThreshold',51)and api.Settings==before,'invalid setting atomic')
    check(not pcall(api.SetPriorities,api,{'Gems','Gems','Escape','Catches'})and api.Settings==before,'invalid permutation atomic')
    local order={'Gems','Revives','Escape','Catches'};local result=api:SetPriorities(order)
    order[1]='bad';result[2]='bad'
    check(api.Settings.Priorities[1]=='Gems'and api.Settings.Priorities[2]=='Revives','SetPriorities copies input and output')
    api:SetSetting('AntiAFK',false);local a,b=counts();check(a==0 and b==1,'AntiAFK off restores ownership')
    api:SetSetting('AntiAFK',true);a,b=counts();check(a==1 and b==1,'AntiAFK on starts when enabled')
    api.Enabled=false;api:SetSetting('AntiAFK',true);a,b=counts();check(a==1 and b==2,'stopped controller does not acquire antiAFK')
    api:SetSetting('AutoRun',false);local _,_,releases=counts();check(releases==1,'role disabling releases movement')
    local humanoid=facing();api:SetSetting('AutoFaceTarget',false)
    check(humanoid.AutoRotate and not facing(),'facing disabling restores auto rotation')
    api.Destroyed=true;before=api.Settings
    check(api:SetSetting('AutoRun',true)==false and api.Settings==before,'destroyed API inert')
    return {passed=n}
end
