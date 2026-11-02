-- Owned-key native requests only. Never opens the trader presentation.
local function createGhostTrader(services)
    local trader={}
    local clock=services.clock or os.clock
    local state,pending,active=nil,nil,false
    local receivedAt,nextSend=0,0
    local cooldownRefresh=false
    local status='Ghost Trader off'
    local cards=math.min(6,math.max(1,math.floor(services.cards or 6)))
    local function note(text,action,target)
        status=text
        if services.operation then services.operation(text,action or 'waiting',target,3)end
    end
    local function snapshot(value)
        if type(value)~='table'or type(value.live)~='boolean'or type(value.restricted)~='boolean'
            or type(value.keys)~='number'or value.keys~=value.keys or math.abs(value.keys)==math.huge
            or type(value.nextAt)~='number'or value.nextAt~=value.nextAt or math.abs(value.nextAt)==math.huge
            or(type(value.deal)~='number'and type(value.deal)~='string')or type(value.opened)~='table'then return nil end
        if type(value.deal)=='number'and(value.deal~=value.deal or math.abs(value.deal)==math.huge)then return nil end
        local opened={}
        for i=1,cards do
            if type(value.opened[i])~='boolean'then return nil end
            opened[i]=value.opened[i]
        end
        return {live=value.live,restricted=value.restricted,keys=value.keys,nextAt=value.nextAt,deal=value.deal,opened=opened}
    end
    local function dispatch(command,slot,now)
        -- Recheck the guards immediately at the request boundary.
        if not services.enabled()or not services.ready()then return false end
        local ok,sent=pcall(services.send,command,slot)
        if not ok or sent~=true then
            state=nil;pending=nil;nextSend=now+4
            note('Ghost Trader request not sent; waiting to refresh','waiting')
            return false
        end
        nextSend=now+2
        if command=='State'then
            state=nil
            pending={command='State',deadline=now+8}
            note('Checking Ghost Trader state','checking')
        else
            pending={command='Flip',slot=slot,deal=state.deal,deadline=now+8}
            note('Flipping spirit card '..slot..' · awaiting confirmation','opening',slot)
        end
        return true
    end
    function trader:Receive(kind,payload)
        if not services.enabled()or not services.ready()then return end
        if kind=='Notice'or kind=='Error'then
            local message=type(payload)=='string'and payload or type(payload)=='table'and(payload.message or payload.text)
            state=nil;pending=nil;nextSend=clock()+15
            note('Ghost Trader: '..(type(message)=='string'and message or 'server request declined'),'waiting')
            return
        end
        local value=kind=='State'and payload or kind=='Result'and type(payload)=='table'and payload.state
        local fresh=snapshot(value)
        if not fresh then return end
        state=fresh;receivedAt=clock();cooldownRefresh=fresh.nextAt>services.serverTime()
        if pending then
            if pending.command=='State'then
                pending=nil
            elseif fresh.deal~=pending.deal or fresh.opened[pending.slot]==true then
                pending=nil
                note('Ghost Trader card result received','completed')
            end
        end
    end
    function trader:Tick()
        local now=clock()
        if not services.enabled()or not services.ready()then
            active=false;state=nil;pending=nil;cooldownRefresh=false
            status=services.enabled()and'Ghost Trader waiting for lobby'or'Ghost Trader off'
            return false
        end
        if not active then
            active=true;state=nil;pending=nil;nextSend=0;cooldownRefresh=false
        end
        if now<nextSend then return false end
        if pending then
            if now<pending.deadline then return false end
            -- A lost Flip reply must be reconciled with State, never replayed blindly.
            return dispatch('State',nil,now)
        end
        if not state or now-receivedAt>15 then return dispatch('State',nil,now)end
        if not state.live then note('Ghost Trader is not live');return false end
        if state.restricted then note('Ghost Trader access restricted');return false end
        if state.keys<1 then note('Ghost Trader waiting for owned keys');return false end
        if state.nextAt>services.serverTime()then note('Ghost Trader cooldown');return false end
        if cooldownRefresh then return dispatch('State',nil,now)end
        local unopened={}
        for slot=1,cards do if state.opened[slot]==false then unopened[#unopened+1]=slot end end
        if #unopened==0 then note('Ghost Trader waiting for next deal');return false end
        local index=(services.random or math.random)(#unopened)
        if type(index)~='number'or index%1~=0 or not unopened[index]then
            note('Ghost Trader waiting for a valid card selection');return false
        end
        return dispatch('Flip',unopened[index],now)
    end
    function trader:Report()
        return {status=status,pending=pending and pending.command or nil,keys=state and state.keys or nil}
    end
    function trader:IsPending()return pending~=nil end
    return trader
end
runner.createGhostTrader=createGhostTrader
