
---@class ArmoredEnemy : PatrolEnemy
ArmoredEnemy = {}
class("ArmoredEnemy").extends(PatrolEnemy)

ArmoredEnemy.ARMORED_ENEMY_SHEET = "images/enemies/armoredEnemy/armored-enemy-table-16-16"

ArmoredEnemy.STUN_FRAMES = 45  -- ~1.5s at Playdate's default 30 fps

function ArmoredEnemy:init(x, y, entity)
    ArmoredEnemy.super.init(self, x, y, entity, ArmoredEnemy.ARMORED_ENEMY_SHEET)
    self.jumpProtected = true
end

function ArmoredEnemy:stun(frames)
    ArmoredEnemy.super.stun(self, frames)
    self.recovering = false
    self:changeState("stunned")
end

function ArmoredEnemy:recoverFromStun()
    self.stunFrames = 0
    self.recovering = true
    self:changeState("recovering")
    -- still frozen and still harmless until the animation ends
end

function ArmoredEnemy:finishRecovery()
    self.recovering = false
    self.xVelocity = self.savedXVelocity or self.xVelocity
    self.canHurtPlayer = true
    self:changeState("idle")
end

function ArmoredEnemy:setupAnimations()
    self:addState("idle", 1, 4, {tickStep = 4})
    -- switch animation to a different animation when the enemy removes their helmet
    self:addState("stunned", 5, 6, {tickStep = 2, loop = false})
    self:addState("recovering", 5, 6, {
        tickStep = 4,
        reverse = true,
        loop = false,
        onAnimationEndEvent = function(self) self:finishRecovery() end,
    })
end