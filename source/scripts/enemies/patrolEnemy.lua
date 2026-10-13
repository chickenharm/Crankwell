local gfx <const> = playdate.graphics
local enemyImage <const> = gfx.image.new("images/enemies/enemy")


--- @class PatrolEnemy : Enemy
PatrolEnemy = {}
class("PatrolEnemy").extends(Enemy)

function PatrolEnemy:init(x, y, entity)
    PatrolEnemy.init(self, x, y, entity)

    
end



function PatrolEnemy:patrol()
    local x, y = self:getPosition()
    local prevX, prevY = self:getPosition()
    local prevXVel, prevYVel = self.xVelocity, self.yVelocity

    local dx, dy = x - prevX, y - prevY
    self.distanceTraveled += math.sqrt(dx * dx + dy * dy)

    if self.maxDistance and self.maxDistance > 0 and self.distanceTraveled >= self.maxDistance then
        self.xVelocity *= -1
        if not self.affectedByGravity then self.yVelocity *= -1 end
        self.distanceTraveled = 0
    end
end

function PatrolEnemy:update()
    PatrolEnemy.super.update(self)
    self.patrol(self)
end