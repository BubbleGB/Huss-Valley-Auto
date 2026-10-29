-- Uses the real Heartbeat signal with isolated prompt snapshots; sends no remotes.
return function(Core)
    local state,calls,frame,completed,problem={}, {},0,false,nil
    local connection
    connection=game:GetService('RunService').Heartbeat:Connect(function()
        local ok,err=pcall(function()
            frame=frame+1
            local enabled=frame~=5 and frame~=10
            local key=frame<6 and 'phase-one' or 'phase-two'
            local due
            state,due=Core.promptStep(state,key,'Chicken',frame*1.1,enabled)
            if due then calls[#calls+1]={key=key,frame=frame,value=state.value}end
            if frame==10 then completed=true;connection:Disconnect()end
        end)
        if not ok then problem=err;completed=true;connection:Disconnect()end
    end)
    local deadline=os.clock()+3
    repeat task.wait()until completed or os.clock()>deadline
    connection:Disconnect()
    assert(not problem,problem)
    assert(completed,'Heartbeat prompt test timed out')
    local first,second=0,0
    for _,call in ipairs(calls)do
        assert(call.frame~=5 and call.frame~=10,'Stop allowed a pending retry')
        assert(call.value=='Chicken','retry changed the selected action')
        if call.key=='phase-one'then first=first+1 else second=second+1 end
    end
    assert(first==3 and second==3,'new phase/token must receive its own bounded retry budget')
    assert(next(state)==nil,'Stop must discard pending request state')
    return {firstPrompt=first,nextPrompt=second,stop='passed',heartbeat='passed'}
end
