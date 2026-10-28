
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
    self:changeState("stunned")
end

function ArmoredEnemy:setupAnimations()
    self:addState("idle", 1, 4, {tickStep = 4})
    -- switch animation to a different animation when the enemy removes their helmet
    self:addState("stunned", 5, 6, {tickStep = 2, loop = false})
end