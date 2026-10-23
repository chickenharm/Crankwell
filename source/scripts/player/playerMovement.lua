local pd <const> = playdate
local gfx <const> = playdate.graphics

local MAX_RUN_SPEED = 2.5

--- @class PlayerMovement
PlayerMovement = {}
class('PlayerMovement').extends()

function PlayerMovement:init(player)
    self.player = player
    self.maxSpeed = MAX_RUN_SPEED

end

function PlayerMovement:changeToRunState(direction, player)
    if direction == "left" then
        player.xVelocity = -self.maxSpeed
        player.globalFlip = 1
    elseif direction == "right" then
        player.xVelocity = self.maxSpeed
        player.globalFlip = 0
    end
    player:changeStateToRun()
end


function PlayerMovement:handleAirInput(player)
    if pd.buttonIsPressed(pd.kButtonLeft) then
        player.xVelocity = -self.maxSpeed
        if not player.grounded then
            player.globalFlip = 1
        end
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        player.xVelocity = self.maxSpeed
         if not player.grounded then
            player.globalFlip = 0
        end
    end
end

-- input helper functions
function PlayerMovement:handleGroundInput(player)
    if pd.buttonJustPressed(pd.kButtonUp) then
        player:changeToJumpState()
    elseif player.jumpBufferTimer > 0 then
        player.jumpBufferTimer -= 1
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        self:changeToRunState("left", player)
    elseif pd.buttonIsPressed(pd.kButtonRight) then
        self:changeToRunState("right", player)
    else
        player:changeToIdleState()
    end
end
