local gfx <const> = playdate.graphics

--- @class FlyingEnemy : Enemy
FlyingEnemy = {}
class("FlyingEnemy").extends(Enemy)

FlyingEnemy.FLYING_ENEMY_SHEET = "images/enemies/flyingEnemy/flying-enemy-table-16-16"

FlyingEnemy.DEFAULT_AMPLITUDE = 20     -- pixels above/below the starting height
FlyingEnemy.DEFAULT_FREQUENCY = 0.05   -- radians of oscillation advanced per frame

function FlyingEnemy:init(x, y, entity)
    FlyingEnemy.super.init(self, x, y, entity, FlyingEnemy.FLYING_ENEMY_SHEET)

    local fields = entity.fields
    self.affectedByGravity = false   -- flying enemies never fall
    self.fallSpeed = 0

    self.baseY = y
    self.oscillationAmplitude = fields.oscillationAmplitude or FlyingEnemy.DEFAULT_AMPLITUDE
    self.oscillationFrequency = fields.oscillationFrequency or FlyingEnemy.DEFAULT_FREQUENCY
    self.oscillationAngle = 0
end

-- Replaces falling with a smooth sine-wave bob. The derivative of
-- y = baseY + amplitude * sin(angle) is used as the velocity so the
-- motion stays smooth frame to frame.
function FlyingEnemy:applyGravity()
    self.oscillationAngle += self.oscillationFrequency
    self.yVelocity = self.oscillationAmplitude * self.oscillationFrequency
        * math.cos(self.oscillationAngle)
end

function FlyingEnemy:setupAnimations()
      self:addState("patrol", 1, 3, {tickStep = 4})
end
