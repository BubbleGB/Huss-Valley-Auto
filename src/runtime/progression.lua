local function createNativeProgression(services)
    local api,Core=services.api,services.Core
    local clock=services.clock or os.clock
    local progression={states={}}
    local blockedStations=setmetatable({},{__mode='k'})
    local flags={pumpkins='AutoPumpkins',quest='AutoQuests',spin='AutoSpins',journey='AutoJourney',crate='AutoCrates',ghost='AutoGhostTrader'}
    local slots={Runner='RunnerEquipment',Catcher='ChaserEquipment',Consumable='ConsumableEquipment'}
    local equipmentSnapshot,equipmentOptions=nil,{}
    local catalogItems={}
    for id,item in pairs(services.gearItems)do if services.gearCatalog.get(id)then catalogItems[id]=item end end
    function progression:IsStationBlocked(prompt)
        local entry=blockedStations[prompt]
        if not entry then return false end
        local position=services.promptPosition(prompt)
        if not position or(position-entry.position).Magnitude>=4 or clock()>=entry.untilAt then blockedStations[prompt]=nil;return false end
        return true
    end
    function progression:AvoidStation(prompt)
        if not prompt then return end
        local position=services.promptPosition(prompt)
        if not position then return end
        local old=blockedStations[prompt]
        local count=math.min(4,(old and old.count or 0)+1)
        blockedStations[prompt]={position=position,count=count,untilAt=clock()+math.min(120,15*2^count)}
    end
    local ui=services.makeUI(progression)
    progression.ui=ui
    function api:EquipmentOptions(slot)
        assert(slots[slot],'Invalid equipment slot')
        local inventory=services.armory()
        if inventory~=equipmentSnapshot then equipmentSnapshot=inventory;equipmentOptions={}end
        if not equipmentOptions[slot]then equipmentOptions[slot]=Core.ownedEquipment(inventory,catalogItems,slot)end
        local result={}
        for _,item in ipairs(equipmentOptions[slot])do result[#result+1]=table.clone(item)end
        return result
    end
    function api:SelectEquipment(slot,id)
        assert(slots[slot],'Invalid equipment slot')
        local owned=id==''
        for _,item in ipairs(self:EquipmentOptions(slot))do if item.id==id then owned=true;break end end
        assert(owned,'Item is not currently owned')
        self:SetSetting(slots[slot],id)
        self.EquipmentStatus='Waiting for native Armory controls'
        return id
    end
    function progression:receive(channel,kind,state)
        if type(state)~='table'then return end
        local cache
        if channel=='crate'then
            if not services.crateCatalog.Crates[state.crate]then return end
            cache=self.states[state.crate]or{revision=0,resultRevision=0};self.states[state.crate]=cache
        elseif channel=='pumpkins'or channel=='halloween'or channel=='quest'or channel=='spin'or channel=='journey'or channel=='ghost'then
            cache=self[channel]or{revision=0,resultRevision=0};self[channel]=cache
        else return end
        if kind=='State'then
            cache.value=state;cache.at=clock();cache.revision=cache.revision+1
        elseif kind=='Result'and channel=='ghost'and type(state.state)=='table'then
            cache.value=state.state;cache.at=clock();cache.revision=cache.revision+1
        end
        local confirmed=kind=='Result'and(channel=='crate'and state.id~=nil or channel=='ghost'and type(state.state)=='table')
            or channel=='spin'and kind=='State'and(state.result~=nil or state.results~=nil or state.message~=nil)
        if channel=='pumpkins'and kind=='Opened'and state.ok==true then confirmed=true end
        if channel=='halloween'and kind=='Bought'and state.ok==true then confirmed=true;cache.lastId=state.id end
        if confirmed then cache.resultRevision=cache.resultRevision+1 end
    end
    local function enabled()return api.Enabled and not api.StopEverything and not api.Destroyed
        and(not services.enabled or services.enabled())end
    function progression:lobbyReady(job)
        local p=services.player
        if not enabled()or p:GetAttribute('InMatch')==true or p:GetAttribute('ClientReady')~=true
            or services.session:GetAttribute('MapChanging')or services.session:GetAttribute('GlobalPaused')
            or services.inputService:GetFocusedTextBox()or services.guiService.MenuIsOpen then return false end
        for _,key in ipairs({'MapVoteOpen','MatchSummaryVisible','TutorialSession','CreatorCameraActive','CutsceneActive'})do
            if p:GetAttribute(key)then return false end
        end
        local own={SpinWheelOpen='spin',GlobalWheelOpen='spin',SpinSummaryOpen='spin',JourneyOpen='journey',
            ArmoryOpen='equip',CrateOpen='crate',GhostTraderActive='ghost',QuestsOpen='quest',HalloweenShopOpen='crate',PumpkinsOpen='pumpkins'}
        for key,kind in pairs(own)do if p:GetAttribute(key)and(not job or job.kind~=kind)
            and not(key=='ArmoryOpen'and job and job.kind=='crate'and job.menu)then return false end end
        if p:GetAttribute('ScreenPresentationActive')and(not job or(job.kind~='pumpkins'and job.kind~='spin'and job.kind~='crate'and job.kind~='ghost'))then return false end
        return true
    end
    local function allowed(job)
        if not job then return true end
        if job.kind=='equip'then return slots[job.slot]and api.Settings[slots[job.slot]]==job.id end
        return flags[job.kind]and api.Settings[flags[job.kind]]==true
    end
    local function stationAvailable(prompt)
        if not prompt or not prompt.Enabled then return false end
        local root=services.player.Character and services.player.Character:FindFirstChild('HumanoidRootPart')
        local position=services.promptPosition(prompt)
        return root and position and math.abs(position.Y-root.Position.Y)<=40
    end
    function progression:jobs()
        local jobs={}
        local inventory=services.armory()
        for _,slot in ipairs({'Runner','Catcher','Consumable'})do
            local id=api.Settings[slots[slot]]
            local equipped=slot=='Consumable'and inventory.equippedGear or services.gearCatalog.equippedForRole(inventory,slot)
            if id~=''and id~=equipped then
                for _,item in ipairs(api:EquipmentOptions(slot))do if item.id==id then
                    jobs[#jobs+1]={key='equip:'..slot..':'..id,kind='equip',slot=slot,id=id,name=item.name,cooldown=15}
                end end
            end
        end
        for _,spec in ipairs({{'pumpkins','Pumpkins','AutoPumpkins'},{'quest','Quests','AutoQuests'},{'journey','Journey','AutoJourney'},{'spin','Wheel Spin','AutoSpins'},{'ghost','Ghost Trader','AutoGhostTrader'}})do
            if api.Settings[spec[3]]then
                local job={key=spec[1],kind=spec[1],name=spec[2],cooldown=60}
                local prompt=spec[1]~='pumpkins'and spec[1]~='journey'and spec[1]~='quest'and ui:Prompt(job)
                if spec[1]=='pumpkins'or spec[1]=='quest'or spec[1]=='journey'or stationAvailable(prompt)then jobs[#jobs+1]=job end
            end
        end
        if api.Settings.AutoCrates then
            local ids={};for id in pairs(services.crateCatalog.Crates)do ids[#ids+1]=id end
            table.sort(ids,function(a,b)
                local x,y=services.crateCatalog.Crates[a].Halloween==true,services.crateCatalog.Crates[b].Halloween==true
                if x~=y then return x end
                return a<b
            end)
            for _,id in ipairs(ids)do
                local item=services.crateCatalog.Crates[id]
                local job={key='crate:'..id,kind='crate',id=id,name=item.Name or id,cooldown=90}
                if item.Halloween then
                    local index=0
                    for _,entry in ipairs(services.halloweenConfig and services.halloweenConfig.Items or{})do
                        if entry.kind=='Crate'then
                            index=index+1
                            if entry.crate==id then job.seasonal=true;job.itemId=entry.id;job.cardIndex=index end
                        end
                    end
                    local value=self.halloween and self.halloween.value
                    if value and type(value.free)=='table'and not(type(value.free[job.itemId])=='number'and value.free[job.itemId]>0)then continue end
                    if not job.seasonal then continue end
                end
                local prompt=ui:Prompt(job)
                if stationAvailable(prompt)then jobs[#jobs+1]=job end
            end
        end
        return jobs
    end
    local function reach(job)
        local prompt=ui:Prompt(job)
        if job.menu or job.kind=='pumpkins'or job.kind=='quest'or job.kind=='journey'or job.kind=='equip'then services.navigation:Cancel();return true end
        if not prompt or not prompt.Enabled then services.navigation:Cancel();return false,'station unavailable' end
        local character=services.player.Character
        local root=character and character:FindFirstChild('HumanoidRootPart')
        local position=services.promptPosition(prompt)
        if not root or not position then return false,'waiting for character' end
        if math.abs(position.Y-root.Position.Y)>40 then services.navigation:Cancel();return false,'station is outside the lobby' end
        local range=math.max(2,prompt.MaxActivationDistance-2)
        local onScreen=not services.promptOnScreen or services.promptOnScreen(prompt)
        if(root.Position-position).Magnitude<=range and onScreen then services.navigation:Cancel();return true end
        if not job.approach or job.prompt~=prompt or job.root~=root or(position-job.promptPosition).Magnitude>2
            or not onScreen and job.approach and(root.Position-job.approach).Magnitude<2 then
            local delta=Vector3.new(root.Position.X-position.X,0,root.Position.Z-position.Z)
            if services.approachDirection then
                local preferred=services.approachDirection()
                if preferred and preferred.Magnitude>.1 then delta=-Vector3.new(preferred.X,0,preferred.Z)end
            end
            local horizontal=math.sqrt(math.max(0,range*range-(root.Position.Y-position.Y)^2))
            job.approach=Vector3.new(position.X,root.Position.Y,position.Z)+(delta.Magnitude>.01 and delta.Unit*math.max(0,horizontal-2)or Vector3.zero)
            local native=services.stationApproach and services.stationApproach(prompt,job)
            if native and(native-position).Magnitude<prompt.MaxActivationDistance then job.approach=native end
            job.prompt,job.root,job.promptPosition=prompt,root,position
        end
        services.navigation:SetGoal(job.approach,1)
        return false,'following lobby path'
    end
    progression.workflow=services.makeWorkflow({clock=clock,enabled=enabled,ready=function(job)return progression:lobbyReady(job)end,
        allowed=allowed,jobs=function()return progression:jobs()end,reach=reach,
        open=function(job)return ui:Open(job)end,inspect=function(job)return ui:Inspect(job)end,
        act=function(job,token)return ui:Act(job,token)end,close=function(job)return ui:Close(job)end,
        halt=function()services.input:Release();services.navigation:Cancel()end,
        operation=services.operation,changed=services.changed})
    function progression:Tick()
        services.input:Tick()
        self.workflow:Tick()
    end
    function progression:Step(character,humanoid,root)
        local state=self.workflow:Report()
        if not self:lobbyReady(state.job)or not state.active or state.phase~='walking'then return Vector3.zero,false end
        local direction,jump=services.navigation:Step(character,humanoid,root)
        if services.navigation.Report and services.navigation:Report().failed then
            self:AvoidStation(state.job and state.job.prompt)
            self.workflow:Cancel('Station unreachable; backing off')
            return Vector3.zero,false,false
        end
        return direction,jump,true
    end
    function progression:Cancel()self.workflow:Cancel()end
    function progression:Report()return self.workflow:Report()end
    return progression
end
runner.createNativeProgression=createNativeProgression
