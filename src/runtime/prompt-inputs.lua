local function createPromptInputs(services)
    local prompts={}
    local lastUse,prepared=nil,false
    local clock=services.clock or os.clock
    local function prepare(button)
        lastUse=clock();prepared=true
        return not services.prepare or services.prepare(button)==true
    end
    function prompts:Reset()
        if prepared and services.finish then services.finish()end
        prepared,lastUse=false,nil
    end
    function prompts:Tick()
        if prepared and clock()-lastUse>=1.5 then self:Reset()end
    end
    local function path(root,...)
        for _,name in ipairs({...})do root=root and root:FindFirstChild(name)end
        return root
    end
    local function visible(object)
        local current=object
        while current do
            if current:IsA('GuiObject')and not current.Visible then return false end
            if current:IsA('ScreenGui')and not current.Enabled then return false end
            current=current.Parent
        end
        return true
    end
    function prompts:CanRandom()
        local b=path(services.playerGui,'Notifications','MainFrame','Choices','Random')
        return b and b:IsA('GuiButton')and b.Active and visible(b)or false
    end
    function prompts:HasRunner(id)
        local button=path(services.playerGui,'Notifications','MainFrame','Choices','PlayerPicker','Options','Player_'..id)
        return button~=nil and button:IsA('GuiButton')and button.Active and visible(button)
    end
    function prompts:Send(action,value)
        if not services.enabled()then return false end
        local button
        if action=='Vote'and type(value)=='string'then
            button=path(services.playerGui,'MapVoteUI','Ballot','Maps',value)
        elseif action=='HeroChoice'and(value=='Hero'or value=='Chicken')then
            button=path(services.playerGui,'Notifications','MainFrame','Choices','RunnerChoice','Options',value)
        elseif action=='SelectHero'and type(value)=='number'and value%1==0 then
            self.LastSelectionRandom=self:CanRandom()
            button=self.LastSelectionRandom and path(services.playerGui,'Notifications','MainFrame','Choices','Random')
                or path(services.playerGui,'Notifications','MainFrame','Choices','PlayerPicker','Options','Player_'..value)
        end
        if not button or not button:IsA('GuiButton')or not button.Active or not visible(button)then return false end
        local parent=button.Parent
        while parent do
            if parent:IsA('ScrollingFrame')then
                local center=button.AbsolutePosition+button.AbsoluteSize/2
                local start,size=parent.AbsolutePosition,parent.AbsoluteSize
                if center.Y<start.Y or center.Y>start.Y+size.Y then
                    parent.CanvasPosition=Vector2.new(parent.CanvasPosition.X,math.max(0,parent.CanvasPosition.Y+center.Y-start.Y-size.Y/2))
                    return false
                end
                if center.X<start.X or center.X>start.X+size.X then
                    parent.CanvasPosition=Vector2.new(math.max(0,parent.CanvasPosition.X+center.X-start.X-size.X/2),parent.CanvasPosition.Y)
                    return false
                end
            end
            parent=parent.Parent
        end
        if not prepare(button)then self.LastBlockedReason='clearing own window';return false end
        local sent=services.input:Tap(button)==true
        self.LastBlockedReason=not sent and services.input.LastBlockedReason or nil
        return sent
    end
    local function dismiss(button)
        return services.enabled()and button and button:IsA('GuiButton')and button.Active and visible(button)
            and prepare(button)and services.input:Tap(button)==true or false
    end
    function prompts:DismissVote(vote,id,expected)
        if not expected or type(vote)~='table'or type(vote.votes)~='table'or vote.votes[tostring(id)]~=expected then return false end
        local close=path(services.playerGui,'MapVoteUI','Ballot','Close')
        if services.voteExpanded and not services.voteExpanded()or close and close:IsA('TextButton')and close.Text=='↗'then return false end
        return dismiss(close)
    end
    function prompts:DismissResults()
        return dismiss(path(services.playerGui,'MatchSummaryUI','HolderFrame','MatchResult','Header','CloseButton'))
    end
    return prompts
end
runner.createPromptInputs=createPromptInputs
