local function createFallenKing(services)
    local controller={}
    local Core=services.Core
    local zones={}
    local active,facing,goal,holding,thrown=false,nil,nil,nil,false
    local nextPlan=0
    local meleeTarget,nextMeleeAt,attackAim=nil,0,false
    local function flat(v)return v*Vector3.new(1,0,1)end
    local function position(object)
        if object:IsA('BasePart')then return object.Position end
        local root=object:FindFirstChild('HumanoidRootPart')or object:FindFirstChild('Pivot')or object.PrimaryPart
        return root and root.Position
    end
    function controller:Reset()
        zones={};active=false;facing=nil;goal=nil;holding=nil;thrown=false;nextPlan=0;meleeTarget=nil;attackAim=false
        services.navigation:Cancel()
        if services.finish then services.finish()end
    end
    function controller:Facing()return active and facing or nil end
    function controller:NeedsAim()return active and attackAim and facing~=nil end
    function controller:Report()return {active=active,hazards=#zones,holding=holding~=nil,goal=goal}end
    function controller:Receive(kind,data)
        if kind~='Attack'or type(data)~='table'or services.session:GetAttribute('BossActive')~=true then return end
        local expires=services.clock()+math.clamp(tonumber(data.seconds)or 1,.2,4)+.5
        local function add(point,radius)
            if #zones>=64 then table.remove(zones,1)end
            zones[#zones+1]={position=point,radius=radius,expires=expires}
        end
        if data.kind=='Ring'and typeof(data.position)=='Vector3' then
            add(data.position,math.clamp(tonumber(data.radius)or 10,1,60)+3)
        elseif data.kind=='Line'and typeof(data.from)=='Vector3'and typeof(data.to)=='Vector3'then
            local delta=data.to-data.from
            local count=math.clamp(math.ceil(delta.Magnitude/5),1,24)
            for i=0,count do add(data.from+delta*(i/count),math.clamp(tonumber(data.width)or 6,1,20)/2+4)end
        end
    end
    function controller:Step(character,humanoid,root,dt)
        local native=services.session:GetAttribute('BossActive')==true
        if not native or not services.enabled()or services.player:GetAttribute('InMatch')~=true then
            if active then self:Reset()end
            return false,Vector3.zero,false
        end
        active=true
        local p=services.player
        if services.session:GetAttribute('BossFighting')~=true or p:GetAttribute('CutsceneActive')
            or p:GetAttribute('BossDownedUntil')or p:GetAttribute('RunState')=='Caught'or not character or not humanoid or not root
            or services.blocked and services.blocked()or humanoid.Health<=0 or root.Anchored or humanoid.Sit or humanoid.PlatformStand
            or character:GetAttribute('MovementLocked')or character:GetAttribute('Ragdolled')or character:GetAttribute('GearMotion')then
            facing=nil;services.navigation:Cancel();return true,Vector3.zero,false
        end
        local now=services.clock()
        for i=#zones,1,-1 do if now>=zones[i].expires then table.remove(zones,i)end end
        local centre=services.session:GetAttribute('BossFogCentre')
        local radius=services.session:GetAttribute('BossFogRadius')
        local fog=typeof(centre)=='Vector3'and type(radius)=='number'and radius>7
        local danger=table.clone(zones)
        local arena=services.world:FindFirstChild('FallenKingFight')
        local king=arena and arena:FindFirstChild('FallenKing')
        local kingAt=king and position(king)
        if kingAt then danger[#danger+1]={position=kingAt,radius=((services.config.King or{}).CatchRadius or 7)+3}end
        local function safe(a,b)
            if fog then
                local before,after=flat(a-centre).Magnitude,flat(b-centre).Magnitude
                if after>radius-5 and after>=before-.1 then return false end
            end
            return Core.clearSegment(a,b,danger)and services.clear(a,b,character)
        end
        local bomb=p:GetAttribute('BossBomb')
        if bomb~=holding then holding=bomb;thrown=false;nextPlan=0 end
        if now>=nextPlan then
            nextPlan=now+.25
            local fight=services.world:FindFirstChild('FallenKingFight')
            goal=nil;facing=nil;meleeTarget=nil
            local arrivalRange=3
            if fight then
                local king=fight:FindFirstChild('FallenKing')
                local target=king and position(king)
                local nearest=math.huge
                for _,object in ipairs(fight:GetChildren())do
                    if object.Name=='Shrine'and object:IsA('Model')and(object:GetAttribute('Health')or 0)>0 then
                        local at=position(object)
                        if at and flat(at-root.Position).Magnitude<nearest then target=at;meleeTarget=at;nearest=flat(at-root.Position).Magnitude end
                    end
                end
                if holding then
                    facing=target
                    if target then
                        local away=flat(root.Position-target)
                        goal=target+(away.Magnitude>.1 and away.Unit or Vector3.xAxis)*22
                    end
                else
                    local function candidate(object)
                        local at=position(object)
                        if not at or math.abs(at.Y-root.Position.Y)>12 or fog and flat(at-centre).Magnitude>radius-6 then return end
                        local distance=flat(at-root.Position).Magnitude
                        if distance<nearest and Core.clearSegment(root.Position,at,danger)then goal=at;nearest=distance end
                    end
                    nearest=math.huge
                    local hearts=p:GetAttribute('BossHearts')
                    local drops=fight:FindFirstChild('HeartDrops')
                    if type(hearts)=='number'and hearts<(services.config.Hearts.Count or 3)and drops then
                        for _,object in ipairs(drops:GetChildren())do if object:IsA('BasePart')or object:IsA('Model')then candidate(object)end end
                    end
                    if not goal then
                        for _,object in ipairs(fight:GetChildren())do
                            if object.Name=='BossBomb'and object:IsA('BasePart')and object.Anchored and object:GetAttribute('Combo')==nil then candidate(object)end
                        end
                    end
                    if not goal and meleeTarget then
                        local away=flat(root.Position-meleeTarget)
                        goal=meleeTarget+(away.Magnitude>.1 and away.Unit or Vector3.xAxis)*math.max(2,(services.meleeReach or 7)-2)
                        arrivalRange=1
                    end
                    facing=target
                end
            end
            if fog and(not goal or flat(goal-centre).Magnitude>radius-6)then goal=Vector3.new(centre.X,root.Position.Y,centre.Z)end
            if goal then goal=Vector3.new(goal.X,root.Position.Y,goal.Z);services.navigation:SetGoal(goal,arrivalRange)
            else services.navigation:Cancel()end
        end
        attackAim=holding~=nil or meleeTarget~=nil and flat(meleeTarget-root.Position).Magnitude<15
        if not holding and meleeTarget and(meleeTarget-root.Position).Magnitude<=(services.meleeReach or 7)
            and now>=nextMeleeAt and Core.clearSegment(root.Position,meleeTarget,danger)
            and services.clear(root.Position,meleeTarget,character,true)then
            facing=meleeTarget
            if services.melee and(not services.meleeAimed or services.meleeAimed(meleeTarget-root.Position))and services.melee()==true then
                nextMeleeAt=now+(services.meleeCooldown or .8)
            end
        end
        if holding and facing and not thrown and(facing-root.Position).Magnitude<55
            and services.clear(root.Position,facing,character,true)and services.aimed(facing-root.Position)then
            if services.throw()==true then thrown=true end
        end
        local move,jump=Vector3.zero,false
        if goal then move,jump=services.navigation:Step(character,humanoid,root)end
        local threats={}
        for _,zone in ipairs(danger)do threats[#threats+1]={position=zone.position,radius=zone.radius,catchRadius=zone.radius,velocity=Vector3.zero}end
        local waypoint=root.Position+(move.Magnitude>.01 and move*12 or Vector3.zero)
        if move.Magnitude<.01 then
            local closest,gap
            for _,zone in ipairs(danger)do
                local offset=flat(root.Position-zone.position)
                local clearance=offset.Magnitude-zone.radius
                if clearance<6 and(not gap or clearance<gap)then closest,gap=offset,clearance end
            end
            if closest then waypoint=root.Position+(closest.Magnitude>.01 and closest.Unit or Vector3.xAxis)*12 end
        end
        if #danger>0 or fog then
            move=Core.choose(root.Position,waypoint,math.max(12,humanoid.WalkSpeed),threats,
                function(d,distance)return safe(root.Position,root.Position+d*(distance or 8))end,move,0)
        end
        if move.Magnitude>.01 and not safe(root.Position,root.Position+move*4)then move=Vector3.zero end
        services.operation(p:GetAttribute('BossDownedUntil')and'Fallen King · waiting for revival'
            or holding and(thrown and'Fallen King · waiting for bomb result'or'Fallen King · aiming bomb')
            or meleeTarget and'Fallen King · attacking shrine'or goal and'Fallen King · collecting supplies'or'Fallen King · avoiding attacks')
        return true,move,jump
    end
    return controller
end
runner.createFallenKing=createFallenKing
