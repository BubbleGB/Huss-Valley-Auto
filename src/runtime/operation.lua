-- Four bounded display channels; this records decisions, never drives gameplay.
local function createOperationStatus(clock,itemName)
    local operation={events={},epoch=0,base={description='Waiting for an active round',action='waiting'}}
    local priorities={avoidance=4,combat=3,progression=2,prompt=1}
    function operation:Base(text,action,target)
        self.base={description=text,action=action or'waiting',target=target}
    end
    function operation:Set(channel,text,seconds,action,target,id,origin)
        local now=clock()
        local previous=self.events[channel]
        origin=origin or now
        if previous and previous.origin>origin then return false end
        self.events[channel]={description=text,action=action,target=target,id=id,origin=origin,
            expires=now+seconds,priority=priorities[channel]or 0}
        return true
    end
    function operation:Clear(channel,id)
        local event=self.events[channel]
        if event and(not id or event.id==id)then self.events[channel]=nil end
    end
    function operation:Reset()
        self.epoch=self.epoch+1
        table.clear(self.events)
        self:Base('Waiting for an active round','waiting')
    end
    function operation:Read(running,inMatch)
        if not running then
            return {running=false,description=self.base.action=='error'and self.base.description or'Stopped',action='stopped'}
        end
        local now=clock()
        local best=self.base
        for channel,event in pairs(self.events)do
            if now>=event.expires then self.events[channel]=nil
            elseif(channel~='progression'or not inMatch)and(channel~='combat'and channel~='avoidance'or inMatch)
                and(event.priority>(best.priority or 0))then best=event end
        end
        return {running=true,description=best.description,action=best.action,target=best.target}
    end
    function operation:Action(record,phase)
        if phase=='requesting'then record.operationEpoch=self.epoch
        elseif record.operationEpoch~=self.epoch then return end
        if phase=='rejected'then self:Clear('combat',record.id);return end
        if clock()-record.requestedClock>3 then return end
        local kind,target=record.kind,record.operationTarget
        local label=kind=='Dive'and'Diving'or kind=='Melee'and'Attacking'or kind=='Dash'and'Dashing'
        local action=kind=='Dive'and'diving'or kind=='Melee'and'melee'or kind=='Dash'and'dashing'or'ability'
        local item=kind:match('^Ability:(.+)$')or kind:match('^Consumable:(.+)$')
        if item then label='Using '..itemName(item);action='using' end
        if not label then return end
        if target and(kind=='Dive'or kind=='Melee')then label=label..(kind=='Dive'and' at 'or' ')..target end
        if phase=='requesting'then label=label..' · requesting' end
        local duration=math.clamp((record.activeDuration or .5)+(record.recovery or .3),.6,2)
        self:Set('combat',label,duration,action,target,record.id,record.requestedClock)
    end
    return operation
end
runner.operation=createOperationStatus(os.clock,function(id)
    local item=gearCatalog.get(id)
    return item and item.Name or id:gsub('(%l)(%u)','%1 %2')
end)
function api:OperationReport()
    return runner.operation:Read(self.Enabled and not self.Destroyed,player:GetAttribute('InMatch')==true)
end
runner.hazardNames={BearTrap='Bear Trap',BananaPeel='Banana Peel',SpringBox='Spring Box',FartCloud='Fart Cloud',
    GraveRise='rising gravestone',BowlingBall='Bowling Ball',RufusLeash="Rufus's Leash"}
function runner.evasionLabel(enemy)
    if enemy.actor then
        local name=enemy.actor.Name
        return name and('Evading '..name)or'Evading a chaser','evading',name
    elseif enemy.kind and runner.hazardNames[enemy.kind]then
        return 'Avoiding '..runner.hazardNames[enemy.kind],'avoiding',runner.hazardNames[enemy.kind]
    elseif enemy.id then return 'Evading pumpkin enemy '..tostring(enemy.id),'evading',tostring(enemy.id)end
    return 'Evading predicted danger','evading'
end
function runner.blockingHazard(a,b,hazards)
    for _,hazard in ipairs(hazards)do
        if not Core.clearSegment(a,b,{hazard})then return runner.hazardNames[hazard.kind]or'hazard'end
    end
end
