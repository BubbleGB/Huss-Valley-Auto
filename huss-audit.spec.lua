return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local start=Vector3.zero
    check(Core.isRunner(true,'Runner','Active',100,true,false,false),'a trapped human runner remains catchable under the native contact sampler')
    check(not Core.isRunner(true,'Runner','Active',100,true,true,false),'movement-locked client bots are excluded by native victim sampling')
    check(not Core.isRunner(true,'Runner','Active',100,false,false,true),'anchored runners must be excluded')
    local function allowed(a,b)return math.abs(b.X)<=60 and math.abs(b.Z)<=40 end
    local function strip(p)return p.X>3 and p.X<7 and math.abs(p.Z)<2 and 100 or 0 end
    local path=Core.route(start,{Vector3.new(10,0,0)},8,allowed,strip,400)
    local detour=false
    for _,p in ipairs(path or{})do if math.abs(p.Z)>3 then detour=true end end
    check(detour,'final goal connection must pay risk instead of bypassing a safer detour')
    path=Core.route(start,{Vector3.new(10,0,0),Vector3.new(0,0,8)},8,allowed,function()return 0 end,400)
    check(path and path[#path]==Vector3.new(0,0,8),'must choose the cheaper finish rather than the first reachable goal')
    path=Core.route(start,{Vector3.new(32,0,0)},8,allowed,strip,400)
    detour=false
    for _,p in ipairs(path or{})do if math.abs(p.Z)>3 then detour=true end end
    check(detour,'risk between grid vertices must count on regular edges')
    local evaluated,duplicates={},0
    path=Core.route(start,{Vector3.new(48,0,0)},8,allowed,function(p)
        local key=string.format('%.5f:%.5f',p.X,p.Z)
        if evaluated[key]then duplicates=duplicates+1 end
        evaluated[key]=true
        return strip(p)
    end,400)
    check(path and duplicates==0,'a route search must reuse stable risk samples instead of rescanning threats for shared vertices')
    local label=Instance.new('TextLabel');label.Active=true
    check(Core.blocksTouch(label),'active text labels can receive drag input')
    label.Active=false
    check(not Core.blocksTouch(label),'decorative text must not block an otherwise empty touch point')
    local frame=Instance.new('Frame');frame.Active=true;label.Parent=frame
    check(Core.blocksTouch(label),'active ancestors must also block injected touches')
    frame.Visible=false
    check(not Core.blocksTouch(label),'hidden ancestors do not intercept input')
    frame:Destroy()
    local records={}
    local function soul(victim,position,taken)
        local r=Instance.new('Configuration');r:SetAttribute('Victim',victim);r:SetAttribute('Body',position)
        r:SetAttribute('TakeBy',taken);records[#records+1]=r;return r
    end
    soul(20,Vector3.new(10,0,0));soul(21,Vector3.new(12,0,0),30);soul(10,Vector3.new(1,0,0))
    local context=Core.soulContext('31,32',records,10,start,35)
    check(context.souls==2 and context.soulsNearby,'Soul Reap must read native CSV capacity and unclaimed soul records')
    records[1]:SetAttribute('TakeBy',22)
    context=Core.soulContext('31,bad,32,33',records,10,start,35)
    check(context.souls==3 and not context.soulsNearby,'claimed souls and own soul must not trigger a wasted cast')
    records[1]:SetAttribute('TakeBy',nil);records[1]:SetAttribute('Body',Vector3.new(100,0,0))
    check(not Core.soulContext(nil,records,10,start,35).soulsNearby,'distant souls must not trigger a cast')
    for _,r in ipairs(records)do r:Destroy()end
    local shieldActor=Instance.new('Folder');local character=Instance.new('Model')
    character:SetAttribute('HitShielded',true)
    check(Core.abilityState(shieldActor,character,10).shielded,'native hit shield remains recognized')
    shieldActor:Destroy();character:Destroy()
    return {passed=n}
end
