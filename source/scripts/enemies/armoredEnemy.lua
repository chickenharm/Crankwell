
---@class ArmoredEnemy : PatrolEnemy
ArmoredEnemy = {}
class("ArmoredEnemy").extends(PatrolEnemy)

ArmoredEnemy.ARMORED_ENEMY_SHEET = "images/enemies/armoredEnemy/armored-enemy-table-16-16"

ArmoredEnemy.STUN_FRAMES = 45  -- ~1.5s at Playdate's default 30 fps

ArmoredEnemy.RECOVERY_PAUSE_FRAMES = 8  -- ~0.25s at 30 fps


function ArmoredEnemy:init(x, y, entity)
    ArmoredEnemy.super.init(self, x, y, entity, ArmoredEnemy.ARMORED_ENEMY_SHEET)
    self.jumpProtected = true
end

function ArmoredEnemy:stun(frames, wasSlam)
    ArmoredEnemy.super.stun(self, frames)
    self.recovering = false
    self.recoveryPauseFrames = 0   -- cancel any pause in progress
    self.stunnedFromSlam = wasSlam == true
    if wasSlam then
        self:changeState("stunnedFromSlam")
    else
        self:changeState("stunned")
    end
end

function ArmoredEnemy:recoverFromStun()
    self.stunFrames = 0
    self.recovering = true
    if self.stunnedFromSlam then
        self:changeState("recoveringFromSlam")
    else
        self:changeState("recovering")
    end
end

function ArmoredEnemy:beginRecoveryPause()
    self.recoveryPauseFrames = ArmoredEnemy.RECOVERY_PAUSE_FRAMES
end

function ArmoredEnemy:updateStun()
    ArmoredEnemy.super.updateStun(self)
    if self.recoveryPauseFrames and self.recoveryPauseFrames > 0 then
        self.recoveryPauseFrames -= 1
        if self.recoveryPauseFrames == 0 then
            self:finishRecovery()
        end
    end
end

function ArmoredEnemy:finishRecovery()
    self.recovering = false
    self.xVelocity = self.savedXVelocity or self.xVelocity
    self.canHurtPlayer = true
    -- after a slam the armor is gone, so the next stomp damages the enemy
    if self.jumpProtected then
        self:changeState("patrol")
    else
        self:changeState("hurt")
    end
end

function ArmoredEnemy:setupAnimations()
    self:addState("patrol", 1, 4, {tickStep = 4})
    self:addState("stunned", 5, 6, {tickStep = 2, loop = false})
    -- plays 6 -> 5 once, holds on frame 5, then starts the pause timer
    self:addState("recovering", 5, 6, {
        tickStep = 4,
        reverse = true,
        loop = false,
        onAnimationEndEvent = function(self) self:beginRecoveryPause() end,
    })
    self:addState("hurt", 7, 10, {tickStep = 4})
    self:addState("stunnedFromSlam", 10, 11, {tickStep = 2, loop = false})
    self:addState("recoveringFromSlam", 10, 11, {
        tickStep = 4,
        reverse = true,
        loop = false,
        onAnimationEndEvent = function(self) self:beginRecoveryPause() end,
    })
end
