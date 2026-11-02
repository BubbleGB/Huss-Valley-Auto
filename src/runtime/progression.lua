-- Native reward/equipment state, independent of the visible game menus.
local progression={nextTick=0,nextRequest=0,refreshAt=0,crateIndex=0,states={},pending=nil,nextEquip=0}
runner.progression=progression
progression.journeyConfig=require(package.Progression.JourneyConfig)
progression.crateCatalog=require(package.Crates.CrateCatalog)
progression.journeyRemote=package.Progression:FindFirstChild('JourneyEvent')
progression.spinRemote=package:FindFirstChild('SpinWheelEvent')
progression.crateRemote=package.Crates:FindFirstChild('CrateEvent')
progression.armoryRemote=package.Weapons.ArmoryEvent
progression.crateIds={}
for id in pairs(progression.crateCatalog.Crates)do progression.crateIds[#progression.crateIds+1]=id end
table.sort(progression.crateIds)
function api:EquipmentOptions(slot)
    assert(slot=='Runner'or slot=='Catcher'or slot=='Consumable','Invalid equipment slot')
    local items={}
    for id,item in pairs(gearItems)do if gearCatalog.get(id)then items[id]=item end end
    return Core.ownedEquipment(armory,items,slot)
end
function api:SelectEquipment(slot,id)
    local name=slot=='Runner'and'RunnerEquipment'or slot=='Catcher'and'ChaserEquipment'or slot=='Consumable'and'ConsumableEquipment'
    assert(name,'Invalid equipment slot')
    local owned=id==''
    for _,item in ipairs(self:EquipmentOptions(slot))do if item.id==id then owned=true;break end end
    assert(owned,'Item is not currently owned')
    self:SetSetting(name,id)
    progression.nextEquip=0
    return id
end
function progression:note(remote,command,item)
    local channel,text,action,seconds
    local itemConfig=item and gearCatalog.get(item)
    local crate=item and self.crateCatalog.Crates[item]
    local crateName=crate and(crate.Name or item)or item
    if command=='EquipGear'then channel,text,action,seconds='equip','Equipping '..(itemConfig and itemConfig.Name or item),'equipping',8
    elseif command=='ClaimAll'then channel,text,action,seconds='journey','Claiming Journey rewards','claiming',12
    elseif command=='Spin'then channel,text,action,seconds='spin','Spinning','spinning',15
    elseif command=='OpenFree'then channel,text,action,seconds='crate','Opening '..crateName,'opening',15
    elseif command=='Open'then channel,text,action,seconds='crate','Preparing '..crateName,'checking',2
    elseif command=='State'then channel,text,action,seconds='spin','Checking free spins','checking',2
    elseif command=='Get'and crate then channel,text,action,seconds='crate','Checking '..crateName,'checking',2
    elseif command=='Get'and remote==self.armoryRemote and self.pendingEquip then
        channel,text,action,seconds='equip','Waiting for equipment confirmation','equipping',8;item=self.pendingEquip.id
    elseif command=='Get'then channel,text,action,seconds='journey','Checking Journey rewards','checking',2
    else return end
    self.operationSequence=(self.operationSequence or 0)+1
    local id='progression:'..self.operationSequence
    self.pending={channel=channel,command=command,item=item,id=id}
    if runner.operation then
        local pending=command=='Spin'or command=='OpenFree'or command=='ClaimAll'or command=='EquipGear'
        runner.operation:Set('progression',text..(pending and' · awaiting confirmation'or''),seconds,action,item,id)
    end
end
function progression:finishOperation(channel,kind,state)
    local pending=self.pending
    if not pending or pending.channel~=channel or type(state)~='table'then return end
    if channel=='crate'and state.crate~=pending.item then return end
    local text
    local done=false
    if channel=='equip'and kind=='State'and state.loaded==true then
        local item=gearCatalog.get(pending.item)
        local equipped=item and item.Kind=='Ability'and gearCatalog.equippedForRole(state,item.UseRole)or state.equippedGear
        done=equipped==pending.item
        if done then text='Equipped '..(item and item.Name or pending.item)end
    elseif channel=='crate'and kind=='Result'and state.id~=nil and pending.command=='OpenFree'then
        local crate=self.crateCatalog.Crates[pending.item]
        done=true;text='Opened '..(crate and crate.Name or pending.item)
    elseif kind=='State'then
        if pending.command=='Get'or pending.command=='State'or pending.command=='Open'then
            done=state.loaded==true or channel=='spin'and type(state.credits)=='number'
        elseif channel=='spin'and(state.result or state.results or state.message)then
            done=true;text=(state.result or state.results)and'Spin result received'or'Spin request finished'
        elseif channel=='journey'and state.loaded==true and state.seasonId==self.journeyConfig.SeasonId
            and not Core.journeyClaimable(state,self.journeyConfig)then
            done=true;text='Journey rewards claimed'
        end
    end
    if done then
        self.pending=nil
        if runner.operation then
            runner.operation:Clear('progression',pending.id)
            if text then runner.operation:Set('progression',text,1.5,'completed',pending.item,pending.id)end
        end
    end
end
function progression:receive(channel,kind,state)
    self:finishOperation(channel,kind,state)
    if kind~='State'or type(state)~='table'then return end
    local now=os.clock()
    if channel=='crate'then
        if not self.crateCatalog.Crates[state.crate]then return end
        self.states[state.crate]={value=state,at=now}
    else self[channel]={value=state,at=now}end
    -- Keep the dispatch hold after replies: native reward presentations may still be active.
end
for _,entry in ipairs({{'journey',progression.journeyRemote},{'spin',progression.spinRemote},{'crate',progression.crateRemote}})do
    if entry[2]then connect(entry[2].OnClientEvent,function(kind,state)progression:receive(entry[1],kind,state)end)end
end
function progression:send(remote,...)
    if not api.Enabled or api.Destroyed or api.StopEverything or not remote then return false end
    remote:FireServer(...)
    self:note(remote,...)
    return true
end
function progression:lobbyReady()
    if not api.Enabled or api.StopEverything or api.Destroyed or player:GetAttribute('InMatch')==true
        or player:GetAttribute('ClientReady')~=true or session:GetAttribute('MapChanging')or session:GetAttribute('GlobalPaused')then return false end
    for _,name in ipairs({'GlobalWheelOpen','ArmoryOpen','ScreenPresentationActive','CreatorCameraActive','MapVoteOpen','MatchSummaryVisible','TutorialSession','CrateOpen'})do
        if player:GetAttribute(name)then return false end
    end
    return not Input:GetFocusedTextBox()and not GuiService.MenuIsOpen
end
function progression:tick(now)
    if now<self.nextTick then return end
    self.nextTick=now+.5
    if not self:lobbyReady()or now<self.nextRequest then return end
    -- Equip one owned preference at a time; wait for authoritative armory snapshots.
    if self.pendingEquip then
        local pending=self.pendingEquip
        local equipped=pending.slot=='Consumable'and armory.equippedGear or gearCatalog.equippedForRole(armory,pending.slot)
        if armory~=pending.snapshot and equipped==pending.id then
            self.pendingEquip=nil;self.nextEquip=now
        elseif pending.refreshSnapshot and armory~=pending.refreshSnapshot then
            -- A fresh Get reply confirms rejection/current ownership before any retry.
            self.pendingEquip=nil;self.nextEquip=now+2
        elseif now>=pending.refreshAt then
            pending.refreshSnapshot=armory;pending.refreshAt=now+8
            self.nextRequest=now+2
            self:send(self.armoryRemote,'Get')
            api.EquipmentStatus='Waiting for equipment confirmation'
            return
        else return end
    end
    if now>=self.nextEquip and armory.loaded and not armory.pending then
        for _,entry in ipairs({{'Runner','RunnerEquipment'},{'Catcher','ChaserEquipment'},{'Consumable','ConsumableEquipment'}})do
            local slot,id=entry[1],api.Settings[entry[2]]
            local equipped=slot=='Consumable'and armory.equippedGear or gearCatalog.equippedForRole(armory,slot)
            if id~=''and equipped~=id then
                for _,item in ipairs(api:EquipmentOptions(slot))do if item.id==id then
                    self.pendingEquip={id=id,slot=slot,snapshot=armory,refreshAt=now+8}
                    self.nextEquip=now+8;self.nextRequest=now+1
                    self:send(self.armoryRemote,'EquipGear',id)
                    api.EquipmentStatus='Equipping '..item.name
                    return
                end end
            end
        end
        api.EquipmentStatus='Equipment confirmed'
    end
    if api.Settings.AutoJourney then
        local state=self.journey
        if not state or now-state.at>30 then
            self.journey={value=nil,at=now};self.nextRequest=now+2
            self:send(self.journeyRemote,'Get');return
        elseif Core.journeyClaimable(state.value,self.journeyConfig)then
            self.journey=nil;self.nextRequest=now+12
            self:send(self.journeyRemote,'ClaimAll',nil,self.journeyConfig.SeasonId);return
        end
    end
    if api.Settings.AutoSpins then
        local state=self.spin
        if not state or now-state.at>15 then
            self.spin={value=nil,at=now};self.nextRequest=now+2
            self:send(self.spinRemote,'State');return
        elseif state.value and(tonumber(state.value.credits)or 0)>=1 then
            self.spin=nil;self.nextRequest=now+15
            self:send(self.spinRemote,'Spin');return
        end
    end
    if api.Settings.AutoCrates and #self.crateIds>0 then
        self.crateIndex=self.crateIndex%#self.crateIds+1
        local id=self.crateIds[self.crateIndex]
        local state=self.states[id]
        if state and Core.freeCrateReady(state.value,state.at,now)then
            self.states[id]=nil;self.nextRequest=now+15
            self:send(self.crateRemote,'OpenFree',id,state.value.token)
        elseif state and state.value and state.value.loaded and state.value.allowed==true
            and(tonumber(state.value.free)or 0)>0 and type(state.value.token)~='string'and now-state.at<20 then
            self.states[id]={value=nil,at=now};self.nextRequest=now+2
            self:send(self.crateRemote,'Open',id) -- request native allocation/token; OpenFree alone consumes it
        elseif not state or now-state.at>20 then
            self.states[id]={value=nil,at=now};self.nextRequest=now+2
            self:send(self.crateRemote,'Get',id)
        end
    end
end
connect(RunService.Heartbeat,function()
    local ok,err=pcall(progression.tick,progression,os.clock())
    if not ok then api.ProgressionError=tostring(err);progression.nextRequest=os.clock()+15 end
end)
-- End native progression
