return function(source)
 local first=assert(source:find('local function createVisualPerformance(services)',1,true),'visual performance factory missing')
 local last=assert(source:find('runner.createVisualPerformance=createVisualPerformance',first,true))
 local make=assert(loadstring(source:sub(first,last-1)..'\nreturn createVisualPerformance'))()
 local count=0;local function check(v,m)assert(v,m);count=count+1 end
 local function instance(class,name,parent)local v=Instance.new(class);v.Name=name;v.Parent=parent;return v end
 local world=instance('Folder','AuditVisualWorld')
 local localCharacter=instance('Model','Local',world);local localPart=instance('Part','Body',localCharacter)
 local other=instance('Model','Other',world);local body=instance('Part','Body',other);body.LocalTransparencyModifier=.25
 local human=instance('Humanoid','Humanoid',other);local distance=human.DisplayDistanceType
 local title=instance('BillboardGui','Nameplate',body)
 local warningRoot=instance('Folder','ValleyGearTraps',other);local warningPart=instance('Part','Warning',warningRoot)
 local warningGui=instance('BillboardGui','WarningLabel',warningPart)
 local cosmetic=instance('Part','Decoration',world);local particle=instance('ParticleEmitter','Dust',cosmetic)
 local disabled=instance('ParticleEmitter','AlreadyDisabled',cosmetic);disabled.Enabled=false
 local trap=instance('Folder','ValleyGearTraps',world);local hazard=instance('Part','Trap',trap);local warning=instance('ParticleEmitter','Warning',hazard)
 local pickups=instance('Folder','LocalRunnerGems',world);local gem=instance('Part','Gem',pickups);gem.CanTouch=true
 local coin=instance('Folder','LocalRunnerCandyCorn',world);local corn=instance('Part','Corn',coin)
 local protection=Instance.new('BindableEvent')
 local now=0;local characters={other};local p=make({world=world,clock=function()return now end,
  protected=function(object)return object:GetAttribute('GameplayWarning')end,
  protectedSignals=function()return{protection.Event}end,
  localCharacter=function()return localCharacter end,otherCharacters=function()return characters end})
 local function flush()for _=1,100 do p:Tick();if p:Report().pending==0 then break end end end
 check(p:Report().scans==0 and p:Report().hidden==0,'default-off controller does not scan or hide')
 p:Configure({HideParticles=true});flush()
 check(not particle.Enabled and not disabled.Enabled,'ambient particles disabled')
 check(warning.Enabled,'trap warning remains visible')
 particle.Enabled=true;task.wait();check(not particle.Enabled,'native effect updates remain suppressed while enabled')
 p:Configure({HideParticles=false});flush();check(particle.Enabled and not disabled.Enabled,'native and original effect values restored')
 p:Configure({HideOtherPlayers=true});flush()
 check(body.LocalTransparencyModifier==1 and localPart.LocalTransparencyModifier==0,'only other avatars hidden')
 check(human.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None and not title.Enabled,'other nameplates hidden')
 check(warningPart.LocalTransparencyModifier==0 and warningGui.Enabled,'avatar-attached gameplay geometry and warnings remain visible')
 check(body.CanCollide and body.Parent==other,'physical object and detection hierarchy untouched')
 local newPart=instance('Part','AccessoryPart',other);task.wait();flush();check(newPart.LocalTransparencyModifier==1,'new avatar visuals are handled')
 body.LocalTransparencyModifier=.6;task.wait();check(body.LocalTransparencyModifier==1,'native transparency updates remain hidden')
 p:Configure({HideGemsCurrency=true,HideOtherPlayers=true});flush()
 check(gem.LocalTransparencyModifier==1 and corn.LocalTransparencyModifier==1 and gem.CanTouch,'pickup visuals hidden without changing touch state')
 check(gem.Parent==pickups and corn.Parent==coin,'collection objects remain detectable')
 p:Configure({HideOtherPlayers=false,HideGemsCurrency=true});flush()
 check(math.abs(body.LocalTransparencyModifier-.6)<.001 and title.Enabled and human.DisplayDistanceType==distance,'latest native avatar properties restored')
 local newOther=instance('Model','Respawn',world);local respawn=instance('Part','Body',newOther);characters={newOther}
 p:Configure({HideOtherPlayers=true,HideGemsCurrency=true});flush();check(respawn.LocalTransparencyModifier==1,'replacement characters are handled')
 p:Configure({HideParticles=true,HideGemsCurrency=true});flush()
 cosmetic:SetAttribute('GameplayWarning',true);protection:Fire(cosmetic);task.wait();flush();check(particle.Enabled,'late gameplay protection restores a hidden effect')
 cosmetic:SetAttribute('GameplayWarning',false);protection:Fire(cosmetic);task.wait();flush();check(not particle.Enabled,'removed protection resumes cosmetic suppression')
 local added=instance('ParticleEmitter','NewDust',cosmetic);task.wait();flush();check(not added.Enabled,'new ambient effects are handled')
 added.Parent=hazard;task.wait();flush();check(added.Enabled,'effect moved into hazard hierarchy is restored')
 added.Parent=cosmetic;task.wait();flush();check(not added.Enabled,'formerly protected effect moved to ambient is reconsidered')
 local prior=gem.LocalTransparencyModifier;p:Destroy()
 check(gem.LocalTransparencyModifier==0 and corn.LocalTransparencyModifier==0 and particle.Enabled,'unload restores owned visuals')
 check(p:Report().hidden==0 and p:Report().pending==0,'unload releases records and pending work')
 check(prior==1,'test exercised pickup hiding')
 world:Destroy();protection:Destroy()
 return {passed=count}
end
