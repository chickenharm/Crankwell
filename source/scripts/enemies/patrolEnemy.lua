local gfx <const> = playdate.graphics
local enemyImage <const> = gfx.image.new("images/enemies/enemy")


--- @class PatrolEnemy : Enemy
PatrolEnemy = {}
class("PatrolEnemy").extends(Enemy)

PatrolEnemy.SHEET = "images/enemies/enemy-table-16-16"

function PatrolEnemy:update()
    local prevX, prevY = self:getPosition()
    PatrolEnemy.super.update(self)
    self:patrol(prevX, prevY)
end

function PatrolEnemy:patrol(prevX, prevY)
    local x, y = self:getPosition()

    local dx, dy = x - prevX, y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self.distanceTraveled = 0
    end
end
