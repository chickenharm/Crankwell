-- slam properties
local SLAM_CRANK_THRESHOLD = 12 -- degrees per frame, backwards
local SLAM_CRANK_THRESHOLD_WHILE_IN_OTHER_STATE = 20;
-- Slowing/stopping the crank often produces a brief backswing, so require the reverse to be
-- sustained and keep the stricter threshold for a short while after fluttering stops.
local SLAM_REVERSE_FRAMES = 2
local SLAM_FLUTTER_GRACE_FRAMES = 10
local SLAM_FREEZE_FRAMES = 12
local SLAM_SPEED = 16


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
        else
            return
        end
    end

    if self.slamPhase == "freeze" then
        self.xVelocity = 0
        self.yVelocity = 0
        self.slamFreezeTimer -= 1
        if self.slamFreezeTimer <= 0 then
            self.slamPhase = "drop"
        end
    else
        player.xVelocity = 0
        player.yVelocity = SLAM_SPEED
    end
end

function Player:updateSlammingFlag(value)
    self.slamming = value
end