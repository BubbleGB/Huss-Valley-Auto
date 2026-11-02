-- Exercise the actual pinned library and API binding, without live gameplay actions.
return function(source)
    local env=getgenv()
    assert(type(getconnections)=='function','native lifecycle verification requires executor connection inspection')
    local input=game:GetService('UserInputService')
    local signals={input.InputBegan,input.InputChanged,input.InputEnded,game:GetService('RunService').RenderStepped}
    local previous={}
    for _,signal in ipairs(signals)do for _,connection in ipairs(getconnections(signal))do if connection.Function then previous[connection.Function]=true end end end
    local unrelated=input.InputChanged:Connect(function()end)
    -- Unrelated handler is excluded by its function identity.
    for _,connection in ipairs(getconnections(input.InputChanged))do if connection.Function then previous[connection.Function]=true end end
    local a=assert(loadstring(source))()
    -- Game/other scripts can register handlers after the baseline; those stay alive.
    local concurrent=input.InputEnded:Connect(function()end)
    local second,secondOwner,secondSentinels
    local ok,err=pcall(function()
        assert(a.UI and a.UI.Backend=='WindUI','categorized WindUI backend is missing')
        local root=game.Players.LocalPlayer.PlayerGui:FindFirstChild('HussAutoCrossUI')
        assert(root and not root:FindFirstChild('Panel'),'old native panel must be removed completely')
        for _,owned in ipairs(a.UI.OwnedGuis)do for _,v in ipairs(owned:GetDescendants())do
            if v:IsA('TextLabel')or v:IsA('TextButton')then
                assert(v.Text~='Minimize window'and v.Text~='Unload script','dashboard duplicate action must be removed')
            end
        end end
        assert(a.UI.Status.ParagraphFrame.UIElements.Title.Text=='Operation status','operation title')
        assert(a.UI.lastStatus=='Stopped','stopped state must be explicit')
        assert(a.UI.UserStatus and a.UI.lastUserStatus:find('LMS (Last Man Standing):',1,true),'native user stats rendered')
        local avatar=assert(a.UI.UserAvatar,'headshot missing')
        local corner=assert(avatar:FindFirstChildOfClass('UICorner'),'headshot corner missing')
        assert(corner.CornerRadius==UDim.new(.5,0)and avatar.Image:find('id='..game.Players.LocalPlayer.UserId,1,true),'circular current-user headshot')
        assert(a.UI.UserStatus.ParagraphFrame.UIElements.Title.Text:find('@'..game.Players.LocalPlayer.Name,1,true),'username rendered')
        assert(a.UI.ServerStatus and a.UI.lastServerStatus and a.UI.lastServerStatus:find('Script runtime:',1,true)and a.UI.lastServerStatus:find('Chasers:',1,true),'Dashboard server status is rendered')
        assert(table.find(a.UI.Categories,'Collection')and not table.find(a.UI.Categories,'Rewards'),'Collection replaces Rewards')
        assert(a.UI.Controls.AutoSeasonalCurrency,'seasonal currency toggle missing')
        assert(a.UI.Controls.AutoGems.ToggleFrame.UIElements.Main:IsDescendantOf(a.UI.Controls.AutoJourney.ToggleFrame.UIElements.Main.Parent),'gems belongs in Collection')
        assert(a.UI.Controls.UseAbilities.ToggleFrame.UIElements.Main:IsDescendantOf(a.UI.Controls.UseConsumables.ToggleFrame.UIElements.Main.Parent),'abilities belongs in Equipment')
        assert(#a.UI.Categories==9,'window must expose all nine categories')
        -- A concurrent independent library creates new input handlers after our baseline.
        local first=assert(source:find('local function prepareWindUI(source)',1,true))
        local last=assert(source:find("local ui={Backend=",first,true))
        local prepare=assert(loadstring(source:sub(first,last-1)..'\nreturn prepareWindUI'))()
        local compatible;compatible,secondOwner=prepare(env.HussWindUICache.source)
        second=assert(loadstring(compatible,'HussWindUI_1_6_66_'..game:GetService('HttpService'):GenerateGUID(false)))(secondOwner)
        assert(debug.info(second.Creator.AddSignal,'s')~=debug.info(a.UI.Library.Creator.AddSignal,'s'),'concurrent library must have a separate compiled scope')
        secondSentinels=table.clone(second.Creator.Signals)
        assert(#secondSentinels>=2,'concurrent library must own independent global input handlers')
        assert(not a.Enabled,'loading a UI must not start automation')
        a.UI.Controls.MapPreference:Select(a.UI.MapNames.Map2)
        assert(a:GetSettings().MapPreference=='Map2','map dropdown must update live voting preference')
        a.UI.Controls.HeroThreshold:Set(8)
        assert(a:GetSettings().HeroThreshold==8,'hero slider must update live policy')
        a.UI:SetPrioritySlot(1,'Gems')
        local p=a:GetSettings().Priorities
        assert(p[1]=='Gems'and p[3]=='Escape','priority slot changes must swap rather than duplicate tasks')
        a:SetSetting('AutoDash',false);a.UI:Refresh()
        assert(a.UI.Controls.AutoDash.Value==false,'external settings changes must reflect in library controls')
        a.UI.Controls.AutoDash:Set(true)
        task.wait()
        assert(a:GetSettings().AutoDash,'toggle must apply to native action policy')
        a:SetSetting('AntiAFK',false)
        a:SetSetting('AutoRun',false);a:SetSetting('AutoChase',false)
        a.UI.Controls.StopEverything:Set(false)
        assert(a.Enabled,'library Start button must start automation')
        a.UI:Minimize();assert(a.Enabled,'minimization must not stop running automation')
        a.UI.Controls.StopEverything:Set(true);assert(not a.Enabled,'library Stop button must stop automation')
        task.wait(.45)
        assert(a.UI.Minimized and a.UI.Badge.Visible and not a.Enabled,'minimizing must preserve automation state and expose restore')
        a.UI:Restore();a.UI:Refresh();task.wait(.1)
        assert(not a.UI.Minimized and not a.UI.Badge.Visible,'restore must reopen the window')
        assert(a.UI.Badge.Text=='Huss\nValley'and a.UI.Badge.Size.X.Offset==a.UI.Badge.Size.Y.Offset,'minimized square branding')
        assert(not a.UI.QuickControl and not a.UI.Badge:FindFirstChild('QuickStartStop'),'minimized badge has no controls')
        local nativeTP=a.SetTPAssistEnabled
        a.SetTPAssistEnabled=function(self,value)self.TPAssistEnabled=false;self.TPDodgeEnabled=false;return false end
        a.UI.Controls.TPAssist:Set(true);a.UI:Refresh()
        assert(not a.UI.Controls.TPAssist.Value,'rejected toggle changes must reflect actual disabled state')
        a.SetTPAssistEnabled=nativeTP
        a.UI.Controls.SpeedMultiplier:Set(1.35)
        assert(math.abs(a.SpeedMultiplier-1.35)<.001,'library speed slider must reach 0.05 steps')
        local profile=a:ExportProfile();profile.settings.HeroThreshold=9
        a:ApplyProfile(profile);assert(a:GetSettings().HeroThreshold==9,'settings profile must apply validated values')
        profile.settings.HeroThreshold=100
        local before=a:GetSettings();assert(not pcall(a.ApplyProfile,a,profile),'invalid profiles must be rejected')
        assert(a:GetSettings().HeroThreshold==before.HeroThreshold,'invalid profile must not partially mutate settings')
        -- Start a real slider drag, then unload before the input ends.
        local slider=a.UI.Controls.SpeedMultiplier
        slider:Set(1.35,{UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(slider.UIElements.SliderIcon.AbsolutePosition.X,0,0)})
        -- Executors may prefix chunk names; derive the exact compiled library scope.
        local librarySource=debug.info(a.UI.Library.Creator.AddSignal,'s')
        assert(librarySource:sub(-#a.UI.LibraryChunkName)==a.UI.LibraryChunkName,'library must have a unique diagnostic chunk name')
        local ownedSignals={};local renderSignals=0
        for index,signal in ipairs(signals)do
            for _,connection in ipairs(getconnections(signal))do
                local fn=connection.Function
                if fn and not previous[fn]and connection.Enabled and debug.info(fn,'s')==librarySource then
                    ownedSignals[#ownedSignals+1]=connection
                    if index==4 then renderSignals=renderSignals+1 end
                end
            end
        end
        assert(#ownedSignals>2 and renderSignals>0,'lifecycle fixture must observe library global connections and active slider RenderStepped drag')
        local registry=table.clone(a.UI.Library.Creator.Signals)
        local owned=a.UI.OwnedGuis
        a:Destroy();task.wait(.5)
        assert(a.Destroyed and not env.HussAutoCross,'close must remove API and controller')
        for _,gui in ipairs(owned)do assert(not gui.Parent,'close must remove every library GUI')end
        local registryConnected=0
        for _,connection in ipairs(registry)do if connection.Connected then registryConnected=registryConnected+1 end end
        assert(registryConnected==0,'close must disconnect every actual current Creator connection')
        -- Re-enumerate live signals: saved executor wrappers can lose Function after disconnect.
        for _,signal in ipairs(signals)do for _,connection in ipairs(getconnections(signal))do
            local fn=connection.Function
            if fn and connection.Enabled and debug.info(fn,'s')==librarySource then
                error(string.format('close must disconnect current library global handler (source=%s line=%s registryBefore=%d registryAfter=%d registryConnected=%d)',
                    librarySource,tostring(debug.info(fn,'l')),#registry,#a.UI.Library.Creator.Signals,registryConnected))
            end
        end end
        for _,connection in ipairs(secondSentinels)do assert(connection.Connected,'cleanup must preserve the concurrent library instance')end
        assert(unrelated.Connected and concurrent.Connected,'library cleanup must preserve unrelated handlers registered before and after UI initialization')
    end)
    if not a.Destroyed then a:Destroy()end
    if secondOwner then secondOwner:Cleanup()end
    if second then for _,key in ipairs({'ScreenGui','NotificationGui','DropdownGui','TooltipGui'})do if second[key]then second[key]:Destroy()end end end
    unrelated:Disconnect();concurrent:Disconnect()
    assert(ok,err)
    return {categories='passed',bindings='passed',priorities='passed',minimize='passed',profile='passed',cleanup='passed'}
end
