function Core.abilityState(actor,character,now)
    local function flag(name)return actor:GetAttribute(name)==true or character:GetAttribute(name)==true end
    local function untilAt(name)
        local a,b=actor:GetAttribute(name),character:GetAttribute(name)
        return math.max(type(a)=='number'and a or 0,type(b)=='number'and b or 0)
    end
    local function timer(name)return untilAt(name)>now end
    local burrowing=character:GetAttribute('Burrowing')
    if type(burrowing)=='number'then burrowing=burrowing>now else burrowing=burrowing~=nil and burrowing~=false end
    return {protected=timer('GhostImmuneUntil')or flag('Ghosted')or flag('FFAInvincible')or flag('Invulnerable')or burrowing,
        shielded=flag('HitShielded')or timer('OneHitShieldUntil'),
        evasive=timer('DashUntil')or timer('RocketUntil')or flag('GearMotion'),
        burstFor=math.clamp(math.max(untilAt('DashUntil'),untilAt('RocketUntil'))-now,0,1.25),
        boosted=flag('GearBoost')or flag('FartBoost'),slowed=flag('GearSlow')}
end

function Core.keepAliveDue(enabled,now,nextAt,busy)
    return enabled and now>=nextAt and not busy
end

function Core.blocksTouch(object)
    local blocked=false
    while object do
        if object:IsA('LayerCollector')and not object.Enabled then return false end
        if object:IsA('GuiObject')then
            if not object.Visible then return false end
            blocked=blocked or object.Active or object:IsA('GuiButton')or object:IsA('TextBox')or object:IsA('ScrollingFrame')
        end
        object=object.Parent
    end
    return blocked
end

function Core.soulContext(serialized,records,userId,position,range)
    local count=0
    for token in string.gmatch(type(serialized)=='string'and serialized or'','[^,]+')do
        if tonumber(token)then count=count+1 end
    end
    local nearby=false
    for _,record in ipairs(records)do
        local victim,body=record:GetAttribute('Victim'),record:GetAttribute('Body')
        if type(victim)=='number'and victim~=userId and not record:GetAttribute('TakeBy')
            and typeof(body)=='Vector3'and(body-position).Magnitude<=range then nearby=true;break end
    end
    return {souls=count,soulsNearby=nearby}
end

function Core.trapAim(relative,velocity,range,armTime,triggerRadius)
    relative,velocity=flat(relative),flat(velocity)
    if relative.Magnitude<0.1 then return nil end
    local a=velocity:Dot(velocity)
    if a<4 then
        if math.abs(relative.Magnitude-range)<=triggerRadius*0.8 then return relative.Unit,armTime+0.1 end
        return nil
    end
    local b=2*relative:Dot(velocity)
    local c=relative:Dot(relative)-range*range
    local discriminant=b*b-4*a*c
    if discriminant<0 then return nil end
    local best
    for _,time in ipairs({(-b-math.sqrt(discriminant))/(2*a),(-b+math.sqrt(discriminant))/(2*a)})do
        if time>=armTime+0.05 and time<=2.25 and(not best or time<best)then best=time end
    end
    if not best then return nil end
    return (relative+velocity*best).Unit,best
end

function Core.clusterTrapAim(candidates,origin,range,armTime,radius,allowed)
    local best,bestTime,bestCount,bestScore,selected
    for _,candidate in ipairs(candidates)do
        if candidate.shielded or candidate.protected then continue end
        local aim,time=Core.trapAim(candidate.position-origin,candidate.velocity,range,armTime,radius)
        if aim and allowed(aim,range)then
            local landing=origin+aim*range
            local count=0
            for _,other in ipairs(candidates)do
                local point=other.position+other.velocity*time
                if not other.shielded and not other.protected and math.abs(point.Y-landing.Y)<=3
                    and flat(point-landing).Magnitude<=radius+.9 then count=count+1 end
            end
            local score=count-time*.1
            if not bestScore or score>bestScore then best,bestTime,bestCount,bestScore,selected=aim,time,count,score,candidate end
        end
    end
    return best,bestTime,bestCount,selected
end

function Core.projectileAim(relative,velocity,speed,range,delay)
    relative=flat(relative)+flat(velocity)*(delay or 0)
    velocity=flat(velocity)
    local a=velocity:Dot(velocity)-speed*speed
    local b=2*relative:Dot(velocity)
    local c=relative:Dot(relative)
    local time
    if math.abs(a)<1e-6 then if b<0 then time=-c/b end
    else
        local discriminant=b*b-4*a*c
        if discriminant>=0 then
            for _,t in ipairs({(-b-math.sqrt(discriminant))/(2*a),(-b+math.sqrt(discriminant))/(2*a)})do
                if t>0 and(not time or t<time)then time=t end
            end
        end
    end
    if not time or time>range/speed then return nil end
    local point=relative+velocity*time
    return point.Magnitude>.01 and point.Unit or nil,time
end

function Core.abilityUseful(id,role,context,items)
    local item=items[id]
    if not item or item.Kind~='Ability'or(item.UseRole and item.UseRole~=role)
        or not context.ready or not context.owned or not context.active or context.blocked or context.charges==0 then return false end
    if role=='Runner'then
        if id=='OneHitShield'then return context.imminent and not context.ownShielded end
        if id=='EmergencyAirhorn'then return (context.nearest or math.huge)<=14 end
        if id=='TimeWarp'then return context.pressured and context.rewindSafe end
        if id=='SoulReap'then return context.soulsNearby and(context.souls or 0)<(item.Cap or 3)end
        if id=='Burrow'then return context.pressured and context.safeLanding and(context.goalDistance or 0)>12 end
        if id=='PocketDoor'then return context.pressured and context.doorBehind and context.castClear end
        if id=='Cloak'then return context.pressured and not context.ownCloaked and(context.goalDistance or 0)>8 end
        if id=='InflatableDecoy'or id=='PumpkinBomb'or id=='FartCloud'then
            return context.pressured and context.safeForward and(context.goalDistance or 0)>8
        end
        return false
    end
    if context.targetProtected or context.targetShielded then return false end
    local distance=context.targetDistance or math.huge
    if id=='BearTrap'then return context.trapOpportunity and context.castClear end
    if id=='BigDagger'then return not context.ownBigDagger and distance>5 and distance<=10 end
    if id=='RocketShoes'then return distance>=18 and distance<=65 and context.safeBurst and not context.ownBurst end
    if id=='RufusLeash'then return distance>4 and distance<=15 and context.castClear end
    if id=='BowlingBall'then return distance>=8 and distance<=40 and context.castClear end
    if id=='KingsDemise'then return distance<=12 and(context.targetCrossing or(context.runnersNearby or 0)>=2)end
    if id=='SpringBox'then return context.blastOpportunity and context.castClear end
    if id=='PiratesCall'then return distance>=12 and distance<=65 and(context.runnersNearby or 0)>=1 end
    if id=='BrokenVow'then return distance<=8 end
    if id=='PumpkinBombChaser'then return distance<=20 and context.castClear end
    return false
end

