-- Native service closures with fake remotes; never claims rewards or equips live items.
return function(source)
 local marker=assert(source:find('-- Runtime',1,true))
 local Core=assert(loadstring(source:sub(1,marker-1)..'\nreturn Core'))()
 local first=assert(source:find('local progression={',marker,true))
 local last=assert(source:find('local function activeRunner(p)',first,true))
 local opFirst=assert(source:find('local function createOperationStatus(',1,true))
 local opLast=assert(source:find('runner.operation=createOperationStatus',opFirst,true))
 local fixture=source:sub(opFirst,opLast-1)..'\n'..[[
return function(Core)
 local now=0
 local os={clock=function()return now end}
 local requests={}
 local remote={OnClientEvent={}}
 function remote:FireServer(...)requests[#requests+1]={...}end
 local journey={SeasonId='s',TrackId='t',Rewards={{Free={Key='a'}}}}
 local catalog={Crates={Basic={}}}
 local function folder(fields)function fields:FindFirstChild()return remote end;return fields end
 local package={Progression=folder({JourneyConfig=journey}),Crates=folder({CrateCatalog=catalog}),Weapons={ArmoryEvent=remote}}
 function package:FindFirstChild()return remote end
 local function require(v)return v end
 local api={Enabled=true,StopEverything=false,Settings=Core.defaultSettings()}
 function api:SetSetting(k,v)self.Settings[k]=v end
 local runner={operation=createOperationStatus(function()return now end,function(id)return id end)}
 local items={Shield={Kind='Ability',Name='Shield',UseRole='Runner'},Trap={Kind='Ability',Name='Trap',UseRole='Catcher'},Adrenaline={Kind='Item',Name='Adrenaline'}}
 local gearItems=items
 local gearCatalog={get=function(id)return items[id]end,equippedForRole=function(a,role)return(a.equippedAbilities or{})[role]or''end}
 local armory={loaded=true,abilities={Shield=true,Trap=true},gear={Adrenaline=2},equippedAbilities={Runner='Shield',Catcher='Trap'}}
 local attrs={ClientReady=true,InMatch=false}
 local player={GetAttribute=function(_,name)return attrs[name]end}
 local session={GetAttribute=function()return false end}
 local Input={GetFocusedTextBox=function()return nil end};local GuiService={MenuIsOpen=false}
 local RunService={Heartbeat={}}
 local function connect()end
]]..source:sub(first,last-1)..[[
 local n=0;local function check(v,m)assert(v,m);n=n+1 end
 api:SelectEquipment('Consumable','Adrenaline');progression:tick(now)
 check(#requests==1 and requests[1][1]=='EquipGear'and requests[1][2]=='Adrenaline','owned selection equips')
 check(runner.operation:Read(true,false).description:find('awaiting confirmation',1,true),'equip dispatch remains pending')
 progression:finishOperation('equip','State',{loaded=false,equippedGear='Adrenaline'})
 check(runner.operation:Read(true,false).description:find('awaiting confirmation',1,true),'unloaded inventory cannot confirm equipment')
 now=9;progression:tick(now);check(#requests==2 and requests[2][1]=='Get','lost equip reply refreshes inventory instead of toggling off')
 armory=table.clone(armory);armory.equippedGear='Adrenaline';now=12;progression:tick(now);check(#requests==2,'confirmed equipment not toggled off')
 progression:finishOperation('equip','State',armory)
 check(runner.operation:Read(true,false).description=='Equipped Adrenaline','native equipment confirmation updates status')
 check(not pcall(api.SelectEquipment,api,'Runner','Missing'),'unowned selection rejected')
 api.Settings.RunnerEquipment='Shield';armory.equippedAbilities.Runner='';api.Enabled=false;api.StopEverything=true
 now=20;progression:tick(now);check(#requests==2,'stop blocks queued equip')
 api.Enabled=true;api.StopEverything=false;attrs.InMatch=true;now=21;progression:tick(now);check(#requests==2,'match defers equip')
 attrs.InMatch=false;armory.equippedAbilities.Runner='Shield'
 api.Settings.AutoJourney=true;now=22;progression:tick(now);check(requests[#requests][1]=='Get','journey requests state')
 progression:receive('journey','State',{loaded=true,seasonId='s',tier=1,claims={}})
 now=25;progression:tick(now);check(requests[#requests][1]=='ClaimAll'and requests[#requests][3]=='s','claim earned native season')
 api.Settings.AutoJourney=false;api.Settings.AutoSpins=true
 progression:receive('spin','State',{credits=1,nextFreeAt=9999});now=38;progression:tick(now)
 check(requests[#requests][1]=='Spin','available credits use native spin')
 check(runner.operation:Read(true,false).description:find('Spinning',1,true),'spinning only after native dispatch')
 progression:receive('spin','State',{credits=0,result={id='fixture'}})
 check(runner.operation:Read(true,false).description=='Spin result received','native spin result ends pending status')
 api.Settings.AutoSpins=false;api.Settings.AutoCrates=true
 progression:receive('crate','State',{crate='Basic',loaded=true,allowed=true,free=1})
 now=54;progression:tick(now);check(requests[#requests][1]=='Open','free allocation obtains native token before opening')
 progression:receive('crate','State',{crate='Basic',loaded=true,allowed=true,free=1,token='owned-token'})
 now=57;progression:tick(now);check(requests[#requests][1]=='OpenFree'and requests[#requests][3]=='owned-token','free crate uses server token')
 check(runner.operation:Read(true,false).description:find('Opening Basic',1,true),'opening crate label')
 progression:receive('crate','Result',{crate='Basic'})
 check(runner.operation:Read(true,false).description:find('Opening Basic',1,true),'malformed crate result cannot claim completion')
 progression:receive('crate','Result',{crate='Basic',id='fixture'})
 check(runner.operation:Read(true,false).description=='Opened Basic','native crate result ends pending status')
 now=74;progression:tick(now);check(requests[#requests][1]=='Get','consumed token not reused')
 progression:receive('crate','State',{crate='Basic',loaded=true,allowed=true,free=0,token='no-free'})
 local count=#requests;now=77;progression:tick(now);check(#requests==count,'no free means no purchase')
 api.Enabled=false;now=100;progression:tick(now);check(#requests==count,'stop blocks all rewards')
 for _,request in ipairs(requests)do check(request[1]~='Prompt'and request[1]~='BuyGems'and request[1]~='PurchaseIntent','never purchase')end
 return {passed=n}
end
]]
 return assert(loadstring(fixture))()(Core)
end
