local pd <const> = playdate
local gfx <const> = playdate.graphics

local MAX_RUN_SPEED = 3
local RUN_ACCEL = 0.25   -- per frame; ~17 frames to reach MAX_RUN_SPEED from standstill
local RUN_DECEL = 0.4    -- per frame; used when no input or reversing
local RUN_REDUCE = 0.32   -- decel when above max speed with input in the same direction
local AIR_MULT = 0.65

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

local function approach(value, target, amount)
    if value < target then
        return math.min(value + amount, target)
    else
        return math.max(value - amount, target)
    end
end

local function getInputDir()
    if pd.buttonIsPressed(pd.kButtonLeft) then return -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then return 1 end
    return 0
end


-- The one function that does Celeste-style horizontal movement
function PlayerMovement:applyHorizontal(player, dir, mult)
    local vx = player.xVelocity
    local sameDir = (vx > 0 and dir > 0) or (vx < 0 and dir < 0)
    local accel = RUN_ACCEL * mult
    if vx ~= 0 and not sameDir then
        accel = RUN_DECEL * mult
    elseif math.abs(vx) > self.maxSpeed then
        accel = RUN_REDUCE * mult
    end
    player.xVelocity = approach(vx, dir * self.maxSpeed, accel)
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
                self:applyHorizontal(player, dir, AIR_MULT)
            end
        end
    else
        if dir ~= 0 then
            self:applyHorizontal(player, dir, AIR_MULT)
        end
    end
end

function PlayerMovement:handleGroundInput(player)
    local dir = getInputDir()
    if dir ~= 0 then
        player.globalFlip = (dir < 0) and 1 or 0
    end

    self:applyHorizontal(player, dir, 1)

    if pd.buttonJustPressed(pd.kButtonUp) then
        player:changeToJumpState()
        return
    end
    if player.jumpBufferTimer > 0 then
        player.jumpBufferTimer -= 1
    end

    if dir ~= 0 or player.xVelocity ~= 0 then
        player:changeStateToRun()
    else
        player:changeToIdleState()
    end
end
