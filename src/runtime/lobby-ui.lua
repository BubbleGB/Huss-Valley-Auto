local function createLobbyUI(services)
    local ui={}
    local clock=services.clock or os.clock
    local sessions={}
    local promptList,promptRoot,promptAt={},nil,-math.huge
    local function child(root,name)return root and root:FindFirstChild(name)end
    local function path(root,...)
        for _,name in ipairs({...})do root=child(root,name);if not root then return nil end end
        return root
    end
    local function visible(object)
        if not object then return false end
        local current=object
        while current do
            if current:IsA('ScreenGui')and current.Enabled~=true then return false end
            if current:IsA('GuiObject')and current.Visible~=true then return false end
            current=current.Parent
        end
        return true
    end
    local function button(object)
        return object and object:IsA('GuiButton')and visible(object)and object.Active==true
    end
    local function find(root,name)
        return root and root:FindFirstChild(name,true)
    end
    local function cache(job)
        local s=services.states()or{}
        if job.seasonal then return s.halloween end
        return job.kind=='crate'and(s.states or{})[job.id]or s[job.kind]
    end
    local function state(job)
        local c=cache(job)
        return c and c.value,c
    end
    local function fresh(c,session)
        return c and type(c.at)=='number'and clock()-c.at<=15
            and(not session.entered or c.at>=session.entered)
    end
    local function session(job)
        local s=sessions[job.key]
        if not s then s={};sessions[job.key]=s end
        return s
    end
    local function root(job)
        local gui=services.playerGui
        if job.kind=='spin'then return path(gui,'SpinWheel','Main')
        elseif job.kind=='quest'then return path(gui,'QuestTracker','Holder','Panel')or path(gui,'ValleyQuests','QuestPanelShade','QuestPanel')
        elseif job.kind=='journey'then return path(gui,'ValleyJourney','Shade','Journal')
        elseif job.kind=='pumpkins'then return path(gui,'Pumpkins','Shade','Pumpkins')
        elseif job.seasonal then return path(gui,'HalloweenShop','HalloweenShop','Stage')
        elseif job.kind=='crate'then return find(child(gui,'Crates'),'Collection')
        elseif job.kind=='ghost'then return path(gui,'GhostTraderUI','UI')
        elseif job.kind=='equip'then return path(gui,'ValleyArmory','Overlay','Canvas')end
    end
    local function equipped(job,a)
        if not a or a.loaded~=true then return false end
        if job.slot=='Consumable'then return a.equippedGear==job.id end
        local catalog=services.gearCatalog
        return catalog and catalog.equippedForRole and catalog.equippedForRole(a,job.slot)==job.id
    end
    local function equipButton(job,r)
        local a=services.armory()
        local item=services.gearCatalog and services.gearCatalog.get(job.id)
        if not a or a.loaded~=true or a.pending or not item then return nil end
        if job.slot=='Consumable'then
            if item.Kind~='Item'or type((a.gear or{})[job.id])~='number'or a.gear[job.id]<1 then return nil end
        elseif(item.Kind~='Ability'or item.UseRole~=job.slot or(a.abilities or{})[job.id]~=true)then return nil end

        if r then
            for _,shop in ipairs(r:GetDescendants())do
                if shop.Name=='GearShop'and visible(shop)then
                    local b=path(shop,job.id,'Equip')
                    if b and visible(b)then return b end
                end
            end
        end
    end
    function ui:Prompt(job)
        local world=services.workspace
        if not world then return nil end
        local scope=world
        if promptRoot~=scope or clock()-promptAt>=2 then
            promptList={};promptRoot=scope;promptAt=clock()
            for _,p in ipairs(scope:GetDescendants())do
                if p:IsA('ProximityPrompt')then promptList[#promptList+1]=p end
            end
        end
        local chosen,best
        local character=services.player and services.player.Character
        local hrp=child(character,'HumanoidRootPart')
        for _,p in ipairs(promptList)do
            if p.Parent and p.Enabled==true and(not services.stationBlocked or not services.stationBlocked(p))then
                local matches=job.kind=='crate'and not job.seasonal and p.Name=='CratePrompt'and p:GetAttribute('CrateId')==job.id
                if job.seasonal then
                    local a=p.Parent
                    while a and a~=world do if a.Name=='HalloweenStore'then matches=true;break end;a=a.Parent end
                end
                matches=matches
                    or job.kind=='ghost'and p.Name=='TradeKeysPrompt'
                if job.kind=='spin'and p.Name=='ProximityPrompt'then
                    local a=p.Parent
                    while a and a~=world do if a.Name=='SpinTheWheel'then matches=true;break end;a=a.Parent end
                end
                if matches then
                    local parent=p.Parent
                    local position=parent:IsA('Attachment')and parent.WorldPosition or parent:IsA('BasePart')and parent.Position
                    local distance=hrp and position and(position-hrp.Position).Magnitude or 0
                    if(not hrp or position and math.abs(position.Y-hrp.Position.Y)<=40)
                        and(not best or distance<best)then chosen,best=p,distance end
                end
            end
        end
        return chosen
    end
    local function hudButton(name)
        return path(services.playerGui,'ValleyHUD','DrawerClip','Panel','Navigation',name)
    end
    local function entryButton(b)
        if not button(b)then return false end
        local p,size=b.AbsolutePosition,b.AbsoluteSize
        if p and size then
            if size.X<=0 or size.Y<=0 or p.X+size.X<=0 or p.Y+size.Y<=0 then return false end
            local camera=services.workspace and services.workspace.CurrentCamera
            local viewport=camera and camera.ViewportSize
            if viewport and(p.X>=viewport.X or p.Y>=viewport.Y)then return false end
            local center=p+size/2;local parent=b.Parent
            while parent do
                if parent:IsA('GuiObject')and parent.ClipsDescendants and parent.AbsolutePosition and parent.AbsoluteSize then
                    local a,z=parent.AbsolutePosition,parent.AbsoluteSize
                    if center.X<a.X or center.Y<a.Y or center.X>a.X+z.X or center.Y>a.Y+z.Y then return false end
                end
                parent=parent.Parent
            end
        end
        return true
    end
    local function scrollTo(b)
        local a=b and b.Parent
        while a do
            if a:IsA('ScrollingFrame')then
                local y=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2
                if y<a.AbsolutePosition.Y or y>a.AbsolutePosition.Y+a.AbsoluteSize.Y then
                    a.CanvasPosition=Vector2.new(a.CanvasPosition.X,math.max(0,a.CanvasPosition.Y+y-a.AbsolutePosition.Y-a.AbsoluteSize.Y/2))
                    return true
                end
            end
            a=a.Parent
        end
        return false
    end
    function ui:Open(job)
        local s=session(job)
        local existing=root(job)
        if visible(existing)and(job.kind~='quest'or existing.Name~='Panel'or existing.Interactable~=false)then return false end
        local entered=clock()
        local sent=false
        if job.kind=='spin'or job.kind=='crate'or job.kind=='ghost'then
            local prompt=self:Prompt(job)
            local character=services.player and services.player.Character
            local hrp=child(character,'HumanoidRootPart')
            if prompt and hrp then sent=services.input:Prompt(prompt,hrp)==true end
        elseif job.kind=='pumpkins'then
            local b=path(services.playerGui,'ValleyHUD','Wallet','Pumpkins')
            if entryButton(b)then sent=services.input:Tap(b)==true end
        elseif job.kind=='quest'then
            local tracker=path(services.playerGui,'QuestTracker','Holder')
            local tab=child(tracker,'Tab')
            if entryButton(tab)and tab.Interactable~=false then sent=services.input:Tap(tab)==true end
            if not tracker then for _,name in ipairs({'TopbarStandard','TopbarCentered','TopbarStandardClipped','TopbarCenteredClipped'})do
                local icon=find(child(services.playerGui,name),'ValleyQuests')
                local b=path(icon,'IconButton','Menu','IconSpot','ClickRegion')
                if entryButton(b)then sent=services.input:Tap(b)==true;break end
            end end
        elseif job.kind=='journey'or job.kind=='equip'then
            local name=job.kind=='journey'and'Journey'or job.slot=='Consumable'and'Items'or'Abilities'
            local b=hudButton(name)
            if job.kind=='equip'and job.slot=='Consumable'and not button(b)then
                b=hudButton('Abilities')
                if not button(b)then b=hudButton('Inventory')end
            end
            if entryButton(b)then sent=services.input:Tap(b)==true
            else
                b=path(services.playerGui,'ValleyHUD','MenuToggle')
                if button(b)then sent=services.input:Tap(b)==true end
            end
        end
        if sent then s.entered=entered;s.blocked=nil;s.done=nil;s.pending=nil end
        return sent
    end
    local function result(visibleValue,waiting,done,action,description)
        return {visible=visibleValue,waiting=waiting or false,done=done or false,action=action,description=description}
    end
    function ui:Inspect(job)
        local s=session(job)
        local r=root(job)
        local shown=visible(r)and(job.kind~='quest'or r.Name~='Panel'or r.Interactable~=false)
        if services.player and(s.pending or s.done)and(job.seasonal and services.player:GetAttribute('HalloweenShopOpen')or job.kind=='pumpkins'and services.player:GetAttribute('PumpkinsOpen'))then shown=true end
        local v,c=state(job)
        local pending=s.pending
        if job.kind=='pumpkins'then
            local tap=path(services.playerGui,'PumpkinTap','Tap')
            if tap and visible(tap)then
                local token={button=tap,kind='pumpkinTap',key=job.key};s.token=token
                return result(true,false,false,token,'Opening pumpkin · tapping native reveal')
            end
        end
        if s.selected and not pending and clock()-(s.selectedAt or 0)>5 then s.blocked=true end
        if pending then
            local confirmed=false
            if job.kind=='pumpkins'then
                confirmed=c and(c.resultRevision or 0)>pending.resultRevision
            elseif job.kind=='equip'then
                local b=equipButton(job,r)
                confirmed=equipped(job,services.armory())and b and b.Text:find('EQUIPPED',1,true)~=nil
            elseif job.kind=='ghost'then
                confirmed=fresh(c,s)and v and type(v.opened)=='table'and(v.deal~=pending.deal or v.opened[pending.slot]==true)
            elseif job.kind=='quest'then
                confirmed=fresh(c,s)and(c.revision or 0)>pending.revision and v and v.loaded==true
                    and(not pending.button.Parent or pending.button.Active==false or pending.button.Text=='CLAIMED'or pending.button.Text=='OWNED')
            elseif job.seasonal then
                confirmed=c and(c.resultRevision or 0)>pending.resultRevision and c.lastId==job.itemId
            elseif job.kind=='journey'then
                confirmed=fresh(c,s)and(c.revision or 0)>pending.revision and v and v.loaded==true
                    and type(v.claims)=='table'and not button(child(r,'ClaimAll'))
                    and(not services.journeyClaimable or services.journeyClaimable(v)==false)
            else
                confirmed=c and(c.resultRevision or 0)>pending.resultRevision
            end
            if confirmed then s.pending=nil;s.done=job.kind~='quest';if job.seasonal then s.revealAt=clock()end;if job.kind=='ghost'then s.ghostRevealAt=clock()end
            elseif clock()>=pending.deadline then
                s.pending=nil;s.blocked=true
            else return result(shown,true,false,nil,pending.description or'Awaiting native confirmation')end
        end
        if s.done then
            if job.kind=='pumpkins'then
                local b=child(r,'Open')
                if not visible(r)and clock()-(s.pumpkinStarted or clock())<25 then return result(shown,true,false,nil,'Opening native pumpkin')end
                if visible(r)and v and type(v.total)=='number'and v.total<1 then return result(shown,false,true,nil,'No owned pumpkins available')end
                if button(b)and fresh(c,s)and v and type(v.total)=='number'and v.total>0 then
                    s.done=nil;return self:Inspect(job)
                elseif not b or not b.Active then
                    if clock()-(s.pumpkinStarted or clock())<25 then return result(shown,true,false,nil,'Opening native pumpkin')end
                end
            end
            if job.seasonal and(not visible(r)or clock()-(s.revealAt or clock())<1)then return result(shown,true,false,nil,'Opening native event crate')end
            if job.kind=='spin'then
                local now=clock();local count=s.spinCount or 1
                local spinning=path(r,'Wheel','Spinner')
                local rotation=spinning and spinning.Rotation
                if type(rotation)=='number'then
                    if s.rotation==nil or math.abs(rotation-s.rotation)>.01 then s.stationaryAt=now end
                    s.rotation=rotation
                end
                local multi=child(r,'Spin5');local skip=child(r,'Skip')
                local busy=count>1 and((multi and not visible(multi))or(skip and visible(skip)))
                local minimum=count>1 and .8 or 5.2
                if now-(s.spinStarted or now)<minimum or busy or spinning and now-(s.stationaryAt or now)<.4 then
                    return result(shown,true,false,nil,'Spinning x'..count..' · waiting for animation')
                end
                if fresh(c,s)and v and type(v.credits)=='number'and v.credits>0 then
                    s.done=nil;s.rotation=nil;s.stationaryAt=nil;s.spinStarted=nil;s.spinCount=nil
                    return self:Inspect(job)
                else return result(shown,false,true,nil,'Native spins finished')end
            end
            if job.kind=='ghost'then
                local continue=child(r,'Continue')
                local leave=child(r,'PanelLeave')
                local started=s.ghostRevealAt or clock();s.ghostRevealAt=started
                if clock()-started>=25 then return result(shown,false,true,nil,'Ghost card reveal timed out')end
                if continue and(continue:IsA('TextLabel')or continue:IsA('TextButton'))and visible(continue)and(continue.TextTransparency==nil or continue.TextTransparency<.9)then
                    s.ghostContinueSeen=true
                    if(s.ghostContinueAttempts or 0)<3 and clock()-(s.ghostContinueAt or -math.huge)>=1 then
                        local token={button=continue,kind='ghostContinue',key=job.key};s.token=token
                        return result(shown,false,false,token,'Continue native Ghost card reveal')
                    end
                elseif button(leave)and(s.ghostContinueSeen or clock()-started>=4)then
                    return result(shown,false,true,nil,'Native Ghost card reveal complete')
                end
                return result(shown,true,false,nil,'Ghost card reveal · awaiting native Continue')
            end
            local continue=job.kind=='crate'and not s.continued and find(r,'Continue')
            if button(continue)then
                local token={button=continue,kind='continue',key=job.key};s.token=token
                return result(shown,false,false,token,'Continue native crate reveal')
            end
            local reveal=job.kind=='crate'and not s.continued and find(r,'Reveal')
            if reveal and visible(reveal)then
                s.revealDeadline=s.revealDeadline or clock()+25
                if clock()<s.revealDeadline then return result(shown,true,false,nil,'Opening '..tostring(job.name or job.id)..' · native reveal')end
            end
            return result(shown,false,true,nil,'Native result received')
        end
        if s.blocked then return result(shown,false,true,nil,'Native confirmation timed out; reopen to refresh')end
        if not shown then return result(false,false,false,nil,'Waiting for native menu')end
        local action
        if job.kind=='spin'then
            if fresh(c,s)and v and type(v.credits)=='number'then
                if v.credits~=v.credits or math.abs(v.credits)==math.huge or v.credits%1~=0 then
                    return result(shown,false,true,nil,'Invalid native spin balance')
                end
                if v.credits<1 then return result(shown,false,true,nil,'No native spin credits available')end
                for _,choice in ipairs({{'Spin10',10},{'Spin5',5},{'Spin',1}})do
                    local b=child(r,choice[1]);local lock=child(b,'Locked')
                    if v.credits>=choice[2]and button(b)and b.AutoButtonColor==true and not(lock and visible(lock))then action={button=b,kind='primary',count=choice[2]};break end
                end
            end
        elseif job.kind=='quest'then
            if r.Name=='Panel'then
                for _,card in ipairs(r:GetChildren())do
                    local b=card.Name:match('^Quest%d+$')and child(card,'Claim')
                    if button(b)and b.Interactable~=false then action={button=b,kind='primary'};break end
                end
                if not action then return result(shown,false,true,nil,'No completed daily quests available')end
            elseif fresh(c,s)and v and v.loaded==true then
                local list=child(r,'QuestList')
                for _,b in ipairs(list and list:GetDescendants()or{})do
                    if b.Name=='Claim'and button(b)and b:IsA('TextButton')and (b.Text=='CLAIM'or b.Text=='CLAIM KNIFE')then
                        action={button=b,kind='primary'};break
                    end
                end
                if not action and v.mode=='Event'and v.event and v.event.claimsEnabled then
                    for _,item in ipairs(v.event.weapons or{})do
                        local b=child(list,item.id)
                        if item.claimable and not item.claimed and button(b)then action={button=b,kind='questTab'};break end
                    end
                end
                if not action then return result(shown,false,true,nil,'No earned quest rewards available')end
            end
        elseif job.kind=='journey'then
            local b=child(r,'ClaimAll')
            if fresh(c,s)and v and v.loaded==true then
                if button(b)then action={button=b,kind='primary'}
                elseif b and b.Active==false then return result(shown,false,true,nil,'No native Journey rewards available')end
            end
        elseif job.kind=='pumpkins'then
            if fresh(c,s)and v and type(v.total)=='number'and not v.restricted then
                if v.total<1 then return result(shown,false,true,nil,'No owned pumpkins available')end
                local b=child(r,'Open');if button(b)then action={button=b,kind='primary'}end
            end
        elseif job.seasonal then
            if fresh(c,s)and v and v.live==true and type(v.free)=='table'then
                local count=v.free[job.itemId]or 0
                if type(count)~='number'or count~=count or count<1 or count%1~=0 or count==math.huge then
                    return result(shown,false,true,nil,'No free event crate available')
                end
                local b=path(r,'Crate'..tostring(job.cardIndex),'Buy')
                local free=false
                for _,label in ipairs(b and b:GetDescendants()or{})do
                    if(label:IsA('TextLabel')or label:IsA('TextButton'))and visible(label)and label.Text:find('FREE:',1,true)then free=true;break end
                end
                if button(b)and free then action={button=b,kind='primary'}end
            end
        elseif job.kind=='crate'then
            local b=find(r,'Continue')
            if button(b)then action={button=b,kind='continue'}
            else
                b=find(r,'Free')
                if fresh(c,s)and v and v.loaded==true and(v.allowed==false or type(v.free)=='number'and v.free<1)then
                    return result(shown,false,true,nil,'No free native crate opening available')
                end
                if fresh(c,s)and v and v.loaded==true and v.allowed==true and type(v.free)=='number'and v.free>0 and button(b)then action={button=b,kind='primary'}end
            end
        elseif job.kind=='ghost'then
            if fresh(c,s)and v then
                if v.live==false or v.restricted==true or type(v.keys)=='number'and v.keys<1
                    or type(v.nextAt)=='number'and v.nextAt>(services.serverTime or clock)()then
                    return result(shown,false,true,nil,'No owned Ghost card currently available')
                end
                if v.live==true and v.restricted==false and type(v.keys)=='number'and v.keys>=1
                    and type(v.nextAt)=='number'and type(v.opened)=='table'then
                    local camera=services.workspace and services.workspace.CurrentCamera
                    local view=child(camera,'GhostTraderView')
                    local choices={};local allOpened=true
                    for slot=1,6 do
                        if v.opened[slot]~=true then allOpened=false end
                        local hit=path(view,'Card'..slot,'Hit')
                        if v.opened[slot]==false and hit then choices[#choices+1]=slot end
                    end
                    if allOpened then return result(shown,false,true,nil,'Native Ghost deal fully opened')end
                    local choice=s.selected or s.choice
                    if choice and v.opened[choice]~=false then choice=nil;s.choice=nil end
                    if not choice and #choices>0 then
                        local index=(services.random or math.random)(#choices)
                        if type(index)=='number'and index%1==0 then choice=choices[index]end
                        s.choice=choice
                    end
                    local hit=choice and path(view,'Card'..choice,'Hit')
                    if hit then action={hit=hit,slot=choice,kind='card'}end
                end
            end
        elseif job.kind=='equip'then
            local a=services.armory();local b=equipButton(job,r)
            local item=services.gearCatalog and services.gearCatalog.get(job.id)
            if a and a.loaded==true and not a.pending then
                local owned=item and(job.slot=='Consumable'and item.Kind=='Item'and type((a.gear or{})[job.id])=='number'and a.gear[job.id]>0
                    or job.slot~='Consumable'and item.Kind=='Ability'and item.UseRole==job.slot and(a.abilities or{})[job.id]==true)
                if not owned then return result(shown,false,true,nil,'Selected equipment unavailable')end
            end
            if equipped(job,a)then return result(shown,false,true,nil,'Already equipped')end
            local text=job.slot=='Consumable'and'EQUIP ITEM'or'EQUIP ABILITY'
            if button(b)and b.Text==text then action={button=b,kind='primary'}
            else
                local tab=path(r,'Tabs',job.slot=='Consumable'and'Items'or'Abilities')
                if button(tab)and not b then action={button=tab,kind='tab'}end
            end
        end
        if action then
            action.key=job.key
            if action.kind=='questTab'then action.description='Opening earned quest reward'
            elseif action.kind=='tab'then action.description='Opening native equipment tab'
            elseif action.kind=='continue'then action.description='Continuing native crate reveal'
            elseif job.kind=='spin'then action.description='Spinning x'..tostring(action.count)
            elseif job.kind=='pumpkins'then action.description='Opening pumpkin'
            elseif job.kind=='quest'then action.description='Claiming quest'
            elseif job.kind=='journey'then action.description='Claiming Journey'
            elseif job.kind=='crate'then action.description='Opening '..tostring(job.name or job.id)
            elseif job.kind=='equip'then action.description='Equipping '..tostring(job.name or job.id)
            elseif job.kind=='ghost'then action.description='Ghost card '..tostring(action.slot)end
            s.token=action
        else s.token=nil end
        return result(shown,false,false,action,action and('Ready: '..action.description)or'Waiting for native control')
    end
    function ui:Act(job,token)
        local s=session(job)
        if not token or s.token~=token or token.key~=job.key then return false end

        local current=self:Inspect(job).action
        if not current or current.kind~=token.kind or current.button~=token.button or current.hit~=token.hit then return false end
        s.token=nil
        if current.button and scrollTo(current.button)then return true end
        local sent
        if current.kind=='pumpkinTap'then
            sent=services.input.TapPumpkin and services.input:TapPumpkin(current.button)==true
        elseif current.kind=='ghostContinue'then
            if current.button:IsA('GuiButton')and current.button.Interactable~=false then sent=services.input:Tap(current.button)==true
            else sent=services.input.TapGhostContinue and services.input:TapGhostContinue(current.button)==true end
        elseif current.hit then sent=services.input:TapCard(current.hit)==true
        else sent=services.input:Tap(current.button)==true end
        if not sent then return false end
        if current.kind=='pumpkinTap'then return true end
        if current.kind=='ghostContinue'then s.ghostContinueAt=clock();s.ghostContinueAttempts=(s.ghostContinueAttempts or 0)+1;return true end
        if current.kind=='tab'or current.kind=='questTab'then return true end
        if current.kind=='continue'then s.done=true;s.continued=true;return true end
        if job.kind=='spin'and current.kind=='primary'then
            s.spinStarted=clock();s.spinCount=current.count or 1
            s.rotation=nil;s.stationaryAt=clock()
        end
        local v,c=state(job)
        if job.kind=='pumpkins'then s.pumpkinStarted=clock()end

        if current.kind=='card'and s.selected~=current.slot then
            s.selected=current.slot;s.selectedAt=clock();return true
        end
        s.selected=nil
        s.pending={deadline=clock()+12,description=(current.description or'Native action')..' · awaiting confirmation',resultRevision=c and c.resultRevision or 0,revision=c and c.revision or 0,
            deal=v and v.deal,slot=current.slot,button=current.button}
        return true
    end
    function ui:Close(job)
        local r=root(job)
        local b
        if job.kind=='pumpkins'or job.seasonal then b=child(r,'CloseButton')
        elseif job.kind=='spin'then b=child(r,'CloseButton')
        elseif job.kind=='ghost'then b=child(r,'PanelLeave')
        elseif job.kind=='crate'then b=find(r,'Close')
        elseif job.kind=='quest'and r and r.Name=='Panel'then b=child(r,'Hide')
        else b=child(r,'Close')end
        local sent=button(b)and services.input:Tap(b)==true or false
        sessions[job.key]=nil
        return sent
    end
    return ui
end
runner.createLobbyUI=createLobbyUI
