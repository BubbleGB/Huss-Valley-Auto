local function automaticPrompts()
    if not api.Enabled or api.Destroyed or player:GetAttribute('AFK')then return end
    local now=workspace:GetServerTimeNow()
    local phase=session:GetAttribute('Phase')
    local state={enabled=api.Enabled,afk=player:GetAttribute('AFK'),inMatch=player:GetAttribute('InMatch'),
        heroMode=api.Settings.HeroMode,heroThreshold=api.Settings.HeroThreshold,autoSelectRunner=api.Settings.AutoSelectRunner,
        role=player:GetAttribute('GameRole'),phase=phase,id=player.UserId,leadId=session:GetAttribute('LeadUserId'),
        selectedId=session:GetAttribute('SelectedUserId'),now=now,endsAt=session:GetAttribute('EndsAt'),
        paused=session:GetAttribute('GlobalPaused')or session:GetAttribute('MapChanging')}
    local candidates={}
    if phase=='HeroChoice'and state.selectedId==state.id then
        state.chasers=0
        for _,actor in ipairs(participants())do
            if actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')=='Catcher'
                and actor:GetAttribute('RunState')~='Lobby'and not actor:GetAttribute('AFK')then state.chasers=state.chasers+1 end
        end
    end
    if phase=='SelectHero'and state.leadId==state.id then
        for _,actor in ipairs(participants())do
            local run=actor:GetAttribute('RunState')
            if actor.UserId~=player.UserId and actor:GetAttribute('InMatch')and actor:GetAttribute('GameRole')=='Runner'
                and run~='Caught'and run~='Lobby'and not actor:GetAttribute('AFK')then candidates[#candidates+1]={id=actor.UserId,name=actor.Name}end
        end
    end
    local key=table.concat({tostring(phase),tostring(session:GetAttribute('RunNumber')),tostring(state.endsAt),tostring(state.leadId),tostring(state.selectedId)},':')
    if choiceRequest.key~=key then choiceRequest={key=key,attempts=0,nextAt=0}end
    local index=random:NextInteger(1,math.max(1,#candidates))
    if choiceRequest.value then
        for i,candidate in ipairs(candidates)do if candidate.id==choiceRequest.value then index=i;break end end
    end
    local action,value=Core.choiceAction(state,candidates,index)
    local due
    choiceRequest,due=Core.promptStep(choiceRequest,key,value,now,api.Enabled)
    if action and due then
        gameState.GameAction:FireServer(action,value)
        local subject=tostring(value)
        if action=='SelectHero'then
            for _,candidate in ipairs(candidates)do if candidate.id==value then subject=candidate.name or'runner';break end end
        end
        runner.operation:Set('prompt',action=='SelectHero'and('Selecting '..subject)or('Choosing '..subject),1.5,'choosing',subject)
        api.ChoicesSent=(api.ChoicesSent or 0)+1
        api.LastChoice={action=action,value=value,chasers=state.chasers}
    end
    local eligible=player:GetAttribute('ClientReady')and player:GetAttribute('InitialLoadingComplete')
        and not player:GetAttribute('InMatch')and not state.paused
    for _,name in ipairs({'TutorialSession','TutorialRouting','TutorialActive','TutorialFinishing','AdminTransferring','ServerBrowserTransferring'})do
        if player:GetAttribute(name)then eligible=false end
    end
    local snapshot=gameState:FindFirstChild('MapVoteState')
    if not api.Settings.AutoVote or not eligible or not snapshot then return end
    local ok,vote=pcall(Http.JSONDecode,Http,snapshot.Value)
    if not ok or type(vote)~='table'then return end
    if voteRequest.key~=vote.token then voteRequest={key=vote.token,attempts=0,nextAt=0}end
    local count=type(vote.options)=='table'and #vote.options or 0
    index=random:NextInteger(1,math.max(1,count))
    if voteRequest.value and type(vote.options)=='table'then
        for i,option in ipairs(vote.options)do if type(option)=='table'and option.id==voteRequest.value then index=i;break end end
    end
    value=Core.voteChoice(vote,player.UserId,now,index,api.Settings.MapPreference)
    voteRequest,due=Core.promptStep(voteRequest,vote.token,value,now,api.Enabled)
    if value and due then
        gameState.MapVoteEvent:FireServer('Vote',value,vote.token)
        local name=value
        for _,option in ipairs(vote.options or{})do if option.id==value then name=option.name or value;break end end
        runner.operation:Set('prompt','Voting for '..name,1.5,'voting',name)
        api.VotesSent=(api.VotesSent or 0)+1
        api.LastVote=value
    end
end

