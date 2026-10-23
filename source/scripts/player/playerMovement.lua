local pd <const> = playdate
local gfx <const> = playdate.graphics

local MAX_RUN_SPEED = 2.5

local FLUTTER_ACCEL = 0.15
local FLUTTER_DRAG = 0.4
local FLUTTER_MAX_SPEED = 1.5
local FLUTTER_TURN_BRAKE = 0.5

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

-- handle air movement with horizontal friction when fluttering
function PlayerMovement:handleAirInput(player)
    local dir = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then dir = -1
    elseif pd.buttonIsPressed(pd.kButtonRight) then dir = 1 end

    if dir ~= 0 and not player.grounded then
        player.globalFlip = (dir < 0) and 1 or 0
    end

    if player.flutter.fluttering then
        if dir == 0 then
            -- no input: bleed off speed
            player:applyDrag(FLUTTER_DRAG)
        else
            -- reversing: brake first so the turn isn't instant
            if player.xVelocity ~= 0 and (player.xVelocity > 0) ~= (dir > 0) then
                player:applyDrag(FLUTTER_TURN_BRAKE)
            end
            if math.abs(player.xVelocity) > FLUTTER_MAX_SPEED then
                -- entered flutter faster than the cap: slow down gradually
                player:applyDrag(FLUTTER_DRAG)
            else
                player.xVelocity = math.max(-FLUTTER_MAX_SPEED,
                math.min(FLUTTER_MAX_SPEED, player.xVelocity + dir * FLUTTER_ACCEL))
            end
        end
    else
        -- original behavior: snap to max speed
        if dir ~= 0 then
            player.xVelocity = dir * self.maxSpeed
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
