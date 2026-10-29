-- Temporary live diagnostic. Observes native movement; does not suppress guards.
local env=getgenv()
if env.HussSpeedTrial and env.HussSpeedTrial.Stop then env.HussSpeedTrial:Stop()end
local p=game.Players.LocalPlayer
local rs=game:GetService('RunService')
local session=game.ReplicatedStorage.ChickenOrHero.Game.Session
local config=env.HussSpeedTrialConfig or{}
local trial={results={},index=0,done=false,connections={},values=config.values or{1.25,1,1.05,1.1,1.15,1.2}}
env.HussSpeedTrial=trial
local previous
local function nextValue()
    trial.index=trial.index+1
    local value=trial.values[trial.index]
    if not value then
        trial.done=true
        for _,c in ipairs(trial.connections)do c:Disconnect()end
        local a=env.HussAutoCross;if a then a:SetSpeedMultiplier(1)end
        return
    end
    trial.current={multiplier=value,wall=0,moving=0,samples=0,backSnaps=0,largeResiduals=0,
        maxResidual=0,maxBackwards=0,maxActual=0,peakExpected=0,nearCap=0,resets=0,warnings={},events={},jumps={}}
    trial.results[#trial.results+1]=trial.current
    previous=nil
    env.HussAutoCross:SetSpeedMultiplier(value)
end
function trial:Stop()
    self.done=true
    for _,c in ipairs(self.connections)do c:Disconnect()end
    local a=env.HussAutoCross;if a then a:SetSpeedMultiplier(1)end
end
nextValue()
trial.connections[#trial.connections+1]=game.ReplicatedStorage.ChickenOrHero.Presentation.MovementGuardEvent.OnClientEvent:Connect(function(kind,data)
    local r=trial.current
    if r then
        r.events[#r.events+1]={kind=kind,data=data,at=r.wall}
        if kind=='Warning'then r.warnings[#r.warnings+1]=data end
    end
end)
trial.connections[#trial.connections+1]=rs.Heartbeat:Connect(function(dt)
    if trial.done then return end
    local r=trial.current;r.wall=r.wall+dt
    local a=env.HussAutoCross
    if not a or not a.Enabled then trial:Stop();return end
    if a.SpeedMultiplier~=r.multiplier then trial:Stop();return end
    local ch=p.Character;local root=ch and ch:FindFirstChild('HumanoidRootPart')
    local h=ch and ch:FindFirstChildOfClass('Humanoid')
    local active=p:GetAttribute('RunState')=='Active'and p:GetAttribute('InMatch')
        and not session:GetAttribute('MapChanging')and not session:GetAttribute('GlobalPaused')
    if root and h then
        local position=root.Position;local velocity=root.AssemblyLinearVelocity*Vector3.new(1,0,1)
        local reset=ch:GetAttribute('MovementReset')
        local phase=session:GetAttribute('Phase');local round=session:GetAttribute('RunNumber')
        local role=p:GetAttribute('GameRole')
        local forced=ch:GetAttribute('GearMotion')or ch:GetAttribute('TackleActive')or ch:GetAttribute('Ragdolled')
            or ch:GetAttribute('Burrowing')or ch:GetAttribute('MovementLocked')
        if previous and previous.character==ch and active and previous.active and not forced and not previous.forced
            and previous.phase==phase and previous.round==round and previous.role==role
            and dt<.12 and dt>.001 then
            if previous.reset~=reset then r.resets=r.resets+1 end
            local delta=(position-previous.position)*Vector3.new(1,0,1)
            local expected=(previous.velocity+velocity)*(.5*dt)
            local residual=(delta-expected).Magnitude
            r.samples=r.samples+1
            r.maxResidual=math.max(r.maxResidual,residual)
            if residual>3 then
                r.largeResiduals=r.largeResiduals+1
                if #r.jumps<20 then r.jumps[#r.jumps+1]={at=r.wall,residual=residual,phase=phase,round=round,
                    resetChanged=reset~=previous.reset,role=role,dt=dt}end
            end
            if previous.velocity.Magnitude>10 then
                local backwards=-delta:Dot(previous.velocity.Unit)
                r.maxBackwards=math.max(r.maxBackwards,backwards)
                if backwards>1.5 and residual>2 then r.backSnaps=r.backSnaps+1 end
            end
            if velocity.Magnitude>10 and h.MoveDirection.Magnitude>.3 then
                r.moving=r.moving+dt
                local speed=a:SpeedReport()
                r.peakExpected=math.max(r.peakExpected,speed.applied)
                r.maxActual=math.max(r.maxActual,velocity.Magnitude)
                if velocity.Magnitude>=speed.applied*.95 then r.nearCap=r.nearCap+dt end
            end
        end
        previous={character=ch,position=position,velocity=velocity,reset=reset,active=active,forced=forced,phase=phase,round=round,role=role}
    else previous=nil end
    if r.moving>=(config.movingSeconds or 12) or r.wall>=(config.wallSeconds or 90) or #r.warnings>0 then
        r.sufficient=r.moving>=(config.movingSeconds or 12)
        nextValue()
    end
end)
return {started=true,current=trial.current.multiplier,values=trial.values}
