
---@class ArmoredEnemy : PatrolEnemy
ArmoredEnemy = {}
class("ArmoredEnemy").extends(PatrolEnemy)

ArmoredEnemy.ARMORED_ENEMY_SHEET = "images/enemies/armoredEnemy/armored-enemy-table-16-16"

ArmoredEnemy.STUN_FRAMES = 45  -- ~1.5s at Playdate's default 30 fps

function ArmoredEnemy:init(x, y, entity)
    ArmoredEnemy.super.init(self, x, y, entity, ArmoredEnemy.ARMORED_ENEMY_SHEET)
    self.jumpProtected = true
    self.stunFrames = 0
end

function ArmoredEnemy:damageEnemy(isSlam)
    if isSlam then
        -- slam actually kills it
        ArmoredEnemy.super.damageEnemy(self)
    elseif self.stunFrames <= 0 then
        self:stun()
    end
end

function ArmoredEnemy:stun()
    self.canHurtPlayer = false
    self.stunFrames = ArmoredEnemy.STUN_FRAMES
    self.savedXVelocity = self.xVelocity
    self.xVelocity = 0
    self:changeState("stunned")
end

function ArmoredEnemy:recoverFromStun()
    self.xVelocity = self.savedXVelocity
    self:changeState("idle")
end

function ArmoredEnemy:update()
    if self.stunFrames > 0 then
        self.stunFrames -= 1
        if self.stunFrames == 0 then
            self:recoverFromStun()
        end
    end
    ArmoredEnemy.super.update(self)
end

function ArmoredEnemy:setupAnimations()
    self:addState("idle", 1, 4, {tickStep = 4})
    -- switch animation to a different animation when the enemy removes their helmet
     self:addState("stunned", 1, 4, {tickStep = 4})
end