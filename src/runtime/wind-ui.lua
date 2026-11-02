-- Pinned MIT library: the only control window; initialization failure cleans up transactionally.
local ui={Backend='WindUI',Controls={},Bindings={},Categories={},OwnedGuis={},Minimized=false,elapsed=0}
api.UI=ui;runner.ui=ui
function ui:Cleanup()
    if self.Cleaned then return end
    self.Cleaned=true
    -- Window destruction invokes callbacks asynchronously; silence them before teardown.
    if self.Window then
        self.Window.OnCloseCallback=nil;self.Window.OnOpenCallback=nil;self.Window.OnDestroyCallback=nil
    end
    if self.LibraryOwner then self.LibraryOwner:Cleanup()end
    if self.Window and not self.Window.Destroyed then pcall(self.Window.Destroy,self.Window)end
    for _,owned in ipairs(self.OwnedGuis)do if owned.Parent then owned:Destroy()end end
    if self.Badge then self.Badge:Destroy()end
end
function api:ExportProfile()
    return {version=1,userId=player.UserId,stopEverything=self.StopEverything==true,settings=self:GetSettings(),speed=self.SpeedMultiplier,smart=self.SmartSpeedEnabled,
        tp=self.TPAssistEnabled,gems=self.AutoGemsEnabled,revives=self.AutoReviveEnabled,inspection=self.InspectionEnabled}
end
function api:ApplyProfile(profile)
    if self.Destroyed then return false end
    assert(type(profile)=='table'and profile.version==1 and type(profile.settings)=='table','Unsupported settings profile')
    assert(profile.userId==nil or profile.userId==player.UserId,'Settings belong to another player')
    assert(profile.stopEverything==nil or type(profile.stopEverything)=='boolean','Invalid stop state')
    local settings=Core.defaultSettings()
    for key,value in pairs(profile.settings)do
        settings[key]=key=='Priorities'and Core.priorityOrder(value)or Core.settingValue(key,value)
    end
    assert(type(profile.speed)=='number'and profile.speed==profile.speed and profile.speed>=1 and profile.speed<=2,'Invalid profile speed')
    for _,key in ipairs({'smart','tp','gems','revives','inspection'})do assert(type(profile[key])=='boolean','Invalid profile '..key)end
    for key,value in pairs(settings)do if key~='Priorities'then self:SetSetting(key,value)end end
    self:SetPriorities(settings.Priorities);self:SetSpeedMultiplier(profile.speed);self:SetSmartSpeedEnabled(profile.smart)
    self:SetTPAssistEnabled(profile.tp);self:SetAutoGemsEnabled(profile.gems);self:SetAutoReviveEnabled(profile.revives)
    self:SetInspectionEnabled(profile.inspection)
    self.StopEverything=profile.stopEverything==true
    if runner.preferences and runner.preferences.ready then self:SetStopEverything(self.StopEverything)end
    if self.UI then self.UI:Refresh()end
    return true
