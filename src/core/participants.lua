function Core.canRun(enabled, inMatch, role, state, locked, mapChanging)
    return enabled and inMatch == true and role == 'Runner' and state == 'Active'
        and not locked and not mapChanging
end

function Core.canHunt(enabled, inMatch, role, state, locked, mapChanging)
    return enabled and inMatch == true and role == 'Catcher' and state == 'Active'
        and not locked and not mapChanging
end

function Core.isRunner(inMatch, role, state, health, locked,bot,anchored)
    return inMatch == true and role == 'Runner' and state == 'Active' and health > 0
        and not anchored and not(bot and locked)
end

function Core.selectChaseTarget(candidates,currentId,position)
    local close={}
    for _,candidate in ipairs(candidates)do
        local relative=candidate.position-position
        local threshold=candidate.id==currentId and 14 or 12
        if candidate.closeClear~=false and math.abs(relative.Y)<=3 and flat(relative).Magnitude<=threshold then close[#close+1]=candidate end
    end
    local pool=#close>0 and close or candidates
    local hidden=false
    for _,candidate in ipairs(pool)do if candidate.invisible then hidden=true;break end end
    local scores={}
    local held,best,nearest
    for _,candidate in ipairs(pool)do
        if hidden and not candidate.invisible then continue end
        local predicted=candidate.position+flat(candidate.velocity or Vector3.zero)*.25
        local weight,count=0,1
        for _,other in ipairs(candidates)do
            if other.id~=candidate.id then
                local point=other.position+flat(other.velocity or Vector3.zero)*.25
                local distance=flat(point-predicted).Magnitude
                if math.abs(point.Y-predicted.Y)<=4 and distance<14 then
                    weight=weight+1-distance/14;count=count+1
                end
            end
        end
        local distance=flat(candidate.position-position).Magnitude
        local score={distance=distance,cost=distance/(1+math.min(.75,.35*weight)),weight=weight,count=count,
            tier=#close>0 and'close'or'normal'}
        scores[candidate.id]=score
        if candidate.id==currentId then held=candidate end
        if not best or score.cost<scores[best.id].cost then best=candidate end
        if not nearest or distance<scores[nearest.id].distance then nearest=candidate end
    end
    if held then
        local current=scores[held.id]
        local near=nearest and scores[nearest.id]
        if nearest.id~=held.id and near.distance<current.distance*.65 and current.distance-near.distance>=4 then
            return nearest,near
        end
        local better=scores[best.id]
        if best.id~=held.id and better.weight>current.weight+.4 and better.cost<current.cost*.8 and current.cost-better.cost>=3 then
            return best,better
        end
        return held,current
    end
    return best,best and scores[best.id]
end

function Core.isInvisible(actor,character,now)
    for _,source in ipairs({actor,character})do
        if source then
            if source:GetAttribute('Cloaked')==true or source:GetAttribute('CloakActive')==true
                or source:GetAttribute('Invisible')==true then return true end
            for _,name in ipairs({'CloakUntil','CloakedUntil','InvisibleUntil'})do
                local untilAt=source:GetAttribute(name)
                if type(untilAt)=='number'and untilAt>now then return true end
            end
        end
    end
    if not character then return false end
    local torso=character:FindFirstChild('Torso')or character:FindFirstChild('UpperTorso')
    local head=character:FindFirstChild('Head')
    return torso and head and (torso.Transparency+head.Transparency)/2>=0.65 or false
end

