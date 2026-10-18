-- slam properties
local SLAM_CRANK_THRESHOLD = 12 -- degrees per frame, backwards
local SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE = 20;
-- Slowing/stopping the crank often produces a brief backswing, so require the reverse to be
-- sustained and keep the stricter threshold for a short while after fluttering stops.
local SLAM_REVERSE_FRAMES = 2
local SLAM_FLUTTER_GRACE_FRAMES = 10
local SLAM_FREEZE_FRAMES = 12
local SLAM_SPEED = 16

local TILE_SIZE = 16
local SLAM_MIN_DISTANCE = 3 * TILE_SIZE
local SLAM_PROBE_LENGTH = 240
local gfx <const> = playdate.graphics


--- @class PlayerSlam
PlayerSlam = {}
class('PlayerSlam').extends()

function PlayerSlam:init(player)
    self.player = player

    -- slam state: nil, "freeze" or "drop"
    self.slamPhase = nil
    self.slamFreezeTimer = 0
    self.slamReverseFrames = 0
    self.slamFlutterGraceTimer = 0
    self.slamming = true
    self.powered = false

end

function PlayerSlam:isPowerSlamming()
    return self.slamPhase == "drop" and self.powered
end

-- Runs after handleState so it overrides any input/drag/gravity velocity changes.
function PlayerSlam:updateSlam(player, flutter)
    if not self.slamPhase then
        -- self.fluttering still holds last frame's value here (updateFlutterState runs later)
        if flutter.fluttering then
            self.slamFlutterGraceTimer = SLAM_FLUTTER_GRACE_FRAMES
        elseif self.slamFlutterGraceTimer > 0 then
            self.slamFlutterGraceTimer -= 1
        end

        local threshold = self.slamFlutterGraceTimer > 0 and SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE or SLAM_CRANK_THRESHOLD
        local airborne = (not player.grounded) and (not player.touchingGround)
        if airborne and IsCrankingBackFast(threshold) then
            self.slamReverseFrames += 1
        else
            self.slamReverseFrames = 0
        end

        if self.slamReverseFrames >= SLAM_REVERSE_FRAMES then
            self.slamReverseFrames = 0
            self.slamPhase = "freeze"
            self.slamFreezeTimer = SLAM_FREEZE_FRAMES
            flutter:cancelFlutterAndGlide()
            if player.currentState ~= "fall" then
                player:changeToFallState() -- change to fall/slam animation
            end
        else
            return
        end
    end

    if self.slamPhase == "freeze" then
        -- check if distance between ground and player is enough for full slam effects
        self.powered = self:distanceToGround() >= SLAM_MIN_DISTANCE
        player.xVelocity = 0
        player.yVelocity = 0
        self.slamFreezeTimer -= 1
        if self.slamFreezeTimer <= 0 then
            self.slamPhase = "drop"
        end
    else
        player.xVelocity = 0
        player.yVelocity = SLAM_SPEED
    end
end

function PlayerSlam:updateSlammingFlag(value)
    self.slamming = value
end

local function isGround(sprite)
    local tag = sprite:getTag()
    return tag ~= TAGS.Hazzard and tag ~= TAGS.Enemy and tag ~= TAGS.Pickup
end

function PlayerSlam:distanceToGround()
    local player = self.player
    -- getCollideBounds is relative to the sprite, so convert to world coordinates
    local rx, ry, bw, bh = player:getCollideBounds()
    local spriteX, spriteY = player:getBounds()
    local bx, by = spriteX + rx, spriteY + ry
    local bottom = by + bh
    local best = math.huge

    -- probe both feet so a ledge under one edge still counts
    for _, x in ipairs({ bx + 1, bx + bw - 1 }) do
        local hits = gfx.sprite.querySpriteInfoAlongLine(x, bottom, x, bottom + SLAM_PROBE_LENGTH)
        for _, info in ipairs(hits) do
            if info.sprite ~= player and isGround(info.sprite) then
                best = math.min(best, math.max(0, info.entryPoint.y - bottom))
                break -- results are sorted by distance, first ground hit is enough
            end
        end
    end
    return best
end