function pumpkin.threats()
    local folder=gameState:FindFirstChild('PumpkinPeople')
    local configModule=gameState:FindFirstChild('PumpkinHuntConfig')
    if not folder or not configModule then return {} end
    local config=require(configModule).People
    local result,seen={},{}
    local now=os.clock()
    for _,record in ipairs(folder:GetChildren())do
        local position=record:GetAttribute('P')
        if typeof(position)=='Vector3'then
            local sample=Core.observeMotion(pumpkin.samples[record],position,now,Vector3.zero)
            pumpkin.samples[record]=sample;seen[record]=true
            local enemy=Core.pumpkinThreat({id=record.Name,position=position,yaw=record:GetAttribute('Yaw'),
                state=record:GetAttribute('State'),velocity=sample.velocity},config)
            if enemy then result[#result+1]=enemy end
        end
    end
    for record in pairs(pumpkin.samples)do if not seen[record]then pumpkin.samples[record]=nil end end
    return result
end

