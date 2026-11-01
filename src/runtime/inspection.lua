-- Optional diagnostics reuse cached decisions; no sensing, casts or movement here.
local inspection={elapsed=0,updates=0,lines={},markers={},motion={}}
runner.inspection=inspection
inspection.button=button('Inspection','Info',UDim2.new(1,-86,0,7),UDim2.fromOffset(42,28),Color3.fromRGB(65,70,83))
title.Size=UDim2.new(1,-106,0,40)
inspection.card=Instance.new('Frame')
inspection.card.Name='InspectionCard';inspection.card.Position=UDim2.new(1,8,0,0)
inspection.card.Size=UDim2.fromOffset(270,194);inspection.card.BackgroundColor3=panel.BackgroundColor3
inspection.card.Visible=false;inspection.card.Parent=panel
Instance.new('UICorner',inspection.card).CornerRadius=UDim.new(0,8)
inspection.details=label('InspectionDetails','',UDim2.fromOffset(10,8),UDim2.fromOffset(250,178))
inspection.details.Parent=inspection.card;inspection.details.TextYAlignment=Enum.TextYAlignment.Top
inspection.details.TextSize=12
inspection.layer=Instance.new('Frame')
inspection.layer.Name='InspectionOverlay';inspection.layer.Size=UDim2.fromScale(1,1)
inspection.layer.BackgroundTransparency=1;inspection.layer.Visible=false;inspection.layer.Parent=gui
local function marker(name,color)
    local v=Instance.new('TextLabel');v.Name=name;v.Size=UDim2.fromOffset(150,22)
    v.AnchorPoint=Vector2.new(.5,1);v.BackgroundColor3=Color3.fromRGB(24,27,35);v.BackgroundTransparency=.15
    v.TextColor3=color;v.Font=Enum.Font.GothamBold;v.TextSize=11;v.Visible=false;v.Parent=inspection.layer
    return v
end
local function line(name,color)
    local v=Instance.new('Frame');v.Name=name;v.AnchorPoint=Vector2.new(.5,.5)
    v.BorderSizePixel=0;v.BackgroundColor3=color;v.Visible=false;v.Parent=inspection.layer
    return v
end
inspection.goal=marker('Goal',Color3.fromRGB(90,230,180))
for i=1,8 do inspection.lines[i]=line('Route'..i,Color3.fromRGB(90,230,180))end
for i=1,4 do
    inspection.markers[i]=marker('Threat'..i,Color3.fromRGB(255,155,100))
    inspection.motion[i]=line('Prediction'..i,Color3.fromRGB(255,155,100))
end
function inspection.hide()
    inspection.layer.Visible=false
end
function api:SetInspectionEnabled(enabled)
    if self.Destroyed then return false end
    assert(type(enabled)=='boolean','Inspection requires true or false')
    self.InspectionEnabled=enabled;inspection.card.Visible=enabled
    inspection.button.BackgroundColor3=enabled and Color3.fromRGB(35,104,118)or Color3.fromRGB(65,70,83)
    inspection.elapsed=.2
    if not enabled then inspection.hide()end
    return enabled
end
connect(inspection.button.Activated,function()api:SetInspectionEnabled(not api.InspectionEnabled)end)
api:SetInspectionEnabled(false)
function inspection.tick(dt)
    if not api.InspectionEnabled then return end
    inspection.elapsed=inspection.elapsed+dt
    if inspection.elapsed<.2 then return end
    inspection.elapsed=0;inspection.updates=inspection.updates+1
    local d=api.Diagnostics or{}
    local stats=runner.stats
    inspection.details.Text=string.format('%s | %s\nRoute: %s | %s\nPlan %.1f ms | early updates %d\nChasers %d | hazards %d\nTime left: %s\nDash: %s\nCrossings: %d safe / %d caught / %d timed out\nMarkers predict 0.35 s; not hitboxes',
        d.role or'Waiting',api.Enabled and'Running'or'Paused',d.routing or'-',api.LastPlanReason or'-',
        api.LastPlanMS or 0,api.ReactivePlans or 0,d.chasers or 0,d.hazards or 0,
        type(d.secondsLeft)=='number'and string.format('%.1f s',math.max(0,d.secondsLeft))or'-',
        api.DashDecision or'-',stats.safe,stats.caught,stats.timeout)
    inspection.hide()
    local context=actionContext
    local camera=workspace.CurrentCamera
    local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    if not api.Enabled or not camera or not root or not context or context.character~=player.Character
        or os.clock()-context.at>.25 then return end
    local inset=GuiService:GetGuiInset()
    local function project(point)
        local p,visible=camera:WorldToViewportPoint(point)
        if not visible or p.Z<=0 then return nil end
        return Vector2.new(p.X-inset.X,p.Y-inset.Y)
    end
    local function drawLine(v,a,b)
        local x,y=project(a),project(b)
        v.Visible=x~=nil and y~=nil
        if v.Visible then
            local delta=y-x;local center=(x+y)*.5
            v.Position=UDim2.fromOffset(center.X,center.Y);v.Size=UDim2.fromOffset(delta.Magnitude,2)
            v.Rotation=math.deg(math.atan2(delta.Y,delta.X))
        end
    end
    local function drawMarker(v,position,text)
        local p=project(position);v.Visible=p~=nil
        if p then v.Position=UDim2.fromOffset(p.X,p.Y);v.Text=text end
    end
    local finish=context.finish
    if finish then drawMarker(inspection.goal,finish,string.format('Goal | %.0f studs',flat(finish-root.Position).Magnitude))
    else inspection.goal.Visible=false end
    local index=navigation and navigation.index or 1
    local path=navigation and navigation.path
    local previous=root.Position
    for i,v in ipairs(inspection.lines)do
        local point=path and path[index+i-1]or i==1 and context.waypoint
        if point then drawLine(v,previous,point);previous=point else v.Visible=false end
    end
    local nearest={}
    for _,enemy in ipairs(context.role=='Catcher'and context.candidates or context.nearby or{})do
        local distance=flat(enemy.position-root.Position).Magnitude
        local index=#nearest+1
        for i,entry in ipairs(nearest)do if distance<entry.distance then index=i;break end end
        if index<=4 then table.insert(nearest,index,{enemy=enemy,distance=distance});nearest[5]=nil end
    end
    for i,v in ipairs(inspection.markers)do
        local entry=nearest[i];v.Visible=false;inspection.motion[i].Visible=false
        if entry then
            local enemy=entry.enemy
            drawMarker(v,enemy.position,string.format('%s | %.0f studs',enemy.kind or(context.role=='Catcher'and'Runner'or'Chaser'),entry.distance))
            drawLine(inspection.motion[i],enemy.position,Core.runnerPosition(enemy,.35))
        end
    end
    inspection.layer.Visible=true
end
