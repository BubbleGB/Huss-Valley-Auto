return function(source)
 local first=assert(source:find('local function createPromptInputs(services)',1,true),'native prompt input factory missing')
 local last=assert(source:find('runner.createPromptInputs=createPromptInputs',first,true))
 local make=assert(loadstring(source:sub(first,last-1)..'\nreturn createPromptInputs'))()
 local root=Instance.new('Folder');local count=0;local function check(v,m)assert(v,m);count=count+1 end
 local function node(class,name,parent)local v=Instance.new(class);v.Name=name;v.Parent=parent;return v end
 local vote=node('ScreenGui','MapVoteUI',root);local ballot=node('Frame','Ballot',vote);local maps=node('Frame','Maps',ballot)
 local card=node('TextButton','Map2',maps);card.Active=true
 local notifications=node('ScreenGui','Notifications',root);local main=node('Frame','MainFrame',notifications);local choices=node('Frame','Choices',main)
 local picker=node('Frame','PlayerPicker',choices);local options=node('Frame','Options',picker);local runner=node('TextButton','Player_123',options);runner.Active=true
 local roles=node('Frame','RunnerChoice',choices);local roleOptions=node('Frame','Options',roles);local hero=node('TextButton','Hero',roleOptions);hero.Active=true
 local chicken=node('TextButton','Chicken',roleOptions);chicken.Active=true
 local touches={};local enabled=true
 local p=make({playerGui=root,enabled=function()return enabled end,input={Tap=function(_,object)touches[#touches+1]=object;return true end}})
 check(p:Send('Vote','Map2')and touches[#touches]==card,'map vote uses exact native card')
 check(not p:Send('Vote','Map9'),'missing map never guesses another control')
 check(p:Send('SelectHero',123)and touches[#touches]==runner,'runner selection uses exact native identity')
 check(p:Send('HeroChoice','Hero')and touches[#touches]==hero,'native Hero choice')
 check(p:Send('HeroChoice','Chicken')and touches[#touches]==chicken,'native Chicken choice')
 choices.Visible=false;check(not p:Send('HeroChoice','Hero'),'hidden choice panel defers input');choices.Visible=true
 enabled=false;check(not p:Send('Vote','Map2'),'stop prevents native prompt input');enabled=true
 local before=#touches;check(not p:Send('HeroChoice','Buy')and not p:Send('Purchase',123)and #touches==before,'unknown actions cannot trigger purchases')
 local close=node('TextButton','Close',ballot);close.Active=true
 check(not p:DismissVote({votes={}},123,'Map2'),'unconfirmed ballot stays open')
 check(not p:DismissVote({votes={['123']='Map7'}},123,'Map2'),'different vote cannot confirm this request')
 check(p:DismissVote({votes={['123']='Map2'}},123,'Map2')and touches[#touches]==close,'confirmed vote uses native close')
 local summary=node('ScreenGui','MatchSummaryUI',root);local holder=node('Frame','HolderFrame',summary)
 local result=node('Frame','MatchResult',holder);local header=node('Frame','Header',result);local dismiss=node('TextButton','CloseButton',header);dismiss.Active=true
 check(p:DismissResults()and touches[#touches]==dismiss,'results use only native close')
 result.Visible=false;check(not p:DismissResults(),'hidden results are untouched');result.Visible=true
 enabled=false;check(not p:DismissResults()and not p:DismissVote({votes={['123']='Map2'}},123,'Map2'),'stop prevents popup dismissal')
 root:Destroy();return {passed=count}
end
