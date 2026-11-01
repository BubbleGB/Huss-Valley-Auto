-- Compatibility adapter for the unchanged, pinned WindUI 1.6.66 asset.
-- Exact anchors and connection inventory fail closed before any library code executes.
local function prepareWindUI(source)
    assert(type(source)=='string'and #source==274078,'WindUI pinned source size mismatch')
    local function replace(old,new,count)
        local found,from,parts=0,1,{}
        while true do
            local first,last=source:find(old,from,true)
            if not first then break end
            found=found+1;parts[#parts+1]=source:sub(from,first-1);parts[#parts+1]=new;from=last+1
        end
        assert(found==count,'WindUI compatibility anchor mismatch: '..old)
        parts[#parts+1]=source:sub(from);source=table.concat(parts)
    end
    replace([=[N.InputBegan:Connect(]=],[=[HussWindSignal(N.InputBegan,]=],1)
    replace([=[end

e.InputChanged:Connect(]=],[=[end

HussWindSignal(e.InputChanged,]=],1)
    replace([=[end)

e.InputEnded:Connect(]=],[=[end)

HussWindSignal(e.InputEnded,]=],1)
    replace([=[ak:GetPropertyChangedSignal"CFrame":Connect(]=],[=[HussWindSignal(ak:GetPropertyChangedSignal("CFrame"),]=],1)
    replace([=[ak:GetPropertyChangedSignal"ViewportSize":Connect(]=],[=[HussWindSignal(ak:GetPropertyChangedSignal("ViewportSize"),]=],1)
    replace([=[ak:GetPropertyChangedSignal"FieldOfView":Connect(]=],[=[HussWindSignal(ak:GetPropertyChangedSignal("FieldOfView"),]=],1)
    replace([=[aj.Destroying:Connect(]=],[=[HussWindSignal(aj.Destroying,]=],1)
    replace([=[ac.InputChanged:Connect(]=],[=[HussWindSignal(ac.InputChanged,]=],1)
    replace([=[ac.InputEnded:Connect(]=],[=[HussWindSignal(ac.InputEnded,]=],3)
    replace([=[ae.InputChanged:Connect(]=],[=[HussWindSignal(ae.InputChanged,]=],1)
    replace([=[ae.InputEnded:Connect(]=],[=[HussWindSignal(ae.InputEnded,]=],1)
    replace([=[ad.RenderStepped:Connect(]=],[=[HussWindSignal(ad.RenderStepped,]=],1)
    replace([=[ac.InputBegan:Connect(]=],[=[HussWindSignal(ac.InputBegan,]=],1)
    replace([=[ak.InputChanged:Connect(]=],[=[HussWindSignal(ak.InputChanged,]=],1)
    replace([=[az.UIElements.SatVibMap.InputBegan:Connect(]=],[=[HussWindSignal(az.UIElements.SatVibMap.InputBegan,]=],1)
    replace([=[x.InputBegan:Connect(]=],[=[HussWindSignal(x.InputBegan,]=],1)
    replace([=[J.InputBegan:Connect(]=],[=[HussWindSignal(J.InputBegan,]=],1)
    replace([=[ak.InputEnded:Connect(]=],[=[HussWindSignal(ak.InputEnded,]=],1)
    replace([=[at.Outline.Top:GetPropertyChangedSignal"AbsoluteSize":Connect(]=],[=[HussWindSignal(at.Outline.Top:GetPropertyChangedSignal("AbsoluteSize"),]=],1)
    replace([=[ai.Move:Connect(]=],[=[HussWindSignal(ai.Move,]=],1)
    replace([=[an.InputBegan:Connect(]=],[=[HussWindSignal(an.InputBegan,]=],1)
    replace([=[an.InputEnded:Connect(]=],[=[HussWindSignal(an.InputEnded,]=],1)
    replace([=[function r.AddSignal(u,v)
local x=u:Connect(v)
table.insert(r.Signals,x)
return x
end]=],[=[HussWindOwner.Creator=r
function r.AddSignal(u,v)
local x=u:Connect(v)
if HussWindOwner.Closed then x:Disconnect() else table.insert(r.Signals,x) end
return x
end]=],1)
    replace([=[for u,v in next,r.Signals do
local x=table.remove(r.Signals,u)
x:Disconnect()
end]=],[=[for u=#r.Signals,1,-1 do
local x=table.remove(r.Signals,u)
x:Disconnect()
end]=],1)
    local _,remaining=source:gsub(':Connect%(', '')
    assert(remaining==1,'WindUI unreviewed connection inventory')
    local owner={Closed=false}
    function owner:Cleanup()
        self.Closed=true
        if self.Creator then self.Creator.DisconnectAll()end
    end
    return 'local HussWindOwner=...\nlocal function HussWindSignal(signal,callback)return HussWindOwner.Creator.AddSignal(signal,callback)end\n'..source,owner
end
