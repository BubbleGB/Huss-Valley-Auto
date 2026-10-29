function Core.choiceAction(state,candidates,index)
    if not state.enabled or state.afk or not state.inMatch or state.paused
        or type(state.endsAt)~='number'or state.now>=state.endsAt then return nil end
    if state.phase=='HeroChoice'and state.role=='Runner'and state.selectedId==state.id then
        return 'HeroChoice',type(state.chasers)=='number'and state.chasers<=5 and'Hero'or'Chicken'
    end
    if state.phase=='SelectHero'and state.role=='Catcher'and state.leadId==state.id and #candidates>0 then
        return 'SelectHero',candidates[math.clamp(index,1,#candidates)].id
    end
    return nil
end

function Core.voteChoice(vote,id,now,index)
    if type(vote)~='table'or vote.phase~='Voting'or type(vote.token)~='string'or vote.token==''
        or type(vote.endsAt)~='number'or now>=vote.endsAt or type(vote.options)~='table'then return nil end
    if type(vote.votes)=='table'and(vote.votes[tostring(id)]or vote.votes[id])then return nil end
    local options={}
    for _,option in ipairs(vote.options)do
        if type(option)=='table'and type(option.id)=='string'and option.id~=''then options[#options+1]=option.id end
    end
    if #options==0 then return nil end
    return options[math.clamp(index,1,#options)]
end

function Core.requestDue(now,nextAt,attempts)
    if now<nextAt or attempts>=3 then return false,attempts end
    return true,attempts+1
end

function Core.promptStep(state,key,value,now,enabled)
    if not enabled then return {},false end
    if state.key~=key then state={key=key,attempts=0,nextAt=0}end
    if value==nil then return state,false end
    local due,attempts=Core.requestDue(now,state.nextAt or 0,state.attempts or 0)
    if due then state.value,state.attempts,state.nextAt=value,attempts,now+1 end
    return state,due
end

