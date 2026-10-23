local pd <const> = playdate
local gfx <const> = playdate.graphics

local MAX_RUN_SPEED = 2.5

local AIR_ACCEL = 0.35
local AIR_DRAG = 0.4
local AIR_TURN_BRAKE = 0.6        -- extra braking when reversing direction
local FLUTTER_ACCEL = 0.15
local FLUTTER_DRAG = 0.5
local FLUTTER_MAX_SPEED = 1.5

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
    local dir = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then dir = -1
    elseif pd.buttonIsPressed(pd.kButtonRight) then dir = 1 end

    local fluttering = player.flutter.fluttering
    local accel = fluttering and FLUTTER_ACCEL or AIR_ACCEL
    local drag = fluttering and FLUTTER_DRAG or AIR_DRAG
    local maxSpeed = fluttering and FLUTTER_MAX_SPEED or self.maxSpeed

    if dir ~= 0 then
        if not player.grounded then
            player.globalFlip = (dir < 0) and 1 or 0
        end
        -- reversing: brake first so the turn isn't instant
        if player.xVelocity ~= 0 and (player.xVelocity > 0) ~= (dir > 0) then
            player:applyDrag(AIR_TURN_BRAKE)
        end
        player.xVelocity = math.max(-maxSpeed, math.min(maxSpeed, player.xVelocity + dir * accel))
    else
        player:applyDrag(drag)
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