end
function ui:Refresh()
    if self.Backend~='WindUI'or self.Cleaned then return end
    local statusText=(api.Enabled and'RUNNING'or'PAUSED')..'  |  '..api.Status
    if statusText~=self.lastStatus then self.Status:SetDesc(statusText);self.lastStatus=statusText end
    if self.MovementState then
        local tpState=api:TPReport()
        local detail=string.format('Base %.2fx | Smart cap %.2fx\nSmart burst remaining %.1f s\nTP Assist: %s',
            api.SpeedMultiplier,api.SmartCap,math.max(0,(api.SmartUntilAt or 0)-workspace:GetServerTimeNow()),
            tpState.blocked and('blocked - '..tostring(tpState.blockReason))or tpState.enabled and'enabled'or'disabled')
        if self.lastMovement~=detail then self.MovementState:SetDesc(detail);self.lastMovement=detail end
    end
    if self.PreferencesState then
        local message=api.SettingsError or'Changes save automatically for this account and load on the next execution, including Stop everything.'
        if self.lastPreferences~=message then self.lastPreferences=message;self.PreferencesState:SetDesc(message)end
    end
    local d=api.Diagnostics or{}
    local text=string.format('Role: %s  |  Route: %s\nPlan: %.2f ms  |  Refresh: %s\nChasers: %d  |  Hazards: %d\nDash: %s\nCrossings: %d safe / %d caught / %d timed out',
        d.role or player:GetAttribute('GameRole')or'Waiting',d.routing or'-',api.LastPlanMS or 0,api.LastPlanReason or'-',
        d.chasers or 0,d.hazards or 0,api.DashDecision or'-',runner.stats.safe,runner.stats.caught,runner.stats.timeout)
    if self.lastDetails~=text then self.Details:SetDesc(text);self.lastDetails=text end
    if self.EquipmentSelectors then
        for _,entry in ipairs(self.EquipmentSelectors)do
            local values,ids,names={'Keep current'}, {['Keep current']=''}, {['']='Keep current'}
            for _,item in ipairs(api:EquipmentOptions(entry.slot))do
                local label=item.name..' ['..item.id..']'..(item.count and(' x'..item.count)or'')
                values[#values+1]=label;ids[label]=item.id;names[item.id]=label
            end
            local signature=table.concat(values,'|')
            entry.ids,entry.names=ids,names
            if signature~=entry.signature then entry.signature=signature;entry.control:Refresh(values)end
        end
        local function equippedName(id)local item=gearCatalog.get(id);return item and item.Name or'None'end
        self.EquipmentState:SetDesc('Equipped runner: '..equippedName(gearCatalog.equippedForRole(armory,'Runner'))
            ..'\nEquipped chaser: '..equippedName(gearCatalog.equippedForRole(armory,'Catcher'))
            ..'\nConsumable: '..equippedName(armory.equippedGear)..'\n'
            ..(api.EquipmentStatus or'Changes equip in the lobby.'))
    end
    for _,binding in ipairs(self.Bindings)do
        local value=binding.read()
        local shown=binding.control.Value
        if type(shown)=='table'and shown.Default~=nil then shown=tonumber(shown.Default)end
        if binding.last~=value or shown~=value then
            binding.last=value
            binding.write(value)
        end
    end
    local snapshot=gameState:FindFirstChild('MapVoteState')
    if self.Ballot and snapshot and self.lastBallot~=snapshot.Value then
        self.lastBallot=snapshot.Value
        local ok,vote=pcall(Http.JSONDecode,Http,snapshot.Value)
        if ok and type(vote)=='table'then
            local names,values={}, {'Random'}
            for _,option in ipairs(vote.options or{})do
                local label=tostring(option.name or option.id)..' ('..tostring(option.id)..')'
                self.MapNames[option.id]=label;self.MapIds[label]=option.id
                names[#names+1]=label
            end
            local ids={};for id in pairs(self.MapNames)do if id~='Random'then ids[#ids+1]=id end end
            table.sort(ids)
            for _,id in ipairs(ids)do values[#values+1]=self.MapNames[id]end
            self.Controls.MapPreference:Refresh(values)
            self.Controls.MapPreference:Select(self.MapNames[api.Settings.MapPreference]or api.Settings.MapPreference)
            self.Ballot:SetDesc(table.concat(names,'\n')..'\nBallot: '..tostring(vote.phase or'Closed'))
        end
    end
end
function ui:SetPrioritySlot(slot,taskName)
    assert(type(slot)=='number'and slot>=1 and slot<=4 and slot%1==0,'Invalid priority slot')
    local order=api:GetSettings().Priorities
    local old=assert(table.find(order,taskName),'Invalid task')
    order[old],order[slot]=order[slot],order[old]
    api:SetPriorities(order);self:Refresh()
end
function ui:Minimize()
    if self.Cleaned then return end
    if self.Window then self.Window:Close()end
    self.Minimized=true;self.Badge.Visible=true
end
function ui:Restore()
    if self.Cleaned then return end
    self.Minimized=false;self.Badge.Visible=false
    if self.Window then self.Window:Open()end
end
ui.Badge=button('RestoreWindow','Huss\nValley',UDim2.fromOffset(22,100),UDim2.fromOffset(64,64),Color3.fromRGB(25,100,90))
ui.Badge.TextSize=17;ui.Badge.Parent=gui;ui.Badge.Visible=false;ui.Badge.Active=true
connect(ui.Badge.Activated,function()if not ui.BadgeDragged then ui:Restore()end;ui.BadgeDragged=false end)
do
    local drag,origin,position,moved
    connect(ui.Badge.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag,origin,position,moved=input,input.Position,ui.Badge.AbsolutePosition,false
            ui.BadgeDragged=false
        end
    end)
    connect(Input.InputChanged,function(input)
        if not drag or(input~=drag and input.UserInputType~=Enum.UserInputType.MouseMovement)then return end
        local delta=input.Position-origin
        moved=moved or delta.Magnitude>5
        if moved then
            ui.BadgeDragged=true
            local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
            ui.Badge.Position=UDim2.fromOffset(math.clamp(position.X+delta.X,0,math.max(0,viewport.X-64)),
                math.clamp(position.Y+delta.Y,0,math.max(0,viewport.Y-64)))
        end
    end)
    connect(Input.InputEnded,function(input)if input==drag then drag=nil end end)
end
connect(Input.InputBegan,function(input,processed)
    if not processed and not Input:GetFocusedTextBox()and input.KeyCode==Enum.KeyCode.RightShift then
        if ui.Minimized then ui:Restore()else ui:Minimize()end
    end
end)
local function attachWindUI()
    local cache=env.HussWindUICache
    if not cache or cache.version~='1.6.66'then
        local request={}
        task.spawn(function()
            request.ok,request.source=pcall(game.HttpGet,game,'https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua')
            request.done=true
        end)
        local deadline=os.clock()+8
        repeat task.wait()until request.done or os.clock()>=deadline
        assert(request.done and request.ok and type(request.source)=='string','WindUI download unavailable; retry loading the script')
        cache={version='1.6.66',source=request.source};env.HussWindUICache=cache
    end
    local compatible,owner=prepareWindUI(cache.source)
    ui.LibraryOwner=owner
    ui.LibraryChunkName='HussWindUI_1_6_66_'..Http:GenerateGUID(false)
    local chunk,compileError=loadstring(compatible,ui.LibraryChunkName)
    if not chunk then env.HussWindUICache=nil;error(compileError,0)end
    local loaded,library=pcall(chunk,owner)
    if not loaded then env.HussWindUICache=nil;error(library,0)end
    ui.Library=library
    for _,key in ipairs({'ScreenGui','NotificationGui','DropdownGui','TooltipGui'})do
        local owned=library[key]
        if typeof(owned)=='Instance'then
            owned.Name='HussAutoCrossWindUI_'..key;owned:SetAttribute('LightsOutKeep',true)
            owned.ResetOnSpawn=false;owned.Parent=player:WaitForChild('PlayerGui')
            ui.OwnedGuis[#ui.OwnedGuis+1]=owned
        end
    end
    local theme=table.clone(library.Themes.Dark)
    theme.Name='HussTeal';theme.Background=Color3.fromRGB(15,20,26);theme.Accent=Color3.fromRGB(20,30,37)
    theme.ElementBackground=Color3.fromRGB(28,38,46);theme.Toggle=Color3.fromRGB(45,210,165)
    theme.Slider=theme.Toggle;theme.Primary=theme.Toggle;theme.Checkbox=theme.Toggle
    library:AddTheme(theme)
    ui.Window=library:CreateWindow({Title='HUSS VALLEY',Author='Auto Play',Folder='HussValleyAutoUI',Theme='HussTeal',
        Size=UDim2.fromOffset(680,520),MinSize=Vector2.new(460,350),MaxSize=Vector2.new(900,700),
        Transparent=false,Resizable=true,SideBarWidth=165,HideSearchBar=false,Acrylic=false,
        OpenButton={Title='Huss Auto',Enabled=false,OnlyMobile=false,Draggable=true}})
    ui.Window.UIElements.Main.Main.Topbar.Active=true
    ui.Window:DisableTopbarButtons({'Close'})
    ui.Window:CreateTopbarButton('Unload','x',function()if not api.Destroyed then api:Destroy()end end,1000)
    ui.Window:OnClose(function()if not api.Destroyed and not ui.Cleaned then ui.Minimized=true;ui.Badge.Visible=true end end)
    ui.Window:OnOpen(function()if not api.Destroyed and not ui.Cleaned then ui.Minimized=false;ui.Badge.Visible=false end end)
    ui.Window:OnDestroy(function()if not api.Destroyed and not ui.Cleaned then api:Destroy()end end)
    local function tab(title,icon)
        local t=ui.Window:Tab({Title=title,Icon=icon});ui.Categories[#ui.Categories+1]=title
        return t
    end
    local dashboard=tab('Dashboard','layout-dashboard')
    local runnerTab=tab('Runner','footprints')
    local chaserTab=tab('Chaser','crosshair')
    local priorities=tab('Priorities','list-ordered')
    local voting=tab('Voting & Roles','vote')
    local movement=tab('Movement','gauge')
    local diagnostics=tab('Diagnostics','activity')
    local rewards=tab('Rewards','gift')
    local equipment=tab('Equipment','backpack')
    local function guarded(fn)
        return function(value)
            if api.Destroyed or ui.Cleaned then return end
            local ok,err=pcall(fn,value)
            api.UIError=not ok and tostring(err)or nil
        end
    end
    local function bind(name,control,read,write)
        ui.Controls[name]=control
        ui.Bindings[#ui.Bindings+1]={control=control,read=read,write=write,last=read()}
        return control
    end
    local function toggle(tab,name,title,description,read,apply)
        read=read or function()return api.Settings[name]end
        apply=apply or function(value)api:SetSetting(name,value)end
        local control=tab:Toggle({Title=title,Desc=description,Value=read(),Callback=guarded(function(value)
            if value~=read()then apply(value)end
        end)})
        return bind(name,control,read,function(value)control:Set(value)end)
    end
    local function dropdown(tab,name,title,values,read,apply,description)
        local control=tab:Dropdown({Title=title,Desc=description,Values=values,Value=read(),AllowNone=false,
            Callback=guarded(function(value)if value~=read()then apply(value)end end)})
        return bind(name,control,read,function(value)control:Select(value)end)
    end
    local function slider(tab,name,title,min,max,step,read,apply,description)
        local control=tab:Slider({Title=title,Desc=description,Step=step,Value={Min=min,Max=max,Default=read()},
            Callback=guarded(function(value)value=tonumber(value);if value and math.abs(value-read())>.00001 then apply(value)end end)})
        if control.UIElements and control.UIElements.SliderContainer then control.UIElements.SliderContainer.Active=true end
        return bind(name,control,read,function(value)control:Set(value)end)
    end
    ui.Status=dashboard:Paragraph({Title='Controller status',Desc='Paused'})
    toggle(dashboard,'StopEverything','Stop everything','On stops every automated action. Off runs enabled features.',
        function()return api.StopEverything==true end,function(value)api:SetStopEverything(value)end)
    dashboard:Button({Title='Minimize window',Desc='Keep running; restore with the badge or Right Shift.',Icon='minus',Callback=function()ui:Minimize()end})
    dashboard:Button({Title='Unload script',Desc='Stop and restore owned input and movement hooks.',Icon='x',Callback=function()api:Destroy()end})
    ui.PreferencesState=dashboard:Paragraph({Title='Automatic settings',Desc='Changes save automatically for this account and load on the next execution, including Stop everything.'})
    dashboard:Button({Title='Reset settings',Desc='Restore defaults and start automation.',Icon='rotate-ccw',Callback=guarded(function()
        if api.Preferences then api.Preferences.corrupt=false end
        api:ApplyProfile({version=1,stopEverything=false,settings=Core.defaultSettings(),speed=1.05,smart=true,tp=false,gems=false,revives=false,inspection=false})
    end)})
    toggle(runnerTab,'AutoRun','Automate runner','Cross automatically and perform enabled runner tasks.')
    toggle(runnerTab,'AutoGems','Collect gems','Take small safe detours for visible gems.',function()return api.AutoGemsEnabled end,function(v)api:SetAutoGemsEnabled(v)end)
    toggle(runnerTab,'AutoRevive','Revive runners','Approach eligible players and complete the native hold.',function()return api.AutoReviveEnabled end,function(v)api:SetAutoReviveEnabled(v)end)
    toggle(runnerTab,'AutoDash','Use dash','Use native dash when it benefits progress or escape.')
    toggle(chaserTab,'AutoChase','Automate chaser','Hunt eligible runners using automatic targeting.')
    toggle(chaserTab,'AutoDive','Use dive','Only dive when the contact prediction passes.')
    toggle(chaserTab,'AutoMelee','Use melee','Attack inside the native predicted melee window.')
    toggle(chaserTab,'AutoFaceTarget','Continuous target facing','Optional; off by default. Native dive alignment still occurs when required.')
    toggle(chaserTab,'FollowCamera','Follow target camera','Optional; off by default. Leave your camera under manual control.')
    priorities:Paragraph({Title='Order eligible tasks',Desc='Higher slots take precedence when tasks compete. Escape controls detours under pressure; immediate danger checks always stay on. Catches applies as chaser; gems and revives apply as runner.'})
    for i=1,4 do
        local slot=i
        dropdown(priorities,'Priority'..i,'Priority '..i,{'Escape','Revives','Gems','Catches'},
            function()return api.Settings.Priorities[slot]end,function(value)ui:SetPrioritySlot(slot,value)end,'Choosing an existing task swaps the two slots.')
    end
    toggle(voting,'AutoVote','Automatically vote','Use the selected map when available; otherwise pick an offered map at random.')
    ui.Ballot=voting:Paragraph({Title='Current ballot',Desc='Loading offered map names'})
    ui.MapNames={Random='Random'};ui.MapIds={Random='Random'}
    local mapConfig=require(gameState.MapVoteConfig)
    for _,map in ipairs(mapConfig.Maps)do
        local label=map.Name..' ('..map.Id..')'
        ui.MapNames[map.Id]=label;ui.MapIds[label]=map.Id
    end
    local mapValues={'Random'}
    for _,map in ipairs(mapConfig.Maps)do mapValues[#mapValues+1]=ui.MapNames[map.Id]end
    dropdown(voting,'MapPreference','Preferred map',mapValues,function()return ui.MapNames[api.Settings.MapPreference]or api.Settings.MapPreference end,
        function(v)api:SetSetting('MapPreference',assert(ui.MapIds[v],'Unknown map'))end,'Names come from the native map catalog and ballot.')
    dropdown(voting,'HeroMode','Hero / Chicken choice',{'Auto','Hero','Chicken'},function()return api.Settings.HeroMode end,
        function(v)api:SetSetting('HeroMode',v)end,'Auto chooses Hero at or below the chaser threshold.')
    slider(voting,'HeroThreshold','Hero chaser threshold',0,50,1,function()return api.Settings.HeroThreshold end,
        function(v)api:SetSetting('HeroThreshold',math.floor(v+.5))end,'Used only when Hero / Chicken choice is Auto.')
    toggle(voting,'AutoSelectRunner','Select a runner when prompted','Pick an eligible runner at random when you lead the chasers.')
    ui.MovementState=movement:Paragraph({Title='Current movement state',Desc='Loading'})
    slider(movement,'SpeedMultiplier','Dynamic speed multiplier',1,2,.05,function()return api.SpeedMultiplier end,
        function(v)api:SetSpeedMultiplier(v)end,'Scales the current native profile, including round modifiers.')
    toggle(movement,'SmartSpeed','Smart speed','Use the existing conservative close-range burst policy.',function()return api.SmartSpeedEnabled end,function(v)api:SetSmartSpeedEnabled(v)end)
    toggle(movement,'TPAssist','TP Assist','Use the existing conservative assistance checks.',function()return api.TPAssistEnabled end,function(v)api:SetTPAssistEnabled(v)end)
    toggle(movement,'UseAbilities','Use equipped abilities','Use owned runner and chaser abilities when useful.')
    toggle(movement,'AntiAFK','Anti-AFK','Stationary touch only on the owned IDLE pad; no keyboard, mouse or world gestures.')
    toggle(diagnostics,'Inspection','Goal and threat markers','Bounded cached forecasts; these are not native hitboxes.',function()return api.InspectionEnabled end,function(v)api:SetInspectionEnabled(v)end)
    ui.Details=diagnostics:Paragraph({Title='Live decisions',Desc='Waiting for a plan'})
    diagnostics:Button({Title='Print crossing report',Icon='clipboard-list',Callback=guarded(function()print(Http:JSONEncode(api:CrossingReport()))end)})
    toggle(rewards,'AutoJourney','Claim Journey rewards','Claim earned free rewards and already owned premium rewards. Never purchase tiers or rebirth.')
    toggle(rewards,'AutoSpins','Use free spins','Use available spin credits in the lobby. Never request a purchase.')
    toggle(rewards,'AutoCrates','Open free crates','Open only native free allocations with a valid token. Never spend coins, gems, keys or Robux.')
    ui.EquipmentState=equipment:Paragraph({Title='Owned loadout',Desc='Waiting for native inventory'})
    ui.EquipmentSelectors={}
    for _,spec in ipairs({{'Runner','RunnerEquipment','Runner ability'},{'Catcher','ChaserEquipment','Chaser ability'},{'Consumable','ConsumableEquipment','Consumable'}})do
        local entry={slot=spec[1],name=spec[2],ids={['Keep current']=''},names={['']='Keep current'}}
        entry.control=dropdown(equipment,entry.name,spec[3],{'Keep current'},
            function()return entry.names[api.Settings[entry.name]]or'Keep current'end,
            function(value)api:SelectEquipment(entry.slot,assert(entry.ids[value],'Unavailable inventory item'))end,
            'Owned items only; unavailable saved choices wait until owned. Current equipment stays authoritative.')
        ui.EquipmentSelectors[#ui.EquipmentSelectors+1]=entry
    end
    toggle(equipment,'UseConsumables','Use equipped consumable','Spend owned charges when useful; respects native restrictions and cooldowns.')
    ui.Window:SelectTab(1)
    ui.Backend='WindUI'
    ui:Refresh()
end
do
    local ok,err=pcall(attachWindUI)
    if not ok then ui:Cleanup();error('UI initialization failed: '..tostring(err),0)end
end
connect(RunService.Heartbeat,function(dt)
    if api.Destroyed or ui.Backend~='WindUI'then return end
    ui.elapsed=ui.elapsed+dt
    if ui.elapsed<.25 then return end
    ui.elapsed=0
    local ok,err=pcall(ui.Refresh,ui)
    if not ok then api.UIError=tostring(err)end
end)
