function Core.ownedEquipment(state,items,slot)
    local result={}
    if not state or not state.loaded then return result end
    for id,item in pairs(items)do
        local ability=item.Kind=='Ability'
        local owned=ability and state.abilities and state.abilities[id]==true
            or not ability and type((state.gear or{})[id])=='number'and state.gear[id]>0
        if owned and(slot=='Consumable'and not ability or ability and item.UseRole==slot)then
            result[#result+1]={id=id,name=item.Name or id,count=not ability and state.gear[id]or nil}
        end
    end
    table.sort(result,function(a,b)if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return result
end
function Core.journeyClaimable(state,config)
    if not state or state.loaded~=true or state.seasonId~=config.SeasonId then return false end
    local claims=state.claims or{}
    for tier,rewards in ipairs(config.Rewards or{})do
        if tier>(state.tier or 0)then break end
        for _,lane in ipairs({'Free','Premium'})do
            local reward=rewards[lane]
            if reward and(lane=='Free'or state.premium==true)then
                local complete=claims[config.TrackId..':'..reward.Key]==true
                    and(not reward.SkinId or(state.skins or{})[reward.SkinId]==true)
                    and(not reward.EmoteId or(state.emotes or{})[reward.EmoteId]==true)
                if not complete then return true end
            end
        end
    end
    return false
end
function Core.freeCrateReady(state,receivedAt,now)
    return state and state.loaded==true and state.allowed==true and(tonumber(state.free)or 0)>0
        and type(state.token)=='string'and #state.token>0 and now-receivedAt>=0 and now-receivedAt<20 or false
end
function Core.consumableUseful(id,role,c)
    if id=='RescueKit'then return role=='Runner'and c.caught and c.rescue and not c.vow and not c.soulReap and not c.boss or false end
    if not c.active then return false end
    if id=='Adrenaline'then return not c.boosted and c.safeForward and(c.goalDistance or 0)>12
        and(role=='Runner'and c.pressured or role=='Catcher'and(c.targetDistance or 0)>14)or false end
    if id=='BananaPeel'then return c.grounded and c.castClear and(c.enemyBehind or role=='Catcher'and c.trapOpportunity)or false end
    if id=='Lifeline'then return role=='Runner'and c.lifelineTarget and c.castClear or false end
    return false
end
