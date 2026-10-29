return function(Core)
    local n=0
    local function check(ok,message)assert(ok,message);n=n+1 end
    local base=table.freeze({MaxSpeed=37.1439264,Acceleration=60,Deceleration=72,StopThreshold=.2,
        Dash=table.freeze({Distance=12,Duration=.28,Cooldown=1.1})})
    local scaled=Core.scaleSpeedProfile(base,1.25)
    check(math.abs(scaled.MaxSpeed-46.429908)<1e-6,'must apply 1.25 to the fully resolved speed')
    check(base.MaxSpeed==37.1439264 and base.Dash.Distance==12,'must preserve native cached profiles')
    check(scaled.Acceleration==60 and scaled.Deceleration==72,'speed slider must preserve native acceleration and braking')
    check(scaled.Dash==base.Dash,'speed slider must preserve native dash distance and timing')
    check(Core.scaleSpeedProfile({MaxSpeed=20,Acceleration=30,Deceleration=40},1.25).MaxSpeed==25,'must handle profile without dash')
    check(Core.scaleSpeedProfile({MaxSpeed=0,Acceleration=0,Deceleration=0},1.25).MaxSpeed==0,'zero speed must remain zero')
    check(Core.speedMultiplier(0)==1 and Core.speedMultiplier(3)==2,'slider must clamp to 1x through 2x')
    check(Core.speedMultiplier(1.23)==1.25 and Core.speedMultiplier(1.21)==1.2,'slider must snap to 0.05 steps')
    for step=0,20 do
        check(math.abs(Core.speedMultiplier(1+step*.05)-(1+step*.05))<1e-9,'must represent all 21 slider positions')
    end
    return {passed=n}
end
