-- Display native player-list values without changing the player or game state.
local function createUserStatus(player,clock)
    local status={nextAt=0}
    function status:Read()
        local now=clock()
        if not self.snapshot or now>=self.nextAt then
            local folder=player:FindFirstChild('leaderstats')
            local function value(name)
                local object=folder and folder:FindFirstChild(name)
                local number=object and object:IsA('ValueBase')and object.Value or player:GetAttribute(name)
                if type(number)=='number'and number==number and number>=0 and number<math.huge then return math.floor(number)end
            end
            local role=player:GetAttribute('GameRole')
            self.snapshot={username=player.Name,userId=player.UserId,level=value('Level'),wins=value('Wins'),
                catches=value('Catches'),lms=value('LMS'),role=role=='Catcher'and'Chaser'or role or'Unknown'}
            self.nextAt=now+1
        end
        return table.clone(self.snapshot)
    end
    function status:Text()
        local r=self:Read()
        local function number(v)return v~=nil and tostring(v)or'—'end
        return string.format('Level: %s  |  Role: %s\nWins: %s  |  Catches: %s\nLMS (Last Man Standing): %s',
            number(r.level),r.role,number(r.wins),number(r.catches),number(r.lms))
    end
    function status:Thumbnail()
        return 'rbxthumb://type=AvatarHeadShot&id='..tostring(player.UserId)..'&w=150&h=150'
    end
    return status
end
runner.userStatus=createUserStatus(player,os.clock)
function api:UserReport()return runner.userStatus:Read()end
