function Core.pumpkinActive(mode,inMatch,out,state)
    return mode=='PumpkinHunt'and inMatch==true and out~=true and state=='Active'
end

function Core.pumpkinThreat(record,config)
    if typeof(record.position)~='Vector3'or record.state=='Broken'or record.state=='Rise'then return nil end
    local heading=CFrame.Angles(0,tonumber(record.yaw)or 0,0).LookVector
    local active=record.state=='Lunge'
    local tell=record.state=='Tell'
    local reach=(config.LungeReach or 4.5)+2
    return {id=record.id,position=record.position,velocity=active and heading*config.LungeSpeed or flat(record.velocity or Vector3.zero),
        radius=reach,catchRadius=reach,maxSpeed=config.Speed,heading=heading,state=record.state,
        activeAbility=active or tell,burstFor=active and math.max(0,config.LungeSeconds-math.max(0,record.age or 0))or nil,
        afterVelocity=active and Vector3.zero or flat(record.velocity or Vector3.zero),
        potentialAbility=tell,potentialVelocity=heading*config.LungeSpeed,
        potentialFor=config.LungeSeconds,potentialRadius=reach,breakRange=config.BreakRange or 22}
end

function Core.pumpkinRouteRisk(position,point,enemies,speed)
    local delta=flat(point-position)
    local horizon=math.min(.7,delta.Magnitude/math.max(1,speed or 30))
    local velocity=delta.Magnitude>.01 and delta.Unit*math.max(1,speed or 30)or Vector3.zero
    local risk=0
    for _,enemy in ipairs(enemies)do
        local gap=Core.threatApproach(position,velocity,enemy,horizon,enemy.radius)
        if gap<0 then risk=risk+500-gap*20 elseif gap<8 then risk=risk+(8-gap)^2 end
        if enemy.potentialAbility then
            local future={position=enemy.position,velocity=enemy.potentialVelocity,expires=enemy.potentialFor}
            local pending=Core.threatApproach(position,velocity,future,horizon,enemy.potentialRadius)
            if pending<0 then risk=risk+500-pending*20 end
        end
    end
    return risk
end
function Core.pumpkinGoal(position,enemies,currentId,hits,seconds,allowed,cost,speed,hitsToOut)
    local best,bestId,bestScore
    local injured=(hits or 0)>=math.max(0,(hitsToOut or 4)-1)
    local objectives=table.clone(enemies)
    table.sort(objectives,function(a,b)
        return flat(a.position-position).Magnitude-(a.id==currentId and 6 or 0)
            <flat(b.position-position).Magnitude-(b.id==currentId and 6 or 0)
    end)
    for index,enemy in ipairs(objectives)do
        if index>6 then break end
        local delta=flat(position-enemy.position)
        do
            local radius=math.min(enemy.breakRange,injured and 21 or(seconds and seconds<15)and 15 or 17)
            local radial=delta.Magnitude>.01 and delta.Unit or Vector3.new(1,0,0)
            local tangent=Vector3.new(-enemy.heading.Z,0,enemy.heading.X)
            local points={}
            if enemy.activeAbility then
                points[#points+1]=position+tangent*14
                points[#points+1]=position-tangent*14
            end
            for i=0,11 do
                local a=i*math.pi/6
                points[#points+1]=enemy.position+Vector3.new(radial.X*math.cos(a)-radial.Z*math.sin(a),0,
                    radial.X*math.sin(a)+radial.Z*math.cos(a))*radius
            end
            for _,point in ipairs(points)do
                point=Vector3.new(point.X,position.Y,point.Z)
                if allowed(position,point)then
                    local distance=flat(point-position).Magnitude
                    local score=-distance*.25-(cost(point)or 0)*12+(enemy.id==currentId and 3 or 0)
                        -Core.pumpkinRouteRisk(position,point,enemies,speed)
                    if enemy.activeAbility then
                        local side=math.abs(flat(point-enemy.position):Dot(tangent))
                        score=score+math.min(side,14)*2
                    end
                    for _,other in ipairs(enemies)do
                        local clearance=Core.threatApproach(point,Vector3.zero,other,.65,other.radius)
                        if clearance<0 then score=score-500+clearance*20 end
                        if other.potentialAbility then
                            local gap=Core.threatApproach(point,Vector3.zero,{position=other.position,
                                velocity=other.potentialVelocity,expires=other.potentialFor},.5,other.potentialRadius)
                            if gap<0 then score=score-500 end
                        end
                    end
                    if not bestScore or score>bestScore then best,bestId,bestScore=point,enemy.id,score end
                end
            end
        end
    end
    return best,bestId
end
