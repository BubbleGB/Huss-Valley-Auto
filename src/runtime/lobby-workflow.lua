local function createLobbyWorkflow(services)
    local workflow={}
    local clock=services.clock or os.clock
    local current,phase,startedAt,deadline=nil,'idle',0,0
    local nextTick,nextInput=0,0
    local lastKey=nil
    local expired=false
    local eligibleAt={}
    local status='Lobby collection idle'
    local function note(text,action)
        status=text
        if services.operation then services.operation(text,action,current and current.name)end
    end
    local function halt()
        if services.halt then services.halt()end
    end
    local function finish(now,text,failed)
        local job=current
        current=nil;phase='idle';deadline=0
        if job then
            eligibleAt[job.key]=now+math.max(failed and 4 or .2,tonumber(job.cooldown)or 0)
        end
        halt()
        if job and services.changed then services.changed(job,false)end
        note(text,'waiting')
    end
    local function guarded(job)
        return services.enabled() and services.ready(job) and (not job or services.allowed(job))
    end
    local function input(method,now,token)
        if now<nextInput then return false end

        if not guarded(current)then
            finish(now,'Lobby collection paused',true)
            return false
        end
        nextInput=now+.6
        local ok,sent=pcall(method,current,token)
        return ok and sent==true
    end
    function workflow:Cancel(reason)
        finish(clock(),reason or 'Lobby collection stopped',true)
    end
    function workflow:Tick()
        local now=clock()

        if not guarded(current)then
            if current then finish(now,'Lobby collection paused',true)end
            return false
        end
        if now<nextTick then return false end
        nextTick=now+.2
        if not current then
            local jobs=services.jobs()or{}
            local start=1
            for index,job in ipairs(jobs)do
                if job.key==lastKey then start=index%#jobs+1;break end
            end
            for offset=0,#jobs-1 do
                local job=jobs[(start+offset-1)%#jobs+1]
                if job.key and now>=(eligibleAt[job.key]or 0)and services.allowed(job)and services.ready(job)then
                    current=job;lastKey=job.key;phase='walking';startedAt=now;expired=false
                    nextInput=now
                    if services.changed then services.changed(job,true)end
                    break
                end
            end
            if not current then return false end
        end
        if phase=='walking'and now-startedAt>=60 then
            finish(now,'Lobby collection timed out',true)
            return false
        end
        if phase=='walking'then
            note('Walking to '..current.name,'walking')
            local ok,reached,reason=pcall(services.reach,current)
            if not ok then
                finish(now,'Lobby route unavailable',true)
                return false
            end
            if reached~=true then
                if type(reason)=='string'then note('Walking to '..current.name..' · '..reason,'walking')end
                return false
            end
            phase='opening';deadline=now+8
        end
        local ok,view=pcall(services.inspect,current)
        if not ok or type(view)~='table'then
            finish(now,'Lobby menu unavailable',true)
            return false
        end
        if phase~='closing'and now-startedAt>=60 then
            if not view.visible then
                finish(now,'Lobby collection timed out',true)
                return false
            end
            phase='closing';deadline=now+8;expired=true
        end
        if phase=='closing'then
            if not view.visible then
                finish(now,expired and 'Lobby collection timed out' or 'Lobby collection complete',expired)
                return false
            end
            if now>=deadline then
                finish(now,'Lobby menu close timed out',true)
                return false
            end
            note('Closing '..current.name,'closing')
            if view.waiting then return false end
            return input(services.close,now)
        end
        if phase=='opening'then
            if view.visible then
                phase='acting';deadline=0
            elseif now>=deadline then
                finish(now,'Lobby menu open timed out',true)
                return false
            else
                note('Opening '..current.name,'opening')
                if view.waiting then return false end
                return input(services.open,now)
            end
        end

        if not view.visible then
            finish(now,'Lobby menu closed',true)
            return false
        end
        if view.waiting then
            note(view.description or ('Waiting for '..current.name),'waiting')
            return false
        end
        if view.done then
            phase='closing';deadline=now+8
            note('Closing '..current.name,'closing')
            return input(services.close,now)
        end
        if view.action~=nil and view.action~=false then
            note(view.description or ('Collecting '..current.name),'collecting')
            return input(services.act,now,view.action)
        end
        note(view.description or ('Waiting for '..current.name),'waiting')
        return false
    end
    function workflow:Report()
        return {status=status,phase=phase,active=current~=nil,job=current,key=current and current.key,
            kind=current and current.kind}
    end
    return workflow
end
runner.createLobbyWorkflow=createLobbyWorkflow
